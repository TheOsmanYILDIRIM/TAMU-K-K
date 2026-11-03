local Json=require("save.json")
local Store=require("save.store")
local Fs=require("save.love_fs")
local Fixture=require("fixture")
local completed=false
function love.load()
  love.filesystem.setIdentity("stage6_save_v2_ci_"..tostring(os.time()))
  local db=Store.new(Fs.new(),{catalog=Fixture.catalog,catalog_version=1,generator_version=1})
  local ok,msg=db:commit(Fixture.empty())
  assert(ok,"LOVE write/readback checkpoint 0: "..tostring(msg))
  local snapshot,meta=db:load(Fixture.world_id)
  assert(meta.status=="ok" and snapshot.world_revision==0)
  ok,msg=db:commit(Fixture.next(snapshot))
  assert(ok,"LOVE checkpoint 1: "..tostring(msg))
  snapshot,meta=db:load(Fixture.world_id)
  assert(meta.status=="ok" and snapshot.world_revision==1)
  assert(snapshot.generated_object_delta.objects["worldobj:v1:20261015:-3:4"].depleted)
  assert(snapshot.applied_commands["place:one"].status=="placed")
  -- A deliberate corrupt current pointer must yield the previous known-good
  -- revision, never a fabricated empty/default world.
  local pointer_path="worlds/"..Fixture.world_id.."/current.json"
  assert(love.filesystem.write(pointer_path,"{"))
  local previous,recovery=db:load(Fixture.world_id)
  assert(recovery.status=="recovered_previous" and recovery.read_only)
  assert(previous.world_revision==0)
  local allowed,reason=db:commit(Fixture.next(previous))
  assert(not allowed and reason=="read_only_quarantine")
  print("LOVE_FS_RECOVERY_OK previous_revision=0 read_only=true")
  local f=love.filesystem.newFile("stage6_save_smoke_report.txt","w")
  assert(f:write("LOVE_FS_SAVE_V2_OK\nrevision=1\nchecksum=sha256\n"))
  f:close()
  print("LOVE_FS_SAVE_V2_OK revision=1")
  completed=true
  love.event.quit(0)
end
function love.update() if completed then love.event.quit(0) end end
