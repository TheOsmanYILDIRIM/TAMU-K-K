local Iso = require("world.iso")

local Camera = {}
Camera.__index = Camera

function Camera.new()
  return setmetatable({ x = 0, y = 0, zoom = 1.7, min_zoom = 0.65, max_zoom = 4.5 }, Camera)
end

function Camera:project(x, y, width, height)
  local px, py = Iso.project(x - self.x, y - self.y)
  return width / 2 + px * self.zoom, height / 2 + py * self.zoom
end

function Camera:unproject(sx, sy, width, height)
  local dx, dy = Iso.unproject((sx - width / 2) / self.zoom,
                              (sy - height / 2) / self.zoom)
  return self.x + dx, self.y + dy
end

function Camera:pan(dx, dy)
  local x, y = Iso.unproject(-dx / self.zoom, -dy / self.zoom)
  self.x, self.y = self.x + x, self.y + y
end

function Camera:zoom_at(factor, sx, sy, width, height)
  assert(type(factor) == "number" and factor > 0 and factor == factor,
         "Zoom factor must be positive")
  local wx, wy = self:unproject(sx, sy, width, height)
  self.zoom = math.max(self.min_zoom, math.min(self.max_zoom, self.zoom * factor))
  local nx, ny = self:unproject(sx, sy, width, height)
  self.x, self.y = self.x + wx - nx, self.y + wy - ny
end

function Camera:reset()
  self.x, self.y, self.zoom = 0, 0, 1.7
end

return Camera
