-- A weapon pattern, attachment or any other loadout change does not alter the
-- native thumbnail request identity, so a cached crop can only be corrected by
-- adopting the pixels the native pipeline renders next. Exercise the production
-- image policy against a lifecycle model that re-renders the same keys.
local root=assert(arg[1]);local images=dofile(root..'/src/images.lua')
local s;local alive={};local calls=0;local shown={};local a={}
function a:snapshot()return s end
function a:prune()end
function a:restore()shown={}end
function a:drain()end
function a:destroy(t)assert(alive[t.handle],'Unknown atlas');alive[t.handle]=nil end
function a:capture(row)
    local entries={}
    for _,item in ipairs(row.items)do
        -- Production excludes completed cards whose region is the blank
        -- remainder of a hand-off, so model that contract here too.
        if item.ready and item.pixels_ready~=false then
            entries[item.key]={uv=item.key,preview=item.preview}
        end
    end
    return {atlas=row.atlas,layout=row.layout,bytes=row.bytes,entries=entries}
end
function a:freeze(row,p)
    assert(alive[p.atlas] and (row.can_freeze or row.can_freeze_idle),'Unsafe handoff')
    calls=calls+1;local fresh='fresh-'..calls;alive[fresh]=true
    return {handle=p.atlas,replacement=fresh,bytes=p.bytes}
end
function a:apply(row,entries)
    local hits=0
    for _,w in ipairs(row.widgets)do
        local e=entries[w.key]
        if e then assert(alive[e.texture.handle],'Entry referenced a destroyed atlas')
            shown[w.key]=true;hits=hits+1 end
    end
    return hits,#row.widgets-hits,row.complete and 0 or hits
end
local cache=images.new(a,{})
local function screen(atlas,ready,pixels_ready,capture_id,freeze_idle,preview)
    -- A native rebuild destroys only its own current working texture; detached
    -- crops owned by the mod stay alive until the mod releases them.
    if s then alive[s.atlas]=nil end
    s={context='world',view='view-1',screen='grid',atlas=atlas,layout='primary',
        bytes=12*1024*1024,capture_id=capture_id,items={},widgets={},
        complete=freeze_idle,can_freeze=false,can_freeze_idle=freeze_idle}
    for i=1,5 do
        s.items[#s.items+1]={key='p'..i,ready=ready,pixels_ready=pixels_ready,preview=preview}
        s.widgets[#s.widgets+1]={key='p'..i}
    end
end

-- 1. First render of the category is cached.
alive['native-1']=true;screen('native-1',true,true,'c1',true);cache:tick(false)
assert(#cache.textures==1 and cache.textures[1].handle=='native-1','First render must be retained')
assert(cache.refreshed==0 and cache.rendered_items==0,'Nothing is superseded on first capture')

-- 2. The same screen is rebuilt after a pattern/attachment change: identical
--    request keys, native re-queues the cards. Cached pixels still present.
alive['native-2']=true;screen('native-2',false,nil,'c2',false);cache:tick(false)
assert(cache.last_hits==5 and cache.last_early_hits==5,'Rebuilt screen must present retained crops immediately')
assert(cache.refreshed==0,'No adoption may happen before the native render completes')
assert(#cache.textures==1,'No second atlas may be retained while nothing is complete')

-- 3. The rebuild completes with the new appearance under the same keys.
alive['native-3']=true;screen('native-3',true,true,'c3',true);cache:tick(false)
assert(cache.refreshed==5,'Re-rendered keys must be adopted instead of served from the old crop')
assert(#cache.textures==1 and cache.textures[1].handle=='native-3','The superseded atlas must be released')
assert(alive['native-1']==nil and alive['native-2']==nil,'Superseded native atlases must not leak')
assert(cache.rendered_items==0,'Adopted keys must stop being reported as superseded')
assert(cache.last_hits==5,'Adoption must rebind the same widgets')

-- 4. Steady state: no repeated hand-off while the native render is unchanged.
local retained=cache.retained
for _=1,3 do cache:tick(false)end
assert(cache.retained==retained and #cache.textures==1,'An unchanged render must not churn the cache')
assert(cache.missing_ready_items==0,'A current crop must count as covered')

-- 5. A blank hand-off remainder is not a render: it must never be adopted.
alive['native-4']=true;screen('native-4',true,false,'c4',false);cache:tick(false)
assert(cache.rendered_items==0 and cache.refreshed==5,'Blank completed cards must not be captured')
assert(cache.blank_ready_items==5 and cache.last_hits==5,'Blank regions keep the retained presentation')
assert(#cache.textures==1 and cache.textures[1].handle=='native-3','Blank regions must not replace the cache')

-- 6. Once the native pipeline really re-renders those cards, the new pixels win.
alive['native-5']=true;screen('native-5',false,nil,'c5',false);cache:tick(false)
alive['native-6']=true;screen('native-6',true,true,'c6',true);cache:tick(false)
assert(cache.refreshed==10,'Re-rendered keys after a blank remainder must be adopted')
assert(cache.textures[1].handle=='native-6','The newest native render must be retained')

-- 7. Partial re-renders refresh the keys that completed without dropping the rest.
alive['native-7']=true
s={context='world',view='view-1',screen='grid',atlas='native-7',layout='primary',
    bytes=12*1024*1024,capture_id='c7',items={},widgets={},
    complete=false,can_freeze=false,can_freeze_idle=false}
for i=1,5 do
    local busy=i<=2
    s.items[#s.items+1]={key='p'..i,ready=not busy,pixels_ready=true}
    s.widgets[#s.widgets+1]={key='p'..i}
end
cache:tick(false)
assert(cache.last_hits==5,'Partial re-renders must keep presenting retained crops')
alive['native-7']=nil;alive['native-8']=true
for _,item in ipairs(s.items)do item.ready=true end
s.atlas='native-8';s.capture_id='c8';s.complete=true;s.can_freeze_idle=true
cache:tick(false)
assert(cache.refreshed==12,'Every re-rendered key must be adopted once its render completes')
assert(cache.textures[1].handle=='native-8','The completed render must become the retained atlas')
cache:clear();assert(cache.bytes==0 and #cache.textures==0 and cache.refreshed==12)

-- 8. A pattern or attachment change does not change the request identity, so it
--    is detected from the configured slots the preview queue reports. The stale
--    crop must be retired at once instead of after the whole grid rebuilds.
alive['cfg-1']=true;screen('cfg-1',true,true,'d1',true,'slots-old')
cache:tick(false)
assert(cache.entries.p1.preview=='slots-old','The capture records the configured slots')
assert(cache.reappeared==0 and cache.changed_items==0)
alive['cfg-2']=true;screen('cfg-2',false,nil,'d2',false,'slots-new')
cache:tick(false)
assert(cache.changed_items==5 and cache.reappeared==5,'A slot change must retire the crop immediately')
assert(cache.last_hits==0,'A re-configured weapon must not be presented from its previous crop')
for i=1,5 do assert(not cache.entries['p'..i],'Retired crops must not survive')end
alive['cfg-3']=true;screen('cfg-3',true,true,'d3',true,'slots-new')
cache:tick(false)
assert(cache.entries.p1.preview=='slots-new','The re-render must be captured with the new slots')
assert(cache.changed_items==0,'Adopting the new appearance is not another change')

-- 9. An unchanged revisit still serves its crop without churn.
alive['cfg-4']=true;screen('cfg-4',false,nil,'d4',false,'slots-new')
cache:tick(false)
assert(cache.changed_items==0 and cache.last_hits==5,'Unchanged slots must keep serving the crop')

-- 10. An unobserved configuration must never retire a crop by itself.
alive['cfg-5']=true;screen('cfg-5',true,true,'d5',true,nil)
cache:tick(false)
assert(cache.changed_items==0,'A missing configuration must not retire a crop')
assert(cache.entries.p1.preview==nil,'An unobserved configuration is stored as unknown')

print('PASS: re-rendered request keys adopt their new pixels (weapon pattern/attachment change), '
    ..'retained presentation is unchanged during regeneration, blank hand-off remainders stay rejected, '
..'unchanged renders do not churn, partial re-renders converge, and a configured-slot change retires its '
..'stale crop at once while unobserved or unchanged slots keep serving it')
