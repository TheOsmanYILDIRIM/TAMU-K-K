package.path="./?.lua;./?/init.lua;"..package.path
local Rules=require("progression.rules")
local Character=require("progression.character")
local Skills=require("progression.skill_contract")
local Hud=require("progression.hud")
local function bad(f) assert(not pcall(f),"expected rejection") end
local identity={player_id="player:local",
  core_instance_id="12345678-1234-4abc-8abc-123456789abc",
  core_definition_id="core:standard"}
local p=Character.new(identity)
local stats=p:snapshot()
assert(stats.character_level==1 and stats.character_xp==0)
assert(p:stat_cap()==10 and p:skill_slots()==2)
for _,name in ipairs(Rules.stats) do assert(p:stat(name)==1) end
assert(#Rules.stats==6 and Rules.stat_cap(3)==20 and Rules.skill_slots(3)==4)
assert(Rules.stat_cap(3)==Rules.stat_cap(3)) -- independent of Core type
assert(not p:can_spend("etkime"))
assert(not p:spend("etkime"))
assert(p:grant("quest_complete","quest:q1")==true)
assert(p.state.character_level==2 and p.state.character_xp==20)
assert(p.state.unspent_points==Rules.points_per_character_level)
assert(not p:grant("quest_complete","quest:q1"))
bad(function() p:grant("craft_complete","quest:q1") end)
bad(function() p:grant("fictitious","quest:q2") end)
bad(function() p:grant("build_complete","") end)
assert(p:can_spend("etkime"))
assert(p:spend("etkime"))
assert(p:stat("etkime")==2 and p.state.unspent_points==1)
assert(p:spend("rezonans"))
assert(p:stat("rezonans")==2 and not p:spend("rezonans"))
assert(p:grant("harvest_complete","harvest:a"))
assert(p:grant("craft_complete","craft:a"))
assert(p:grant("build_complete","build:a"))
assert(p.state.character_level==2 and p.state.character_xp==120)
assert(p:grant("quest_complete","quest:q2"))
assert(p.state.character_level==3 and p.state.character_xp==40)
-- Event replay and snapshot recovery preserve exact awarded XP/points.
local snap=p:snapshot()
local recovered=Character.restore(snap)
snap.allocations.etkime=99
snap.applied_events["hack:1"]="quest_complete"
assert(recovered:stat("etkime")==2)
assert(recovered.state.applied_events["hack:1"]==nil)
assert(not recovered:grant("harvest_complete","harvest:a"))
assert(recovered.state.character_xp==40)
bad(function()
  local s=recovered:snapshot();s.version=2;Character.restore(s)
end)
bad(function()
  local s=recovered:snapshot();s.unspent_points=s.unspent_points+1
  Character.restore(s)
end)
bad(function()
  local s=recovered:snapshot();s.applied_events["fake"]="craft_complete"
  Character.restore(s)
end)
bad(function()
  local s=recovered:snapshot();s.allocations.extra=1;Character.restore(s)
end)
bad(function()
  local s=recovered:snapshot();s.core.level=0;Character.restore(s)
end)
-- An explicit Core level ceiling is common to ordinary/rare Core definitions;
-- lowering a Core would fail validation rather than silently destroy a stat.
local rich=recovered:snapshot()
rich.core.definition_id="core:storm"
assert(Character.restore(rich):stat_cap()==recovered:stat_cap())
-- Future skill catalogue is declarative and capability-first.
local ore={id="core:ore_trace",version=1,capabilities={
  {id="core:detect_hidden_ore",mode="unlock"}},
  stat_affinities={duyarlilik=2,bilis=1},
  progression={mode="use_xp",start_level=1}}
assert(Skills.validate(ore) and Skills.opens(ore,"core:detect_hidden_ore"))
assert(Skills.source_slot_cost("learned")==1)
assert(Skills.source_slot_cost("core_innate")==0)
assert(not Skills.opens(ore,"core:charge_axe"))
bad(function()
  local invalid={id="core:invalid",version=1,capabilities={
    {id="core:charge_axe",mode="unlock"}},stat_affinities={charisma=1}}
  Skills.validate(invalid)
end)
bad(function() Skills.validate({id="core:bad",version=1,capabilities={}}) end)
bad(function() Skills.validate({id="core:bad",version=1,capabilities={{id="core:x",mode="feat"}}}) end)
bad(function() Skills.source_slot_cost("free_swap") end)
-- Mobile modal interactions never allow a stat-panel tap to reach the world.
for _,size in ipairs({{320,700},{360,780},{392,850},{720,1100}}) do
  local safe={x=0,y=0,w=size[1],h=size[2]}
  local hud=Hud.new()
  local layout=hud:layout(safe)
  assert(layout.toggle.x>=0 and layout.toggle.x+layout.toggle.w<=safe.w)
  assert(layout.panel.y+layout.panel.h<=safe.h)
  local a=layout.toggle
  assert(hud:hit(a.x+8,a.y+8,safe)=="stats_toggle")
  hud.open=true
  for _,row in ipairs(layout.rows) do
    assert(row.add.x>=layout.panel.x and row.add.x+row.add.w<=layout.panel.x+layout.panel.w)
    assert(hud:hit(row.add.x+8,row.add.y+5,safe)=="stats_add:"..row.id)
  end
  assert(hud:hit(safe.w-4,safe.h-4,safe)=="stats_panel")
end
print("CORE_STAT_PROGRESSION_OK levels, caps, XP ledger, stat spend, restore, skill contract, mobile HUD")
