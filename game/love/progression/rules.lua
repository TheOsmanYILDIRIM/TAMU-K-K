-- Core/stat progression V1 prototype tuning. No RPG feat/proficiency/stat-use XP.
-- The numerical curve is PROVISIONAL; only the shared ceiling mechanics are agreed.
local R={}
R.version=1
R.stats={"etkime","hakimiyet","kararlilik","duyarlilik","bilis","rezonans"}
R.labels={etkime="ETKIME",hakimiyet="HAKIMIYET",kararlilik="KARARLILIK",
  duyarlilik="DUYARLILIK",bilis="BILIS",rezonans="REZONANS"}
R.base_stat=1
R.points_per_character_level=2
R.maximum_level=1000 -- representation safety bound; not approved gameplay max.
R.event_xp={harvest_complete=20,craft_complete=30,build_complete=50,
  exploration_discovery=80,combat_victory=60,quest_complete=120}
local function positive_integer(n)
  return type(n)=="number" and n==n and n~=math.huge
    and n~=-math.huge and n==math.floor(n) and n>=1 and n<=R.maximum_level
end
function R.check_level(n)
  assert(positive_integer(n),"invalid progression level")
  return n
end
function R.stat_cap(core_level)
  R.check_level(core_level)
  return 10+5*(core_level-1) -- same cap for all six stats and Core types
end
function R.skill_slots(core_level)
  R.check_level(core_level)
  return 2+(core_level-1) -- same normal slot count for all Core types
end
function R.xp_to_next(character_level)
  R.check_level(character_level)
  if character_level==R.maximum_level then return nil end
  return 100*character_level
end
function R.stat_known(id)
  for _,name in ipairs(R.stats) do if id==name then return true end end
  return false
end
return R
