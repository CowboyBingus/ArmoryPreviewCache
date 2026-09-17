local root=assert(arg[1])
local images=dofile(root..'/src/images.lua')
local adapter={restores=0,destroys=0,freezes=0}
local s
function adapter:snapshot()return s end
function adapter:restore()self.restores=self.restores+1 end
function adapter:prune()end
function adapter:capture(row)
    local entries={};for _,v in ipairs(row.items)do entries[v.key]={uv='uv-'..v.key}end
    return {atlas=row.atlas,layout=row.layout,bytes=row.bytes,entries=entries}
end
function adapter:freeze(row,candidate)
    assert(row.can_freeze and row.atlas==candidate.atlas)
    self.freezes=self.freezes+1
    return {handle=candidate.atlas,replacement='fresh-'..self.freezes,bytes=candidate.bytes}
end
function adapter:apply(row,entries)
    local h,m=0,0
    for _,w in ipairs(row.widgets)do
        if entries[w.key]then assert(entries[w.key].uv=='uv-'..w.key);h=h+1 else m=m+1 end
    end
    return h,m
end
function adapter:destroy(texture)
    assert(texture.handle~=s.atlas,'The native working atlas must never be freed')
    self.destroys=self.destroys+1
end
local function row(atlas,key,complete,early)
    return {context='world',atlas=atlas,layout='layout',bytes=12*1024*1024,
        capture_id=atlas..key,items={{key=key,ready=complete}},widgets={{key=key}},complete=complete,can_freeze=early}
end
local cache=images.new(adapter,{})
s=row('native-a','helmet',true,false);cache:tick(false)
assert(cache.retained==0 and cache.last_hits==0,'A completed atlas remains game-owned until handoff')
cache:before();s=row('native-a','armor',false,true);cache:tick(false)
assert(cache.retained==1 and cache.entries.helmet and cache.last_hits==0)
s=row('fresh-1','armor',true,false);cache:before();cache:tick(false)
s=row('fresh-1','helmet',false,true);cache:before();cache:tick(false)
assert(cache.retained==2 and cache.last_hits==1,'Repeat must bind a retained helmet while native generation is incomplete')
assert(not s.complete,'Cache hits must not forge native completion')
s=row('fresh-2','helmet',true,false);cache:before();cache:tick(false)
s=row('fresh-2','armor',false,true);cache:before();cache:tick(false)
assert(cache.retained==2 and cache.last_hits==1,'An already-cached category must not retain another atlas')
-- A late callback cannot claim that overwritten pixels are immutable.
s=row('fresh-2','cape',true,false);cache:tick(false)
s=row('fresh-2','weapon',false,false);cache:tick(false)
assert(cache.retained==2 and cache.late_switches==1 and not cache.entries.cape)
-- Layout changes invalidate candidates and keys before handoff.
s=row('fresh-2','cape',true,false);s.capture_id='new-cape';cache:tick(false)
s=row('fresh-2','weapon',false,true);s.layout='resized';cache:tick(false)
assert(cache.retained==2 and not cache.entries.cape)
-- Pressure releases only detached textures and keeps original presentation.
cache:before();cache:tick(true)
assert(cache.bytes==0 and #cache.textures==0 and adapter.destroys==2)
-- A reused world must not serve images from the former context.
s=row('new-working','helmet',true,false);cache:tick(false)
s=row('new-working','armor',false,true);cache:tick(false)
s=row('fresh-3','helmet',false,false);s.context='new-world';cache:tick(false)
assert(cache.last_hits==0 and cache.bytes==0)
-- Bound memory; no unbounded allocation when eight atlases have been retained.
for i=1,10 do
    s=row('working-'..i,'item-'..i,true,false);cache:tick(false)
    s=row('working-'..i,'next-'..i,false,true);cache:tick(false)
end
assert(#cache.textures==8 and cache.bytes==96*1024*1024)
cache:clear();assert(cache.bytes==0)
-- Allocation failure must leave the cache and game ownership unchanged.
local freeze=adapter.freeze;adapter.freeze=function()return nil end
s=row('failed-working','uncached',true,false);cache:tick(false)
s=row('failed-working','next',false,true);cache:tick(false)
assert(#cache.textures==0 and not cache.entries.uncached)
adapter.freeze=freeze
-- Menu/view recreation invalidates unfinished capture metadata, not detached
-- entries. Never freeze a candidate collected from the departed controller.
local before_view_freezes=adapter.freezes
s=row('view-working','uncached-view',true,false);s.view='old-controller-world';cache:tick(false)
assert(cache.pending_items==1)
s=row('view-working','new-view',false,true);s.view='new-controller-world';cache:tick(false)
assert(adapter.freezes==before_view_freezes and not cache.entries['uncached-view'])
print('PASS: finished-image revisit before native completion; early-only handoff; late/resize rejection; duplicate suppression; world invalidation; restoration; pressure cleanup; eight-atlas budget; allocation failure')
