local root=assert(arg[1]);local policy=dofile(root..'/src/policy.lua')
local profile=dofile(root..'/src/profile.lua')
local function item(kind,n)return {kind=kind,id=string.format('%016x',n)}end
local function adapter()
    local a={refs={},order={}}
    function a:resolve(i)return i.id end
    function a:valid_leases(ls)for id in pairs(ls)do if not self.refs[id]then return false end end;return true end
    function a:acquire(id)self.refs[id]=(self.refs[id] or 0)+1;self.order[#self.order+1]=id;return true end
    function a:release(id)assert(self.refs[id]);self.refs[id]=self.refs[id]-1 end
    return a
end
local a=adapter();local c=policy.new(a);local capes={}
for i=1,37 do capes[i]=item(4,i);c:remember(capes[i])end
for i=1,150 do c:remember(item(2,1000+i))end
local s={owner='A',world='menu',menu=true,active=true,blocked=false,items=capes}
c:tick(s,0,false)
local encoded=profile.encode(c:profile(),'build')
local b=adapter();local cold=policy.new(b)
for _,i in ipairs(profile.decode(encoded,'build'))do cold:remember(i)end
local startup={owner='A',world='ship',menu=false,prefetch=true,active=false,items={}}
for i=0,31 do cold:tick(startup,i*.05,false)end
for _,i in ipairs(capes)do assert(cold.leases[i.id],'BUG: recently revisited capes lose prewarm priority to old insertion order')end
assert(b.order[1]==capes[1].id,'Preserve foreground order within the recent group')
assert(cold.startup_acquires==128 and #b.order==128,'Recency must not increase startup budgets')
local stable=profile.encode(c:profile(),'build')
for i=1,50 do c:tick(s,i*.05,false)end
assert(profile.encode(c:profile(),'build')==stable,'Stable menu must not churn profile ordering')
-- Repeated observations keep one entry and preserve learned customization.
local weapon=item(0,9000);weapon.attachments={'000000000000aabb'}
c:remember(weapon);c:remember(item(2,9001));c:remember(item(0,9000))
local p=c:profile();assert(p[#p].id==weapon.id and p[#p].attachments[1]==weapon.attachments[1])
local n=0;for _,i in ipairs(p)do if i.id==weapon.id then n=n+1 end end;assert(n==1)
for i=1,300 do c:remember(item(3,10000+i))end
c:remember(weapon);assert(#c:profile()==192 and c:profile()[192].id==weapon.id)
cold:clear();c:clear()
-- All grids and both mixed pre-select groups use this same policy. Primary and
-- secondary share native kind 0 but retain separate semantic item identities.
local surfaces={
    {'primary',{0,0,0}}, {'secondary',{0,0,0}}, {'throwable',{1,1,1}},
    {'helmet',{2,2,2}}, {'armor',{3,3,3}}, {'cape',{4,4,4}},
    {'weapon_preselect',{0,0,1}}, {'cosmetic_preselect',{3,2,4}},
    {'briefing_loadout',{2,3,4,0,0,1}},
    {'briefing_primary',{0,0,0}}, {'briefing_secondary',{0,0,0}},
    {'briefing_throwable',{1,1,1}}, {'briefing_helmet',{2,2,2}},
    {'briefing_armor',{3,3,3}}, {'briefing_cape',{4,4,4}},
}
for _,surface in ipairs(surfaces)do
    local source=policy.new(adapter());local group={}
    for i,kind in ipairs(surface[2])do
        group[i]=item(kind,100+i);source:remember(group[i])
    end
    for i=1,150 do source:remember(item(2,1000+i))end
    source:tick({owner='A',world='menu',menu=true,active=true,items=group},0,false)
    local target_adapter=adapter();local target=policy.new(target_adapter)
    for _,i in ipairs(profile.decode(profile.encode(source:profile(),'build'),'build'))do target:remember(i)end
    for tick=0,1 do target:tick(startup,tick*.05,false)end
    for i,request in ipairs(group)do
        assert(target.leases[request.id],surface[1]..' must get early startup priority')
        assert(target_adapter.order[i]==request.id,surface[1]..' must keep foreground order')
    end
    source:clear();target:clear()
end
print('PASS: recency applies to primary/secondary/throwable/helmet/armor/cape and both pre-select groups; 37-cape revisit survives old-category competition; profile roundtrip and foreground order; no stable-menu churn; unique entries/custom attachments; unchanged bounds')
