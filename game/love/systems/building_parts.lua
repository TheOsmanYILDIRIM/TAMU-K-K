-- TAMU KOK modular construction piece definitions.
-- Prototype-only catalog: not Stage5 JSON definitions, save_v2 or production assets.
-- 32 world units per cell; rotations 0/1/2/3 face S/W/N/E respectively.
local M={unit=32,wall_height=24,slab_height=2}
local defs={}
local function side(id,kind,x,y,z,facing)
  return {id=id,kind=kind,x=x,y=y,z=z,facing=facing,axis="side"}
end
local function vertical(id,kind,x,y,z,axis)
  return {id=id,kind=kind,x=x,y=y,z=z,facing=0,axis=axis}
end
local function add(id,mode,shape,material,size,cost,sockets,flags)
  assert(not defs[id],"duplicate construction definition")
  defs[id]={id=id,mode=mode,rotation_steps=4,size=size,cost=cost,
    sockets=sockets,visual={shape=shape,material=material,
      status="procedural_default",four_views=true,
      module_size=flags and flags.module_size or size},flags=flags or {}}
end
local function foundation()
  local s={
    side("wall_n","wall_mount",0,-16,4,6),
    side("wall_e","wall_mount",16,0,4,0),
    side("wall_s","wall_mount",0,16,4,2),
    side("wall_w","wall_mount",-16,0,4,4),
    side("join_n","foundation_join",0,-16,0,6),
    side("join_e","foundation_join",16,0,0,0),
    side("join_s","foundation_join",0,16,0,2),
    side("join_w","foundation_join",-16,0,0,4),
    vertical("deck","deck",0,0,4,"up")
  }
  for _,a in ipairs({{"nw",-17,-17},{"ne",17,-17},{"se",17,17},{"sw",-17,17}}) do
    s[#s+1]=vertical("post_"..a[1],"post_mount",a[2],a[3],4,"up")
  end
  return s
end
local function floor_sockets()
  local s={vertical("bottom","deck",0,0,0,"down"),
    vertical("roof","roof_mount",0,0,2,"up"),
    side("wall_n","wall_mount",0,-16,2,6),
    side("wall_e","wall_mount",16,0,2,0),
    side("wall_s","wall_mount",0,16,2,2),
    side("wall_w","wall_mount",-16,0,2,4),
    side("stair_n","stair_mount",0,-16,2,6),
    side("stair_e","stair_mount",16,0,2,0),
    side("stair_s","stair_mount",0,16,2,2),
    side("stair_w","stair_mount",-16,0,2,4),
    side("join_n","deck_join",0,-16,0,6),
    side("join_e","deck_join",16,0,0,0),
    side("join_s","deck_join",0,16,0,2),
    side("join_w","deck_join",-16,0,0,4)}
  for _,a in ipairs({{"nw",-17,-17},{"ne",17,-17},{"se",17,17},{"sw",-17,17}}) do
    s[#s+1]=vertical("post_"..a[1],"post_mount",a[2],a[3],2,"up")
  end
  return s
end
local function wall_sockets(height)
  return {side("bottom","wall_mount",0,0,0,6),
    side("left","wall_end",-16,0,height/2,4),
    side("right","wall_end",16,0,height/2,0),
    vertical("top_deck","deck",0,-16,height,"up"),
    vertical("top_roof","roof_mount",0,-16,height,"up")}
end
local function roof_sockets(height)
  return {vertical("bottom","roof_mount",0,0,0,"down"),
    side("join_n","roof_join",0,-16,0,6),
    side("join_e","roof_join",16,0,0,0),
    side("join_s","roof_join",0,16,0,2),
    side("join_w","roof_join",-16,0,0,4)}
end
local function fence_sockets()
  return {side("left","fence_join",-16,0,6,4),
    side("right","fence_join",16,0,6,0)}
end
local wood={["core:wood_plank"]=2}
local stone={["core:stone"]=4}
add("tamu:foundation_wood","foundation","foundation","wood",{32,32,4},
  {["core:wood_plank"]=4,["core:wood_log"]=2},foundation(),{pier_supported=true})
add("tamu:foundation_stone","foundation","foundation","stone",{32,32,4},
  {["core:stone"]=8},foundation(),{pier_supported=true})
add("tamu:floor_wood","attached","floor","wood",{30,30,2},wood,
  floor_sockets(),{walk_surface_pending=true,module_size={32,32,2}})
add("tamu:floor_stone","attached","floor","stone",{30,30,2},stone,
  floor_sockets(),{walk_surface_pending=true,module_size={32,32,2}})
for _,material in ipairs({"wood","stone"}) do
  local cost=material=="wood" and {["core:wood_plank"]=3} or {["core:stone"]=5}
  add("tamu:wall_"..material,"attached","wall",material,{30,2,24},
    cost,wall_sockets(24),{module_size={32,2,24}})
  add("tamu:window_"..material,"attached","window",material,{30,2,24},
    cost,wall_sockets(24),{opening_collision_pending=true,
      module_size={32,2,24}})
  add("tamu:doorway_"..material,"attached","doorway",material,{30,2,24},
    cost,wall_sockets(24),{opening_collision_pending=true,
      module_size={32,2,24}})
end
add("tamu:halfwall_wood","attached","halfwall","wood",{30,2,12},
  {["core:wood_plank"]=2},wall_sockets(12),
  {module_size={32,2,12}})
add("tamu:railing_wood","attached","railing","wood",{30,2,12},
  {["core:wood_plank"]=2},wall_sockets(12),
  {module_size={32,2,12}})
add("tamu:post_wood","attached","post","wood",{2,2,24},
  {["core:wood_log"]=2},
  {vertical("bottom","post_mount",0,0,0,"down")})
add("tamu:roof_flat_wood","attached","roof_flat","wood",{30,30,2},
  {["core:wood_plank"]=3},roof_sockets(2),{module_size={32,32,2}})
add("tamu:roof_slope_wood","attached","roof_slope","wood",{30,30,12},
  {["core:wood_plank"]=4},roof_sockets(12),
  {sloped_sprite_only=true,collision_conservative=true,module_size={32,32,12}})
add("tamu:stairs_wood","attached","stairs","wood",{30,30,24},
  {["core:wood_plank"]=5},
  {side("bottom","stair_mount",0,16,0,2),
    vertical("top_deck","deck",0,-16,24,"up")},
  {walk_surface_pending=true,collision_conservative=true,
    module_size={32,32,24}})
add("tamu:fence_wood","free","fence","wood",{30,2,12},
  {["core:wood_log"]=2},fence_sockets(),{module_size={32,2,12}})
add("tamu:fence_stone","free","fence","stone",{30,2,12},
  {["core:stone"]=4},fence_sockets(),{module_size={32,2,12}})
add("tamu:fence_gate_wood","free","fence_gate","wood",{30,2,12},
  {["core:wood_plank"]=3},fence_sockets(),
  {opening_collision_pending=true,module_size={32,2,12}})
function M.all()
  -- The caller owns the table; Kit.new validates and copies all gameplay fields.
  local out={}
  for id,d in pairs(defs) do out[id]=d end
  return out
end
function M.get(id)
  return defs[id]
end
function M.ids()
  local a={}
  for id in pairs(defs) do a[#a+1]=id end
  table.sort(a)
  return a
end
return M
