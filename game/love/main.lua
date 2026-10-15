local Scene = require("world.scene")
local Biomes = require("world.biomes")
local Renderer = require("world.renderer")
local App = require("core.app")

local app
local ci_smoke = os.getenv("OSMAN_LOVE_SMOKE") == "1"
local ci_rendered_frames = 0

local function safe_area(width, height)
  if love.window and love.window.getSafeArea then
    local x, y, w, h = love.window.getSafeArea()
    if x and w and w > 0 and h > 0 then
      return { x = x, y = y, w = w, h = h }
    end
  end
  return { x = 0, y = 0, w = width, h = height }
end

function love.load()
  Biomes.validate()
  local w, h = love.graphics.getDimensions()
  app = App.new(Scene, w, h, safe_area(w, h))
end

function love.resize(w, h)
  if app then app:resize(w, h, safe_area(w, h)) end
end

function love.update(dt)
  app:update(dt, {
    up = love.keyboard.isDown("w", "up"),
    down = love.keyboard.isDown("s", "down"),
    left = love.keyboard.isDown("a", "left"),
    right = love.keyboard.isDown("d", "right"),
  })
end

function love.draw()
  Renderer.draw(Scene, app.camera, app.selected, app.width, app.height)
  app.hud:draw(app.selected, app.camera.zoom)
  if ci_smoke then
    ci_rendered_frames = ci_rendered_frames + 1
    if ci_rendered_frames == 3 then
      print("LOVE_RENDER_SMOKE_OK " .. tostring(app.width) .. "x" .. tostring(app.height))
      io.stdout:flush()
      love.event.quit()
    end
  end
end

function love.touchpressed(id, x, y) app:press(id, x, y) end
function love.touchmoved(id, x, y) app:move(id, x, y) end
function love.touchreleased(id, x, y) app:release(id, x, y) end

-- Ignore touch-synthesized mouse events; otherwise one finger becomes two pointers.
function love.mousepressed(x, y, button, istouch)
  if button == 1 and not istouch then app:press("mouse", x, y) end
end
function love.mousemoved(x, y, _, _, istouch)
  if not istouch then app:move("mouse", x, y) end
end
function love.mousereleased(x, y, button, istouch)
  if button == 1 and not istouch then app:release("mouse", x, y) end
end
function love.wheelmoved(_, delta)
  local x, y = love.mouse.getPosition()
  app:wheel(delta, x, y)
end
function love.keypressed(key)
  if key == "r" or key == "home" then app.camera:reset() end
  if key == "escape" then app.selected = nil end
end
