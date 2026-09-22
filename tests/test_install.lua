local root=assert(arg[1])
local install=dofile(root..'/src/install.lua')
local profile=dofile(root..'/src/profile.lua')
local policy=dofile(root..'/src/policy.lua')
local function scenario(mode)
    local files,clock,cleared,updates,shutdowns={},0,0,0,0
    local in_menu,log_opens=true,0
    local image_ticks,image_restores,image_clears=0,0,0
    local adapter={}
    function adapter:valid_leases()return true end
    function adapter:resolve(i)return i.id end
    function adapter:acquire()return true end
    function adapter:release()cleared=cleared+1;return true end
    function adapter:snapshot()
        if mode=='snapshot' then error('transient unavailable')end
        return {owner='o',world='w',menu=in_menu,active=in_menu,top=in_menu and 5 or 1,items={{kind=2,id='0000000000000001'}}}
    end
    local env=setmetatable({CowboyBingusModLoader={api=1}}, {__index=_G});env._G=env
    env.os={getenv=function()return 'fixture'end,remove=function(p)files[p]=nil;return true end,
        rename=function(a,b)if files[a]then files[b]=files[a];files[a]=nil;return true end end}
    env.io={open=function(path,how)
        if how=='rb' then
            if not files[path]then return nil end
            return {read=function(_,n)return files[path]:sub(1,n)end,close=function()end}
        end
        files[path]=''
        return {write=function(self,...)
            for i=1,select('#',...)do files[path]=files[path]..tostring(select(i,...))end;return self
        end,close=function()end}
    end}
    env.CowboyBingusDiagnostics=mode=='normal' or mode=='growth'
    env.CowboyBingusModLoader.open_log=function(name)
        log_opens=log_opens+1
        assert(name=='ArmoryPreviewCache.log')
        return env.io.open('fixture/CowboyBingus/Helldivers2/Logs/'..name,'w')
    end
    if mode=='off'then files['fixture/ArmoryPreviewCache.ini']='enabled=0'end
    if mode=='normal'then files['fixture/ArmoryPreviewCache.ini']='disk=1'end
    env.update=function(dt,marker)
        updates=updates+1;assert(marker=='marker')
        if mode=='original'then error('original failure')end
        return 1,nil,3
    end
    env.shutdown=function()shutdowns=shutdowns+1;return 'shutdown-result'end
    local api={assert_thread=function()end,module=function(n)return n or 'exe'end,
        module_hash=function()return mode=='build' and 'wrong' or 'hash'end,
        process_id=42,process_created_filetime_hex='01dd46d0dd8ae445',
        time=function()return clock end,memory=function()return 8*1024^3,(mode=='growth' and updates or 1)*1024^3,16*1024^3 end}
    local fn=setfenv(assert(loadfile(root..'/src/install.lua')),env)()
    local image_adapter={}
    local image_policy={new=function(a)
        assert(a==image_adapter)
        return {enabled=true,status='fixture',textures={},
            before=function()image_restores=image_restores+1 end,
            clear=function()image_clears=image_clears+1 end,
            tick=function()image_ticks=image_ticks+1 end}
    end}
    local dependency_module={new=function()error('Native adapter owns dependency initialization')end}
    fn(function()return api end,{new=function(_,_,_,_,d)assert(d==dependency_module);return adapter end},policy,profile,{},
       {revision='test',game_sha256='hash',exe_sha256='hash'},
       {new=function()return image_adapter end},image_policy,{},
       dependency_module)
    local wrapper=env.update
    fn(function()error('duplicate init')end,nil,nil,nil,nil,nil)
    assert(env.update==wrapper,'Duplicate import must not wrap again')
    if mode=='original'then
        assert(not pcall(env.update,.1,'marker'));assert(env.ArmoryPreviewCache.status=='original_update_failed')
    else
        local a,b,c=env.update(.1,'marker');assert(a==1 and b==nil and c==3)
        clock=3
        assert(select('#',env.update(.1,'marker'))==3)
        if mode=='normal' or mode=='growth' or mode=='quiet'then
            assert(env.ArmoryPreviewCache.status=='foreground_lookahead')
            assert(not files['fixture/ArmoryPreviewCache.profile'],'active menu must defer profile IO')
            assert(image_ticks==2 and image_restores==1)
            env.update(.001,'marker')
            assert(image_ticks==3 and image_restores==2,'Image binding must run below the asset polling interval')
            if mode=='quiet' then
                for i=1,600 do clock=3+i/60;env.update(1/60,'marker')end
                assert(log_opens==1,'idle and menu frames must not rewrite routine logs')
                assert(not files['fixture/ArmoryPreviewCache.profile'],'interaction cannot save profiles')
            else
                local log=assert(files['fixture/CowboyBingus/Helldivers2/Logs/ArmoryPreviewCache.log'])
                assert(log:find('rendered_image_cache=1',1,true))
                assert(log:find('disk_status=removed_after_v7_crash',1,true))
            end
            in_menu=false;clock=clock+6;env.update(.1,'marker')
            assert(files['fixture/ArmoryPreviewCache.profile']:find('2:0000000000000001',1,true),
                   'deferred profile is saved after menu exit')
        elseif mode=='build'then assert(env.ArmoryPreviewCache.status:find('Unsupported game build',1,true))
        elseif mode=='off'then assert(env.ArmoryPreviewCache.status=='disabled_by_config')
        elseif mode=='snapshot'then assert(env.ArmoryPreviewCache.status=='waiting_for_ui')end
    end
    assert(env.shutdown()=='shutdown-result' and shutdowns==1)
    assert(cleared==((mode=='normal' or mode=='growth' or mode=='quiet') and 1 or 0))
    if mode=='normal' or mode=='growth' or mode=='quiet'then assert(image_clears==1,'Image resources must be cleaned up on shutdown')end
end
for _,mode in ipairs({'normal','quiet','growth','build','off','snapshot','original'})do scenario(mode)end
local host=setmetatable({tostring=function(v)
    if type(v)=='cdata'then return '[cdata (deleted)]'end
    return tostring(v)
end},{__index=_G})
local platform=setfenv(assert(loadfile(root..'/src/platform.lua')),host)()(dofile(root..'/src/read_api.lua'))
assert(#platform.process_created_filetime_hex==16 and platform.process_created_filetime_hex:match('^[0-9a-f]+$'))
platform.assert_thread();local free,private,commit=platform.memory();assert(free>0 and private>0 and commit>0 and platform.time()>0)
-- The former per-poll FFI casts deterministically failed after ~8,163 calls.
for i=1,50000 do platform.memory()end
print('PASS: 50000 memory polls without exhausting the LuaJIT type table')
print('PASS: update return arity, duplicate load, shutdown cleanup, original error propagation, unsupported build, disable switch, transient UI absence, profile save and Windows memory telemetry')

-- The real asset adapter skips thumbnail data outside menu/prewarm states.
do
    local ffi=require('ffi');local native=dofile(root..'/src/native.lua')
    local function ptr(n)return ffi.cast('uint8_t *',n)end
    local function addr(p)return tonumber(ffi.cast('uintptr_t',p))end
    local function u64(n)local p=ffi.new('uint64_t[1]',n);return ffi.string(p,8)end
    local G,E=0x100000,0x200000;local UI,SM,HOLDER=0x300000,0x400000,0x500000
    local A,OWNER,WORLD=0x600000,0x700000,0x800000
    local cells={
        [G+0x276c020]=u64(E+0x27ccc20),[E+0x27ccc20+16]=u64(A),
        [A+752]=u64(E+0x31ff80),[A+768]=u64(E+0x3201e0),
        [G+0x277fee8]=u64(OWNER),[OWNER+16416]=u64(HOLDER),
        [G+0x277fe60]=u64(SM),[G+0x277fdc8]=u64(UI),[UI+15424]=u64(WORLD),
        [UI+15884]=string.rep('\0',4)}
    local header=ffi.new('uint32_t[8]');header[2]=1024;header[6]=2
    ffi.copy(header,u64(OWNER+32),8);cells[OWNER]=ffi.string(header,32)
    local top,depth=1,1
    local function stack()
        local b=ffi.new('uint32_t[6]');b[0]=top;b[5]=depth;return ffi.string(b,24)
    end
    local api={read=function(p,n)
        local a=addr(p)
        assert(a~=G+0x277fdb8,'thumbnail reached')
        if a==SM+140 then return stack()end
        return assert(cells[a],'unexpected native read')
    end,pointer=function(b,o)
        if not b then return nil end
        local p=ffi.new('uint64_t[1]');ffi.copy(p,b:sub((o or 0)+1,(o or 0)+8),8)
        return p[0]~=0 and ptr(p[0]) or nil
    end}
    local adapter=native.new(api,ptr(G),ptr(E),{})
    local s=adapter:snapshot()
    assert(not s.menu and not s.prefetch and #s.items==0 and s.owner and s.world,
           'inactive UI must preserve lease identity without reading thumbnails')
    top=5;local ok,why=pcall(adapter.snapshot,adapter)
    assert(not ok and tostring(why):find('thumbnail reached',1,true),'Armory path must remain active')
    depth=0;ok,why=pcall(adapter.snapshot,adapter)
    assert(not ok and tostring(why):find('thumbnail reached',1,true),'startup prewarm must remain active')
end
print('PASS: inactive native thumbnail reads skipped; Armory and startup prewarm paths retained')
