-- Standalone Stage 2 LÖVE demo. CI copies this to a TEMP game root main.lua.
-- Real game main.lua/core app remain unchanged for parallel Stage 3 work.
local Query=require("world.world_query")
local Stream=require("world.stream")
local Terrain=require("world.terrain_renderer")
local Camera=require("core.camera")
local query=Query.new(20261015)
local stream=Stream.new(query,{size=256,step=32,max_loaded=144,build_budget=5})
local camera=Camera.new()
local count=0
local running_smoke=os.getenv("OSMAN_LOVE_WORLD_SMOKE")=="1"
local w,h=720,1100
local last

function love.load()
  w,h=love.graphics.getDimensions()
end

function love.resize(width,height) w,h=width,height end

function love.update(dt)
  local vx=(love.keyboard.isDown("left","a") and 1 or 0)
          -(love.keyboard.isDown("right","d") and 1 or 0)
  local vy=(love.keyboard.isDown("up","w") and 1 or 0)
          -(love.keyboard.isDown("down","s") and 1 or 0)
  local length=math.sqrt(vx*vx+vy*vy)
  if length>0 then camera:pan(vx/length*360*dt,vy/length*360*dt) end
  last=stream:update(camera,w,h)
end

function love.draw()
  Terrain.draw(stream,camera,w,h)
  love.graphics.setColor(.94,.96,.89)
  love.graphics.print("WORLD V2 / seed 20261015",16,18)
  love.graphics.print(string.format("Chunks: %d / %d   Zoom: %.2fx",
    last.loaded,last.needed,camera.zoom),16,40)
  love.graphics.print("WASD / arrows: pan   Wheel: zoom   R: reset",16,62)
  count=count+1
  if running_smoke and count>=5 and last.loaded>0 then
    print("LOVE_WORLD_SMOKE_OK chunks="..last.loaded.." frames="..count)
    io.stdout:flush()
    love.event.quit()
  end
end

function love.wheelmoved(_,dy)
  camera:zoom_at(1.15^dy,w/2,h/2,w,h)
end
function love.keypressed(key)
  if key=="r" then camera:reset() end
end
local drag=false
function love.mousepressed(x,y,button,istouch)
  if button==1 and not istouch then drag=true end
end
function love.mousereleased(_,_,button,istouch)
  if button==1 and not istouch then drag=false end
end
function love.mousemoved(_,_,dx,dy,istouch)
  if drag and not istouch then camera:pan(dx,dy) end
end
local fingers={}
function love.touchpressed(id,x,y) fingers[id]={x=x,y=y} end
function love.touchmoved(id,x,y)
  local prev=fingers[id];if not prev then return end
  camera:pan(x-prev.x,y-prev.y);prev.x,prev.y=x,y
end
function love.touchreleased(id) fingers[id]=nil end
