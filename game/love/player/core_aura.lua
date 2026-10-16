-- Core plasma aura model. Not a stat-system implementation.
-- Gameplay stats/palette are supplied by a future canonical registry.
-- With no configured stats, a neutral placeholder visual is returned.
local A={}
local DEFAULT={.27,.79,.91}
local SECONDARY={.69,.64,.93}
local function finite(n)
  return type(n)=="number" and n==n and math.abs(n)<math.huge
end
local function valid_color(color)
  assert(type(color)=="table" and #color==3,"three-channel aura color required")
  for i=1,3 do
    assert(finite(color[i]) and color[i]>=0 and color[i]<=1,"invalid aura color channel")
  end
  return {color[1],color[2],color[3]}
end
local function percent_bucket(percent,step)
  return math.floor((percent+1e-9)/step)*step
end
function A.resolve(stats,palette,previous,opts)
  opts=opts or {}
  local step=opts.step or 10
  local hysteresis=opts.hysteresis or 5
  assert(finite(step) and step>0 and step<=100
      and finite(hysteresis) and hysteresis>=0 and hysteresis<=100,
      "invalid aura bucket/hysteresis")
  if stats==nil then
    return {primary=nil,secondary=nil,
      primary_color={DEFAULT[1],DEFAULT[2],DEFAULT[3]},
      secondary_color={SECONDARY[1],SECONDARY[2],SECONDARY[3]},
      buckets={},neutral=true}
  end
  assert(type(stats)=="table" and type(palette)=="table",
    "stats and palette must be supplied together")
  local ranks,total={},0
  for id,value in pairs(stats) do
    assert(type(id)=="string" and id:match("^[%w_:%-]+$") and #id<=64
      and finite(value) and value>=0,"invalid stat value/ID")
    if value>0 then
      local color=valid_color(palette[id])
      ranks[#ranks+1]={id=id,value=value,color=color}
      total=total+value
    end
  end
  assert(finite(total),"stat sum overflow")
  if total==0 then return A.resolve(nil,nil,nil,opts) end
  for _,entry in ipairs(ranks) do entry.percent=100*entry.value/total end
  table.sort(ranks,function(a,b)
    if a.percent==b.percent then return a.id<b.id end
    return a.percent>b.percent
  end)
  local primary=ranks[1]
  if previous and previous.primary and previous.primary~=primary.id then
    for _,entry in ipairs(ranks) do
      if entry.id==previous.primary and primary.percent-entry.percent<hysteresis then
        primary=entry
        break
      end
    end
  end
  local secondary
  for _,entry in ipairs(ranks) do
    if entry.id~=primary.id then secondary=entry;break end
  end
  local buckets={}
  for _,entry in ipairs(ranks) do
    buckets[entry.id]=percent_bucket(entry.percent,step)
  end
  return {primary=primary.id,secondary=secondary and secondary.id or nil,
    primary_color=primary.color,
    secondary_color=secondary and secondary.color or primary.color,
    buckets=buckets,neutral=false}
end
return A
