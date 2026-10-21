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

-- A full 180 physics-step idle/move episode must reuse immutable cliff
-- classifications but keep the exact obstacle rectangles and their order.
local checks=0
local function h(x,y)
 checks=checks+1
 return x>=16 and 16 or 0
end
local raw=Topo.new({height_at=h})
local fast=Topo.new({height_at=h,static_collider_cache=true})
for _,bounds in ipairs({{-16,-16,32,32},{0,0,32,32},{4,4,12,12},
  {-24,-8,8,16},{9,9,23,23},{-8,-8,24,24}}) do
 local a=raw:colliders(bounds[1],bounds[2],bounds[3],bounds[4],8)
 local b=fast:colliders(bounds[1],bounds[2],bounds[3],bounds[4],8)
 assert(#a==#b,"R2 collider cache changed cliff count")
 for i=1,#a do
  for _,key in ipairs({"x","y","w","h"}) do
   assert(a[i][key]==b[i][key],"cliff rectangle changed "..key)
  end
 end
end
local before=checks
local original=fast:colliders(0,0,32,32,8)
for _=1,180 do
 local current=fast:colliders(0,0,32,32,8)
 assert(#current==#original)
end
assert(checks==before,"cached repeated geometry must not resample height")
assert(fast._collider_cache.hits>=180*16 and fast._collider_cache.misses>0)
assert(fast._collider_cache.count<=fast._collider_cache.limit)
-- Mutable worlds are not cached by default; moving a cliff must stay live.
local current_slope=0
local dynamic=Topo.new({height_at=function(x,y) return x*current_slope end})
assert(#dynamic:colliders(0,0,16,16,8)==0)
current_slope=1
assert(#dynamic:colliders(0,0,16,16,8)==4)
print("R2_STATIC_COLLIDER_CACHE_PARITY_OK unchanged_rects=180x16")

print("R2 topography contract, ramps, steps, sight, building, chunks, colliders OK")
