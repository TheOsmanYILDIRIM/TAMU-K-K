package.path="./?.lua;./?/init.lua;"..package.path
local Json=require("save.json")
local Store=require("save.store")
local Bridge=require("save.stage5_transaction_bridge")
local F=require("tests.save_v2_fixture")
local fs={files={},fail=false}
function fs:mkdir(_) return true end
function fs:read(path) return self.files[path] end
function fs:write(path,bytes)
  if self.fail and path:find("/current.json",1,true) then return false end
  self.files[path]=bytes;return true
end
local store=Store.new(fs,{catalog=F.catalog,generator_version=1,catalog_version=1})
assert(store:commit(F.empty()))
local live={wood=0,craft=0,build=0}
local published=0
local bridge=Bridge.new(store,F.world_id,function()
  return {wood=live.wood,craft=live.craft,build=live.build}
end,function(candidate,kind,args,s,previous,id)
  local key=kind=="harvest" and "wood" or kind
  candidate[key]=candidate[key]+1
  s.world_revision=previous.world_revision+1
  s.journal_sequence=previous.journal_sequence+1
  s.applied_commands[id]={revision=s.world_revision,status="complete"}
  return true
end,function(domain,s)
  live=domain
  published=published+1
end)
for _,kind in ipairs({"harvest","craft","build"}) do
  fs.fail=true
  local ok=bridge:run(kind..":1",kind,{})
  assert(not ok and published==0 and live.wood==0 and live.craft==0 and live.build==0)
  fs.fail=false
end
for _,kind in ipairs({"harvest","craft","build"}) do
  local ok,why=bridge:run(kind..":1",kind,{})
  assert(ok,why)
end
assert(live.wood==1 and live.craft==1 and live.build==1 and published==3)
for _,kind in ipairs({"harvest","craft","build"}) do
  local ok,why=bridge:run(kind..":1",kind,{})
  assert(not ok and why=="duplicate")
end
local restored,meta=store:load(F.world_id)
assert(meta.status=="ok" and restored.world_revision==3)
print("STAGE5_DETACHED_BRIDGE_OK failed-write no-publish harvest craft build replay")
