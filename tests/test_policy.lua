local root=assert(arg[1])
local policy=dofile(root..'/src/policy.lua')
local profile=dofile(root..'/src/profile.lua')
local function item(i)return {kind=2,id=string.format('%016x',i)}end
local function setup(options)
    local a={refs={},calls=0,removed=0,owner='A'}
    function a:resolve(i)return i.kind<=4 and i.id or nil end
    function a:valid_leases(ls,o)
        if o~=self.owner then return false end
        for id in pairs(ls)do if not self.refs[id]then return false end end
        return true
    end
    function a:acquire(id,o)assert(o==self.owner);self.refs[id]=(self.refs[id] or 0)+1;self.calls=self.calls+1;return true end
    function a:release(id,o)assert(o==self.owner and self.refs[id]);self.refs[id]=self.refs[id]-1;self.removed=self.removed+1;return true end
    local c=policy.new(a,options)
    local s={owner='A',world='ship',menu=true,active=true,items={}}
    return c,a,s
end
local c,a,s=setup({limit=6,prewarm=false})
for i=1,6 do s.items[i]=item(i)end
-- Preserve the game's independent reference through every cache lifecycle.
a.refs[item(1).id]=1
c:tick(s,0,false);assert(c.acquires==4)
c:tick(s,.05,false);assert(c.acquires==6 and a.refs[item(1).id]==2)
c:tick(s,.1,false);assert(c.acquires==6,'Repeat grid must reuse held leases')
-- Native UI busy toggles during generation; it is not leaving the Armory.
for i=1,10 do
    s.blocked=true;c:tick(s,.1+i*.001,false)
    assert(c.status=='thumbnail_ui_busy' and c.acquires==6 and c.releases==0)
    s.blocked=false;c:tick(s,.1+i*.0015,false)
end
assert(a.refs[item(1).id]==2,'Busy intervals must retain the independent lease')
s.items={item(7),item(8)};c:tick(s,.2,false)
local count=0;for _ in pairs(c.leases)do count=count+1 end
assert(count==6 and c.releases==2 and c.acquires==8,'Bounded eviction')
s.menu=false;c:tick(s,.3,false)
assert(next(c.leases)==nil and a.refs[item(1).id]==1 and a.calls==a.removed)
-- Cold launch learns semantic identities and prewarms without foreground cards.
local text=profile.encode(c:profile(),'build')
local learned,valid=profile.decode(text,'build');assert(valid and #learned==8)
local cold,b,cs=setup({limit=6});cs.active=false
for _,i in ipairs(learned)do cold:remember(i)end
cold:tick(cs,0,false);assert(cold.prewarms==4)
cold:tick(cs,.1,false);assert(cold.prewarms==6)
cold:tick(cs,.2,true);assert(next(cold.leases)==nil and b.calls==b.removed)
cold:tick(cs,.3,true);assert(cold.status=='memory_pressure' and b.calls==6)
cs.menu=false;cold:tick(cs,.4,false);cs.menu=true;cold:tick(cs,.5,false);assert(b.calls==10)
-- Native owner replacement retires references without unloading its successor.
b.owner='B';cs.owner='B';b.refs={};local removed=b.removed
cold:tick(cs,.6,false);assert(b.removed==removed and cold.retired==4)
-- An in-place clear cannot cause us to unload another subsystem's references.
b.refs={};cold:tick(cs,.7,false)
assert(cold.quarantined and next(cold.leases)==nil and b.removed==removed)
cold:clear();assert(b.removed==removed)
assert(#profile.decode(text,'other build')==0)
assert(#profile.decode(text:sub(1,-2),'build')==0)
assert(#profile.decode(string.rep('x',16385),'build')==0)
assert(#profile.decode('ArmoryPreviewCache1 build\n2:0000000000000000\n5:0000000000000001\n2:0000000000000001\n2:0000000000000001\n','build')==1)
local many=policy.new(a)
for i=1,300 do many:remember(item(i))end
assert(#many:profile()==192 and many:profile()[1].id==item(109).id)
local opts=profile.options('enabled=0\nprewarm=0');assert(not opts.enabled and not opts.prewarm)
assert(not profile.options().disk and not profile.options('disk=1').disk,'Retired disk path cannot be re-enabled')
-- Failed acquisitions never produce release obligations.
local denied,d,ds=setup();function d:acquire()return false end
ds.items={item(1)};denied:tick(ds,0,false);denied:clear();assert(d.removed==0)
local guard=policy.new_memory_guard();local gib=1024^3
assert(not guard:tick(0,30*gib,30*gib))
assert(guard:tick(1,gib,30*gib)=='low_physical_memory' and guard.trips==1)
assert(guard:tick(2,30*gib,30*gib)=='memory_recovery_cooldown')
assert(guard:tick(30,30*gib,30*gib)=='memory_recovery_cooldown')
assert(not guard:tick(31,30*gib,30*gib) and not guard.active)
assert(guard:tick(32,30*gib,gib)=='low_commit_headroom' and guard.trips==2)
assert(guard:tick(70,3*gib,30*gib)=='memory_recovery_cooldown','Recovery needs headroom')
assert(guard:tick(71,30*gib,30*gib)=='memory_recovery_cooldown')
assert(guard:tick(73,gib,30*gib)=='low_physical_memory','A new dip restarts recovery')
assert(guard:tick(74,30*gib,30*gib)=='memory_recovery_cooldown')
assert(not guard:tick(103,30*gib,30*gib))
print('PASS: bounded leases, busy UI retention, independent references, cold profile, real memory-pressure thresholds and automatic recovery, manager reset and malformed profiles')
