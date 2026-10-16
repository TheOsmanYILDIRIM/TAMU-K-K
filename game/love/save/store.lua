-- Snapshot + immutable journal, checksum and verified pointer recovery.
-- Existing world state is never changed by load; recovered data is read-only.
local Json=require("save.json")
local Hash=require("save.hash")
local Validate=require("save.validate")
local Store={}
Store.__index=Store
local function safe(f,...)
  local ok,a,b,c=pcall(f,...)
  if not ok then return false,"io_or_contract_error:"..tostring(a) end
  return a,b,c
end
local function checksummed_path(root,category,n,digest,ext)
  return root.."/"..category.."/"..tostring(n).."-"..digest.."."..ext
end
local function root_of(id) return "worlds/"..id end
local function sorted_revision_keys(entries,n)
  local ids={}
  for id,obj in pairs(entries) do
    if obj.revision==n then ids[#ids+1]=id end
  end
  table.sort(ids)
  return Json.array(ids)
end
local function match_array(a,b)
  if #a~=#b then return false end
  for i=1,#a do if a[i]~=b[i] then return false end end
  return true
end
-- Replay safety: previously committed identities and depletion never disappear
-- or silently change when a new full-state checkpoint is accepted.
local function monotonic(old,new)
  local collections={"applied_commands","applied_transactions","placed_instances"}
  for _,name in ipairs(collections) do
    for id,entry in pairs(old[name]) do
      if new[name][id]==nil or Json.encode(new[name][id])~=Json.encode(entry) then
        return false,"ledger_or_instance_rewrite:"..name..":"..id
      end
    end
  end
  for id in pairs(old.generated_object_delta.objects) do
    if new.generated_object_delta.objects[id]==nil then
      return false,"restored_depleted_object"
    end
  end
  if new.player.id~=old.player.id then return false,"player_identity_changed" end
  return true
end
function Store.new(fs,opts)
  assert(type(fs)=="table" and type(fs.read)=="function"
     and type(fs.write)=="function" and type(fs.mkdir)=="function","fs port required")
  assert(type(opts)=="table" and type(opts.catalog)=="table",
    "explicit canonical catalog required")
  return setmetatable({fs=fs,opts=opts},Store)
end
function Store:raw(path)
  local data=self.fs:read(path)
  if data==nil then return nil end
  if type(data)~="string" or #data>8*1024*1024 then error("invalid file size") end
  return data
end
function Store:read_pointer(path,id)
  local raw=self:raw(path)
  if raw==nil then return nil end
  local p=Json.decode(raw)
  if type(p)~="table" then error("invalid pointer") end
  local keys={pointer_version=true,world_id=true,revision=true,sequence=true,
    snapshot_sha256=true,journal_sha256=true,snapshot=true,journal=true}
  for k in pairs(p) do if not keys[k] then error("unknown pointer key") end end
  for k in pairs(keys) do if p[k]==nil then error("incomplete pointer") end end
  if p.pointer_version~=1 or p.world_id~=id or type(p.revision)~="number"
     or p.revision<0 or p.revision~=math.floor(p.revision)
     or type(p.sequence)~="number" or p.sequence<0
     or p.sequence~=math.floor(p.sequence) then error("invalid pointer metadata") end
  if type(p.snapshot_sha256)~="string" or not p.snapshot_sha256:match("^[0-9a-f]+$")
    or #p.snapshot_sha256~=64 or type(p.journal_sha256)~="string"
    or not p.journal_sha256:match("^[0-9a-f]+$") or #p.journal_sha256~=64 then
    error("invalid pointer hashes")
  end
  local root=root_of(id)
  if p.snapshot~=checksummed_path(root,"snapshots",p.revision,p.snapshot_sha256,"json")
   or p.journal~=checksummed_path(root,"journal",p.sequence,p.journal_sha256,"jsonl") then
    error("pointer path mismatch")
  end
  return p
end
function Store:verify_pointer(p,id)
  local snap=self:raw(p.snapshot)
  if not snap or Hash.sha256(snap)~=p.snapshot_sha256 then error("snapshot checksum failed") end
  local state=Json.decode(snap)
  local opts={}
  for k,v in pairs(self.opts) do opts[k]=v end
  opts.world_id=id
  Validate.check(state,opts)
  if state.world_revision~=p.revision or state.journal_sequence~=p.sequence then
    error("pointer snapshot revision mismatch")
  end
  local journal=self:raw(p.journal)
  if not journal or Hash.sha256(journal)~=p.journal_sha256 then
    error("journal checksum failed")
  end
  if journal:sub(-1)~="\n" then error("journal truncated") end
  local j=Json.decode(journal:sub(1,-2))
  if type(j)~="table" then error("bad journal") end
  local expected={format=true,save_version=true,world_id=true,world_revision=true,
    sequence=true,state_sha256=true,command_ids=true,transaction_ids=true}
  for k in pairs(j) do if not expected[k] then error("extra journal key") end end
  for k in pairs(expected) do if j[k]==nil then error("missing journal key") end end
  if j.format~="love-world-journal" or j.save_version~=2 or j.world_id~=id
    or j.world_revision~=p.revision or j.sequence~=p.sequence
    or j.state_sha256~=p.snapshot_sha256
    or type(j.command_ids)~="table" or type(j.transaction_ids)~="table"
    or not (getmetatable(j.command_ids) and getmetatable(j.command_ids).__json_array)
    or not (getmetatable(j.transaction_ids) and getmetatable(j.transaction_ids).__json_array)
    or not match_array(j.command_ids,sorted_revision_keys(state.applied_commands,p.revision))
    or not match_array(j.transaction_ids,sorted_revision_keys(state.applied_transactions,p.revision))
    then error("journal inconsistent with snapshot") end
  return state
end
function Store:inspect(id)
  if not Validate.uuid(id) then return nil,"invalid_world_id" end
  local root=root_of(id)
  local current_path=root.."/current.json"
  local previous_path=root.."/previous.json"
  local ok,ptr=pcall(self.read_pointer,self,current_path,id)
  if ok and ptr then
    local verified,state=pcall(self.verify_pointer,self,ptr,id)
    if verified then return state,{status="ok",read_only=false,pointer=ptr} end
  end
  local prev_ok,previous=pcall(self.read_pointer,self,previous_path,id)
  if prev_ok and previous then
    local verified,state=pcall(self.verify_pointer,self,previous,id)
    if verified then return state,{status="recovered_previous",read_only=true,pointer=previous} end
  end
  if ok and not ptr and prev_ok and not previous then return nil,{status="absent",read_only=true} end
  return nil,{status="quarantined",read_only=true}
end
function Store:load(id)
  return self:inspect(id)
end
function Store:checked_write(path,bytes)
  local old=self:raw(path)
  if old~=nil then
    if old~=bytes then error("immutable file conflict") end
    return
  end
  if not self.fs:write(path,bytes) then error("write failure: "..path) end
  if self:raw(path)~=bytes then error("write/readback mismatch: "..path) end
end
function Store:commit(state)
  local ok,err=pcall(Validate.check,state,self.opts)
  if not ok then return false,"rejected:"..tostring(err) end
  local id=state.world_id
  local old,meta=self:inspect(id)
  if meta.status=="quarantined" or meta.status=="recovered_previous" then
    return false,"read_only_quarantine"
  end
  if old then
    if state.world_revision==old.world_revision
      and Json.encode(state)==Json.encode(old) then return true,"unchanged" end
    if state.world_revision~=old.world_revision+1
      or state.journal_sequence~=old.journal_sequence+1
      or state.seed~=old.seed or state.catalog_version~=old.catalog_version
      or state.generator_version~=old.generator_version then
        return false,"nonsequential_or_incompatible"
    end
    local allowed,reason=monotonic(old,state)
    if not allowed then return false,reason end
  elseif state.world_revision~=0 or state.journal_sequence~=0 then
    return false,"fresh_world_must_start_at_zero"
  end
  local root=root_of(id)
  local body=Json.encode(state).."\n"
  local digest=Hash.sha256(body)
  local journal_data=Json.encode({
    format="love-world-journal",save_version=2,world_id=id,
    world_revision=state.world_revision,sequence=state.journal_sequence,
    state_sha256=digest,
    command_ids=sorted_revision_keys(state.applied_commands,state.world_revision),
    transaction_ids=sorted_revision_keys(state.applied_transactions,state.world_revision)
  }).."\n"
  local jdigest=Hash.sha256(journal_data)
  local p={pointer_version=1,world_id=id,revision=state.world_revision,
    sequence=state.journal_sequence,snapshot_sha256=digest,journal_sha256=jdigest,
    snapshot=checksummed_path(root,"snapshots",state.world_revision,digest,"json"),
    journal=checksummed_path(root,"journal",state.journal_sequence,jdigest,"jsonl")}
  local pbytes=Json.encode(p).."\n"
  local success,why=safe(function()
    for _,dir in ipairs({root,root.."/snapshots",root.."/journal"}) do
      if not self.fs:mkdir(dir) then error("mkdir failure: "..dir) end
    end
    self:checked_write(p.journal,journal_data)
    self:checked_write(p.snapshot,body)
    self:verify_pointer(p,id)
    -- Old committed current is saved before publishing new current.
    if meta.pointer then
      local previous_data=Json.encode(meta.pointer).."\n"
      if not self.fs:write(root.."/previous.json",previous_data) then
        error("previous write failure")
      end
      if self:raw(root.."/previous.json")~=previous_data then
        error("previous readback mismatch")
      end
    end
    if not self.fs:write(root.."/current.json",pbytes) then error("pointer write failure") end
    if self:raw(root.."/current.json")~=pbytes then error("pointer readback mismatch") end
    local latest=self:read_pointer(root.."/current.json",id)
    self:verify_pointer(latest,id)
    return true,"committed"
  end)
  if not success then return false,why end
  return true,"committed",p
end
return Store
