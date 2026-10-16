package.path="./?.lua;./?/init.lua;"..package.path
local Inventory=require("systems.inventory")
local Json=require("save.json")
local Store=require("save.store")
local Fixture=require("tests.save_v2_fixture")
local Compose=require("save.stage5_checkpoint")
local inv=Inventory.new(12)
local world={seed=20261015,generator_version=1,delta={}}
function world:export_delta()
  local objects={}
  for id,v in pairs(self.delta) do objects[id]={depleted=v.depleted} end
  return {version=1,seed=self.seed,generator_version=self.generator_version,objects=objects}
end
local building={world_id=Fixture.world_id}
function building:snapshot()
  return {world_id=self.world_id,placed={}}
end
local function candidate(revision,sequence,commands,transactions)
 return Compose.compose({inventory=inv,world=world,building=building,
   world_id=Fixture.world_id,player_id="player:local",x=-32,y=64,
   catalog_version=1,catalog=Fixture.catalog,revision=revision,sequence=sequence,
   applied_commands=commands or {},applied_transactions=transactions or {}})
end
local fs={files={},fail=false}
function fs:mkdir() return true end
function fs:read(p) return self.files[p] end
function fs:write(p,b)
 if self.fail and p:find("/current.json",1,true) then return false end
 self.files[p]=b;return true
end
local store=Store.new(fs,{catalog=Fixture.catalog,catalog_version=1,generator_version=1})
local initial=candidate(0,0)
assert(store:commit(initial))
local id="worldobj:v1:20261015:-3:4"
assert(inv:credit_harvest({type="HarvestCompleted",transaction_id="harvest:1:1",item_id="core:wood_log",amount=3}))
world.delta[id]={depleted=true}
local commands={["harvest:1"]={revision=1,status="complete"}}
local transactions={["harvest:1:1"]={revision=1,item_id="core:wood_log",amount=3}}
local next_state=candidate(1,1,commands,transactions)
fs.fail=true
local ok=store:commit(next_state)
assert(not ok)
local existing=store:load(Fixture.world_id)
assert(existing.world_revision==0,"unpublished pending data must not appear on disk")
fs.fail=false
ok=store:commit(next_state)
assert(ok,"commit after failed pointer")
local loaded,meta=store:load(Fixture.world_id)
assert(meta.status=="ok" and loaded.world_revision==1)
assert(loaded.player.inventory.slots[1].count==3)
assert(loaded.generated_object_delta.objects[id].depleted)
assert(loaded.applied_transactions["harvest:1:1"].amount==3)
local dup=Json.decode(Json.encode(next_state))
dup.world_revision=2;dup.journal_sequence=2
dup.applied_transactions["harvest:1:1"].amount=6
local success,reason=store:commit(dup)
assert(not success and reason:find("ledger_or_instance_rewrite",1,true))
fs.files["worlds/"..Fixture.world_id.."/current.json"]="{"
local rollback,info=store:load(Fixture.world_id)
assert(info.status=="recovered_previous" and info.read_only and rollback.world_revision==0)
print("STAGE5_CHECKPOINT_PASS")
