-- Pure-Lua regression: opt-in must preserve every screen-overlapping chunk
-- at the tall mobile viewport where 48 centre-distance slots miss corners.
package.path="./?.lua;./?/init.lua;"..package.path
local Camera=require("core.camera")
local Stream=require("world.stream")
local Iso=require("world.iso")
local query={field={},sample=function() return {biome="meadow"} end}
local cam=Camera.new()
cam.x,cam.y,cam.zoom=64,128,1.7
local world=Stream.new(query,{size=256,step=8,max_loaded=48})
local function overlaps(c,w,h,pad)
  local x,y=Iso.project(c.cx*256-cam.x,c.cy*256-cam.y)
  local edge=256*math.sqrt(.5)*cam.zoom
  local sx,sy=w*.5+x*cam.zoom,h*.5+y*cam.zoom
  return sx+edge>=-pad and sx-edge<=w+pad
    and sy+edge>=-pad and sy<=h+pad
end
for _,dims in ipairs({{720,1600},{691,1536},{360,780}}) do
  local w,h=dims[1],dims[2]
  local old=world:needed(cam,w,h)
  assert(#old<=48)
  local old_keys={}
  for _,v in ipairs(old) do old_keys[v.key]=true end
  world.viewport_cover=true
  local covered=world:needed(cam,w,h)
  local present={}
  for _,v in ipairs(covered) do present[v.key]=true end
  local needed=0
  local lost_old=0
  -- Cover the entire AABB candidate range, not just the returned list.
  for cy=-7,7 do for cx=-7,7 do
    local c={cx=cx,cy=cy,key=cx..":"..cy}
    if overlaps(c,w,h,0) then
      needed=needed+1
      if not old_keys[c.key] then lost_old=lost_old+1 end
      assert(present[c.key],"screen-visible chunk missing: "..c.key)
    end
  end end
  for _,c in ipairs(covered) do
    assert(c.key and c.distance)
  end
  if h>=1536 then
    assert(lost_old>=1,"regression fixture no longer exercises 48 cutoff")
  end
  print(string.format("R2_VIEWPORT_COVER_OK size=%dx%d visible=%d old_lost=%d covered=%d",
    w,h,needed,lost_old,#covered))
  world.viewport_cover=nil
end
-- Default Stream:needed ordering and cap remain unchanged when opt-in is off.
assert(#world:needed(cam,720,1600)==48)
print("R2_VIEWPORT_RENDER_ONLY_TEST_OK")
