return function(base)
    local ffi=require('ffi')
    ffi.cdef[[
        uint64_t GetTickCount64(void);
        uint32_t GetCurrentThreadId(void);
        uint32_t GetCurrentProcessId(void);
        int GetProcessTimes(void *,void *,void *,void *,void *);
        int GlobalMemoryStatusEx(void *status);
        int K32GetProcessMemoryInfo(void *process,void *counters,uint32_t size);
    ]]
    local kernel=ffi.load('kernel32');local api=base()
    local main_thread=kernel.GetCurrentThreadId()
    function api.time()return tonumber(kernel.GetTickCount64())/1000 end
    function api.assert_thread()assert(kernel.GetCurrentThreadId()==main_thread,'Wrong update thread')end
    local process_times=ffi.new('uint64_t[4]')
    assert(kernel.GetProcessTimes(kernel.GetCurrentProcess(),process_times,process_times+1,process_times+2,process_times+3)~=0)
    api.process_id=tonumber(kernel.GetCurrentProcessId())
    local creation_words=ffi.cast('uint32_t *',process_times)
    api.process_created_filetime_hex=string.format('%08x%08x',tonumber(creation_words[1]),tonumber(creation_words[0]))
    local memory=ffi.new('uint64_t[8]');local process_memory=ffi.new('uint64_t[10]')
    local function dword(array,value)ffi.cast('uint32_t *',array)[0]=value end
    -- Anonymous function ctypes are not collected by LuaJIT. Creating these
    -- casts per poll exhausted its type table after about 8,163 memory polls.
    local global=ffi.cast('int (*)(void *)',kernel.GlobalMemoryStatusEx)
    local private=ffi.cast('int (*)(void *,void *,uint32_t)',kernel.K32GetProcessMemoryInfo)
    function api.memory()
        dword(memory,64);dword(process_memory,80)
        assert(global(memory)~=0 and private(kernel.GetCurrentProcess(),process_memory,80)~=0,'Memory telemetry unavailable')
        -- MEMORYSTATUSEX: available physical RAM at +16, available commit at +32.
        return tonumber(memory[2]),tonumber(process_memory[9]),tonumber(memory[4])
    end
    local original=api.read
    function api.read(address,size)
        if type(size)~='number' or size<1 or size>32768 or size%1~=0 then return nil end
        return original(address,size)
    end
    return api
end
