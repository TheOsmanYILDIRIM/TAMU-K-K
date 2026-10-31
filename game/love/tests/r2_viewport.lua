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

-- Real Terrain.draw contract under a deterministic graphics mock. The Canvas
-- caches only complete static materials and invalidates on mesh/camera/size/DPI.
local Terrain=require("world.terrain_renderer")
local target=nil
local draws={terrain=0,canvas=0,builds=0,releases=0}
local pw,ph,dpi=720,1600,1
local function new_canvas()
 draws.builds=draws.builds+1
 return {is_canvas=true,release=function() draws.releases=draws.releases+1 end}
end
love={graphics={
 newCanvas=function(w,h,settings)
  assert(w==pw and h==ph and settings.dpiscale==dpi)
  return new_canvas()
 end,
 getPixelDimensions=function() return pw,ph end,
 getDPIScale=function() return dpi end,
 setCanvas=function(c) target=c end,
 clear=function() end,push=function() end,pop=function() end,
 translate=function() end,scale=function() end,setColor=function() end,
 draw=function(item)
  if item.is_canvas then
   assert(target==nil,"drawing Canvas into itself")
   draws.canvas=draws.canvas+1
  else
   draws.terrain=draws.terrain+1
  end
 end,
}}
local q={field={},sample=function() return {biome="meadow"} end}
local meshA={is_canvas=false}
local chunk={x=0,y=0,cx=0,cy=0,size=256,
 _terrain_meshes={meadow=meshA}}
local scene={query=q,wanted_count=1,visible=function() return {chunk} end}
local cam2=Camera.new()
cam2.x,cam2.y,cam2.zoom=0,0,1.7
local opts={canvas_cache=true,viewport_cull=true,atmosphere=false}
local key="standard:0.35:nil:nil:"..tostring(q)
chunk._terrain_key=key
Terrain.draw(scene,cam2,720,1600,opts)
assert(draws.terrain==1 and draws.canvas==1 and draws.builds==1)
Terrain.draw(scene,cam2,720,1600,opts)
assert(draws.terrain==1 and draws.canvas==2 and
 Terrain._canvas_hits==1,"stationary Canvas should bypass all material meshes")
cam2.x=16
Terrain.draw(scene,cam2,720,1600,opts)
assert(draws.terrain==2 and draws.builds==1,
 "camera movement must repaint existing Canvas")
chunk._terrain_meshes={meadow={is_canvas=false}}
Terrain.draw(scene,cam2,720,1600,opts)
assert(draws.terrain==3,"mesh identity change must invalidate")
scene.wanted_count=2
Terrain.draw(scene,cam2,720,1600,opts)
assert(draws.terrain==4,"incomplete streamed scene must bypass old Canvas")
scene.wanted_count=1
pw,ph,dpi=691,1536,1
Terrain.draw(scene,cam2,691,1536,opts)
assert(draws.builds==2 and draws.releases==1,
 "resizing must release and recreate high-DPI compatible Canvas")
pw,ph,dpi=1382,3072,2
Terrain.draw(scene,cam2,691,1536,opts)
assert(draws.builds==3 and draws.releases==2,
 "pixel-density change must recreate Canvas at physical size")
opts.canvas_cache=false
Terrain.draw(scene,cam2,691,1536,opts)
assert(draws.releases==3,"disabling cached terrain must release framebuffer")
print("R2_CANVAS_INVALIDATION_OK still/move/mesh/pending/resize/dpi/disable")
-- Opt-in terrain residency must put future camera halo ahead of the
-- behind-camera halo, without altering legacy cap or visible coverage.
do
 local s=Stream.new(query,{size=256,step=8,max_loaded=80,
   render_only_25d=true})
 local moving=Camera.new()
 moving.x,moving.y,moving.zoom=64,128,1.7
 s:needed(moving,720,1100)
 moving.x=moving.x+2
 local items=s:needed(moving,720,1100)
 assert(s._25d_prefetch_dir and s._25d_prefetch_dir.x>.9)
 local last=nil
 for i,c in ipairs(items) do
   if not s.visible_required_keys[c.key] then
     local x=(c.cx+.5)*256-(moving.x+512)
     local y=(c.cy+.5)*256-moving.y
     local score=x*x+y*y
     if last then assert(score>=last,'forward halo lost priority') end
     last=score
   end
 end
 assert(last and #items<=math.max(80,s.visible_required_count+24),
   'opt-in forward halo missing or bounded staging cap exceeded')
end
print('TAMU_25D_FORWARD_HALO_PRIORITY_OK')

