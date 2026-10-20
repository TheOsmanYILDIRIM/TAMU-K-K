-- R2 D: optional shaderless organic terrain; logic and saves remain authoritative.
local Iso=require("world.iso")
local Materials=require("world.materials")
local Marching=require("world.marching")
local Terrain={}
local water={.19,.37,.46}
local profiles={low={grid=64,fleck=64},standard={grid=32,fleck=32},high={grid=16,fleck=16}}
local function finite(x) return type(x)=="number" and x==x and x>-math.huge and x<math.huge end
local function graphics() assert(love and love.graphics,"LOVE graphics required");return love.graphics end
local function projection(x,y,topo,height_scale)
 local h=topo and topo:height(x,y) or 0
 assert(finite(h),"invalid topography height")
 return Iso.project(x,y,h*height_scale)
end
local function light(topo,x,y)
 if not topo then return 1 end
 local s=topo:sample(x,y)
 assert(type(s)=="table" and finite(s.gradient_x) and finite(s.gradient_y),
   "invalid B topography gradient")
 return Materials.light(s.gradient_x,s.gradient_y)
end
local function vertex(out,x,y,biome,opts,alpha)
 local sx,sy=projection(x,y,opts.topography,opts.height_scale)
 local color=biome=="water" and water or Materials.color(biome,x,y)
 local shade=light(opts.topography,x,y)
 out[#out+1]={sx,sy,0,0,math.min(1,color[1]*shade),
  math.min(1,color[2]*shade),math.min(1,color[3]*shade),alpha or 1}
end
local function mesh(flat,biome,query,opts)
 if not flat or #flat==0 then return nil end
 local out={}
 for _,p in ipairs(flat) do
  local alpha=1
  if biome~="meadow" then
   local signed=query.field:channel(p[1],p[2],biome)
   if biome=="water" then
    -- C's authored water uses signed WORLD UNITS; Generator v1 water
    -- continues using its original dimensionless scalar and threshold.
    local band=.035
    if opts.routes and opts.routes.features then
     local authored=opts.routes.features:signed(p[1],p[2],"water")
     if authored>=0 then band=3.2 end
    end
    alpha=Materials.edge_alpha(signed,band)
   else
    alpha=Materials.edge_alpha(signed,.055)
    if opts.boundaries then
     alpha=alpha*Materials.authored_feather(opts.boundaries,p[1],p[2],24)
    end
   end
  end
  vertex(out,p[1],p[2],biome,opts,alpha)
 end
 return graphics().newMesh(out,"triangles","static")
end
local function meadow(chunk,query,opts)
 local out={}
 local step,size=opts.grid,chunk.size
 assert(size%step==0,"profile step must divide chunk size")
 -- The fallback is the bottom layer of EVERY terrain material. Previously
 -- it stayed bright meadow under authored forest/rocky, so transparent
 -- feather edges revealed luminous polygon outlines. Tint this base
 -- using the existing authoritative biome query at absolute grid nodes.
 -- Without authored regions Generator v1 remains bit-for-bit unchanged.
 local memo={}
 local function base_biome(x,y)
  if not opts.boundaries then return "meadow" end
  local key=x..":"..y
  if not memo[key] then
   local sample=query:sample(x,y)
   assert(sample and (sample.biome=="meadow" or
          sample.biome=="forest" or sample.biome=="rocky"),
          "authored base material needs a valid biome")
   memo[key]=sample.biome
  end
  return memo[key]
 end
 for y=chunk.y,chunk.y+size-step,step do
  for x=chunk.x,chunk.x+size-step,step do
   for _,p in ipairs({{x,y},{x+step,y},{x+step,y+step},
                     {x,y},{x+step,y+step},{x,y+step}}) do
    vertex(out,p[1],p[2],base_biome(p[1],p[2]),opts)
   end
  end
 end
 return graphics().newMesh(out,"triangles","static")
end
local function detail_type(query,opts,x,y)
 local sample=query:sample(x,y)
 if type(sample)~="table" then return nil end
 local biome=sample.biome
 if biome~="meadow" and biome~="forest" and biome~="rocky" then return nil end
 if query.field:channel(x,y,"water")>-.025 then return nil end
 if biome=="forest" and query.field:channel(x,y,"forest")<.04 then return nil end
 if biome=="rocky" and query.field:channel(x,y,"rocky")<.04 then return nil end
 local path=false
 if opts.routes then
  assert(type(opts.routes.surface_at)=="function","validated C facade required")
  local s=opts.routes:surface_at(x,y)
  if s and s.wet then return nil end
  path=s and (s.path_feature_id~=nil or s.crossing_kind=="bridge") or false
 else
  path=sample.feature=="path"
 end
 return path and "path" or biome
end
local fleck_color={
 meadow={.60,.73,.45},forest={.34,.49,.36},
 rocky={.59,.62,.58},path={.59,.48,.36}}
local function detail_mesh(chunk,query,opts)
 local out={}
 local step=opts.fleck
 assert(chunk.size%step==0)
 for iy=0,chunk.size/step-1 do for ix=0,chunk.size/step-1 do
  local gx,gy=chunk.x+ix*step,chunk.y+iy*step
  local x=gx+step*(.20+.60*Materials.fleck(gx,gy,1))
  local y=gy+step*(.20+.60*Materials.fleck(gx,gy,2))
  local kind=detail_type(query,opts,x,y)
  if kind then
   local tone=fleck_color[kind]
   local radius=1.6+Materials.fleck(gx,gy,3)*(kind=="rocky" and 4 or 6)
   local angle=6.283185307179586*Materials.fleck(gx,gy,4)
   local dx,dy=math.cos(angle)*radius,math.sin(angle)*radius
   for _,p in ipairs({{x-dx,y-dy},{x+dx,y+dy},{x-dy*.24,y+dx*.24}}) do
    local sx,sy=projection(p[1],p[2],opts.topography,opts.height_scale)
    local shade=light(opts.topography,p[1],p[2])
    out[#out+1]={sx,sy,0,0,tone[1]*shade,tone[2]*shade,tone[3]*shade,
       kind=="path" and .49 or .22}
   end
  end
 end end
 return #out>0 and graphics().newMesh(out,"triangles","static") or nil
end
function Terrain.invalidate(chunk)
 if not chunk then return end
 -- Stream evicts _meshes; keep the alias in sync so camera panning
 -- releases the very same LÖVE GPU resources as explicit invalidation.
 if chunk._meshes==chunk._terrain_meshes then chunk._meshes=nil end
 if chunk._terrain_meshes then
  for _,v in pairs(chunk._terrain_meshes) do
   if v and v.release then v:release() end
  end
 end
 chunk._terrain_meshes=nil;chunk._terrain_key=nil
end
function Terrain.profile(quality)
 local p=assert(profiles[quality or "standard"],"unknown R2 quality profile")
 return {grid=p.grid,fleck=p.fleck}
end

-- Only chunks intersecting a validated authored river need finer contour
-- sampling. Always sample the SAME world-space field used by collisions:
-- this changes raster fidelity, never the water mask or valley physics.
local function river_near_chunk(chunk,routes)
 local features=routes and routes.features and routes.features.features
 if not features then return false end
 for _,feature in ipairs(features) do
  if feature.kind=="water" then
   local margin=feature.width/2+4
   for i=1,#feature.points-1 do
    local a,b=feature.points[i],feature.points[i+1]
    local minx,maxx=math.min(a[1],b[1])-margin,math.max(a[1],b[1])+margin
    local miny,maxy=math.min(a[2],b[2])-margin,math.max(a[2],b[2])+margin
    if maxx>=chunk.x and minx<=chunk.x+chunk.size
      and maxy>=chunk.y and miny<=chunk.y+chunk.size then
     return true
    end
   end
  end
 end
 return false
end
local function water_vertices(chunk,query,opts)
 if not river_near_chunk(chunk,opts.routes) then
  return chunk.layers.water and chunk.layers.water.vertices
 end
 -- R2 H uses 8-unit gameplay/stream samples. Refine only the rendered
 -- water contour to 4-unit cells, with absolute-origin Marching Squares.
 assert(chunk.size%4==0,"fine river step must divide chunk size")
 return Marching.build(function(x,y)
  return query.field:channel(x,y,"water")
 end,chunk.x,chunk.y,chunk.size,4,0).vertices
end
local boundaries_cache=setmetatable({},{__mode="k"})
local function authored_boundaries(query,routes)
 local authored=routes and routes.base and routes.base.authored
 if not authored then
  authored=query.authored
  if authored and authored.authored then authored=authored.authored end
 end
 if not authored or not authored.regions then return nil end
 local edges=boundaries_cache[authored]
 if not edges then
  edges=Materials.authored_edges(authored.regions)
  boundaries_cache[authored]=edges
 end
 return edges
end
local function rebuild(chunk,query,opts,key)
 local l=assert(chunk.layers,"chunk layers required")
 local meshes={
  meadow=meadow(chunk,query,opts),
  forest=mesh(l.forest and l.forest.vertices,"forest",query,opts),
  rocky=mesh(l.rocky and l.rocky.vertices,"rocky",query,opts),
  water=mesh(water_vertices(chunk,query,opts),"water",query,opts),
  detail=detail_mesh(chunk,query,opts)}
 assert(not chunk._meshes,"another renderer owns chunk GPU meshes")
 chunk._terrain_meshes=meshes
 chunk._meshes=meshes -- existing Stream eviction releases this table
 chunk._terrain_key=key
 return meshes
end
function Terrain.draw(stream,camera,width,height,options)
 local lg=graphics()
 assert(type(stream)=="table" and type(stream.visible)=="function"
        and stream.query and stream.query.field and stream.query.sample,
        "WorldQuery stream required")
 options=options or {}
 local quality=options.quality or "standard"
 local profile=Terrain.profile(quality)
 local scale=options.height_scale or .35
 assert(finite(scale) and scale>=0 and scale<=4,"invalid height scale")
 if options.topography then
  assert(type(options.topography.height)=="function" and
     type(options.topography.sample)=="function","B API required")
 end
 local opts={grid=profile.grid,fleck=profile.fleck,
  topography=options.topography,height_scale=scale,routes=options.routes,
  boundaries=authored_boundaries(stream.query,options.routes)}
 local key=quality..":"..tostring(scale)..":"..tostring(options.topography)
          ..":"..tostring(options.routes)..":"..tostring(stream.query)
 lg.clear(.065,.105,.118,1)
 lg.push("all")
 lg.translate(width/2,height/2)
 lg.scale(camera.zoom)
 local sx,sy=Iso.project(camera.x,camera.y)
 lg.translate(-sx,-sy)
 local cached={}
 for _,chunk in ipairs(stream:visible()) do
  if chunk._terrain_key~=key then Terrain.invalidate(chunk) end
  cached[#cached+1]=chunk._terrain_meshes or rebuild(chunk,stream.query,opts,key)
 end
 -- Render whole visible world in material passes. Painting a meadow chunk
 -- after a neighbour's forest/water layer creates hard rectangular seams.
 lg.setColor(1,1,1,1)
 for _,name in ipairs({"meadow","forest","rocky","water","detail"}) do
  for _,drawables in ipairs(cached) do
   if drawables[name] then lg.draw(drawables[name]) end
  end
 end
 lg.pop()
 if options.atmosphere~=false then
  -- Smooth screen-space vertex alpha, never separate hard-edged rectangles.
  if not Terrain._fog or Terrain._fog_width~=width or Terrain._fog_height~=height then
   if Terrain._fog then Terrain._fog:release() end
   local function p(x,y,alpha) return {x,y,0,0,.07,.13,.14,alpha} end
   local horizon=height*.45
   Terrain._fog=lg.newMesh({
    p(0,0,.17),p(width,0,.17),p(width,horizon,0),
    p(0,0,.17),p(width,horizon,0),p(0,horizon,0)
   },"triangles","static")
   Terrain._fog_width,Terrain._fog_height=width,height
  end
  lg.push("all")
  lg.setColor(1,1,1,1)
  lg.draw(Terrain._fog)
  lg.pop()
 end
end
return Terrain
