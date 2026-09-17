-- Behavioral regression: a quick category visit has useful completed cards
-- even while offscreen cards are unfinished. No renderer calls in this test.
local root=assert(arg[1])
local images=dofile(root..'/src/images.lua')
local s
local a={freezes=0,events={}}
function a:snapshot()return s end
function a:restore()self.events[#self.events+1]='restore'end
function a:prune()end
function a:destroy()self.events[#self.events+1]='destroy'end
function a:capture(row)
    local e={}
    for _,i in ipairs(row.items)do if i.ready then e[i.key]={uv=i.key}end end
    if not next(e)then return end
    return {atlas=row.atlas,layout=row.layout,bytes=row.bytes,entries=e}
end
function a:freeze(row,p)
    assert(row.can_freeze and row.atlas==p.atlas)
    self.freezes=self.freezes+1
    return {handle=p.atlas,replacement='fresh-'..self.freezes,bytes=p.bytes}
end
function a:apply(row,entries)
    local hits=0
    for _,w in ipairs(row.widgets)do if entries[w.key]then hits=hits+1 end end
    return hits,#row.widgets-hits
end
local function row(atlas,request,ready,early)
    return {context='world',atlas=atlas,layout='layout',bytes=1024,
        capture_id=atlas..request,complete=ready==2,can_freeze=early,
        items={{key=request..'1',ready=ready>=1},{key=request..'2',ready=ready==2}},
        widgets={{key=request..'1'}}}
end
local cache=images.new(a,{})
s=row('native','cape',1,false);cache:tick(false)
s=row('native','armor',0,true);cache:tick(false)
assert(cache.entries.cape1 and not cache.entries.cape2,'Preserve the completed cape card without caching unfinished pixels')
assert(cache.retained==1)
s=row('fresh-1','cape',0,true);cache:tick(false)
assert(cache.last_hits==1,'A short revisit must use the completed card from the previous short visit')
-- Progress inside the same request must not detach a texture that native
-- rendering is still filling. Refresh metadata as additional cards finish.
s=row('fresh-1','helmet',1,false);cache:tick(false)
cache:tick(false);assert(a.freezes==1)
s=row('fresh-1','helmet',2,false);cache:tick(false)
assert(a.freezes==1)
s=row('fresh-1','armor',0,true);cache:tick(false)
assert(cache.entries.helmet1 and cache.entries.helmet2 and a.freezes==2)
-- Late request changes must never retain an already overwritten candidate.
s=row('fresh-2','weapon',1,false);cache:tick(false)
s=row('fresh-2','armor',0,false);cache:tick(false)
assert(not cache.entries.weapon1 and cache.late_switches==1)
-- Native restarting the same request can regress completion. Do not keep
-- stale readiness metadata across that restart.
s=row('fresh-2','weapon',1,false);cache:tick(false)
s=row('fresh-2','weapon',0,false);cache:tick(false)
s=row('fresh-2','armor',0,true);cache:tick(false)
assert(not cache.entries.weapon1)
-- Ship/pre-select can retain the world/atlas while the grid controller is gone.
s={context='world',atlas='fresh-2',layout='layout',items={},widgets={}}
cache:tick(false)
assert(cache.status=='waiting_for_thumbnail_screen' and cache.pending_items==0 and cache.entries.cape1)
-- Later completion replaces the earlier partial atlas without stranding its
-- GPU budget or freeing textures that still supply other entries.
s=row('fresh-2','cape',2,false);cache:tick(false)
local before_replace=#a.events
s=row('fresh-2','armor',0,true);cache:tick(false)
assert(cache.entries.cape1 and cache.entries.cape2 and cache.entries.helmet1)
assert(cache.released==1 and #cache.textures==2 and cache.bytes==2048)
assert(a.events[before_replace+1]=='restore' and a.events[before_replace+2]=='destroy','Unbind all references before freeing a superseded atlas')
print('PASS: short-visit completed-card retention; incomplete pixels excluded; same-request progress never detaches; refreshed completion metadata; late handoff rejection; readiness regression')
