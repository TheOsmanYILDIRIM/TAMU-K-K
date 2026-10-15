-- Single collision authority for physics, swept AABB and A*.
local Q={};Q.__index=Q
function Q.new(water,objects)
  assert(water and type(water.obstacles)=="function")
  assert(objects and type(objects.obstacles)=="function")
  return setmetatable({water=water,objects=objects},Q)
end
function Q:obstacles(x1,y1,x2,y2)
  local list=self.water:obstacles(x1,y1,x2,y2)
  local obj=self.objects:obstacles(x1,y1,x2,y2)
  for i=1,#obj do list[#list+1]=obj[i] end
  return list
end
return Q
