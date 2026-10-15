local J={};J.__index=J
function J.new(radius,deadzone)
  assert(type(radius)=='number' and radius>0)
  deadzone=deadzone or .12
  assert(type(deadzone)=='number' and deadzone>=0 and deadzone<1)
  return setmetatable({radius=radius,deadzone=deadzone,id=nil,x=0,y=0,dx=0,dy=0},J)
end
function J:press(id,x,y)
  if self.id~=nil or id==nil then return false end
  self.id,self.x,self.y,self.dx,self.dy=id,x,y,0,0
  return true
end
function J:move(id,x,y)
  if id~=self.id or id==nil then return false end
  local dx,dy=x-self.x,y-self.y
  local length=math.sqrt(dx*dx+dy*dy)
  local strength=math.min(1,length/self.radius)
  if strength<=self.deadzone then self.dx,self.dy=0,0
  else
    local output=(strength-self.deadzone)/(1-self.deadzone)
    self.dx,self.dy=dx/length*output,dy/length*output
  end
  return true
end
function J:release(id)
  if self.id~=id or id==nil then return false end
  self.id,self.dx,self.dy=nil,0,0
  return true
end
function J:axis() return self.dx,self.dy end
return J
