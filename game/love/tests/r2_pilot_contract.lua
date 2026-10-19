-- R2 G: deterministic runtime, read-pin, collision/path and Stage5 safeguards.
package.path="./?.lua;./?/init.lua;"..package.path
local Pilot=require("world.r2_playable")
local Collision=require("physics.collision")
local Inventory=require("systems.inventory")
local Building=require("systems.building")
local Camera=require("core.camera")
local Hash=require("save.hash")
assert(Hash.sha256("abc")==
  "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
local function raw(name)
  local f=assert(io.open("../../data/worldbuild/"..name,"rb"))
  local text=f:read("*a");f:close();return text
end
local function valid(name) return raw(name) end
local p=Pilot.new({read=valid})
local duplicate=Pilot.new({read=valid})
assert(p.query.seed==20261018 and p.query.generator_version==1)
assert(p.scene.production_enabled==false and p.persistence_supported==false)
assert(#p.routes.crossings==0 and #duplicate.routes.crossings==0)
assert(p.query.map_id=="worldmap:fisilti-ormani")
assert(p.query:surface_at(704,128).wet)
assert(p.query:surface_at(704,128).immersion==.5)
assert(p.query:surface_at(704,128).speed_multiplier==.55)
assert(p.query:route_cost({x=690,y=128},{x=718,y=128}).cost>28)
assert(not p:can_build(64,128,5))
local b=Building.new(Inventory.new(12),p.query,p.solid,
  "12345678-1234-4abc-8abc-123456789abc")
local bank_a,bank_b=680,734
assert(Collision.can_stand(b,bank_a,128,5)
  and Collision.can_stand(b,bank_b,128,5),"actual R2 crossing banks blocked")
assert(not b:surface_at(bank_a,128).wet
  and not b:surface_at(bank_b,128).wet,"actual R2 banks must be dry")
local mx,my,hit=Collision.move(b,bank_a,128,bank_b-bank_a,0,5)
assert(not hit and math.abs(mx-bank_b)<.01 and math.abs(my-128)<.01,
  "R2 crossing contains a solid cliff or object; no fake bridge")
local player=p:spawn_player(b)
assert(p.query:is_walkable(player.x,player.y))
assert(Collision.can_stand(b,player.x,player.y,5))
local cam=p:mount_camera(Camera.new())
cam.x,cam.y=player.x,player.y
for _,pos in ipairs({{64,128},{704,128},{320,420},{1100,350}}) do
  local x,y=pos[1],pos[2]
  local sx,sy=cam:project(x,y,720,1100)
  local ix,iy=cam:unproject(sx,sy,720,1100)
  assert(math.abs(ix-x)<.025 and math.abs(iy-y)<.025,
    "height-aware camera roundtrip mismatch")
end
local before_x,before_y=player.x,player.y
local ok,why=player:navigate_to(before_x+16,before_y,8,1200)
assert(ok,"authored spawn short path blocked: "..tostring(why))
for _=1,130 do player:update(1/60,0,0) end
assert((player.x-before_x)^2+(player.y-before_y)^2>8^2,
  "real controller/path failed to move")
assert(Collision.can_stand(b,player.x,player.y,player.radius))
for _,a in ipairs({{"fisilti_ormani.r2.v1.json"," "},
                   {"osman_overworld.v2.json","\n"}}) do
  assert(not pcall(function()
    Pilot.new({read=function(name)
      if name==a[1] then return raw(name)..a[2] end
      return raw(name)
    end})
  end),"modified R2 source accepted: "..a[1])
end
assert(not pcall(function() Pilot.new({read=function() return nil end}) end))
assert(not pcall(function() p:mount_camera(cam) end))
print("R2_G_CONTRACT_OK pinned-docs, opt-in, no-bridge, camera, path, wet, no-build")
