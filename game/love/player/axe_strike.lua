local M={}
local function clamp(x) return math.max(0,math.min(1,x)) end
local function smooth(x) x=clamp(x);return x*x*(3-2*x) end
local function lerp(a,b,t) return a+(b-a)*t end
local function rotate(x,y,a) return x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a) end
-- Source image 121227.png: unmodified RGBA, mirrored at draw time.
M.asset={pivot={1115,1120},edge={190,405},mirror=true}
function M.pose(t,core,target,scale)
  scale=scale or .18
  local p,e=M.asset.pivot,M.asset.edge
  local dx=(p[1]-e[1])*scale
  local dy=(e[2]-p[2])*scale
  local a0,a1,a2=-.12,-1.28,.30
  -- Scale-relative reach keeps the 1254px original artwork proportional to
  -- the small autonomous core at portrait zoom levels.
  local gx,gy=core.x+11*(scale/.08),core.y-7*(scale/.08)
  local hx,hy=rotate(dx,dy,a1)
  local contactx,contacty=target.x-hx,target.y-hy
  local angle,x,y,phase
  if t<.28 then
    local u=smooth(t/.28)
    angle=lerp(a0,a2,u);x=lerp(gx,gx+5,u);y=lerp(gy,gy-17,u);phase="prepare"
  elseif t<.53 then
    local u=smooth((t-.28)/.25)
    angle=lerp(a2,a1,u);x=lerp(gx+5,contactx,u);y=lerp(gy-17,contacty,u);phase="strike"
  elseif t<.60 then
    angle=a1;x=contactx;y=contacty;phase="impact"
  else
    local u=smooth((t-.60)/.40)
    angle=lerp(a1,a0,u);x=lerp(contactx,gx,u);y=lerp(contacty,gy,u);phase="recover"
  end
  local ex,ey=rotate(dx,dy,angle)
  return {x=x,y=y,angle=angle,edgeX=x+ex,edgeY=y+ey,phase=phase,progress=t,scale=scale}
end
function M.draw(g,image,elapsed,core,target,scale)
  local duration=.88
  local t=(elapsed%duration)/duration
  local pose=M.pose(t,core,target,scale)
  if t>.29 and t<.60 then
    local points={}
    local first=math.max(.28,t-.13)
    for i=0,16 do
      local q=first+(t-first)*i/16
      local v=M.pose(q,core,target,scale)
      points[#points+1]={v.edgeX,v.edgeY}
    end
    for i=2,#points do
      local u=i/#points
      g.setColor(.14,.83,.96,.08+.52*u)
      g.setLineWidth(2+9*u)
      g.line(points[i-1][1],points[i-1][2],points[i][1],points[i][2])
    end
  end
  g.push("all")
  g.translate(pose.x,pose.y)
  g.rotate(pose.angle)
  g.scale(-pose.scale,pose.scale)
  g.setColor(1,1,1,1)
  g.draw(image,-M.asset.pivot[1],-M.asset.pivot[2])
  g.pop()
  if t>=.53 and t<.70 then
    local life=1-(t-.53)/.17
    for i=1,12 do
      local a=i*2.39996
      local r=(1-life)*(9+5*(i%4))
      g.setColor(1,.54+.3*life,.20,life*.72)
      g.circle("fill",target.x+math.cos(a)*r,target.y+math.sin(a)*r*.65,1+2*life)
    end
  end
  g.setColor(1,1,1,1)
  return pose
end
return M
