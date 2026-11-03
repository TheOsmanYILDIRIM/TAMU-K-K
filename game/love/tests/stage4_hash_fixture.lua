package.path="./?.lua;./?/init.lua;"..package.path
local Placement=require("objects.placement")
local query={seed=20261015,sample=function() return {biome="forest",walkable=true} end}
local water={obstacles=function() return {} end}
local p=Placement.new(query,water)
local grid,ones,adjacent= {},0,0
local t0=os.clock()
for y=-30,30 do
  grid[y]={}
  for x=-30,30 do
    local obj=p:at(x,y)
    grid[y][x]=obj and 1 or 0
    ones=ones+grid[y][x]
    if obj and (x+y)%13==0 then
      io.write(string.format("%s %s %.6f %.6f\n",obj.id,obj.def_id,obj.x,obj.y))
    end
  end
end
for y=-30,29 do for x=-30,29 do
  if grid[y][x]==1 and grid[y+1][x+1]==1 then adjacent=adjacent+1 end
end end
-- The old linear hash produced about 45% double-occupied diagonal pairs.
-- A de-correlated forest occupancy should be close to 0.52^2 ~= 0.27.
assert(adjacent/3600>0.17 and adjacent/3600<0.36,"diagonal striping regression")
assert(ones>1200 and ones<2700,"pathological resource frequency")
assert(os.clock()-t0<8,"resource site CPU budget exceeded")
io.write(string.format("HASH_OK count=%d diagonal_pairs=%d\n",ones,adjacent))
