-- View-only procedural terrain. WorldQuery, collision, liquids and saves
-- remain authoritative; authored worldbuild intent is NOT rendered as physics.
local Iso = require("world.iso")
local Materials = require("world.materials")
local Terrain = {}
local water={.20,.43,.55}

local function vertices(flat,biome)
  local out={}
  for _,p in ipairs(flat) do
    local x,y=Iso.project(p[1],p[2])
    local color=biome=="water" and water or Materials.color(biome,p[1],p[2])
    out[#out+1]={x,y,0,0,color[1],color[2],color[3],1}
  end
  return out
end
local function mesh(flat,biome)
  if not flat or #flat==0 then return nil end
  return love.graphics.newMesh(vertices(flat,biome),"triangles","static")
end
local function quad(chunk)
  local x,y,s=chunk.x,chunk.y,chunk.size
  local a={x,y};local b={x+s,y};local c={x+s,y+s};local d={x,y+s}
  return {a,b,c,a,c,d}
end
function Terrain.invalidate(chunk)
  if chunk then chunk._terrain_meshes=nil end
end
function Terrain.draw(stream,camera,width,height)
  local lg=love.graphics
  lg.clear(.09,.16,.18,1)
  lg.push("all")
  lg.translate(width/2,height/2)
  lg.scale(camera.zoom)
  local cam_x,cam_y=Iso.project(camera.x,camera.y)
  lg.translate(-cam_x,-cam_y)
  for _,chunk in ipairs(stream:visible()) do
    if not chunk._terrain_meshes then
      local layers=chunk.layers
      chunk._terrain_meshes={
        meadow=mesh(quad(chunk),"meadow"),
        forest=mesh(layers.forest.vertices,"forest"),
        rocky=mesh(layers.rocky.vertices,"rocky"),
        water=mesh(layers.water.vertices,"water")
      }
    end
    lg.setColor(1,1,1,1)
    for _,name in ipairs({"meadow","forest","rocky","water"}) do
      local drawable=chunk._terrain_meshes[name]
      if drawable then lg.draw(drawable) end
    end
  end
  lg.pop()
end
return Terrain
