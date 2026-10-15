-- Screen-space 8-way facing for 45-degree isometric projected world movement.
local D={names={'E','SE','S','SW','W','NW','N','NE'}}
local K=math.sqrt(0.5)
function D.from_world(dx,dy,previous)
  if dx==0 and dy==0 then return previous or 'S' end
  local sx,sy=(dx-dy)*K,(dx+dy)*K/2
  local oct=math.floor((math.atan(sy,sx)+math.pi/8)/(math.pi/4))%8
  return D.names[oct+1]
end
return D
