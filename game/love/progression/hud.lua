-- Session prototype of touch-safe character stat allocation HUD.
-- Uses ASCII labels because the current LÖVE default font is not localized.
local Rules=require("progression.rules")
local H={}
H.__index=H
function H.new() return setmetatable({open=false},H) end
function H:layout(s)
  assert(type(s)=="table" and s.w>=280 and s.h>=500,
    "invalid stat HUD safe area")
  local t={toggle={x=s.x+12,y=s.y+139,w=92,h=35}}
  local y=s.y+179
  local bottom=s.y+s.h-275-8
  local height=math.max(196,math.min(239,bottom-y))
  local panel={x=s.x+12,y=y,w=math.min(s.w-24,420),h=height}
  t.panel=panel;t.rows={}
  local step=math.min(30,(height-48)/6)
  for i,id in ipairs(Rules.stats) do
    local ry=y+32+(i-1)*step
    t.rows[i]={id=id,x=panel.x+7,y=ry,w=panel.w-14,h=step}
    t.rows[i].add={x=panel.x+panel.w-53,y=ry+1,w=43,h=step-2}
  end
  return t
end
local function inside(b,x,y)
  return x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h
end
function H:hit(x,y,s)
  local a=self:layout(s)
  if inside(a.toggle,x,y) then return "stats_toggle" end
  if self.open then
    for _,row in ipairs(a.rows) do
      if inside(row.add,x,y) then return "stats_add:"..row.id end
    end
    return "stats_panel" -- Modal; do not tunnel a press into world/hotbar.
  end
  return nil
end
function H:draw(g,s,progression)
  local a=self:layout(s)
  g.push("all")
  g.setColor(.13,.26,.29,.96)
  g.rectangle("fill",a.toggle.x,a.toggle.y,a.toggle.w,a.toggle.h,7,7)
  g.setColor(.96,.95,.83)
  g.printf(self.open and "CLOSE STAT" or "STATS",a.toggle.x+2,a.toggle.y+10,
    a.toggle.w-4,"center")
  if self.open then
    local panel=a.panel
    local state=progression.state
    g.setColor(.04,.11,.14,.97)
    g.rectangle("fill",panel.x,panel.y,panel.w,panel.h,9,9)
    g.setColor(1,.94,.82)
    local xp_next=Rules.xp_to_next(state.character_level)
    local status=string.format("LV %d  XP %d/%s   PTS %d   CORE %d",
      state.character_level,state.character_xp,tostring(xp_next or "MAX"),
      state.unspent_points,state.core.level)
    g.print(status,panel.x+8,panel.y+8)
    for _,row in ipairs(a.rows) do
      local value=progression:stat(row.id)
      g.setColor(.85,.9,.86)
      g.print(Rules.labels[row.id],row.x,row.y+6)
      g.print(value.."/"..progression:stat_cap(),row.x+panel.w*.54,row.y+6)
      local add=row.add
      local enabled=progression:can_spend(row.id)
      g.setColor(enabled and .13 or .16,enabled and .45 or .22,
        enabled and .34 or .22,.98)
      g.rectangle("fill",add.x,add.y,add.w,add.h,4,4)
      g.setColor(enabled and 1 or .55,enabled and 1 or .65,.9)
      g.printf("+",add.x,add.y+4,add.w,"center")
    end
    g.setColor(.72,.82,.81)
    g.print("SLOTS "..progression:skill_slots().."  SESSION ONLY / NOT SAVED",
      panel.x+8,panel.y+panel.h-17)
  end
  g.pop()
end
return H
