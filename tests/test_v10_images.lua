-- Native destroys its working atlas on layout switches. Exercise all eight
-- requested surfaces with the production image policy and a lifecycle model.
local root=assert(arg[1]);local images=dofile(root..'/src/images.lua')
local s;local alive={};local calls=0;local shown={};local a={}
function a:snapshot()return s end
function a:prune()end
function a:restore()shown={}end
function a:destroy(t)assert(t.handle~=s.atlas and alive[t.handle]);alive[t.handle]=nil end
function a:capture(row)
    local entries={};for _,item in ipairs(row.items)do if item.ready then entries[item.key]={uv=item.key}end end
    return {atlas=row.atlas,layout=row.layout,bytes=row.bytes,entries=entries}
end
function a:freeze(row,p)
    assert(alive[p.atlas] and (row.can_freeze or row.can_freeze_idle))
    calls=calls+1;local fresh='fresh-'..calls;alive[fresh]=true
    return {handle=p.atlas,replacement=fresh,bytes=p.bytes}
end
function a:apply(row,entries)
    local hits=0
    for _,w in ipairs(row.widgets)do
        local e=entries[w.key]
        if e then assert(alive[e.texture.handle],'No cache entry may reference a destroyed atlas');shown[w.key]=true;hits=hits+1 end
    end
    return hits,#row.widgets-hits,row.complete and 0 or hits
end
local cache=images.new(a,{})
local surfaces={'helmet','armor','cape','primary','secondary','throwable','weapon_preselect','cosmetic_preselect'}
local generation=0
local function request(name,ready)
    if s then alive[s.atlas]=nil end -- native resize destroys only its current working texture
    generation=generation+1
    local atlas='native-'..name..generation;alive[atlas]=true
    local pre=name:find('preselect')~=nil
    s={context='world',screen=pre and name or 'grid',atlas=atlas,layout=name,bytes=12*1024*1024,
        capture_id=atlas..name,items={},widgets={},complete=ready,can_freeze_idle=ready,can_freeze=false}
    for i=1,(pre and 3 or 5)do
        local key=name..i;s.items[#s.items+1]={key=key,ready=ready};s.widgets[#s.widgets+1]={key=key}
    end
end
for _,name in ipairs(surfaces)do
    request(name,true);cache:tick(false)
    assert(cache.pending_items==0,'Fully completed pixels must be retained before the next switch')
    for _,w in ipairs(s.widgets)do assert(shown[w.key],'Idle detachment must rebind in the same callback')end
end
assert(cache.idle_retained==8 and #cache.textures==8 and cache.bytes==96*1024*1024)
for _,name in ipairs(surfaces)do
    request(name,false);cache:tick(false)
    assert(cache.last_hits==#s.widgets and cache.last_early_hits==#s.widgets,'Every surface hits before new native generation')
end
assert(cache.preselect_hits==12 and cache.pending_drops==0)
request('new_scroll_page',true);cache:tick(false)
assert(cache.idle_retained==9 and cache.evicted==1 and #cache.textures==8,'A full cache must admit new work through bounded eviction')
cache:clear();assert(cache.bytes==0 and #cache.textures==0)
print('PASS: all six grids and both three-slot pre-select screens survive destructive layout switches; same-callback idle presentation; early revisit hits; eight-atlas LRU; cleanup')
