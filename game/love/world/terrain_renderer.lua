-- Draws procedural terrain WITHOUT modifying game/love/main.lua or shared core.
-- Cached LOVE meshes use isometric projected world vertices; pan/zoom is a transform.
local Biomes = require("world.biomes")
local Iso = require("world.iso")
local Terrain = {}

local colors = {
  forest=Biomes.resolve("forest").color,
  rocky=Biomes.resolve("rocky").color,
  water={0.20,0.43,0.55}
}

local function make_mesh(flat, color)
  if #flat==0 then return nil end
  local vertices={}
  for _,world_point in ipairs(flat) do
    local x,y=Iso.project(world_point[1],world_point[2])
    vertices[#vertices+1]={x,y,0,0,color[1],color[2],color[3],1}
  end
  return love.graphics.newMesh(vertices,"triangles","static")
end

local function base_quad(chunk)
  local x,y,s=chunk.x,chunk.y,chunk.size
  local a,b=Iso.project(x,y)
  local c,d=Iso.project(x+s,y)
  local e,f=Iso.project(x+s,y+s)
  local g,h=Iso.project(x,y+s)
  return {a,b,c,d,e,f,g,h}
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
    if not chunk._meshes then
      chunk._meshes={}
      for _,name in ipairs({"forest","rocky","water"}) do
        chunk._meshes[name]=make_mesh(chunk.layers[name].vertices,colors[name])
      end
    end
    lg.setColor(Biomes.resolve("meadow").color)
    lg.polygon("fill",base_quad(chunk))
    lg.setColor(1,1,1,1)
    for _,name in ipairs({"forest","rocky","water"}) do
      local mesh=chunk._meshes[name]
      if mesh then lg.draw(mesh) end
    end
  end
  lg.pop()
end

return Terrain
