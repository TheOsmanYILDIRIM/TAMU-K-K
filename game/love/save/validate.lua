-- Independent Stage 6 contract gate. No Stage 5 runtime dependency.
local V={}
local function fail(msg) error("save_v2: "..msg,0) end
local function require_type(x,k,t)
  if type(x)~=t then fail(k.." must be "..t) end
end
local function exact(x,label,keys)
  require_type(x,label,"table")
  for k in pairs(x) do if not keys[k] then fail(label.." has unknown field "..tostring(k)) end end
  for k in pairs(keys) do if x[k]==nil then fail(label.." missing "..k) end end
end
local function optional(x,label,allowed,required)
  require_type(x,label,"table")
  for k in pairs(x) do if not allowed[k] then fail(label.." has unknown field "..tostring(k)) end end
  for _,k in ipairs(required) do if x[k]==nil then fail(label.." missing "..k) end end
end
local function fields(names)
  local t={}
  for _,n in ipairs(names) do t[n]=true end
  return t
end
local function integer(n,low,high)
  return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
     and n==math.floor(n) and n>=low and n<=high
end
local function finite(n)
  return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function ident(s)
  return type(s)=="string" and s:match("^[a-z][a-z0-9_-]*:[a-z][a-z0-9_-]*$")~=nil
end
local function uuid(s)
  if type(s)~="string" then return false end
  local a,b,c,d,e=s:match("^(%x+)%-(%x+)%-(%x+)%-(%x+)%-(%x+)$")
  return a~=nil and #a==8 and #b==4 and #c==4 and #d==4 and #e==12
    and c:sub(1,1)=="4" and d:sub(1,1):match("[89aAbB]")~=nil
end
local function ensure_id(s,label)
  if not ident(s) then fail("invalid "..label) end
end
local function nonempty(s,label,limit)
  if type(s)~="string" or #s==0 or #s>(limit or 128) then fail("invalid "..label) end
end
local function catalog_entry(catalog,id,placed)
  ensure_id(id,"definition ID")
  local item=catalog[id]
  if type(item)~="table" then fail("unknown catalog definition "..id) end
  local max=item.max_stack
  if not integer(max,1,2147483647) then fail("missing/invalid stack rule "..id) end
  if placed and not item.placeable then fail("unplaceable definition "..id) end
  return item
end
local top=fields({"format","save_version","world_id","seed","generator_version",
  "catalog_version","world_revision","player","generated_object_delta","placed_instances",
  "applied_commands","applied_transactions","journal_sequence"})
local player_fields=fields({"id","x","y","inventory"})
local inv_fields=fields({"version","catalog_version","capacity","slots"})
local slot_fields=fields({"slot","def_id","count"})
local delta_fields=fields({"version","seed","generator_version","objects"})
local place_fields=fields({"id","def_id","x","y","rotation","owner_id","command_id","revision"})
local cmd_fields=fields({"revision","status","reason"})
local tx_fields=fields({"revision","item_id","amount"})
local statuses={started=true,complete=true,failed=true,interrupted=true,crafted=true,placed=true}

function V.check(s,opts)
  opts=opts or {}
  if type(opts.catalog)~="table" then fail("catalog resolver required") end
  local catalog=opts.catalog
  exact(s,"world",top)
  if s.format~="love-world-2d" or s.save_version~=2 then fail("wrong format/version") end
  if not uuid(s.world_id) then fail("invalid world UUIDv4") end
  if opts.world_id and s.world_id~=opts.world_id then fail("world_id mismatch") end
  if not integer(s.seed,0,2147483646) then fail("invalid seed") end
  if opts.seed and s.seed~=opts.seed then fail("seed mismatch") end
  if not integer(s.generator_version,1,1000000) or
     s.generator_version~=(opts.generator_version or 1) then fail("generator version mismatch") end
  if not integer(s.catalog_version,1,1000000) or
     s.catalog_version~=(opts.catalog_version or 1) then fail("catalog version mismatch") end
  if not integer(s.world_revision,0,9007199254740991) then fail("invalid world revision") end
  if not integer(s.journal_sequence,0,9007199254740991)
    or s.journal_sequence<s.world_revision then fail("invalid journal sequence") end
  exact(s.player,"player",player_fields)
  nonempty(s.player.id,"player ID")
  if not finite(s.player.x) or not finite(s.player.y) then fail("invalid player position") end
  local inv=s.player.inventory
  exact(inv,"inventory",inv_fields)
  if inv.version~=1 or inv.catalog_version~=s.catalog_version then fail("inventory version mismatch") end
  if not integer(inv.capacity,1,256) then fail("inventory capacity") end
  require_type(inv.slots,"slots","table")
  local mt=getmetatable(inv.slots)
  if not mt or not mt.__json_array then fail("inventory slots not JSON array") end
  if #inv.slots>inv.capacity then fail("too many inventory slots") end
  local used={}
  for _,slot in ipairs(inv.slots) do
    exact(slot,"inventory slot",slot_fields)
    if not integer(slot.slot,1,inv.capacity) or used[slot.slot] then fail("duplicate/out-of-range slot") end
    used[slot.slot]=true
    local def=catalog_entry(catalog,slot.def_id)
    if not integer(slot.count,1,def.max_stack) then fail("invalid stack count") end
  end
  for k in pairs(inv.slots) do
    if type(k)~="number" or not integer(k,1,#inv.slots) then fail("sparse/bad slot array") end
  end
  local delta=s.generated_object_delta
  exact(delta,"delta",delta_fields)
  if delta.version~=1 or delta.seed~=s.seed or delta.generator_version~=s.generator_version then
    fail("world generation delta mismatch")
  end
  require_type(delta.objects,"delta objects","table")
  for id,state in pairs(delta.objects) do
    local seed,x,y
    if type(id)=="string" then seed,x,y=id:match("^worldobj:v1:(%d+):(-?%d+):(-?%d+)$") end
    if seed==nil or tostring(tonumber(seed))~=tostring(s.seed)
      or tonumber(x)==nil or tonumber(y)==nil then fail("invalid procedural object id") end
    exact(state,"delta object",fields({"depleted"}))
    if state.depleted~=true then fail("invalid depleted state") end
  end
  require_type(s.placed_instances,"placed instances","table")
  for id,placed in pairs(s.placed_instances) do
    if not uuid(id) then fail("invalid placed key UUIDv4") end
    exact(placed,"placed",place_fields)
    if placed.id~=id or not uuid(placed.id) then fail("placed identity conflict") end
    catalog_entry(catalog,placed.def_id,true)
    if not finite(placed.x) or not finite(placed.y)
      or not integer(placed.rotation,0,7) then fail("invalid placement transform") end
    nonempty(placed.owner_id,"placement owner")
    nonempty(placed.command_id,"placement command")
    if not integer(placed.revision,1,s.world_revision) then fail("invalid placed revision") end
  end
  require_type(s.applied_commands,"commands","table")
  for id,entry in pairs(s.applied_commands) do
    nonempty(id,"command ledger ID")
    optional(entry,"command",cmd_fields,{"revision","status"})
    if not integer(entry.revision,0,s.world_revision) or not statuses[entry.status] then
      fail("invalid command ledger")
    end
    if entry.reason~=nil and type(entry.reason)~="string" then fail("invalid command reason") end
  end
  require_type(s.applied_transactions,"transactions","table")
  for id,entry in pairs(s.applied_transactions) do
    nonempty(id,"transaction ledger ID")
    exact(entry,"transaction",tx_fields)
    catalog_entry(catalog,entry.item_id)
    if not integer(entry.revision,0,s.world_revision) or
      not integer(entry.amount,1,2147483647) then fail("invalid transaction") end
  end
  return true
end
V.uuid=uuid
return V
