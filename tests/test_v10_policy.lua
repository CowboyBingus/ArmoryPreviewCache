local root=assert(arg[1]);local policy=dofile(root..'/src/policy.lua');local profile=dofile(root..'/src/profile.lua')
local a={refs={}}
function a:valid_leases(ls)for id in pairs(ls)do if not self.refs[id]then return false end end;return true end
function a:resolve_all(i)return {i.id, i.attachments and i.attachments[1] or 'default-'..i.id}end
function a:acquire(id)self.refs[id]=(self.refs[id] or 0)+1;return true end
function a:release(id)assert(self.refs[id]);self.refs[id]=self.refs[id]-1 end
local id='0011223344556677';local attachment='fedcba9876543210'
local c=policy.new(a,{limit=4});c:remember({kind=0,id=id,attachments={attachment}})
local s={owner='A',world='startup',menu=false,prefetch=true,active=false,items={}}
c:tick(s,0,false)
assert(c.startup_acquires==2 and c.dependency_acquires==1 and c.prewarms==2)
assert(c.leases[attachment] and c.status=='startup_dependency_prewarm')
s.menu=true;s.world='armory';s.blocked=true;s.active=true;s.items={{kind=0,id=id}}
c:tick(s,1,false)
assert(c.releases==0 and c.leases[attachment],'First Armory world must inherit startup leases and learned customization')
s.items={{kind=0,id='new'}};c:tick(s,2,false)
assert(c.leases.new and c.leases['default-new'],'Busy flag must not suppress foreground dependency lookahead')
s.menu=false;c:tick(s,3,false);assert(next(c.leases)==nil,'Startup window must not reopen after menu exit')
local cold=policy.new(a);cold:remember({kind=0,id=id});cold:tick(s,0,false)
cold:tick(s,61,false);assert(next(cold.leases)==nil,'Startup prefetch has a hard expiry')
local old='ArmoryPreviewCache1 build\n0:'..id..'\n'
local learned,ok=profile.decode(old,'build');assert(ok and #learned==1)
learned[1].attachments={attachment}
local saved=profile.encode(learned,'build');local loaded,valid=profile.decode(saved,'build')
assert(valid and loaded[1].attachments[1]==attachment and loaded[1].id==id)
assert(not select(2,profile.decode(saved,'different build')))
assert(#profile.decode('ArmoryPreviewCache2 build\n0:'..id..'|,'..attachment..'\n','build')==0)
assert(#profile.decode('ArmoryPreviewCache2 build\n0:'..id..'|'..attachment..','..attachment..'\n','build')==0)
print('PASS: startup before Armory; default/custom dependency prewarm; no first-world flush; foreground during busy UI; bounded startup expiry; legacy profile migration; precise 64-bit attachment IDs; malformed input rejection')
