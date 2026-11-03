-- Pure authoritative-candidate character progression; no save_v2 mutation.
-- Character XP yields freely allocated stat points; stat actions never earn stat XP.
-- Actual durable ownership, Core transfer and Core upgrade await a versioned transaction.
local Rules=require("progression.rules")
local P={}
P.__index=P
local function integer(v,lo,hi)
  return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
    and v==math.floor(v) and v>=lo and v<=hi
end
local function id(v)
  return type(v)=="string" and #v>=1 and #v<=128
    and v:match("^[%w:_%-]+$")~=nil
end
local function exact(t,fields)
  assert(type(t)=="table","progression table required")
  for k in pairs(t) do assert(fields[k],"unknown progression field "..tostring(k)) end
  for k in pairs(fields) do assert(t[k]~=nil,"missing progression field "..k) end
end
local function copy(t)
  local out={}
  for k,v in pairs(t) do
    if type(v)=="table" then out[k]=copy(v) else out[k]=v end
  end
  return out
end
local top_fields={format=true,version=true,player_id=true,character_level=true,
  character_xp=true,unspent_points=true,allocations=true,core=true,applied_events=true}
local core_fields={instance_id=true,definition_id=true,level=true}
local function check(s)
  exact(s,top_fields)
  assert(s.format=="core-progression" and s.version==Rules.version,
    "invalid progression format/version")
  assert(id(s.player_id),"invalid player id")
  Rules.check_level(s.character_level)
  exact(s.core,core_fields)
  assert(id(s.core.instance_id) and id(s.core.definition_id),"invalid Core identity")
  Rules.check_level(s.core.level)
  local threshold=Rules.xp_to_next(s.character_level)
  assert(integer(s.character_xp,0,threshold and threshold-1 or 0),
    "invalid character XP remainder")
  local points=0
  assert(type(s.allocations)=="table","missing allocations")
  local count=0
  for name,v in pairs(s.allocations) do
    assert(Rules.stat_known(name),"unknown stat allocation")
    assert(integer(v,0,100000) and v+Rules.base_stat<=Rules.stat_cap(s.core.level),
      "invalid stat allocation/ceiling")
    points=points+v
    count=count+1
  end
  assert(count==#Rules.stats,"six stat allocations required")
  assert(integer(s.unspent_points,0,1000000),"invalid unspent points")
  assert(points+s.unspent_points==
    (s.character_level-1)*Rules.points_per_character_level,"point budget mismatch")
  assert(type(s.applied_events)=="table","event ledger required")
  local accumulated=0
  for event_id,kind in pairs(s.applied_events) do
    assert(id(event_id) and Rules.event_xp[kind],"invalid XP event ledger")
    accumulated=accumulated+Rules.event_xp[kind]
    assert(accumulated<=9007199254740991,"XP event overflow")
  end
  local earned=0
  for lvl=1,s.character_level-1 do earned=earned+Rules.xp_to_next(lvl) end
  assert(accumulated==earned+s.character_xp,"XP ledger mismatch")
  return true
end
function P.new(opts)
  assert(type(opts)=="table" and id(opts.player_id)
    and id(opts.core_instance_id) and id(opts.core_definition_id),
    "explicit player and Core identity required")
  local allocations={}
  for _,stat in ipairs(Rules.stats) do allocations[stat]=0 end
  local self=setmetatable({state={
    format="core-progression",version=Rules.version,player_id=opts.player_id,
    character_level=1,character_xp=0,unspent_points=0,
    allocations=allocations,core={instance_id=opts.core_instance_id,
      definition_id=opts.core_definition_id,level=1},
    applied_events={}
  }},P)
  check(self.state)
  return self
end
function P.restore(snapshot)
  check(snapshot)
  local self=setmetatable({state=copy(snapshot)},P)
  return self
end
function P:snapshot()
  check(self.state)
  return copy(self.state)
end
function P:stat_cap()
  return Rules.stat_cap(self.state.core.level)
end
function P:skill_slots()
  return Rules.skill_slots(self.state.core.level)
end
function P:stat(id_name)
  assert(Rules.stat_known(id_name),"unknown stat")
  return Rules.base_stat+self.state.allocations[id_name]
end
function P:can_spend(name)
  return Rules.stat_known(name) and self.state.unspent_points>0
    and self:stat(name)<self:stat_cap()
end
function P:spend(name)
  if not Rules.stat_known(name) then return false,"unknown_stat" end
  if self.state.unspent_points==0 then return false,"no_points" end
  if self:stat(name)>=self:stat_cap() then return false,"core_cap" end
  self.state.allocations[name]=self.state.allocations[name]+1
  self.state.unspent_points=self.state.unspent_points-1
  check(self.state)
  return true,"allocated"
end
function P:grant(kind,event_id)
  assert(type(kind)=="string" and Rules.event_xp[kind],
    "unrecognized character XP event")
  assert(id(event_id),"stable event id required")
  local previous=self.state.applied_events[event_id]
  if previous then
    assert(previous==kind,"same event ID reused for a different kind")
    return false,"duplicate"
  end
  local level=self.state.character_level
  local xp=self.state.character_xp+Rules.event_xp[kind]
  local levels=0
  local threshold=Rules.xp_to_next(level)
  while threshold and xp>=threshold do
    xp=xp-threshold
    level=level+1
    levels=levels+1
    threshold=Rules.xp_to_next(level)
  end
  -- At the representation maximum extra XP is intentionally not accepted.
  assert(threshold or xp==0,"character progression maximum reached")
  self.state.applied_events[event_id]=kind
  self.state.character_level=level
  self.state.character_xp=xp
  self.state.unspent_points=self.state.unspent_points+
    levels*Rules.points_per_character_level
  check(self.state)
  return true,levels
end
return P
