-- Marching Squares contours + clipped cell patches for fill.
-- Nodes are sampled at ABSOLUTE world coordinates to guarantee chunk seams.
-- Ambiguous saddle cases (5/10) use the center value for consistent topology.
local M = {}

local function crossing(a, b, level)
  local delta = b.value - a.value
  local t = (delta == 0) and 0.5 or (level - a.value) / delta
  t = math.max(0, math.min(1, t))
  return {a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t}
end

local function clip_triangle(tri, level, out)
  local clipped = {}
  local previous = tri[#tri]
  for i = 1, #tri do
    local current = tri[i]
    local a, b = previous.value > level, current.value > level
    if a ~= b then
      local p = crossing(previous, current, level)
      clipped[#clipped + 1] = {p[1], p[2]}
    end
    if b then clipped[#clipped + 1] = {current.x, current.y} end
    previous = current
  end
  for i = 2, #clipped - 1 do
    out[#out+1] = clipped[1]
    out[#out+1] = clipped[i]
    out[#out+1] = clipped[i+1]
  end
end

-- Edge order: top=1, right=2, bottom=3, left=4.
local segments = {
  [1]={{1,4}}, [2]={{1,2}}, [3]={{4,2}}, [4]={{2,3}},
  [6]={{1,3}}, [7]={{4,3}}, [8]={{3,4}}, [9]={{1,3}},
  [11]={{2,3}}, [12]={{2,4}}, [13]={{1,2}}, [14]={{1,4}}
}

function M.build(sampler, origin_x, origin_y, size, step, threshold, checkpoint)
  assert(type(sampler) == "function", "sampler required")
  assert(type(size) == "number" and size > 0
     and type(step) == "number" and step > 0
     and size / step == math.floor(size / step), "step must divide size")
  assert(checkpoint==nil or type(checkpoint)=="function", "invalid checkpoint")
  threshold = threshold or 0
  local n = size / step
  local rows = {}
  for iy = 0, n do
    local row = {}
    for ix = 0, n do
      local x, y = origin_x + ix * step, origin_y + iy * step
      local v = sampler(x, y)
      assert(type(v) == "number" and v == v and math.abs(v) < math.huge,
             "invalid sampled scalar field")
      row[ix+1] = {x = x, y = y, value = v}
      if checkpoint and ix % 16 == 15 then checkpoint() end
    end
    rows[iy+1] = row
    if checkpoint then checkpoint() end
  end
  local output = {vertices = {}, contours = {}}
  for iy = 1, n do
    for ix = 1, n do
      local tl, tr = rows[iy][ix], rows[iy][ix+1]
      local br, bl = rows[iy+1][ix+1], rows[iy+1][ix]
      local center = {
        x=(tl.x+br.x)/2, y=(tl.y+br.y)/2,
        value=(tl.value+tr.value+br.value+bl.value)/4
      }
      local four = {tl,tr,br,bl}
      -- Fill via center-fan clipped triangles; no square tile edges drawn.
      for k=1,4 do
        clip_triangle({four[k],four[k%4+1],center},threshold,output.vertices)
      end
      local mask=(tl.value > threshold and 1 or 0)
               +(tr.value > threshold and 2 or 0)
               +(br.value > threshold and 4 or 0)
               +(bl.value > threshold and 8 or 0)
      if mask ~= 0 and mask ~= 15 then
        local edges = {
          crossing(tl,tr,threshold), crossing(tr,br,threshold),
          crossing(bl,br,threshold), crossing(tl,bl,threshold)
        }
        local pairs = segments[mask]
        if mask == 5 then
          pairs = center.value > threshold and {{1,2},{3,4}} or {{1,4},{2,3}}
        elseif mask == 10 then
          pairs = center.value > threshold and {{1,4},{2,3}} or {{1,2},{3,4}}
        end
        for _,pair in ipairs(pairs) do
          output.contours[#output.contours+1] = {
            edges[pair[1]], edges[pair[2]]
          }
        end
      end
      if checkpoint and ix % 16 == 0 then checkpoint() end
    end
    if checkpoint then checkpoint() end
  end
  return output
end

return M
