-- Stateless global 64-unit lattice; chunk ownership is derived from world coords.
-- Deliberately avoids Lua integer bitops and math.random for LuaJIT parity.
local Collision=require("physics.collision")
local Defs=require("objects.definitions")
local P={};P.__index=P
-- All intermediate products fit exactly in IEEE-754 doubles (LuaJIT).
-- Quadratic axis mixing removes the diagonal correlation of linear hashes.
local MOD=1000003
local function mix(seed,x,y,salt)
  local ix,iy=x%MOD,y%MOD
  local h=((seed%MOD)*97+ix*16807+iy*48271+salt*1013)%MOD
  h=(h+((ix*iy)%MOD)*1847+((ix*ix)%MOD)*463+((iy*iy)%MOD)*919)%MOD
  h=(h*48271+1)%MOD
  h=(h+math.floor(h/37)*1931)%MOD
  h=(h*69621+1)%MOD
  return h/MOD
end
function P.new(query,water,spacing)
  spacing=spacing or 64
  assert(query and query.seed and query.sample and water and water.obstacles)
  assert(spacing>0 and spacing%1==0 and 256%spacing==0,"spacing must divide 256")
  return setmetatable({query=query,water=water,spacing=spacing},P)
end
function P:at(gx,gy)
  assert(type(gx)=="number" and gx%1==0 and type(gy)=="number" and gy%1==0
    and math.abs(gx)<1000000 and math.abs(gy)<1000000,"invalid site")
  local seed=self.query.seed
  local x=(gx+.5)*self.spacing+(mix(seed,gx,gy,11)-.5)*self.spacing*.56
  local y=(gy+.5)*self.spacing+(mix(seed,gx,gy,12)-.5)*self.spacing*.56
  local sample=self.query:sample(x,y)
  if not sample.walkable or sample.feature=="path" then return nil end
  local roll=mix(seed,gx,gy,13)
  local kind
  if sample.biome=="forest" and roll<.52 then kind="core:oak_tree"
  elseif sample.biome=="rocky" and roll<.43 then kind="core:stone_rock"
  elseif sample.biome=="meadow" then
    if roll<.085 then kind="core:oak_tree"
    elseif roll<.14 then kind="core:stone_rock" end
  end
  if not kind then return nil end
  local def=Defs.get(kind)
  -- Water uses the same conservative Marching collider as the player.
  if not Collision.can_stand(self.water,x,y,def.radius+4) then return nil end
  return {id=("worldobj:v1:%d:%d:%d"):format(seed,gx,gy),
    def_id=kind,kind=def.kind,x=x,y=y,radius=def.radius,
    cx=math.floor(x/256),cy=math.floor(y/256),gx=gx,gy=gy}
end
return P
