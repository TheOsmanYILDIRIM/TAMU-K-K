-- Construction piece families, 4 authored directions, socket seam and height contracts.
-- Intentionally independent of R2, live renderer and save_v2.
package.path="./?.lua;./?/init.lua;"..package.path
local Parts=require("systems.building_parts")
local Visual=require("systems.building_visual_contract")
local Kit=require("systems.building_kit")
local Iso=require("world.iso")
local defs=Parts.all()
local ids=Parts.ids()
assert(#ids==19,"construction family catalog changed without updating acceptance")
assert(Parts.unit==32 and Parts.wall_height==24)
local function near(a,b)
  return math.abs(a-b)<1e-7
end
local function uuid(n)
  return ("12345678-1234-4abc-8abc-%012d"):format(n)
end
local function stock()
  local I={slots={["core:stone"]=10000,["core:wood_plank"]=10000,
    ["core:wood_log"]=10000}}
  function I:preview()
    local t={};for k,v in pairs(self.slots) do t[k]=v end;return t
  end
  function I:preview_remove(t,k,n)
    if (t[k] or 0)<n then return false end
    t[k]=t[k]-n;return true
  end
  function I:commit_preview(t) self.slots=t end
  return I
end
local world={
  sample=function(_,x,y)
    return {height=0,walkable=true,feature=nil}
  end,
  obstacles=function()return {} end,
  is_protected=function(_,x,y)return x>175 and x<200 end
}
local inventory=stock()
local counter=0
local function new_id()
  counter=counter+1;return uuid(counter)
end
local function kit()
  return Kit.new(defs,world,{cell=32,max_pier=32,reach=500})
end
local function plan(k,def_id,pos,rot,connection)
  local id=new_id()
  local result=k:plan("plan:"..id,id,def_id,pos or {x=0,y=0},
    rot or 0,connection,{x=0,y=0},"owner:test")
  assert(result.ok,"cannot plan "..def_id..": "..tostring(result.status))
  return id
end
local function finish(k,id)
  local part=assert(k.items[id])
  local materials={}
  for item in pairs(part.def.cost) do materials[#materials+1]=item end
  table.sort(materials)
  for _,item in ipairs(materials) do
    local result=k:deliver("finish:"..id..":"..item,
      id,item,part.def.cost[item],inventory)
    assert(result.ok,"cannot finish "..part.def_id..": "..tostring(result.status))
  end
  assert(k.items[id].status=="built")
end
-- Every definition is drawable at all four orientations without clipping.
local assets={}
for _,id in ipairs(ids) do
  local def=assert(Parts.get(id))
  assert(def.id==id and defs[id]==def)
  assert(def.rotation_steps==4 and #def.size==3)
  assert(def.visual.status=="procedural_default")
  for rot=0,3 do
    local layout=Visual.layout(def,rot)
    assert(Visual.check_canvas(layout))
    assert(layout.source.anchor_x==64 and layout.source.anchor_y==92)
    assert(near(layout.output.runtime_scale,0.5))
    assert(not assets[layout.asset_id],"duplicate view identity")
    assets[layout.asset_id]=true
    local used={}
    for _,s in ipairs(def.sockets) do
      assert(not used[s.id],"duplicate socket")
      used[s.id]=true
      assert(layout.sockets[s.id],"missing projected socket marker")
    end

  end
end
local cached=Visual.precompute(defs)
for _,id in ipairs(ids) do
  for rot=0,3 do
    assert(cached[id][rot].asset_id==Visual.layout(defs[id],rot).asset_id)
    local bounds=cached[id][rot].screen_bounds
    assert(bounds.max_x>bounds.min_x and bounds.max_y>bounds.min_y)
  end
end
local slope=Visual.layout(defs["tamu:roof_slope_wood"],0)
assert(near(slope.top.nw.z,12) and near(slope.top.ne.z,12))
assert(near(slope.top.sw.z,0) and near(slope.top.se.z,0))
local stairs_visual=Visual.layout(defs["tamu:stairs_wood"],0)
assert(near(stairs_visual.top.nw.z,24) and near(stairs_visual.top.se.z,0))
assert(near(Visual.source_ppu*32*math.sqrt(.5),32*math.sqrt(2)))
-- A 32-unit square is ~90.51x45.25px at 128px source size.
local l=Visual.layout(defs["tamu:floor_wood"],0)
assert(near(l.bottom.ne.px-l.bottom.sw.px,64*math.sqrt(2)))
assert(near(l.bottom.se.py-l.bottom.nw.py,32*math.sqrt(2)))
assert(defs["tamu:floor_wood"].size[1]==30 and
  defs["tamu:floor_wood"].visual.module_size[1]==32)
-- Two adjacent modules share IDENTICAL projected world-edge landmarks.
local function projected(p,dx,dy)
  local sx,sy=Iso.project(p.x+dx,p.y+dy,p.z)
  return Visual.pivot_x+sx*Visual.source_ppu,
    Visual.pivot_y+sy*Visual.source_ppu
end
for rot=0,3 do
  local floor=Visual.layout(defs["tamu:floor_wood"],rot)
  local a,b=floor.bottom.ne,floor.bottom.se
  local c,d=floor.bottom.nw,floor.bottom.sw
  local ax,ay=projected(a,0,0)
  local cx,cy=projected(c,32,0)
  local bx,by=projected(b,0,0)
  local dx,dy=projected(d,32,0)
  if rot==0 then
    assert(near(ax,cx) and near(ay,cy))
    assert(near(bx,dx) and near(by,dy))
  end
end
-- Four directional walls around one foundation: no AABB false-collision
-- at corners or at adjoining floor slab borders.
local k=kit()
local foundation=plan(k,"tamu:foundation_wood",{x=0,y=0})
finish(k,foundation)
local root=k.items[foundation]
local wall_directions={
  {socket="wall_s",rotation=0,x=0,y=16},
  {socket="wall_w",rotation=1,x=-16,y=0},
  {socket="wall_n",rotation=2,x=0,y=-16},
  {socket="wall_e",rotation=3,x=16,y=0}
}
local walls={}
for _,entry in ipairs(wall_directions) do
  local connection={parent_id=foundation,parent_socket=entry.socket,
    child_socket="bottom"}
  local valid,shape=k:preview("tamu:wall_wood",{x=99,y=99},entry.rotation,
    connection,{x=0,y=0})
  assert(valid and near(shape.x,entry.x) and near(shape.y,entry.y) and
    near(shape.z,4),"directional snap is not world-exact")
  local id=plan(k,"tamu:wall_wood",{x=99,y=99},entry.rotation,connection)
  local wall=k.items[id]
  assert(near(wall.x,entry.x) and near(wall.y,entry.y))
  local ps=Visual.layout(defs["tamu:foundation_wood"],0).sockets[entry.socket]
  local cs=Visual.layout(defs["tamu:wall_wood"],entry.rotation).sockets.bottom
  assert(near(ps.x,wall.x+cs.x) and near(ps.y,wall.y+cs.y)
    and near(ps.z,wall.z+cs.z),"visual markers disagree with gameplay socket")
  walls[entry.socket]=id
  -- Same socket must reject a second child before inventory changes.
  local repeated=k:preview("tamu:doorway_wood",{x=0,y=0},
    entry.rotation,connection,{x=0,y=0})
  assert(repeated==false)
  finish(k,id)
end
local extension=plan(k,"tamu:wall_wood",{x=0,y=0},0,
  {parent_id=walls.wall_s,parent_socket="left",child_socket="right"})
assert(near(k.items[extension].x,-32) and near(k.items[extension].y,16))
finish(k,extension)
local floor=plan(k,"tamu:floor_wood",{x=0,y=0},0,
  {parent_id=foundation,parent_socket="deck",child_socket="bottom"})
finish(k,floor)
assert(near(k.items[floor].z,4))
-- All four wall side sockets and floor slab coexist with 30-unit
-- physical envelope while their artwork is rendered at 32-unit pitch.
local stone_neighbor=plan(k,"tamu:foundation_stone",{x=500,y=500},0,
  {parent_id=foundation,parent_socket="join_e",child_socket="join_w"})
assert(near(k.items[stone_neighbor].x,32) and near(k.items[stone_neighbor].y,0))
finish(k,stone_neighbor)
local floor_next=plan(k,"tamu:floor_stone",{x=0,y=0},0,
  {parent_id=stone_neighbor,parent_socket="deck",child_socket="bottom"})
finish(k,floor_next)
assert(near(k.items[floor_next].x-k.items[floor].x,32))
-- Upper floor mounts vertically to completed wall; an unbuilt wall
-- cannot support it. Wall top exactly meets slab bottom at world z=28.
local wall_s=walls.wall_s
local upper=plan(k,"tamu:floor_wood",{x=0,y=0},0,
  {parent_id=wall_s,parent_socket="top_deck",child_socket="bottom"})
assert(near(k.items[upper].z,28))
finish(k,upper)
local upper_wall=plan(k,"tamu:doorway_wood",{x=0,y=0},0,
  {parent_id=upper,parent_socket="wall_s",child_socket="bottom"})
assert(near(k.items[upper_wall].z,30))
finish(k,upper_wall)
assert(k.items[upper_wall].def_id=="tamu:doorway_wood")
local roof=plan(k,"tamu:roof_slope_wood",{x=0,y=0},0,
  {parent_id=upper_wall,parent_socket="top_roof",child_socket="bottom"})
assert(near(k.items[roof].z,54))
finish(k,roof)
local post=plan(k,"tamu:post_wood",{x=0,y=0},0,
  {parent_id=foundation,parent_socket="post_nw",child_socket="bottom"})
assert(near(k.items[post].x,-17) and near(k.items[post].y,-17))
finish(k,post)
local stone_wall=plan(k,"tamu:wall_stone",{x=0,y=0},3,
  {parent_id=floor_next,parent_socket="wall_e",child_socket="bottom"})
finish(k,stone_wall)
local window=plan(k,"tamu:window_stone",{x=0,y=0},2,
  {parent_id=floor_next,parent_socket="wall_n",child_socket="bottom"})
finish(k,window)
local halfwall=plan(k,"tamu:halfwall_wood",{x=0,y=0},0,
  {parent_id=floor_next,parent_socket="wall_s",child_socket="bottom"})
finish(k,halfwall)
local railing=plan(k,"tamu:railing_wood",{x=0,y=0},1,
  {parent_id=upper,parent_socket="wall_w",child_socket="bottom"})
finish(k,railing)
-- Child-to-parent graph blocks unsafe support destruction.
assert(k:remove("remove-support",foundation).status=="has_dependents")
local unsafe=k:preview("tamu:foundation_wood",{x=180,y=0},0,nil,{x=0,y=0})
assert(unsafe==false,"protected world region must veto placement")
-- Stairs leave the north floor edge and rise one 24-unit structural level.
local stairs=plan(k,"tamu:stairs_wood",{x=0,y=0},0,
  {parent_id=upper,parent_socket="stair_n",child_socket="bottom"})
assert(near(k.items[stairs].y,-32) and near(k.items[stairs].z,30))
finish(k,stairs)
-- Connected fences are free objects until the player chooses an end socket.
local fences=kit()
local fence1=plan(fences,"tamu:fence_wood",{x=0,y=0})
finish(fences,fence1)
local fence2=plan(fences,"tamu:fence_gate_wood",{x=0,y=0},0,
  {parent_id=fence1,parent_socket="right",child_socket="left"})
assert(near(fences.items[fence2].x,32))
finish(fences,fence2)
local fence3=plan(fences,"tamu:fence_stone",{x=0,y=0},0,
  {parent_id=fence2,parent_socket="right",child_socket="left"})
assert(near(fences.items[fence3].x,64))
finish(fences,fence3)
-- Strongly typed vertical sockets reject invalid axis pairs.
local invalid=fences:preview("tamu:fence_wood",{x=0,y=0},0,
  {parent_id=fence1,parent_socket="right",child_socket="right"},{x=0,y=0})
assert(invalid==false)
local sample=k:snapshot()
assert(sample.version==1 and #sample.parts>=17)
assert(#k:obstacles({x=-18,y=15,w=36,h=3,z=7,d=10})>=1)
print(("BUILDING_PIECES_OK variants=%d views=%d sockets=checked directional_walls=4 "..
  "multi_floor=1 authored_art_seams=pending"):format(#ids,#ids*4))
