package.path = "./?.lua;./?/init.lua;" .. package.path

local Cam = require("core.camera")
local App = require("core.app")
local Scene = require("world.scene")

local function near(a, b, tolerance)
  assert(math.abs(a-b) < (tolerance or 1e-6), tostring(a).." ~= "..tostring(b))
end

local cam = Cam.new()
for _, point in ipairs({{-90,45},{0,0},{101,-37}}) do
  local sx, sy = cam:project(point[1], point[2], 720, 1100)
  local x, y = cam:unproject(sx, sy, 720, 1100)
  near(x, point[1]); near(y, point[2])
end
local before_x, before_y = cam:unproject(280, 450, 720, 1100)
cam:zoom_at(1.45, 280, 450, 720, 1100)
local after_x, after_y = cam:unproject(280, 450, 720, 1100)
near(before_x, after_x); near(before_y, after_y)
cam:zoom_at(1000, 360, 550, 720, 1100)
near(cam.zoom, cam.max_zoom)
cam:zoom_at(0.0001, 360, 550, 720, 1100)
near(cam.zoom, cam.min_zoom)
cam:reset(); near(cam.zoom, 1.7)

local app = App.new(Scene, 720, 1100)
assert(app:select_at(360, 550).biome.id == "forest")
assert(app:select_at(0, 0) == nil)
app.camera:reset()
local a, b = app.camera.x, app.camera.y
app:press("mouse", 330, 540)
app:move("mouse", 370, 560)
app:release("mouse", 370, 560)
assert(app.camera.x ~= a or app.camera.y ~= b)
app.camera:reset()
app:press("mouse", 360, 550)
local chosen = app:release("mouse", 360, 550)
assert(chosen and chosen.biome.id == "forest")
local old_zoom = app.camera.zoom
local plus = app.hud.buttons[1]
assert(app:press("touch", plus.x + 10, plus.y + 10) == "plus")
assert(app.camera.zoom > old_zoom)
app:release("touch", plus.x + 10, plus.y + 10)
local reset = app.hud.buttons[3]
assert(app:press("touch", reset.x + 10, reset.y + 10) == "reset")
near(app.camera.zoom, 1.7)
app:release("touch", reset.x + 10, reset.y + 10)
app:press(1, 200, 400)
app:press(2, 400, 400)
app:move(2, 460, 400)
assert(app.camera.zoom > 1.7)
app:release(2, 460, 400)
app:release(1, 200, 400)
app.camera:reset()
app:update(1, {right=true})
assert(app.camera.x ~= 0 or app.camera.y ~= 0)
app:resize(320, 640, {x=0,y=24,w=320,h=598})
for _, button in ipairs(app.hud.buttons) do
  assert(button.x>=0 and button.y>=0)
  assert(button.x+button.w<=320 and button.y+button.h<=640)
  assert(app.hud:hit(button.x+button.w/2,button.y+button.h/2)==button.id)
end
print("runtime input/camera/mobile tests OK")
