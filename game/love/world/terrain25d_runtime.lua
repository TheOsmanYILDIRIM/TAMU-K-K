-- Opt-in, render-only R2 terrain. Stream owns mesh release via chunk._meshes.
local Geo=require("world.terrain25d_geometry")
local Iso=require("world.iso")
local Json=require("save.json")
local Runtime={}; Runtime.__index=Runtime
-- Select broad dominant material regions; avoid alternating 128-unit
-- two-variant parity checkerboards seen in real LÖVE screenshots.
local function stable(x,y)
  local ix,iy=math.floor(x/384),math.floor(y/384)
  local h=(ix*73856093+iy*19349663+ix*iy*83492791)%2147483647
  return math.floor(h/8)
end
function Runtime.new(pilot)
 assert(pilot and pilot.query and pilot.topography and pilot.routes and pilot.render_options,
   "authored R2 pilot required")
 local m=Json.decode(assert(love.filesystem.read("assets/terrain25d/manifest.json")))
 assert(m.version==1 and #m.assets>=20 and m.atlas_pages[1],"25D manifest invalid")
 local fam={}
 for _,a in ipairs(m.assets) do
   if a.atlas_page=="atlas_00.png" and a.uv_rect then
     local f=fam[a.family] or {};f[#f+1]=a;fam[a.family]=f
   end
 end
 for _,kind in ipairs({"grass","forest","dirt","rock","wetland","oak","conifer","boulder"}) do
   assert(fam[kind] and #fam[kind]>0,"atlas material absent: "..kind)
   table.sort(fam[kind],function(a,b) return a.id<b.id end)
 end
 local image=love.graphics.newImage("assets/terrain25d/atlas_00.png")
 local w,h=image:getDimensions()
 assert(w==m.atlas_pages[1].width and h==m.atlas_pages[1].height,"atlas dimensions mismatch")
 image:setFilter("nearest","nearest");image:setWrap("clamp","clamp")
 return setmetatable({pilot=pilot,manifest=m,atlas=image,families=fam,
   built=0,visible=0,draw_calls=0,uploads_per_frame=0,build_budget=1,step=32},Runtime)
end
function Runtime:family(x,y)
 local q=self.pilot.query
 local s=q:sample(x,y)
 local wet,dist=q:water_mask(x,y)
 if wet or (type(dist)=="number" and dist>-18) then return "wetland" end
 if s.feature=="path" then return "dirt" end
 if s.biome=="forest" then return "forest" end
 if s.biome=="rocky" then return "rock" end
 return "grass"
end
function Runtime:prepare(chunk)
 assert(not chunk._25d_meshes and not chunk._meshes,"chunk already owns GPU meshes")
 local pilot=self.pilot
 local scale=pilot.render_options.height_scale or .35
 local geo=Geo.build_chunk(pilot.query,pilot.topography,{size=chunk.size,
   height_scale=scale,uv_scale=128},{x=chunk.x,y=chunk.y},self.step)
 local n=chunk.size/self.step
 local groups={}
 for iy=0,n-1 do for ix=0,n-1 do
   local x,y=chunk.x+(ix+.5)*self.step,chunk.y+(iy+.5)*self.step
   local list=self.families[self:family(x,y)]
   local a=list[1+stable(x,y)%#list]
   local group=groups[a.id]
   if not group then group={asset=a,indices={}};groups[a.id]=group end
   local i=iy*(n+1)+ix+1
   local out=group.indices
   for _,v in ipairs({i,i+1,i+n+2,i,i+n+2,i+n+1}) do out[#out+1]=v end
 end end
 local meshes,order={},{}
 for id,group in pairs(groups) do
   local vertices=Geo.love_vertices({format="terrain25d-v1",
     vertices=geo.vertices,indices=group.indices},group.asset.uv_rect)
   local gpu=love.graphics.newMesh(vertices,"triangles","static")
   gpu:setTexture(self.atlas)
   meshes[id]=gpu;order[#order+1]=id
 end
 table.sort(order)
 local water=chunk.layers and chunk.layers.water
 if water and water.vertices and #water.vertices>0 then
   local vertices={}
   for _,p in ipairs(water.vertices) do
     local sx,sy=Iso.project(p[1],p[2],pilot.topography:height(p[1],p[2])*scale)
     vertices[#vertices+1]={sx,sy,0,0,.18,.52,.63,.88}
   end
   meshes["!water"]=love.graphics.newMesh(vertices,"triangles","static")
 end
 chunk._25d_meshes=meshes;chunk._25d_ground_order=order
 chunk._meshes=meshes -- Stream:update already releases this map upon eviction.
 self.built=self.built+1
end
function Runtime:draw(stream,camera,w,h)
 assert(stream and stream.visible and camera and camera.zoom>0)
 local chunks=stream:visible()
 local clock=love.timer and love.timer.getTime
 local deadline=clock and clock()+.003
 local uploads=0
 for _,c in ipairs(chunks) do
   if not c._25d_meshes and uploads<self.build_budget
       and (not deadline or clock()<deadline) then
     self:prepare(c);uploads=uploads+1
   end
 end
 self.uploads_per_frame=uploads
 local g=love.graphics
 g.clear(.075,.115,.128,1);g.push("all")
 g.translate(w/2,h/2);g.scale(camera.zoom)
 local x,y=Iso.project(camera.x,camera.y)
 g.translate(-x,-y);g.setColor(1,1,1,1)
 local calls,visible=0,0
 for _,c in ipairs(chunks) do
   if c._25d_meshes then
     visible=visible+1
     for _,id in ipairs(c._25d_ground_order) do
       g.draw(c._25d_meshes[id]);calls=calls+1
     end
   end
 end
 for _,c in ipairs(chunks) do
   if c._25d_meshes and c._25d_meshes["!water"] then
     g.draw(c._25d_meshes["!water"]);calls=calls+1
   end
 end
 g.pop()
 self.visible,self.draw_calls=visible,calls
 return visible
end
return Runtime
