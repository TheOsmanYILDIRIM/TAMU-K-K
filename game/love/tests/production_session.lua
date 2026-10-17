package.path="./?.lua;./?/init.lua;"..package.path
local Query=require("world.world_query")
local Water=require("world.collision_adapter")
local World=require("objects.world")
local Solid=require("objects.query")
local Inventory=require("systems.inventory")
local Craft=require("systems.crafting")
local Building=require("systems.building")
local Harvest=require("objects.harvesting")
local Session=require("save.production_session")
local F=require("tests.save_v2_fixture")
local function fresh()
  local q=Query.new(20261015)
  local water=Water.new(q,8)
  local w=World.new(q,water)
  local so=Solid.new(water,w)
  local inv=Inventory.new(12)
  return {query=q,world=w,solid=so,inventory=inv,
    building=Building.new(inv,q,so,F.world_id),
    crafting=Craft.new(inv),harvesting=Harvest.new(w,38,inv)}
end
local fs={files={},fail=false}
function fs:mkdir(_) return true end
function fs:read(path) return self.files[path] end
function fs:write(path,bytes)
  if self.fail then return false end
  self.files[path]=bytes;return true
end
local live=fresh()
assert(not Session.open(live,{fs=fs,world_id=F.world_id}))
local opts={fs=fs,world_id=F.world_id,create=true,
  player_id="player:local",x=7,y=-12}
local session,reason=Session.open(live,opts)
assert(session,reason)
local reopened=fresh()
local other,why=Session.open(reopened,{fs=fs,world_id=F.world_id})
assert(other,why)
assert(other.position.x==7 and other.position.y==-12)
assert(other.revision==0)
local root="worlds/"..F.world_id
fs.files[root.."/current.json"]="corrupted"
local protected=fresh()
local blocked,why=Session.open(protected,{fs=fs,world_id=F.world_id,create=true,
  player_id="player:local",x=0,y=0})
assert(not blocked and why=="quarantined")
assert(next(protected.world.delta)==nil)
print("STAGE6_PRODUCTION_SESSION_OK create reopen quarantine")
