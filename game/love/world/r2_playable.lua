-- R2 G: opted-in, session-only playable pilot. Not a save migration.
-- Pinned content is the reviewed 2026-10-19 R2 manifest/map, not a fallback.
local Json=require("save.json")
local Hash=require("save.hash")
local H=require("world.r2_compat_bridge")
local ObjectQuery=require("objects.query")
local Collision=require("physics.collision")
local Controller=require("player.controller")
local M={};M.__index=M
local files={
 ["fisilti_ormani.r2.v1.json"]="df5d0eeca59030e6585558c15d8f1e7bf049638ea8032dc17c1b80c74106f598",
 ["osman_overworld.v2.json"]="ac5903fd22cd466cfc1786cbeef44f2679be87317c6bfd757a05a282172f78dc"
}
local function source_read(name)
  assert(love and love.filesystem and type(love.filesystem.getSource)=="function",
    "R2 pilot needs the real LÖVE source")
  local source=love.filesystem.getSource():gsub("[/\\]+$","")
  assert(source:match("[/\\]game[/\\]love$"),
    "R2 pilot requires an unpacked repository source; no bundled map or silent fallback")
  local path=source.."/../../data/worldbuild/"..name
  local f,err=io.open(path,"rb")
  assert(f,"R2 pilot source unavailable ("..name.."): "..tostring(err))
  local bytes=f:read("*a");f:close()
  return bytes
end
local function read_doc(name,reader)
  local bytes=reader(name)
  assert(type(bytes)=="string" and #bytes>100 and #bytes<1000000,
    "R2 source absent or unexpectedly sized: "..name)
  assert(Hash.sha256(bytes)==files[name],
    "R2 content mismatch; pilot blocked until source/manifest explicitly reviewed: "..name)
  return Json.decode(bytes)
end
function M.new(options)
  options=options or {}
  assert(type(options)=="table","pilot options must be a table")
  local reader=options.read or source_read
  assert(type(reader)=="function","R2 source reader required")
  local authored=read_doc("fisilti_ormani.r2.v1.json",reader)
  local manifest=read_doc("osman_overworld.v2.json",reader)
  local scene=H.new(authored,manifest) -- H validates matching schema/version/geography.
  assert(scene.production_enabled==false and scene.persistence_supported==false
    and scene.query.seed==20261018 and scene.query.generator_version==1,
    "unsafe R2 lifecycle or generator")
  assert(#scene.routes.crossings==0,"R2 pilot must never invent a bridge or ford")
  local spawn
  for _,site in ipairs(manifest.sites) do
    if site.id=="site:fisilti-uyanis" then
      assert(not spawn and site.role=="spawn","duplicate or invalid pilot spawn")
      spawn=site
    end
  end
  assert(spawn and spawn.anchor[1]==64 and spawn.anchor[2]==128,
    "unapproved Fısıltı Ormanı spawn")
  local solid={objects=scene.population,topography=scene.topography,query=scene.query}
  function solid:obstacles(x1,y1,x2,y2)
    local hits=self.objects:obstacles(x1,y1,x2,y2)
    local cliffs=self.topography:colliders(x1,y1,x2,y2,8)
    for _,rect in ipairs(cliffs) do hits[#hits+1]=rect end
    return hits
  end
  function solid:surface_at(x,y)
    local surface=self.query:surface_at(x,y)
    local topo=self.topography:sample(x,y)
    -- Wet movement and immersion are retained; moderate terrain slows walking.
    local slope=(topo.class=="moderate") and .80 or 1
    return {speed_multiplier=surface.speed_multiplier*slope,
      immersion=surface.immersion,wet=surface.wet,water_body=surface.water_body,
      topography_class=topo.class}
  end
  return setmetatable({query=scene.query,objects=scene.population,
    water=scene.water,solid=solid,topography=scene.topography,
    routes=scene.routes,manifest=manifest,authored_map=authored,spawn_site=spawn,
    scene=scene,persistence_supported=false,render_options={
      topography=scene.topography,routes=scene.routes,quality="standard",
      height_scale=.35,atmosphere=true}},M)
end
function M:spawn_player(building)
  assert(building and building.obstacles and building.surface_at)
  local ax,ay=self.spawn_site.anchor[1],self.spawn_site.anchor[2]
  -- The authored anchor is authoritative; nearby search is ONLY for a solid-free
  -- point in the same protected clearing, never a procedural replacement map.
  for radius=0,32,8 do
    for dy=-radius,radius,8 do for dx=-radius,radius,8 do
      if radius==0 or math.max(math.abs(dx),math.abs(dy))==radius then
        local x,y=ax+dx,ay+dy
        if self.query:is_walkable(x,y) and
           Collision.can_stand(building,x,y,5) then
          return Controller.new(building,{x=x,y=y,radius=5,speed=96})
        end
      end
    end end
  end
  error("R2 authored spawn is blocked; no fabricated fallback",2)
end
function M:mount_camera(camera)
  assert(camera and type(camera.project)=="function"
    and type(camera.unproject)=="function","camera required")
  assert(not camera._r2_mounted,"R2 camera may only be mounted once")
  local project,unproject=camera.project,camera.unproject
  local topo,scale=self.topography,self.render_options.height_scale
  camera.project=function(self,x,y,w,h)
    local sx,sy=project(self,x,y,w,h)
    return sx,sy-topo:height(x,y)*scale*self.zoom
  end
  camera.unproject=function(self,sx,sy,w,h)
    local x,y=unproject(self,sx,sy,w,h)
    for _=1,5 do
      x,y=unproject(self,sx,sy+topo:height(x,y)*scale*self.zoom,w,h)
    end
    return x,y
  end
  camera._r2_mounted=true
  return camera
end
function M:can_build(x,y,r)
  -- H's manifest contains no approved build zones. No speculative placement.
  return self.objects:can_build(x,y,r)
end
return M
