-- Read-only reproduction of the native default-attachment/package lookups.
-- Never calls the allocating configuration builders or edits preview slots.
local ffi=require('ffi')
local bit=require('bit')
local M={}
local dword=ffi.new('uint32_t[1]');local qword=ffi.new('uint64_t[1]')
local zero=string.rep('\0',8)
local function u32(b,o)ffi.copy(dword,b:sub(o+1,o+4),4);return tonumber(dword[0])end
local function raw(b,o)return b:sub(o+1,o+8)end
local function hex(b)return(b:reverse():gsub('.',function(v)return string.format('%02x',v:byte())end))end
local function unhex(s)return(s:gsub('..',function(v)return string.char(tonumber(v,16))end)):reverse()end
function M.new(api,game)
    local function read(p,n)local bytes=assert(api.read(p,n),'Dependency memory unavailable');return bytes end
    local function ptr(p)local value=assert(api.pointer(read(p,8)),'Dependency pointer unavailable');return value end
    local self={defaults={},attachments={},identity=nil,known_weapons={}}
    function self:refresh()
        local database=ptr(game+0x346bf98);local definitions=ptr(database+0xf12e10)
        local groups=u32(read(game+0x348da98,4),0)
        assert(groups>0 and groups<=64,'Attachment group bounds')
        local gp=read(game+0x37c5b50,groups*8)
        local map=read(game+0x3799810,28)
        local storage=assert(api.pointer(map));local count=u32(map,8)
        assert(count>0 and count<=262144 and bit.band(count,count-1)==0,'Package mapping bounds')
        local headers,identity={},read(database+0xf12e10,8)..gp..map
        for i=0,groups-1 do
            local h=read(assert(api.pointer(gp,i*8)),16)
            assert(u32(h,8)<=4096,'Attachment row bounds')
            headers[#headers+1]=h;identity=identity..h
        end
        if self.identity==identity then return end
        local by_number,by_hash={},{}
        local total=0
        local function package(id)
            ffi.copy(qword,id,8)
            local start=tonumber((qword[0]*u32(map,24))%count)
            for probe=0,math.min(count,256)-1 do
                local row=read(storage+((start+probe)%count)*16,16)
                if raw(row,0)==id then return raw(row,8)~=zero and hex(raw(row,8)) or nil end
                if raw(row,0)==raw(map,16)then return nil end
            end
            return nil -- Bounded unresolved lookup, never an invented package.
        end
        for _,h in ipairs(headers)do
            local n=u32(h,8);total=total+n;assert(total<=8192,'Attachment catalogue bound')
            local rows=n>0 and assert(api.pointer(h)) or nil
            for first=0,n-1,256 do
                local amount=math.min(256,n-first);local bytes=read(rows+first*88,amount*88)
                for j=0,amount-1 do
                    local o=j*88;local id=raw(bytes,o+32)
                    if id~=zero then
                        local kinds={};local kn=u32(bytes,o+56)
                        assert(kn<=16,'Attachment kind bounds')
                        if kn>0 then
                            local kb=read(assert(api.pointer(bytes,o+48)),kn*4)
                            for k=0,kn-1 do kinds[u32(kb,k*4)]=true end
                        end
                        local entry={id=hex(id),package=package(id),kinds=kinds}
                        by_number[u32(bytes,o+8)]=entry;by_hash[entry.id]=entry
                    end
                end
            end
        end
        local defaults,known={},{}
        local buckets=read(definitions,648*16)
        local fallback=read(game+0x213f2b8,320)
        for i=0,647 do
            local id=raw(buckets,i*16)
            if id~=zero then
                local index=u32(buckets,i*16+8);assert(index<324,'Weapon configuration index bounds')
                local config=read(definitions+10368+index*46600,120)
                local selected={}
                for j=0,9 do
                    local kind=u32(config,j*8)
                    if kind<1 or kind>9 then break end
                    if not selected[kind]then selected[kind]=by_number[u32(config,j*8+4)]end
                end
                local allowed={}
                for j=0,9 do local kind=u32(config,80+j*4);if kind==0 then break end;allowed[kind]=true end
                for kind=0,9 do if not selected[kind] and allowed[kind]then
                    local candidate=by_number[u32(fallback,kind*32)]
                    if candidate and candidate.kinds[kind]then selected[kind]=candidate end
                end end
                local entries={}
                for kind=0,9 do if selected[kind]then entries[#entries+1]=selected[kind].id end end
                defaults[hex(id)]=entries;known[hex(id)]=true
            end
        end
        self.defaults,self.attachments,self.known_weapons=defaults,by_hash,known
        self.identity=identity
    end
    function self:resolve(item)
        local result,seen={},{}
        local function add(ids)
            for _,id in ipairs(ids or {})do
                local a=self.attachments[id]
                if a and a.package and not seen[a.package]then
                    seen[a.package]=true;result[#result+1]=a.package
                end
            end
        end
        add(self.defaults[item.id]);add(item.attachments)
        return result
    end
    function self:queued()
        local p=ptr(game+0x347ce60);local ring=read(p+50448,8+128*200)
        local head,tail=u32(ring,0),u32(ring,4)
        assert(head<128 and tail<128,'Weapon queue bounds')
        local rows={}
        while head~=tail do
            local o=8+head*200;local n=u32(ring,o+80);assert(n<=10,'Weapon dependency count')
            local id=hex(raw(ring,o+64));local attachments,seen={},{}
            for j=0,n-1 do
                local a=hex(raw(ring,o+88+j*8))
                if self.attachments[a] and not seen[a]then attachments[#attachments+1]=a;seen[a]=true end
            end
            if self.known_weapons[id]then rows[id]=attachments end
            head=(head+1)%128
        end
        return rows
    end
    return self
end
return M
