-- SkillDefinition v1 authoring gate, NOT a runtime spell/skill catalogue.
-- Skill functionality is capabilities; no Pathfinder feats or universal jobs.
-- Definitions are declarative; no executable code is stored in JSON/Lua data.
local Rules=require("progression.rules")
local S={}
local function id(v)
  return type(v)=="string" and #v>0 and #v<=128 and
    v:match("^[a-z][a-z0-9_-]*:[a-z][a-z0-9_-]*$")~=nil
end
local function integer(v,lo,hi)
  return type(v)=="number" and v==math.floor(v) and v>=lo and v<=hi
end
local allowed={id=true,version=true,capabilities=true,stat_affinities=true,
  progression=true}
local modes={unlock=true,enhance=true}
function S.validate(def)
  assert(type(def)=="table","SkillDefinition must be a table")
  for k in pairs(def) do assert(allowed[k],"unknown SkillDefinition field") end
  assert(id(def.id) and def.version==1,"invalid SkillDefinition ID/version")
  assert(type(def.capabilities)=="table" and #def.capabilities>0,
    "skill must grant at least one capability")
  local seen={}
  for i,cap in ipairs(def.capabilities) do
    assert(type(cap)=="table" and id(cap.id) and modes[cap.mode],
      "invalid skill capability")
    for k in pairs(cap) do
      assert(k=="id" or k=="mode","unknown capability field")
    end
    assert(not seen[cap.id],"duplicate capability")
    seen[cap.id]=true
  end
  for k in pairs(def.capabilities) do
    assert(type(k)=="number" and integer(k,1,#def.capabilities),
      "capabilities must be an array")
  end
  if def.stat_affinities~=nil then
    assert(type(def.stat_affinities)=="table","invalid stat affinities")
    for k,weight in pairs(def.stat_affinities) do
      assert(Rules.stat_known(k) and integer(weight,1,100),
        "invalid stat affinity")
    end
  end
  if def.progression~=nil then
    assert(type(def.progression)=="table" and
      def.progression.mode=="use_xp" and
      integer(def.progression.start_level,1,1),
      "skill progression must use XP with level 1 start")
    for k in pairs(def.progression) do
      assert(k=="mode" or k=="start_level","unknown skill progression field")
    end
  end
  return true
end
function S.source_slot_cost(source)
  if source=="learned" then return 1 end
  if source=="core_innate" then return 0 end
  error("unknown skill source",2)
end
function S.opens(def,capability_id)
  S.validate(def)
  for _,cap in ipairs(def.capabilities) do
    if cap.id==capability_id and cap.mode=="unlock" then return true end
  end
  return false
end
return S
