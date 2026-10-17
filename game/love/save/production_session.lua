-- Explicit Stage6 lifecycle for a production LÖVE world.
-- Opt-in only: no autosave, no implicit overwrite of old user saves.
local Store=require("save.store")
local Fs=require("save.love_fs")
local Restore=require("save.stage5_domain_restore")
local Clone=require("save.stage5_domain_clone")
local Catalog=require("systems.catalog")
local Checkpoint=require("save.stage5_checkpoint")
local Session={}
Session.__index=Session
function Session.open(live,opts)
  assert(live and live.building and live.world and live.inventory)
  assert(type(opts)=="table" and type(opts.world_id)=="string")
  local store=Store.new(opts.fs or Fs.new(),{
    catalog=Catalog.items(),catalog_version=Catalog.version(),
    generator_version=live.world.generator_version,seed=live.world.seed})
  assert(live.building.world_id==opts.world_id,"world ID mismatch")
  local state,meta=store:load(opts.world_id)
  if meta.status=="quarantined" or meta.status=="recovered_previous" then
    return nil,meta.status -- Never overwrite a corrupt/recovered save.
  end
  if meta.status=="absent" then
    assert(opts.create==true,"explicit create required")
    local fresh=Checkpoint.compose({
      inventory=live.inventory,world=live.world,building=live.building,
      world_id=opts.world_id,catalog=Catalog.items(),
      catalog_version=Catalog.version(),revision=0,sequence=0,
      player_id=assert(opts.player_id),x=assert(opts.x),y=assert(opts.y),
      applied_commands={},applied_transactions={}
    })
    local ok,why=store:commit(fresh)
    if not ok then return nil,why end
    state=fresh
  end
  local candidate,position=Restore.restore(live,state)
  Clone.publish(live,candidate)
  return setmetatable({store=store,world_id=opts.world_id,
    revision=state.world_revision,position=position},Session),"ok"
end
function Session:reload(live)
  local state,meta=self.store:load(self.world_id)
  if not state or meta.status~="ok" then return false,meta.status end
  local candidate,position=Restore.restore(live,state)
  Clone.publish(live,candidate)
  self.revision=state.world_revision
  self.position=position
  return true,position
end
return Session
