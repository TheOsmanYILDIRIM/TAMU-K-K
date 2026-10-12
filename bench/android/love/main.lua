local SIDE,SEED,THRESHOLD=192,42,0.51
local SEG={ {},{{3,0}},{{0,1}},{{3,1}},{{1,2}},{{3,2},{0,1}},{{0,2}},{{3,2}},{{2,3}},{{0,2}},{{0,3},{1,2}},{{1,2}},{{1,3}},{{0,1}},{{3,0}},{} }
local lines={} local gen_ms=0 local frames=0 local elapsed=0
local function h(x,y,s) local n=(x*15731+y*789221+s*137631)%65521 return ((n*251+17)%65521)/65520 end
local function lerp(a,b,t) return a+(b-a)*t end
local function noise(x,y,s)
 local ix,iy=math.floor(x),math.floor(y)
 local u,v=x-ix,y-iy
 u=u*u*(3-2*u) v=v*v*(3-2*v)
 return lerp(lerp(h(ix,iy,s),h(ix+1,iy,s),u),lerp(h(ix,iy+1,s),h(ix+1,iy+1,s),u),v)
end
local function density(x,y) return 0.67*noise(x/22,y/22,SEED)+0.33*noise(x/8,y/8,SEED+91) end
local function iso(x,y) return (x-y)*5,(x+y)*2.5 end
local function cross(a,b,va,vb)
 local t= math.abs(vb-va)<1e-8 and 0.5 or math.max(0,math.min(1,(THRESHOLD-va)/(vb-va)))
 return {lerp(a[1],b[1],t),lerp(a[2],b[2],t)}
end
function love.load()
 local t=love.timer.getTime()
 local values={}
 for y=0,SIDE do local row={} values[y]=row for x=0,SIDE do row[x]=density(x-SIDE/2,y-SIDE/2) end end
 for y=0,SIDE-1 do for x=0,SIDE-1 do
  local v={values[y][x],values[y][x+1],values[y+1][x+1],values[y+1][x]}
  local mask=0 for i=1,4 do if v[i]>=THRESHOLD then mask=mask+2^(i-1) end end
  if mask~=0 and mask~=15 then
   local p0={x-SIDE/2,y-SIDE/2} local p1={p0[1]+1,p0[2]} local p2={p0[1]+1,p0[2]+1} local p3={p0[1],p0[2]+1}
   local e={cross(p0,p1,v[1],v[2]),cross(p1,p2,v[2],v[3]),cross(p3,p2,v[4],v[3]),cross(p0,p3,v[1],v[4])}
   for _,pair in ipairs(SEG[mask+1]) do
    local a,b=e[pair[1]+1],e[pair[2]+1]
    local ax,ay=iso(a[1],a[2]) local bx,by=iso(b[1],b[2])
    lines[#lines+1]={ax,ay,bx,by}
   end
  end
 end end
 gen_ms=(love.timer.getTime()-t)*1000
 print(("BENCH LOVE seed=42 cells=%d segments=%d generation_ms=%.3f"):format(SIDE*SIDE,#lines,gen_ms))
end
function love.update(dt)
 frames=frames+1 elapsed=elapsed+dt
 if frames==300 then print(("BENCH LOVE avg_fps=%.3f"):format(frames/elapsed));frames=0;elapsed=0 end
end
function love.draw()
 love.graphics.clear(0.141,0.235,0.212,1)
 local cx,cy=love.graphics.getDimensions()
 cx=cx/2 cy=cy/2
 love.graphics.setColor(0.663,0.831,0.557)
 love.graphics.setLineWidth(1.5)
 for _,l in ipairs(lines) do love.graphics.line(l[1]+cx,l[2]+cy,l[3]+cx,l[4]+cy) end
 love.graphics.setColor(1,1,1)
 love.graphics.print("LOVE 2D | seed 42 | cells 36864",12,20)
end
