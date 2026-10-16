package.path="./?.lua;./?/init.lua;"..package.path
local Json=require("save.json")
local Store=require("save.store")
local Tx=require("save.transaction")
local F=require("tests.save_v2_fixture")
local fs={files={},fails=false}
function fs:mkdir(_) return true end
function fs:read(path) return self.files[path] end
function fs:write(path,bytes)
  if self.fails and path:find("/current.json",1,true) then return false end
  self.files[path]=bytes;return true
end
local store=Store.new(fs,{catalog=F.catalog,generator_version=1,catalog_version=1})
local zero=F.empty()
assert(store:commit(zero))
local live=zero
local count=0
local transaction=Tx.new(store,F.world_id,function(next_state)
  live=next_state
  count=count+1
end)
local function stage(s)
  s.world_revision=s.world_revision+1
  s.journal_sequence=s.journal_sequence+1
  s.player.inventory.slots=Json.array({{slot=1,def_id="core:wood_log",count=3}})
  s.generated_object_delta.objects["worldobj:v1:20261015:-3:4"]={depleted=true}
  s.applied_transactions["harvest:1:1"]={revision=1,item_id="core:wood_log",amount=3}
  s.applied_commands["harvest:1"]={revision=1,status="complete"}
  return true
end
fs.fails=true
local ok=transaction:run("harvest:1",stage)
assert(not ok and count==0 and live.player.inventory.slots[1]==nil)
assert(next(live.generated_object_delta.objects)==nil)
assert(next(live.applied_transactions)==nil)
fs.fails=false
ok=transaction:run("harvest:1",stage)
assert(ok and count==1)
assert(live.player.inventory.slots[1].count==3)
assert(live.generated_object_delta.objects["worldobj:v1:20261015:-3:4"].depleted)
ok=transaction:run("harvest:1",stage)
assert(not ok and count==1)
local persisted=store:load(F.world_id)
assert(persisted.applied_transactions["harvest:1:1"].amount==3)
assert(persisted.player.inventory.slots[1].count==3)
assert(persisted.world_revision==1)
print("STAGE5_TRANSACTION_BOUNDARY_PASS")
