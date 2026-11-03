-- Session prototype of touch-safe character stat allocation HUD.
-- Uses ASCII labels because the current LÖVE default font is not localized.
local Rules=require("progression.rules")
local H={}
H.__index=H
function H.new() return setmetatable({open=false},H) end
local function finite(v)
  return type(v)=="number" and v==v and v>-math.huge and v<math.huge
end
function H:layout(s)
  -- getSafeArea can be smaller than the LÖVE window (insets, split-screen,
  -- landscape, desktop resize). Those are valid viewports, not corrupt data.
  assert(type(s)=="table" and finite(s.x) and finite(s.y)
    and finite(s.w) and finite(s.h) and s.w>0 and s.h>0,
    "invalid stat HUD safe area")
  local cached=self._layout_cache
  if cached and cached.x==s.x and cached.y==s.y
     and cached.w==s.w and cached.h==s.h then
    return cached.layout
  end
  local compact=s.w<280 or s.h<500
  local pad=compact and math.max(2,math.min(12,s.w*.03,s.h*.03)) or 12
  local toggle_h=compact and math.max(1,math.min(35,s.h-2*pad)) or 35
  local toggle={x=s.x+pad,y=s.y+(compact and pad or 139),
    w=math.max(1,math.min(92,s.w-2*pad)),h=toggle_h}
  local y=compact and math.min(s.y+s.h-pad,toggle.y+toggle.h+pad) or s.y+179
  local bottom=compact and s.y+s.h-pad or s.y+s.h-275-8
  local height=compact and math.max(0,math.min(239,bottom-y))
    or math.max(196,math.min(239,bottom-y))
  local panel={x=s.x+pad,y=y,w=math.max(1,math.min(s.w-2*pad,420)),h=height}
  local t={toggle=toggle,panel=panel,rows={},
    -- On exceptionally short/narrow surfaces keep the toggle and an
    -- explicit notice; never create overlapping invisible +/- hitboxes.
    compact_unavailable=height<196 or panel.w<170}
  if not t.compact_unavailable then
    local step=math.min(30,(height-48)/6)
    for i,id in ipairs(Rules.stats) do
      local ry=y+32+(i-1)*step
      local add_w=math.min(43,math.max(1,panel.w*.24))
      t.rows[i]={id=id,x=panel.x+7,y=ry,w=panel.w-14,h=step}
      t.rows[i].add={x=panel.x+panel.w-add_w-10,y=ry+1,
        w=add_w,h=step-2}
    end
  end
  self._layout_cache={x=s.x,y=s.y,w=s.w,h=s.h,layout=t}
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
    if a.compact_unavailable then
      g.setColor(.04,.11,.14,.97)
      g.rectangle("fill",panel.x,panel.y,panel.w,panel.h,7,7)
      g.setColor(1,.94,.82)
      g.printf("Rotate to portrait or enlarge window",panel.x+4,panel.y+4,
        math.max(1,panel.w-8),"left")
      g.pop()
      return
    end
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
