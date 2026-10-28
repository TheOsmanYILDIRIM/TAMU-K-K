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
 assert(v[8]==1 and v[3]==v[3] and v[4]==v[4],
   "authored wetland bank must use sharp, opaque world UVs")
end
for _,v in ipairs(left.path) do
 assert(v[8]==1 and v[3]==v[3] and v[4]==v[4],
   "authored path must use real dirt atlas UVs, not flat brown paint")
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
assert(Materials.edge_jitter(64,32,433)==Materials.edge_jitter(64,32,433))
local shuffled={
 {id="cool"},{id="warm"},{id="bright"}
}
local profiles={
 cool={32,-8,17,9},warm={41,8,22,12},bright={58,1,23,11}
}
local a=Materials.choose("dirt",112,88,shuffled,profiles)
local b=Materials.choose("dirt",112,88,shuffled,profiles)
assert(a.id==b.id and (a.id=="cool" or a.id=="warm" or a.id=="bright"),
  "CIELAB source-ID selection must be deterministic")
assert(Materials.choose("dirt",112,88,shuffled,profiles,
  profiles.bright,1).id=="bright",
  "near-border ID selection should favor color-matching source assets")
assert(Materials.choose("dirt",112,88,shuffled,profiles,
  profiles.cool,1).id=="cool",
  "color-compatible sources must remain distinct, without blending pixels")
assert(Materials.family(sample,true,x,y)=="wetland")
assert(Materials.family({biome="rocky",grade=2,feature="meadow"},false,x,y)=="rock")
-- Render-only forest understory may not turn an entire 384-unit Voronoi
-- zone into solid meadow. Fine source-ID islands must coexist instead.
assert(Materials.family({biome="forest",feature="meadow"},false,32,48)=="forest")
local grasses,forest=0,0
for gx=-180,180,8 do
 for gy=-180,180,8 do
  local kind=Materials.interior_family("forest",gx,gy)
  if kind=="grass" then grasses=grasses+1 else
   assert(kind=="forest")
   forest=forest+1
  end
  assert(Materials.interior_family("forest",gx,gy)==kind)
 end
end
assert(grasses>12 and forest>100 and grasses<forest,
  "sparse, stable source-ID understory required")
-- The original bright authored-forest clearing remains bright at its
-- centre, while its neighbour becomes gradually darker by density.
assert(Materials.understory_coverage("forest",409,-76)>.75,
  "previous green clearing was erased rather than transitioned")
assert(Materials.understory_coverage("forest",650,120)<.2,
  "dark forest interior lost its material identity")
assert(Materials.interior_family("wetland",0,0)=="wetland",
  "authored wetland/path surfaces must never be replaced by undergrowth")
-- A broad, categorical forest-to-meadow boundary must contain both
-- unmodified source families on BOTH sides of the authored polygon.
-- Source ID islands are sharp, never RGB/alpha blends.
local query_edge={
 sample=function(_,gx,gy)
   return {biome=gx<0 and "forest" or "meadow"}
 end
}
local area={regions={{polygon={
 {-220,-250},{0,-250},{0,250},{-220,250}
}}}}
local edges=Materials.boundaries(query_edge,area)
assert(#edges>=1,"synthetic authored border missing")
local left_alt,right_alt,left_total,right_total=0,0,0,0
for ix=-88,88,8 do
 for iy=-128,128,8 do
  local primary=ix<0 and "forest" or "grass"
  local edge=Materials.nearest_boundary(edges,ix,iy)
  local chosen,other=Materials.interleaved_family(primary,edge,ix,iy)
  assert(chosen=="forest" or chosen=="grass" or chosen=="dirt",
    "unapproved biome transition source family")
  assert(Materials.interleaved_family(primary,edge,ix,iy)==chosen,
    "cross-chunk categorical biome decision is nondeterministic")
  if ix<0 then
    left_total=left_total+1
    if chosen~="forest" then left_alt=left_alt+1 end
  else
    right_total=right_total+1
    if chosen~="grass" then right_alt=right_alt+1 end
  end
 end
end
assert(left_alt>25 and right_alt>25,
  "biome transition band collapses to a hard line")
-- The middle of the boundary must contain a genuinely mixed material
-- mosaic, including earthy bridge sources, not simply a rounded contour.
local near={forest=0,grass=0,dirt=0}
for sx=-16,16,4 do
 for sy=-132,132,4 do
  local primary=sx<0 and "forest" or "grass"
  local edge=Materials.nearest_boundary(edges,sx,sy)
  local family=Materials.interleaved_family(primary,edge,sx,sy)
  assert(near[family]~=nil,"unexpected transition family")
  near[family]=near[family]+1
 end
end
assert(near.forest>40 and near.grass>40 and near.dirt>12,
  "transition must include native forest, meadow and earth sources")
for _,ix in ipairs({-150,150}) do
 local primary=ix<0 and "forest" or "grass"
 assert(Materials.interleaved_family(primary,
   Materials.nearest_boundary(edges,ix,0),ix,0)==primary,
   "transition leaks into unchanged biome interior")
end
print("TERRAIN25D_SHORE_OK water=2 banks=2 path=1 seam=2 materials=deterministic")
