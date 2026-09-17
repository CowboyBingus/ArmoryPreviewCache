local root=assert(arg[1])
local native=dofile(root..'/src/image_native.lua')
local function bytes(hex)return(hex:gsub('..',function(v)return string.char(tonumber(v,16))end))end
local function old_key(b)return b:sub(9,20)..b:sub(25,40)..b:sub(49,56)..b:sub(65,72)..b:sub(85,104)end
local function change(b,offset)return b:sub(1,offset)..string.char((b:byte(offset+1)+1)%256)..b:sub(offset+2)end
for _,example in ipairs(dofile(root..'/tests/image_key_fixture.lua'))do
    local early,done=bytes(example.early),bytes(example.done)
    assert(old_key(early)~=old_key(done),'Fixture must reproduce the actual v5 miss')
    local key=native.key('layout',early,'grid and style')
    assert(key==native.key('layout',done,'grid and style'),'Cached item must match BEFORE native camera preparation')
    for _,offset in ipairs({24,32,48,64,68,88,92,96,100})do
        assert(key~=native.key('layout',change(early,offset),'grid and style'),'Visual identity and stable camera inputs must remain distinct')
    end
    assert(key~=native.key('other layout',early,'grid and style'))
    assert(key~=native.key('layout',early,'other camera style'))
end
print('PASS: actual helmet/armor pre-generation inputs miss v5 but match v6; visual IDs, overrides, dimensions, stable camera inputs, grid/style and layout remain distinct')
