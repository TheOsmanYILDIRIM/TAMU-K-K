-- Render-order key is the projected foot position (not sprite origin/top).
local D={}
local K=math.sqrt(.5)/2
function D.key(x,y,z)
  assert(type(x)=='number' and type(y)=='number')
  return (x+y)*K-(z or 0)
end
function D.before(a,b)
  if a.depth~=b.depth then return a.depth<b.depth end
  return tostring(a.id)<tostring(b.id)
end
return D
