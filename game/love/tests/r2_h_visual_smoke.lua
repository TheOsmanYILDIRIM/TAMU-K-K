-- H opt-in A-F diagnostic renderer, not the production G pilot.
package.path="./?.lua;./?/init.lua;"..package.path
local Json=require("save.json")
local H=require("world.r2_compat_bridge")
local Stream=require("world.stream")
local Camera=require("core.camera")
local Terrain=require("world.terrain_renderer")
local Iso=require("world.iso")
local function read(name)
 local f=assert(io.open("../../data/worldbuild/"..name,"rb"))
 local s=f:read("*a");f:close();return Json.decode(s)
end
local scene=H.new(read("fisilti_ormani.r2.v1.json"),
 read("osman_overworld.v2.json"))
local mode=os.getenv("OSMAN_R2_H_SCENE") or "river"
assert(mode=="river" or mode=="spawn")
local camera=Camera.new()
local w,h,frames=720,1100,0
-- River width 22 world units: 32-unit Marching samples alias the stream.
-- Use 8-unit world-space water contour sampling in the isolated diagnostic;
-- the production game and Generator v1 remain unchanged.
local stream=Stream.new(scene.query,{size=256,
 step=mode=="river" and 8 or 32,max_loaded=48,build_budget=48})
local points
function love.load()
 assert(love.window.setMode(w,h,{resizable=false,msaa=0}))
 if mode=="river" then camera.x,camera.y=704,128
 else camera.x,camera.y=64,128 end
 camera.zoom=1.4
 stream:update(camera,w,h,48)
 points=scene.population:objects_in({min_x=camera.x-256,min_y=camera.y-256,
 max_x=camera.x+256,max_y=camera.y+256})
end
function love.update()
 frames=frames+1
 if frames>22 then
  print("R2_H_LOVE_SMOKE_OK mode="..mode.." objects="..#points)
  io.stdout:flush();love.event.quit(0)
 end
end
function love.draw()
 Terrain.draw(stream,camera,w,h,{topography=scene.topography,
  routes=scene.routes,quality="standard",atmosphere=true})
 -- Minimal diagnostic markers display actual E resource instance positions.
 love.graphics.push("all")
 love.graphics.translate(w/2,h/2)
 love.graphics.scale(camera.zoom)
 local sx,sy=Iso.project(camera.x,camera.y)
 love.graphics.translate(-sx,-sy)
 for _,o in ipairs(points) do
  local x,y=Iso.project(o.x,o.y,scene.topography:height(o.x,o.y)*.35)
  love.graphics.setColor(.9,.9,.75,.9)
  love.graphics.circle("line",x,y,math.max(2,o.radius*.4))
 end
 love.graphics.pop()
 if frames==12 then
  love.graphics.captureScreenshot("r2-h-compat-"..mode..".png")
 end
end
