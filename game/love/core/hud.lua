local Hud = {}
Hud.__index = Hud

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

function Hud.new(width, height)
  local self = setmetatable({}, Hud)
  self:resize(width, height)
  return self
end

function Hud:resize(width, height, safe)
  assert(width > 0 and height > 0, "Invalid viewport")
  self.width, self.height = width, height
  safe = safe or { x = 0, y = 0, w = width, h = height }
  local scale = clamp(math.min(width / 720, height / 1100), 0.75, 1.5)
  self.scale = scale
  local edge = 12 * scale
  local bx = clamp(safe.x + safe.w - 72 * scale, edge, width - 58 * scale)
  local top = math.max(edge, safe.y + edge)
  local bottom = math.min(height - 70 * scale, safe.y + safe.h - 67 * scale)
  local size = 56 * scale
  self.buttons = {
    { id = "plus", x = bx, y = top + 45 * scale, w = size, h = size, label = "+" },
    { id = "minus", x = bx, y = top + 108 * scale, w = size, h = size, label = "-" },
    { id = "reset", x = bx, y = bottom, w = size, h = size, label = "R" },
  }
  self.header_y = top
  self.footer_y = math.max(top + 170 * scale, bottom - 13 * scale)
end

function Hud:hit(x, y)
  for _, b in ipairs(self.buttons) do
    if x >= b.x and y >= b.y and x <= b.x + b.w and y <= b.y + b.h then
      return b.id
    end
  end
  return nil
end

function Hud:draw(selected, zoom)
  local lg = love.graphics
  local s = self.scale
  lg.setColor(0.055, 0.105, 0.10, 0.86)
  lg.rectangle("fill", 8*s, self.header_y, math.min(self.width - 90*s, 425*s), 76*s, 11*s, 11*s)
  lg.setColor(0.96, 0.95, 0.85, 1)
  lg.print("WORLD / EXPLORER", 20*s, self.header_y + 10*s)
  local subtitle = selected and (selected.region.id .. " / " .. selected.biome.id)
                           or "Drag to explore  |  Tap a region"
  lg.print(subtitle, 20*s, self.header_y + 39*s)
  lg.setColor(0.075, 0.14, 0.13, 0.82)
  lg.rectangle("fill", 8*s, self.footer_y, math.min(self.width - 92*s, 425*s), 44*s, 9*s, 9*s)
  lg.setColor(0.83, 0.94, 0.83, 1)
  lg.print(string.format("3 biomes  /  zoom %.1fx  /  no texture assets", zoom),
           16*s, self.footer_y + 11*s)
  for _, b in ipairs(self.buttons) do
    lg.setColor(0.10, 0.20, 0.19, 0.94)
    lg.rectangle("fill", b.x, b.y, b.w, b.h, 13*s, 13*s)
    lg.setColor(0.83, 0.94, 0.83, 1)
    lg.rectangle("line", b.x, b.y, b.w, b.h, 13*s, 13*s)
    lg.printf(b.label, b.x, b.y + b.h/2 - 8, b.w, "center")
  end
end

return Hud
