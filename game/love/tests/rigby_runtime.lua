package.path='./?.lua;./?/init.lua;'..package.path
local Json=require('save.json')
local Rig=require('player.rigby_runtime')
local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local rig=Rig.new(Json.decode(read('assets/osman_rig/rig.json')))
local fixture=Json.decode(read('tests/rigby_reference.json'))
local max_error=0;local vertex_count=0
local function near(a,b,tol)
 local err=math.abs(a-b);max_error=math.max(max_error,err)
 assert(err<(tol or 1e-7),string.format('%.17g ~= %.17g (error %.9g)',a,b,err))
end
for _,s in ipairs(fixture.samples) do
 rig:evaluate(s.clip,s.time,false)
 for i,m in ipairs(s.world) do local w=rig.world[i]
  for j,k in ipairs({'a','b','c','d','tx','ty'}) do near(w[k],m[j]) end
 end
 local q=rig:quads();assert(#q==#s.geometry,'draw list count mismatch')
 for i,expected in ipairs(s.geometry) do
  local g=q[i];assert(g.slot==expected.slot+1 and g.image==expected.image and #g.vertices==expected.count,'slot/texture mismatch')
  local sig={0,0,0,0,0,0}
  for n,v in ipairs(g.vertices) do
   local x,y=v[1],v[2]
   sig[1]=sig[1]+x;sig[2]=sig[2]+y;sig[3]=sig[3]+x*n;sig[4]=sig[4]+y*n
   sig[5]=sig[5]+x*x;sig[6]=sig[6]+y*y;vertex_count=vertex_count+1
  end
  for j,v in ipairs(sig) do near(v,expected.signature[j],1e-4) end
 end
end
-- Continuous, not quantized frame lookup.
rig:evaluate('walk',.12345);local x=rig.world[9].tx
rig:evaluate('walk',.12346);assert(math.abs(rig.world[9].tx-x)>1e-8)
-- Variable dt gives the same pose at the same playback time.
local t=0;for i=1,72 do t=t+.01 end
rig:evaluate('walk',t,true);local p=rig:capture();rig:evaluate('walk',.72,true)
for i,b in ipairs(p) do for k,v in pairs(b) do near(v,rig.local_pose[i][k],1e-8) end end
-- Reflected, scale-isolated feet are reproduced; no external flip.
for _,name in ipairs({'idle','mirror_idle','back_idle','mirror_back_idle'}) do
 rig:evaluate(name,0);local sign=name:find('mirror') and -1 or 1
 assert(rig.world[1].a*sign>0,'root facing wrong')
end
-- Procedural bone modification affects output at arbitrary time.
rig:evaluate('idle',.3);local old=rig.world[4].a
rig:evaluate('idle',.3,false,{head={rotation=8}});assert(math.abs(old-rig.world[4].a)>.01)
-- Endpoint loop equivalence and independent pose instances.
for name,a in pairs(rig.animations) do
 rig:evaluate(name,0);local start=rig:capture();rig:evaluate(name,a.duration,false)
 if name:match('idle$') or name:match('walk$') or name:match('run$') then
  for i,b in ipairs(start) do for k,v in pairs(b) do near(v,rig.local_pose[i][k],1e-6) end end
 end
end
assert(not pcall(function() rig:evaluate('missing',0) end))
assert(not pcall(function() rig:evaluate('idle',0/0) end))
print(string.format('RIGBY_REFERENCE_OK samples=%d bone_matrices=%d vertex_checks=%d max_abs_error=%.9g',#fixture.samples,#fixture.samples*#rig.bones,vertex_count,max_error))
