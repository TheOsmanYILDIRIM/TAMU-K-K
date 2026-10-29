-- Independent construction kernel acceptance; no R2, renderer, or save_v2 mutation.
package.path="./?.lua;./?/init.lua;"..package.path
local Spatial=require("systems.building_spatial")
local Kit=require("systems.building_kit")
local Inv={}
function Inv.new()
  local self={stocks={},applied={}}
  function self:credit_harvest(e)
    if self.applied[e.transaction_id] then return false end
    self.applied[e.transaction_id]=true
    self.stocks[e.item_id]=(self.stocks[e.item_id] or 0)+e.amount
    return true
  end
  function self:count(k) return self.stocks[k] or 0 end
  function self:preview()
    local t={};for k,n in pairs(self.stocks) do t[k]=n end;return t
  end
  function self:preview_remove(t,k,n)
    if (t[k] or 0)<n then return false end
    t[k]=t[k]-n;return true
  end
  function self:commit_preview(t)self.stocks=t end
  return self
end
local function uuid(n) return ("12345678-1234-4abc-8abc-%012d"):format(n) end
local defs={
 ["tamu:foundation"]={id="tamu:foundation",mode="foundation",rotation_steps=4,
    size={32,32,4},cost={["core:wood_plank"]=2},sockets={
      {id="north",kind="wall",x=0,y=-16,z=4,facing=6},
      {id="south",kind="wall",x=0,y=16,z=4,facing=2}}},
 ["tamu:wall"]={id="tamu:wall",mode="attached",rotation_steps=4,
    size={32,2,20},cost={["core:wood_plank"]=3},sockets={
      {id="bottom",kind="wall",x=0,y=0,z=0,facing=6},
      {id="top",kind="floor",x=0,y=0,z=20,facing=0}}},
 ["tamu:fence"]={id="tamu:fence",mode="free",rotation_steps=4,
    size={16,2,8},cost={["core:wood_log"]=1},sockets={}}
}
local world={sample=function(_,x,y)
  return {height=x>=128 and 2 or x/16,walkable=y<128,feature=y>110 and "water" or nil}
end,obstacles=function()return {} end,is_protected=function(_,x,y)return x>70 and x<90 end}
local kit=Kit.new(defs,world,{cell=32,max_pier=16,reach=300})
local player={x=0,y=0}
local p={x=0,y=0}
local ok,shape=kit:preview("tamu:foundation",p,0,nil,player)
assert(ok and shape.z==1 and kit.revision==0)
local a=kit:plan("p1",uuid(1),"tamu:foundation",p,0,nil,player,"player:local")
assert(a.ok and a.status=="planned" and kit.revision==1)
assert(kit:plan("p1",uuid(1),"tamu:foundation",p,0,nil,player,"player:local")==a)
assert(kit:plan("p1",uuid(2),"tamu:foundation",p,0,nil,player,"player:local").status=="command_conflict")
assert(#kit:obstacles({x=-10,y=-10,w=20,h=20,z=0,d=10})==0)
assert(kit:preview("tamu:foundation",p,0,nil,player)==false)
local inv=Inv.new(6)
assert(inv:credit_harvest({type="HarvestCompleted",transaction_id="p-wood",item_id="core:wood_plank",amount=10}))
assert(kit:deliver("d1",uuid(1),"core:wood_plank",1,inv).status=="delivered")
assert(inv:count("core:wood_plank")==9)
assert(kit:deliver("d1",uuid(1),"core:wood_plank",1,inv).status=="delivered")
assert(inv:count("core:wood_plank")==9)
assert(kit:deliver("d2",uuid(1),"core:wood_plank",1,inv).status=="built")
assert(#kit:obstacles({x=-10,y=-10,w=20,h=20,z=0,d=10})==1)
assert(kit:deliver("d3",uuid(1),"core:wood_plank",1,inv).status=="not_planned")
local attach={parent_id=uuid(1),parent_socket="south",child_socket="bottom"}
local wok,wpos=kit:preview("tamu:wall",{x=0,y=0},0,attach,player)
assert(wok and wpos.x==0 and wpos.y==16 and wpos.z==5)
assert(kit:plan("p2",uuid(2),"tamu:wall",{x=0,y=0},0,attach,player,"player:local").ok)
assert(kit:preview("tamu:wall",{x=0,y=0},0,attach,player)==false)
assert(kit:remove("rm1",uuid(1)).status=="has_dependents")
assert(kit:deliver("d4",uuid(2),"core:wood_plank",3,inv).status=="built")
assert(kit:remove("rm2",uuid(2)).status=="dismantle_not_implemented")
assert(#kit:obstacles({x=-10,y=15,w=20,h=5,z=5,d=15})==1)
local f=kit:plan("p3",uuid(3),"tamu:fence",{x=35,y=0},1,nil,player,"player:local")
assert(f.ok and kit:remove("rm3",uuid(3)).ok)
local bad=kit:plan("p4",uuid(4),"tamu:foundation",{x=80,y=0},0,nil,player,"player:local")
assert(not bad.ok and bad.status=="protected_area")
local snap=kit:snapshot()
assert(snap.version==1 and snap.parts[1].id==uuid(1) and snap.parts[2].id==uuid(2))
snap.parts[1].x=999
assert(kit.items[uuid(1)].x==0)
local spatial=Spatial.new(64)
for i=1,1000 do
  spatial:insert("p"..i,{x=(i%50)*128,y=math.floor(i/50)*128,w=16,h=16},{id=("p%04d"):format(i)})
end
assert(spatial.count==1000)
local pos={x=0,y=0,w=16,h=16}
for i=1,1000 do
  local ix=(i%50)*128
  local iy=math.floor(i/50)*128
  local hits=spatial:query({x=ix,y=iy,w=16,h=16})
  assert(#hits==1 and hits[1].id==("p%04d"):format(i))
end
-- The single-cell query does not need to traverse unrelated 999 pieces.
assert(#spatial:query({x=0,y=0,w=32,h=32})<=1)
assert(spatial:remove("p50") and spatial.count==999)
assert(not spatial:remove("p50"))
assert(#spatial:query({x=-64,y=-64,w=64,h=64})==0)
-- Reject unsafe terrain, protected areas and implicit free-standing walls.
assert(kit:preview("tamu:foundation",{x=0,y=128},0,nil,player)==false)
assert(kit:preview("tamu:wall",{x=200,y=0},0,nil,player)==false)
local obstacle_world={sample=world.sample,obstacles=function()return {{x=40,y=0,w=40,h=40}} end}
local blocked=Kit.new(defs,obstacle_world,{reach=400})
assert(blocked:preview("tamu:fence",{x=50,y=20},0,nil,player)==false)
local wrong=Kit.new(defs,world,{reach=200})
assert(not pcall(function() wrong:preview("tamu:fence",{x=0,y=0},4,nil,player) end))
print("BUILDING_KIT_OK 1000-index, blueprint, socket, support, 3D collision, idempotent staged material")
