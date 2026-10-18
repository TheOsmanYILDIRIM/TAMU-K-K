package.path="./?.lua;./?/init.lua;"..package.path
local Query=require("world.world_query")
local Water=require("world.collision_adapter")
local Overlay=require("objects.authored_population")
local Collision=require("physics.collision")
local Harvest=require("objects.harvesting")
local ObjectQuery=require("objects.query")
local q=Query.new(20261018)
local water=Water.new(q,8)
local anchors={}
local occupied={}
for gy=-8,8 do
  for gx=-8,8 do
    if #anchors<2 then
      local x,y=gx*64+25,gy*64+25
      local sample=q:sample(x,y)
      local kind=sample.biome=="rocky" and "core:stone_rock" or "core:oak_tree"
      if sample.biome~="rocky" or kind=="core:stone_rock" then
        local def=require("objects.definitions").get(kind)
        if sample.walkable and sample.feature~="path" and sample.feature~="water"
          and def.biomes[sample.biome] and Collision.can_stand(water,x,y,def.radius+4) then
          local separated=true
          for _,a in ipairs(anchors) do
            if math.abs(a.x-x)<100 and math.abs(a.y-y)<100 then separated=false end
          end
          if separated then anchors[#anchors+1]={id="anchor-"..(#anchors+1),
            region_id="region:test",x=x,y=y,def_id=kind} end
        end
      end
    end
  end
end
assert(#anchors==2,"fixture must find two dry authored sites")
local function build(list)
  return Overlay.new(q,water,"worldmap:test",list)
end
local a=build(anchors)
local b=build({anchors[2],anchors[1]})
assert(a.authored[1].id==b.authored[1].id and a.authored[2].id==b.authored[2].id)
assert(a.authored[1].id:match("^worldobj:authored:v1:test:anchor%-%d+$"))
local seen={}
for _,o in ipairs(a.authored) do
  assert(o.cx==math.floor(o.x/256) and o.cy==math.floor(o.y/256))
  assert(not seen[o.id]);seen[o.id]=true
  assert(a:get(o.id)==o)
  local area={min_x=o.x-20,min_y=o.y-20,max_x=o.x+20,max_y=o.y+20}
  local hits=a:objects_in(area)
  local once=0
  for _,found in ipairs(hits) do
    if found.id==o.id then once=once+1 end
    assert(not (found.id~=o.id and math.abs(found.x-o.x)<found.radius+o.radius+4
      and math.abs(found.y-o.y)<found.radius+o.radius+4),"procedural collision not suppressed")
  end
  assert(once==1)
  assert(not Collision.can_stand(ObjectQuery.new(water,a),o.x,o.y,1))
end
local o=a.authored[1]
local h=Harvest.new(a,38)
local cmd=h:begin("authored-1",o.id,o.x+o.radius+5,o.y)
assert(cmd.ok)
for i=1,40 do h:update(.1,o.x+o.radius+5,o.y) end
local events=h:drain_events()
assert(#events>=1 and events[1].object_id==o.id)
assert(a:is_depleted(o.id))
assert(not h:begin("authored-2",o.id,o.x+o.radius+5,o.y).ok)
assert(not pcall(function() a:export_delta() end),"authored save silently enabled")
local keep={}
for _,v in ipairs(anchors) do keep[#keep+1]=v end
keep[2]=anchors[1]
assert(not pcall(function() build(keep) end),"duplicate author IDs accepted")
local bad={id="anchor-bad",region_id="region:test",x=o.x,y=o.y,
  def_id=o.def_id}
assert(not pcall(function() build({anchors[1],bad}) end),"overlap accepted")
local p
for gy=-10,10 do
  for gx=-10,10 do
    p=p or a.base:site(gx,gy)
  end
end
assert(p and p.id:match("^worldobj:v1:"),"generator v1 identity changed")
local standalone=build({})
assert(standalone:get(p.id) and standalone:get(p.id).id==p.id)
assert(standalone:export_delta().generator_version==1)
-- Compare the same negative-coordinate global bounds as adjacent 256-unit chunks.
local full=standalone:objects_in({min_x=-257,min_y=-257,max_x=255,max_y=255})
local ids={}
for _,v in ipairs(full) do ids[v.id]=true end
for _,bounds in ipairs({
  {min_x=-257,min_y=-257,max_x=-1,max_y=255},
  {min_x=-1,min_y=-257,max_x=255,max_y=255}
}) do
  for _,v in ipairs(standalone:objects_in(bounds)) do
    assert(ids[v.id],"chunk-query object drift")
  end
end
print("WORLDBUILD_E_POPULATION_OK Lua authored IDs, collision, harvest, v1 and save guard")
