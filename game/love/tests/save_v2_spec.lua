package.path="./?.lua;./?/init.lua;"..package.path
local Json=require("save.json")
local Hash=require("save.hash")
local Validate=require("save.validate")
local Store=require("save.store")
local Fixture=require("tests.save_v2_fixture")
local checks=0
local function check(v,msg) checks=checks+1;assert(v,msg or "assertion failed") end
local function equals(a,b) return Json.encode(a)==Json.encode(b) end
local function rejected(fn)
  local ok=pcall(fn)
  check(not ok,"expected fail closed")
end
local function memory()
  local fs={files={},writes=0,failed=nil,cut=nil}
  function fs:mkdir(_path) return true end
  function fs:read(path) return self.files[path] end
  function fs:write(path,data)
    self.writes=self.writes+1
    if self.failed and path:find(self.failed,1,true) then return false end
    if self.cut and path:find(self.cut,1,true) then
      self.files[path]=data:sub(1,math.max(1,math.floor(#data/3)))
      return true
    end
    self.files[path]=data
    return true
  end
  return fs
end
local function start(fs)
  return Store.new(fs,{catalog=Fixture.catalog,catalog_version=1,generator_version=1})
end
local uuid=Fixture.world_id
local function root() return "worlds/"..uuid.."/" end
local function run()
  check(Hash.pure("abc")=="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    "sha256 known-answer")
  check(Hash.pure("")=="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "sha256 empty")
  check(Json.encode(Json.decode('{"a":[1,2],"b":"x"}'))=='{"a":[1,2],"b":"x"}')
  rejected(function() Json.decode('{"a":1,"a":2}') end)
  rejected(function() Json.decode('{"a":null}') end)
  rejected(function() Json.decode('{"a":3e}') end)
  rejected(function() Json.decode('{"x":[],"x":{}}') end)
  local fs=memory()
  local store=start(fs)
  local absent,absent_meta=store:load(uuid)
  check(absent==nil and absent_meta.status=="absent","empty world")
  local zero=Fixture.empty()
  check(Validate.check(zero,{catalog=Fixture.catalog,catalog_version=1,generator_version=1}))
  local ok,code=store:commit(zero)
  check(ok and code=="committed","first checkpoint "..tostring(code))
  local got,meta=store:load(uuid)
  check(equals(got,zero) and meta.status=="ok" and not meta.read_only,"load 0")
  local first_pointer=fs.files[root().."current.json"]
  check(first_pointer~=nil,"pointer present")
  local writes=fs.writes
  ok,code=store:commit(zero)
  check(ok and code=="unchanged" and fs.writes==writes,"retry idempotent")
  local one=Fixture.next(zero)
  check(Validate.check(one,{catalog=Fixture.catalog,catalog_version=1,generator_version=1}))
  ok,code=store:commit(one)
  check(ok and code=="committed","second checkpoint "..tostring(code))
  got,meta=store:load(uuid)
  check(equals(got,one) and meta.status=="ok","load 1 with negative coords/ledgers")
  check(fs.files[root().."previous.json"]==first_pointer,"rollback pointer")
  check(got.applied_commands["place:one"].status=="placed","durable command ledger")
  check(got.applied_transactions["harvest:one"].amount==2,"durable tx ledger")
  local good_current=fs.files[root().."current.json"]
  fs.files[root().."current.json"]="{"
  got,meta=store:load(uuid)
  check(equals(got,zero) and meta.read_only and meta.status=="recovered_previous",
    "corrupt pointer rollback")
  ok,code=store:commit(one)
  check(not ok and code=="read_only_quarantine","no writing over corrupt pointer")
  fs.files[root().."current.json"]=good_current
  local ptr=Json.decode(good_current)
  local valid_journal=fs.files[ptr.journal]
  fs.files[ptr.journal]="truncated"
  got,meta=store:load(uuid)
  check(equals(got,zero) and meta.read_only,"corrupt journal rolls back")
  fs.files[ptr.journal]=valid_journal
  local valid_snapshot=fs.files[ptr.snapshot]
  fs.files[ptr.snapshot]=nil
  got,meta=store:load(uuid)
  check(equals(got,zero) and meta.read_only,"missing snapshot rolls back")
  fs.files[ptr.snapshot]=valid_snapshot
  local old=Json.decode(Json.encode(one))
  old.world_revision=2;old.journal_sequence=2
  local write_baseline=fs.files[root().."current.json"]
  fs.failed="journal/"
  ok,code=store:commit(old)
  check(not ok and fs.files[root().."current.json"]==write_baseline,"disk failure preserves current")
  fs.failed=nil
  fs.cut="snapshots/"
  ok,code=store:commit(old)
  check(not ok and fs.files[root().."current.json"]==write_baseline,"partial write preserves current")
  fs.cut=nil
  got,meta=store:load(uuid)
  check(meta.status=="ok" and equals(got,one),"last good still accessible")
  local unknown=Json.decode(Json.encode(one))
  unknown.player.inventory.slots[1].def_id="core:missing"
  rejected(function() Validate.check(unknown,{catalog=Fixture.catalog,generator_version=1,catalog_version=1}) end)
  ok=store:commit(unknown)
  check(not ok,"unknown ID cannot save")
  local mismatch=Json.decode(Json.encode(one))
  mismatch.generator_version=2
  rejected(function() Validate.check(mismatch,{catalog=Fixture.catalog,generator_version=1,catalog_version=1}) end)
  local bad_delta=Json.decode(Json.encode(one))
  bad_delta.generated_object_delta.objects["worldobj:v1:20261015:-3:4"]=nil
  bad_delta.generated_object_delta.objects["worldobj:v1:20261016:-3:4"]={depleted=true}
  rejected(function() Validate.check(bad_delta,{catalog=Fixture.catalog,generator_version=1,catalog_version=1}) end)
  local dup=Json.decode(Json.encode(one))
  dup.player.inventory.slots[2].slot=1
  rejected(function() Validate.check(dup,{catalog=Fixture.catalog,generator_version=1,catalog_version=1}) end)
  local bad_uuid=Json.decode(Json.encode(one))
  bad_uuid.placed_instances[Fixture.placed_id].id="12345678-1234-4abc-7abc-123456789abe"
  rejected(function() Validate.check(bad_uuid,{catalog=Fixture.catalog,generator_version=1,catalog_version=1}) end)
  -- Retrying the same damaged content address must fail, not overwrite it.
  ok,code=store:commit(old)
  check(not ok and fs.files[root().."current.json"]==write_baseline,
    "partial immutable snapshot cannot be overwritten")
  -- A different, correctly checksummed revision-2 snapshot may commit safely.
  local changed=Json.decode(Json.encode(one))
  changed.world_revision=2;changed.journal_sequence=2
  changed.player.inventory.slots[1].count=3
  ok,code=store:commit(changed)
  check(ok and code=="committed","independent snapshot digest can recover "..tostring(code))
  got,meta=store:load(uuid)
  check(meta.status=="ok" and equals(got,changed),"roundtrip latest state")
  check(fs.files[root().."previous.json"]==write_baseline,"previous remains last good")
  local attempt=Json.decode(Json.encode(changed))
  attempt.world_revision=3;attempt.journal_sequence=3
  attempt.applied_commands["place:one"].status="failed"
  ok,code=store:commit(attempt)
  check(not ok and code:find("ledger_or_instance_rewrite",1,true),"durable command replay rewrite rejected")
  attempt=Json.decode(Json.encode(changed))
  attempt.world_revision=3;attempt.journal_sequence=3
  attempt.applied_transactions["harvest:one"].amount=99
  ok,code=store:commit(attempt)
  check(not ok and code:find("ledger_or_instance_rewrite",1,true),"durable tx rewrite rejected")
  attempt=Json.decode(Json.encode(changed))
  attempt.world_revision=3;attempt.journal_sequence=3
  attempt.generated_object_delta.objects["worldobj:v1:20261015:-3:4"]=nil
  ok,code=store:commit(attempt)
  check(not ok and code=="restored_depleted_object","depleted object must remain depleted")
  attempt=Json.decode(Json.encode(changed))
  attempt.world_revision=3;attempt.journal_sequence=3
  attempt.placed_instances[Fixture.placed_id].x=22
  ok,code=store:commit(attempt)
  check(not ok and code:find("ledger_or_instance_rewrite",1,true),"placed instance identity immutable")
  local malformed=Json.decode(Json.encode(changed))
  malformed.player.inventory.slots={}
  rejected(function()
    Validate.check(malformed,{catalog=Fixture.catalog,generator_version=1,catalog_version=1})
  end)
  -- All failed replay attempts must leave the last committed pointer untouched.
  check(fs.files[root().."current.json"]~=nil,"no pointer loss")
  local wrong_opt=Store.new(fs,{catalog=Fixture.catalog,generator_version=2,catalog_version=1})
  got,meta=wrong_opt:load(uuid)
  check(got==nil or meta.read_only,"generator mismatch read-only")
  -- Missing both recovery anchors must not silently initialize.
  fs.files[root().."current.json"]="corrupt"
  fs.files[root().."previous.json"]="corrupt"
  got,meta=store:load(uuid)
  check(got==nil and meta.status=="quarantined","missing safe checkpoint")
  ok,code=store:commit(Fixture.empty())
  check(not ok and code=="read_only_quarantine","never overwrite quarantined world")
end
run()
print("SAVE_V2_PASS assertions="..checks)
