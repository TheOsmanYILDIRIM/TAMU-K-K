local Marching = require("world.marching")
local Query = require("world.world_query")
local Chunks = {}
Chunks.__index = Chunks

function Chunks.new(query, opts)
  opts = opts or {}
  assert(query and query.field and query.sample, "WorldQuery required")
  local size, step = opts.size or 256, opts.step or 32
  assert(size > 0 and step > 0 and size/step == math.floor(size/step),
         "invalid chunk geometry")
  return setmetatable({query=query,size=size,step=step},Chunks)
end

function Chunks.key(cx, cy)
  assert(cx == math.floor(cx) and cy == math.floor(cy), "integer chunk coords required")
  return tostring(cx)..":"..tostring(cy)
end

function Chunks:build(cx, cy)
  local key = Chunks.key(cx, cy)
  local x0, y0 = cx*self.size, cy*self.size
  local output = {key=key, cx=cx, cy=cy, x=x0, y=y0, size=self.size, layers={}}
  for _,name in ipairs({"forest","rocky","water"}) do
    output.layers[name] = Marching.build(function(x,y)
      return self.query.field:channel(x,y,name)
    end, x0,y0,self.size,self.step,0)
  end
  return output
end

return Chunks
