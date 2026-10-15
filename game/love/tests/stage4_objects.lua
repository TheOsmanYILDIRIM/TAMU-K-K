package.path="./?.lua;./?/init.lua;"..package.path
local Query=require("world.world_query")
local Adapter=require("world.collision_adapter")
local World=require("objects.world")
local Defs=require("objects.definitions")
local ObjectQuery=require("objects.query")
local Collision=require("physics.collision")
local Controller=require("player.controller")
local Path=require("navigation.pathfinder")
local Harvest=require("objects.harvesting")
local Wallet=require("objects.wallet")
local q=Query.new(20261015)
local water=Adapter.new(q,8)
local a=World.new(q,water)
local twin=World.new(Query.new(20261015),Adapter.new(Query.new(20261015),8))
local other_q=Query.new(20261016)
local other=World.new(other_q,Adapter.new(other_q,8))
local ids,tree,rock={},nil,nil
local total=0
local started=os.clock()
for gy=-15,15 do for gx=-15,15 do
  local p=a:site(gx,gy)
  local t=twin:site(gx,gy)
  assert((p==nil)==(t==nil),"same-seed spawn mismatch")
  if p then
    total=total+1
    assert(not ids[p.id],"duplicate instance id")
    ids[p.id]=true
    assert(p.id==t.id and p.x==t.x and p.y==t.y and p.def_id==t.def_id)
    assert(p.cx==math.floor(p.x/256) and p.cy==math.floor(p.y/256))
    assert(Defs.get(p.def_id).biomes[q:get_biome(p.x,p.y)])
    assert(Collision.can_stand(water,p.x,p.y,p.radius+4),"water colliding spawn")
    assert(a:get(p.id)==p)
    if p.kind=="tree" then tree=tree or p else rock=rock or p end
  end
end end
assert(total>10 and tree and rock,"missing forest/rock object diversity")
assert(other:site(tree.gx,tree.gy)==nil or other:site(tree.gx,tree.gy).id~=tree.id)
for _,p in ipairs({{0,0},{-256,-256},{256,256},{-1,255}}) do
  local x,y=p[1],p[2]
  local list=a:objects_in({min_x=x-4,min_y=y-4,max_x=x+4,max_y=y+4})
  local seen={}
  for _,o in ipairs(list) do
    assert(not seen[o.id]);seen[o.id]=true
    assert(o.cx==math.floor(o.x/256) and o.cy==math.floor(o.y/256))
  end
end
local solid=ObjectQuery.new(water,a)
assert(not Collision.can_stand(solid,tree.x,tree.y,1),"tree does not collide")
assert(not Collision.can_stand(solid,rock.x,rock.y,1),"rock does not collide")
local bx,by=tree.x+tree.radius+8,tree.y
assert(Collision.can_stand(solid,bx,by,1),"approach is obstructed")
local nx,ny,hit=Collision.move(solid,bx,by,-50,0,1)
assert(hit and nx>tree.x+tree.radius,"swept AABB crossed tree")
local h=Harvest.new(a,38)
local too_far=h:begin("far",tree.id,tree.x+200,tree.y)
assert(not too_far.ok and too_far.status=="out_of_range")
assert(h:begin("far",tree.id,tree.x+tree.radius+12,tree.y)==too_far,
 "same command cannot change its authorization")
local from_x,from_y=tree.x+tree.radius+12,tree.y
local start=h:begin("harvest:1",tree.id,from_x,from_y)
assert(start.ok and start.status=="started")
assert(h:begin("harvest:1",tree.id,from_x,from_y)==start)
for i=1,30 do h:update(.1,from_x,from_y) end
local result=h:begin("harvest:1",tree.id,from_x,from_y)
assert(result.ok and result.status=="complete")
assert(a:is_depleted(tree.id))
local drops=h:drain_events()
assert(#drops==1 and drops[1].type=="HarvestCompleted")
assert(drops[1].item_id=="core:wood_log" and drops[1].amount==3)
assert(#h:drain_events()==0)
local bag=Wallet.new()
assert(bag:apply(drops[1]) and not bag:apply(drops[1]))
assert(bag:count("core:wood_log")==3)
local replay=h:begin("harvest:2",tree.id,from_x,from_y)
assert(not replay.ok and replay.status=="depleted")
assert(#h:drain_events()==0 and bag:count("core:wood_log")==3)
local delta=a:export_delta()
assert(delta.version==1 and delta.seed==q.seed and delta.objects[tree.id].depleted)
delta.objects[tree.id].depleted=false
assert(a:is_depleted(tree.id),"delta snapshot must be a copy")
assert(a:get(tree.id).id==tree.id,"object ID changed after depletion")
assert(Collision.can_stand(solid,tree.x,tree.y,1),"depleted tree still collides")
local a_reload=a:objects_in({min_x=tree.x-16,min_y=tree.y-16,max_x=tree.x+16,max_y=tree.y+16})
for _,o in ipairs(a_reload) do assert(o.id~=tree.id,"depleted object respawned") end
local h2=Harvest.new(a,38)
local rx,ry=rock.x+rock.radius+10,rock.y
assert(h2:begin("rock-1",rock.id,rx,ry).ok)
h2:update(.25,rx,ry) -- dt is capped per update against frame spikes
assert(h2:progress()>0 and h2:progress()<1)
h2:update(.1,rock.x+300,rock.y)
assert(h2:begin("rock-1",rock.id,rx,ry).status=="interrupted")
assert(not a:is_depleted(rock.id),"interrupted job depleted resource")
assert(h2:begin("rock-2",rock.id,rx,ry).ok)
for i=1,40 do h2:update(.1,rx,ry) end
local stone=h2:drain_events()
assert(#stone==1 and stone[1].item_id=="core:stone" and stone[1].amount==2)
assert(bag:apply(stone[1]) and bag:count("core:stone")==2)
assert(not pcall(function() a:objects_in({min_x=0,min_y=0,max_x=1000000,max_y=1000000}) end))
assert(a.cache_size<=a.max_cache)
-- A* and player share exactly the same combined query as swept motion.
local px,py=rock.x+rock.radius+24,rock.y
if Collision.can_stand(solid,px,py,5) then
  local player=Controller.new(solid,{x=px,y=py,radius=5})
  for i=1,20 do player:update(1/60,-1,0);assert(Collision.can_stand(solid,player.x,player.y,5)) end
end
print(string.format("STAGE4_OBJECTS_OK seed=20261015 sites=%d time=%.3f cache=%d",
  total,os.clock()-started,a.cache_size))
