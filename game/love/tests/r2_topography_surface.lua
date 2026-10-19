-- Pure-Lua R2 topography contract; executed unchanged on 5.4 and LuaJIT.
package.path = "./?.lua;./?/init.lua;" .. package.path
local Topo=require("world.topography_surface")
local Field=require("world.field")
local function approx(x,y,eps)
  assert(math.abs(x-y) <= (eps or 1e-9),tostring(x).." != "..tostring(y))
end
local function fails(f)
  assert(not pcall(f),"expected rejection")
end
local function linear(slope)
  return Topo.new({height_at=function(x,y) return slope*x end,
    sample_stride=1})
end
-- The real Generator v1 height is already world-space, seed-stable and continuous.
local field=Field.new(20261018)
local generator=Topo.new({height_at=function(x,y) return field:sample(x,y).height end})
local field_from_other_chunk=Field.new(20261018)
local other_chunk=Topo.new({height_at=function(x,y) return field_from_other_chunk:sample(x,y).height end})
for _,p in ipairs({{0,0},{256,128},{-256,-256},{512,512},{0,256}}) do
  local x,y=p[1],p[2]
  approx(generator:height(x,y),field:sample(x,y).height)
  approx(generator:sample(x,y).height,generator:sample(x,y).height)
end
-- A chunk is NOT part of the height key. Cross chunk seams identically.
for _,edge in ipairs({-256,0,256,512}) do
  approx(generator:height(edge,17),other_chunk:height(edge,17))
  approx(generator:sample(edge,17).grade,other_chunk:sample(edge,17).grade)
  local left=generator:transition(edge-1,17,edge+1,17)
  local right=generator:transition(edge+1,17,edge-1,17)
  assert(left.walkable == right.walkable)
  assert(left.walkable == other_chunk:transition(edge-1,17,edge+1,17).walkable)
  approx(left.max_grade,right.max_grade,1e-8)
  local a=generator:colliders(edge-8,0,edge+8,16,8)
  local b=generator:colliders(edge-8,0,edge+8,16,8)
  assert(#a==#b)
  for i=1,#a do assert(a[i].x==b[i].x and a[i].y==b[i].y) end
end
local gentle=linear(0.04)
assert(gentle:sample(10,0).class=="gentle")
assert(gentle:transition(0,0,12,0).walkable)
approx(gentle:transition(0,0,12,0).speed_multiplier,1)
local moderate=linear(0.3)
assert(moderate:sample(10,0).class=="moderate")
local uphill=moderate:transition(0,0,12,0)
local downhill=moderate:transition(12,0,0,0)
assert(uphill.walkable and downhill.walkable)
assert(uphill.speed_multiplier < downhill.speed_multiplier and downhill.speed_multiplier < 1)
local cliff=linear(1)
assert(cliff:sample(10,0).class=="cliff")
assert(not cliff:transition(0,0,12,0).walkable)
assert(cliff:transition(0,0,0,0).walkable)
-- Ramp/steps are explicit stable authored corridors, NOT automatic shortcuts.
local ramp=Topo.new({height_at=function(x,y) return x end,
  zones={{id="connector:ramp",kind="ramp",min_x=0,min_y=0,max_x=25,max_y=20}},
  sample_stride=1})
assert(ramp:transition(2,10,12,10).walkable)
assert(not ramp:transition(-2,10,12,10).walkable)
local stepped=Topo.new({height_at=function(x,y) return x>=6 and 1 or 0 end,
  zones={{id="connector:steps",kind="steps",min_x=0,min_y=0,max_x=20,max_y=20}},
  sample_stride=1})
assert(stepped:transition(2,10,10,10).walkable)
local high_step=Topo.new({height_at=function(x,y) return x>=6 and 4 or 0 end,
  zones={{id="connector:steps",kind="steps",min_x=0,min_y=0,max_x=20,max_y=20}}})
assert(not high_step:transition(2,10,10,10).walkable)
-- Occlusion uses actual terrain height, not rendered sprite ordering.
local ridge=Topo.new({height_at=function(x,y) return math.max(0,12-math.abs(x-10)*2) end,
 sample_stride=1})
assert(not ridge:line_of_sight(0,0,20,0))
assert(ridge:line_of_sight(0,0,20,0,20,20))
assert(gentle:line_of_sight(0,0,20,0))
local flat=Topo.new({height_at=function() return 4 end})
assert(flat:can_build(0,0,20,20))
assert(not moderate:can_build(0,0,20,20))
local uneven=Topo.new({height_at=function(x,y) return x*0.09 end})
local ok,reason=uneven:can_build(0,0,20,20)
assert(not ok and reason=="uneven_footprint")
assert(not ramp:can_build(2,2,4,4))
assert(#ramp:colliders(0,0,16,16,8)==0)
local blocks=cliff:colliders(0,0,16,16,8)
assert(#blocks==4 and blocks[1].x==0 and blocks[1].y==0
 and blocks[2].x==8 and blocks[3].y==8)
assert(#flat:colliders(0,0,16,16,8)==0)
-- No silent invalid height, NaN, overlapping portal or unsafe budget fallback.
fails(function() Topo.new({}) end)
fails(function() Topo.new({height_at=function() return 0/0 end}):sample(0,0) end)
fails(function() flat:transition(0,0,math.huge,0) end)
fails(function() flat:transition(0,0,10000,0) end)
fails(function() flat:can_build(0,0,1000,1000) end)
fails(function() flat:colliders(0,0,1000,1000,1) end)
fails(function() Topo.new({height_at=function()return 0 end,
 zones={{id="a",kind="ramp",min_x=0,min_y=0,max_x=2,max_y=2},
 {id="b",kind="steps",min_x=1,min_y=1,max_x=3,max_y=3}}}) end)
local wrapped=Topo.new({world={get_height=function(self,x,y) return x+y end}})
approx(wrapped:height(12,-4),8)
print("R2 topography contract, ramps, steps, sight, building, chunks, colliders OK")
