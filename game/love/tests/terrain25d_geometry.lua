package.path="./?.lua;./?/init.lua;"..package.path
local Geo=require("world.terrain25d_geometry")
local Light=require("world.terrain25d_lighting")
local Iso=require("world.iso")
local function close(a,b) return math.abs(a-b)<1e-9 end
local function make_topo(f)
 return {height=function(_,x,y) return f(x,y) end,
  sample=function(_,x,y)
   local d=1
   return {gradient_x=(f(x+d,y)-f(x-d,y))/(2*d),
    gradient_y=(f(x,y+d)-f(x,y-d))/(2*d)}
  end}
end
local function eq(a,b)
 assert(#a==#b)
 for i=1,#a do
  if type(a[i])=="table" then eq(a[i],b[i]) else assert(a[i]==b[i]) end
 end
end
local flat=make_topo(function() return 4 end)
local opts={size=64,height_scale=.65}
local a=Geo.build_chunk(nil,flat,opts,{x=0,y=0},8)
local b=Geo.build_chunk(nil,flat,opts,{x=64,y=0},8)
assert(#a.vertices==81 and #a.indices==384 and #Geo.love_vertices(a)==384)
for iy=0,8 do
 local va=a.vertices[iy*9+9]
 local vb=b.vertices[iy*9+1]
 eq(va,vb)
 assert(close(va[6],0) and close(va[7],0) and close(va[8],1))
 local px,py=Iso.project(64,iy*8,4*.65)
 assert(close(va[1],px) and close(va[2],py))
end
local slope=make_topo(function(x,y) return .25*x-.5*y+2 end)
local sa=Geo.build_chunk(nil,slope,opts,{x=-128,y=-64},8)
local sb=Geo.build_chunk(nil,slope,opts,{x=-64,y=-64},8)
for iy=0,8 do eq(sa.vertices[iy*9+9],sb.vertices[iy*9+1]) end
local again=Geo.build_chunk(nil,slope,opts,{x=-128,y=-64},8)
for i=1,#sa.vertices do eq(sa.vertices[i],again.vertices[i]) end
eq(sa.indices,again.indices)
assert(sa.vertices[1][6]<0 and sa.vertices[1][7]>0)
local reverse=Geo.build_chunk(nil,make_topo(function(x,y) return -.25*x+.5*y end),opts,{x=-128,y=-64},8)
assert(sa.vertices[1][5]~=reverse.vertices[1][5],"slope directions must affect lighting")
local far=Geo.build_chunk(nil,slope,opts,{x=-8192,y=16384},8)
assert(#far.vertices==81)
local cliff=make_topo(function(x,y) return 1e5*x+2e5*y end)
local steep=Geo.build_chunk(nil,cliff,opts,{x=0,y=0},8)
for _,v in ipairs(steep.vertices) do
 assert(v[5]==v[5] and v[5]>=0 and v[5]<=1 and v[8]>0 and v[8]<=1)
end
local n1,n2,n3=Light.normal(0,0,.65)
assert(n1==0 and n2==0 and n3==1)
-- Exact physical wet mask: no new water classification.
local query={water_mask=function(_,x,y) return x==64 and y==32,1 end}
local wet=Geo.build_chunk(query,flat,opts,{x=0,y=0},8)
assert(wet.vertices[4*9+9][13]==1 and wet.vertices[1][13]==0)
assert(not pcall(Geo.build_chunk,nil,flat,opts,{x=1,y=0},8))
print("TERRAIN25D_GEOMETRY_OK seams=2 determinism=1 negative=1 far=1 flat=1 cliffs=1 water=1")
