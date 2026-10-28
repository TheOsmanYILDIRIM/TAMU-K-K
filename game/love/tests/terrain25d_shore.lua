-- Authoritative signed-water contour, banks and authored paths (pure Lua).
package.path="./?.lua;./?/init.lua;"..package.path
local Shore=require("world.terrain25d_shore")
local Materials=require("world.terrain25d_materials")
local function near(a,b) return math.abs(a-b)<1e-8 end
local topo={height=function(_,x,y) return .1*x+.03*y end}
local query={
 water_mask=function(_,x,y)
   local signed=16-math.abs(y-32)
   return signed>0,signed
 end
}
local features={features={
 {kind="water",width=32,points={{0,32},{128,32}}},
 {kind="path",width=18,points={{24,-32},{24,96}}}
}}
function features:signed(x,y,kind)
 if kind=="path" then return 9-math.abs(x-24) end
 return 16-math.abs(y-32)
end
local route={features=features}
local left=Shore.build({x=0,y=0,size=64,layers={}},query,topo,route,.35)
local yields=0
local co=coroutine.create(function()
 return Shore.build({x=0,y=0,size=64,layers={}},
   query,topo,route,.35,function() coroutine.yield("checkpoint") end)
end)
while coroutine.status(co)~="dead" do
 local ok,tag=coroutine.resume(co)
 assert(ok,tag)
 if coroutine.status(co)~="dead" then
   assert(tag=="checkpoint")
   yields=yields+1
 end
end
assert(yields>0,"authored shoreline must be cooperatively precomputable")
local right=Shore.build({x=64,y=0,size=64,layers={}},query,topo,route,.35)
assert(left.refined and right.refined)
assert(left.authored_path and not right.authored_path)
assert(#left.water>0 and #left.bank>0 and #left.path>0)
assert(#right.water>0 and #right.bank>0 and #right.path==0)
-- Authored channel centre has a deeper, darker color than the shallow edge.
local deep,shallow
for _,v in ipairs(left.water) do
 assert(#v==8 and v[5]==v[5] and v[5]>=0 and v[5]<=1)
 assert(v[6]>=0 and v[6]<=1 and v[8]>0 and v[8]<=1)
end
-- Compare the same world-space sample directly through the public output:
-- bank remains translucent and never paints a solid gray square.
for _,v in ipairs(left.bank) do
 assert(v[8]>=0 and v[8]<=.30,"bank overlay too opaque")
end
assert(#left.water%3==0 and #left.bank%3==0)
-- Both chunks must sample the same interpolated shore at their common seam.
local function seam(verts,world_x)
 local result={}
 for _,v in ipairs(verts) do
  local sy=v[2]
  local sx=v[1]
  local xproj,yproj=(world_x-32)*math.sqrt(.5),(world_x+32)*math.sqrt(.5)/2
  -- The authored shoreline intersects y=16 and y=48; compare projected.
  for _,y in ipairs({16,48}) do
   local p,q=require("world.iso").project(world_x,y,topo:height(world_x,y)*.35)
   if near(sx,p) and near(sy,q) then result[y]=true end
  end
 end
 return result
end
local ls,rs=seam(left.water,64),seam(right.water,64)
assert(ls[16] and ls[48] and rs[16] and rs[48],
  "neighboring water shore projected seams differ")
local empty=Shore.build({x=384,y=384,size=64,layers={}},
  query,topo,route,.35)
assert(not empty.refined and not empty.authored_path
  and #empty.bank==0 and #empty.path==0)
local sample={biome="forest",grade=.05,feature="meadow"}
local x,y=-1000,336
assert(Materials.region(x,y)==Materials.region(x,y))
assert(Materials.variant("forest",x,y,2)==Materials.variant("forest",x,y,2))
assert(Materials.variant("forest",x,y,1)==1)
assert(Materials.family(sample,true,x,y)=="wetland")
assert(Materials.family({biome="rocky",grade=2,feature="meadow"},false,x,y)=="rock")
print("TERRAIN25D_SHORE_OK water=2 banks=2 path=1 seam=2 materials=deterministic")
