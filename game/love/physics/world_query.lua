-- WorldQuery v1: stable interface independent of terrain/chunk implementation.
-- query:obstacles(minX,minY,maxX,maxY) -> complete array of axis-aligned rects
-- overlapping the bounds, each {x,y,w,h} (positive dimensions), in world units.
-- Missing/unloaded data must raise an error; it is NEVER implicitly empty terrain.
local M = {}
local function finite(n)
  return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end
M.finite = finite
function M.assert_query(query)
  assert(type(query) == 'table' and type(query.obstacles) == 'function',
    'WorldQuery.obstacles(bounds) required')
end
function M.obstacles(query, x1, y1, x2, y2)
  M.assert_query(query)
  assert(finite(x1) and finite(y1) and finite(x2) and finite(y2), 'nonfinite query bound')
  assert(x1 <= x2 and y1 <= y2, 'invalid query bounds')
  local list = query:obstacles(x1,y1,x2,y2)
  assert(type(list) == 'table', 'WorldQuery must return a complete array, not nil')
  -- Collision consumes the provider array synchronously without mutation.
  -- Avoid cloning every result during the CCD sweep.
  local count = #list
  for i = 1, count do
    local r = list[i]
    assert(type(r) == 'table' and finite(r.x) and finite(r.y)
      and finite(r.w) and finite(r.h) and r.w > 0 and r.h > 0,
      'invalid obstacle at index '..i)
  end
  for k in pairs(list) do
    assert(type(k)=='number' and k%1==0 and k>=1 and k<=count,
      'WorldQuery obstacles must be a dense array')
  end
  return list
end
return M
