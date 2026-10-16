-- Isolated LÖVE screenshotable integration demo. Copy this file to main.lua
-- ONLY in a scratch/CI checkout; the game's real main.lua is untouched.
local Scenario=require("systems.scenario")
local Stream=require("world.stream")
local Terrain=require("world.terrain_renderer")
local Objects=require("objects.renderer")
local Camera=require("core.camera")
local result
local stream,camera,width,height,frames
local smoke=os.getenv("OSMAN_LOVE_STAGE5_SMOKE")=="1"
local saved=false

function love.load()
  result=Scenario.run(20261015)
  camera=Camera.new()
  camera.x,camera.y=result.player.x,result.player.y
  stream=Stream.new(result.query,{
    size=256,step=32,max_loaded=100,build_budget=5})
  width,height=love.graphics.getDimensions()
  frames=0
end

function love.resize(w,h) width,height=w,h end
function love.update(dt)
  stream:update(camera,width,height)
  local dx=(love.keyboard.isDown("right","d") and -1 or 0)
    +(love.keyboard.isDown("left","a") and 1 or 0)
  local dy=(love.keyboard.isDown("down","s") and -1 or 0)
    +(love.keyboard.isDown("up","w") and 1 or 0)
  if dx~=0 or dy~=0 then camera:pan(dx*dt*200,dy*dt*200) end
end
function love.draw()
  Terrain.draw(stream,camera,width,height)
  Objects.draw(result.resources,stream,camera,width,height,result.player,nil)
  local g=love.graphics
  for _,placed in pairs(result.building.placed) do
    local x,y=camera:project(placed.x,placed.y,width,height)
    local z=camera.zoom
    g.setColor(.12,.08,.06,.65)
    g.rectangle("fill",x-18*z,y-7*z,36*z,14*z)
    g.setColor(.66,.44,.21)
    g.rectangle("fill",x-15*z,y-26*z,30*z,25*z)
    g.setColor(.88,.66,.34)
    g.rectangle("line",x-15*z,y-26*z,30*z,25*z)
  end
  g.setColor(.05,.12,.13,.92)
  g.rectangle("fill",12,12,math.min(width-24,520),120,12,12)
  g.setColor(.95,.96,.88)
  g.print("STAGE 5 / PROCEDURAL WORLD + CRAFTING + BUILD",24,23)
  g.print("Tree harvested -> 3 logs -> 4 planks -> workbench",24,49)
  g.print(string.format("Logs %d | Planks %d | Bench placed %d",
    result.inventory:count("core:wood_log"),
    result.inventory:count("core:wood_plank"),result.building.revision),24,73)
  g.print("Isolated domain proof — no disk saves or APK",24,98)
  frames=frames+1
  if smoke and frames>=40 and #stream:visible()>0
    and stream.wanted_count==#stream:visible() then
    if not saved then
      saved=true
      love.graphics.captureScreenshot("stage5-workbench-smoke.png")
    end
    print("LOVE_STAGE5_SMOKE_OK chunks="..#stream:visible()
      .." world_revision="..result.building.revision
      .." logs="..result.inventory:count("core:wood_log"))
    io.stdout:flush()
    love.event.quit()
  end
end
function love.wheelmoved(_,dy)
  camera:zoom_at(1.15^dy,width/2,height/2,width,height)
end
