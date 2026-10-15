local Camera = require("core.camera")
local Hud = require("core.hud")
local Regions = require("world.regions")

local App = {}
App.__index = App

function App.new(world, width, height, safe)
  assert(world and world.regions, "World required")
  local self = setmetatable({
    world = world, camera = Camera.new(), hud = Hud.new(width, height),
    width = width, height = height, pointers = {}, selected = nil
  }, App)
  self.hud:resize(width, height, safe)
  return self
end

function App:resize(width, height, safe)
  self.width, self.height = width, height
  self.hud:resize(width, height, safe)
end

local function pointer_count(pointers)
  local count = 0
  for _ in pairs(pointers) do count = count + 1 end
  return count
end

local function two_points(pointers)
  local first, second
  for _, pointer in pairs(pointers) do
    if not first then first = pointer
    else second = pointer; break end
  end
  return first, second
end

function App:select_at(sx, sy)
  local x, y = self.camera:unproject(sx, sy, self.width, self.height)
  self.selected = Regions.sample(self.world, x, y)
  return self.selected
end

function App:press(id, x, y)
  if pointer_count(self.pointers) == 0 then
    local action = self.hud:hit(x, y)
    if action == "plus" then
      self.camera:zoom_at(1.25, self.width/2, self.height/2, self.width, self.height)
    elseif action == "minus" then
      self.camera:zoom_at(0.8, self.width/2, self.height/2, self.width, self.height)
    elseif action == "reset" then
      self.camera:reset()
    end
    if action then return action end
  end
  self.pointers[id] = { x = x, y = y, start_x = x, start_y = y, moved = false }
  if pointer_count(self.pointers) >= 2 then
    for _, p in pairs(self.pointers) do p.moved = true end
  end
  return nil
end

function App:move(id, x, y)
  local p = self.pointers[id]
  if not p then return end
  local count = pointer_count(self.pointers)
  if count == 1 then
    local dx, dy = x - p.x, y - p.y
    if (x-p.start_x)^2 + (y-p.start_y)^2 > 100 then p.moved = true end
    if p.moved then self.camera:pan(dx, dy) end
  else
    local a, b = two_points(self.pointers)
    local old_mx, old_my = (a.x+b.x)/2, (a.y+b.y)/2
    local old_dist = math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2)
    p.x, p.y = x, y
    local new_mx, new_my = (a.x+b.x)/2, (a.y+b.y)/2
    local new_dist = math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2)
    self.camera:pan(new_mx-old_mx, new_my-old_my)
    if old_dist > 0 and new_dist > 0 then
      self.camera:zoom_at(new_dist/old_dist, new_mx, new_my,
                          self.width, self.height)
    end
    p.moved = true
    return
  end
  p.x, p.y = x, y
end

function App:release(id, x, y)
  local p = self.pointers[id]
  if not p then return end
  local tap = not p.moved and pointer_count(self.pointers) == 1
    and (x-p.start_x)^2 + (y-p.start_y)^2 <= 100
  self.pointers[id] = nil
  if tap then return self:select_at(x, y) end
  return nil
end

function App:wheel(delta, x, y)
  if delta == 0 then return end
  self.camera:zoom_at(1.15 ^ delta, x or self.width/2,
    y or self.height/2, self.width, self.height)
end

function App:update(dt, keys)
  dt = math.max(0, math.min(dt, 0.05))
  keys = keys or {}
  local dx = (keys.left and 1 or 0) - (keys.right and 1 or 0)
  local dy = (keys.up and 1 or 0) - (keys.down and 1 or 0)
  if dx ~= 0 or dy ~= 0 then
    local length = math.sqrt(dx*dx + dy*dy)
    self.camera:pan(dx/length*420*dt, dy/length*420*dt)
  end
end

return App
