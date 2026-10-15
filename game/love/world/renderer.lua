local Biomes = require("world.biomes")

local Renderer = {}

local function color_with_lightness(rgb, factor)
  return math.min(rgb[1]*factor,1), math.min(rgb[2]*factor,1),
         math.min(rgb[3]*factor,1), 1
end

function Renderer.draw(world, camera, selected, width, height)
  local lg = love.graphics
  lg.clear(0.09, 0.16, 0.18, 1)
  for _, region in ipairs(world.regions) do
    local biome = Biomes.resolve(region.biome, region.variant)
    local points = {}
    for _, vertex in ipairs(region.polygon) do
      local sx, sy = camera:project(vertex[1], vertex[2], width, height)
      points[#points+1], points[#points+2] = sx, sy
    end
    local picked = selected and selected.region.id == region.id
    local amount = picked and 1.27 or 1
    lg.setColor(color_with_lightness(biome.color, amount))
    -- LÖVE cannot fill arbitrary concave polygons directly: triangulate them.
    for _, triangle in ipairs(love.math.triangulate(points)) do
      lg.polygon("fill", triangle)
    end
    lg.setColor(picked and 0.98 or 0.18,
                picked and 0.91 or 0.31,
                picked and 0.58 or 0.28, 1)
    lg.setLineWidth(picked and 4 or 2)
    lg.polygon("line", points)
  end
  lg.setColor(1, 1, 1, 1)
end

return Renderer
