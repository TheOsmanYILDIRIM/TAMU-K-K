-- Immutable authored R2 terrain cache. Generated offline from the exact
-- production LÖVE mesh vertices; no terrain, collision or save state changes.
-- Files are packaged into .love and addressed by stable world chunk coords.
local Json=require('save.json')
local M={}
local ROOT='assets/terrain25d/baked/'
local BAKING='25d-bake/'
local FORMAT='tamu-25d-mesh-v1'
local REV='r2-25d-20261029-geometry-v1'
local function name(c) return ('c_%d_%d.json.z'):format(c.cx,c.cy) end
local function stamp(runtime)
 return table.concat({REV,tostring(runtime.pilot.query.seed),
   tostring(#runtime.manifest.assets),tostring(#runtime.manifest.atlas_pages),
   tostring(runtime.terrain_uv_scale or 64)},':')
end
local function array_copy(t)
 local a=Json.array()
 for i,v in ipairs(t) do a[i]=v end
 return a
end
local function valid_order(t)
 if type(t)~='table' then return false end
 for _,v in ipairs(t) do if type(v)~='string' then return false end end
 return true
end
function M.source_path(chunk) return ROOT..name(chunk) end
function M.save(runtime,chunk)
 assert(love and love.graphics and love.data and love.filesystem,
   'real LOVE required for mesh baking')
 assert(chunk._25d_meshes and chunk._25d_bounds and chunk._25d_ground_order,
   'bake only fully built chunks')
 local items=Json.array()
 local keys={}
 for key in pairs(chunk._25d_meshes) do keys[#keys+1]=key end
 table.sort(keys)
 for _,key in ipairs(keys) do
  local mesh=chunk._25d_meshes[key]
  local rows=Json.array()
  for i=1,mesh:getVertexCount() do
   local v=Json.array({mesh:getVertex(i)})
   assert(#v==8,'baked vertex format mismatch')
   rows[#rows+1]=v
  end
  items[#items+1]={key=key,vertices=rows}
 end
 local overlay=chunk._25d_overlay_order
 local doc={format=FORMAT,stamp=stamp(runtime),
   cx=chunk.cx,cy=chunk.cy,size=chunk.size,
   bounds=array_copy(chunk._25d_bounds),
   ground_order=array_copy(chunk._25d_ground_order),
   overlay_order={path=array_copy(overlay.path),bank=array_copy(overlay.bank)},
   meshes=items}
 local plain=Json.encode(doc)
 assert(#plain<8*1024*1024,'one baked chunk exceeds JSON codec ceiling')
 local packed=love.data.compress('string','zlib',plain,6)
 assert(love.filesystem.createDirectory(BAKING),'cannot create bake directory')
 local ok,err=love.filesystem.write(BAKING..name(chunk),packed)
 assert(ok,'unable to write baked chunk: '..tostring(err))
 return #packed
end
-- Binary runtime cache: small JSON metadata, exact mesh byte layout.
-- LÖVE 11.x default mesh: float32 x/y/u/v + normalized RGBA8 (20 bytes).
local STRIDE=20
local function byte(v)
 return math.max(0,math.min(255,math.floor(v*255+.5)))
end
local function binary_name(c) return ('c_%d_%d'):format(c.cx,c.cy) end
function M.save_binary(runtime,chunk)
 assert(chunk._25d_meshes and chunk._25d_ground_order,'binary bake needs completed chunk')
 local keys={}
 for key in pairs(chunk._25d_meshes) do keys[#keys+1]=key end
 table.sort(keys)
 local payload,entries={},Json.array()
 for _,key in ipairs(keys) do
  local mesh=chunk._25d_meshes[key]
  local count=mesh:getVertexCount()
  local bytes={}
  for i=1,count do
   local x,y,u,v,r,g,b,a=mesh:getVertex(i)
   bytes[i]=love.data.pack('string','<ffffBBBB',x,y,u,v,
      byte(r),byte(g),byte(b),byte(a))
  end
  payload[#payload+1]=table.concat(bytes)
  entries[#entries+1]={key=key,count=count}
 end
 local meta={format='tamu-25d-binary-v1',stamp=stamp(runtime),
  cx=chunk.cx,cy=chunk.cy,size=chunk.size,
  bounds=array_copy(chunk._25d_bounds),
  ground_order=array_copy(chunk._25d_ground_order),
  overlay_order={path=array_copy(chunk._25d_overlay_order.path),
    bank=array_copy(chunk._25d_overlay_order.bank)},
  meshes=entries}
 assert(love.filesystem.createDirectory(BAKING))
 local name=binary_name(chunk)
 local compressed=love.data.compress('string','zlib',table.concat(payload),6)
 assert(love.filesystem.write(BAKING..name..'.verts.z',compressed))
 assert(love.filesystem.write(BAKING..name..'.meta.json',Json.encode(meta)))
 return #compressed
end
local function load_binary(runtime,chunk,prepared)
 local name=ROOT..binary_name(chunk)
 if not prepared and (not love.filesystem.getInfo(name..'.meta.json','file') or
    not love.filesystem.getInfo(name..'.verts.z','file')) then return false end
 local ok,doc,raw=pcall(function()
  if prepared then
    return Json.decode(prepared.meta),prepared.raw
  end
  local meta=Json.decode(assert(love.filesystem.read(name..'.meta.json')))
  local bytes=love.data.decompress('string','zlib',
    assert(love.filesystem.read(name..'.verts.z')))
  return meta,bytes
 end)
 if not ok then print('TAMU_25D_BINARY_REJECT '..tostring(doc));return false end
 if doc.format~='tamu-25d-binary-v1' or doc.stamp~=stamp(runtime)
    or doc.cx~=chunk.cx or doc.cy~=chunk.cy or doc.size~=chunk.size
    or type(doc.bounds)~='table' or #doc.bounds~=4
    or not valid_order(doc.ground_order)
    or type(doc.overlay_order)~='table'
    or not valid_order(doc.overlay_order.path)
    or not valid_order(doc.overlay_order.bank)
    or type(doc.meshes)~='table' or #doc.meshes==0 then return false end
 local total,lookup=0,{}
 for _,entry in ipairs(doc.meshes) do
  if type(entry.key)~='string' or lookup[entry.key]
     or type(entry.count)~='number' or entry.count<3
     or entry.count%3~=0 or entry.count%1~=0 then return false end
  lookup[entry.key]=true
  total=total+entry.count*STRIDE
 end
 if #raw~=total then return false end
 for _,page in ipairs(doc.ground_order) do
  if not lookup[page] or not runtime.page_metadata[page] then return false end
 end
 for _,layer in ipairs({'path','bank'}) do
  for _,page in ipairs(doc.overlay_order[layer]) do
   if not lookup['!'..layer..':'..page] or not runtime.page_metadata[page] then
    return false end
  end
 end
 local data=love.data.newByteData(raw)
 local gpu,position={},0
 local built,err=pcall(function()
  for _,entry in ipairs(doc.meshes) do
   local mesh=love.graphics.newMesh(entry.count,'triangles','static')
   local view=love.data.newDataView(data,position,entry.count*STRIDE)
   mesh:setVertices(view)
   position=position+entry.count*STRIDE
   gpu[entry.key]=mesh
   if entry.key~='!water' then
    local page=entry.key:match('^!%a+:(atlas_%d+%.png)$') or entry.key
    mesh:setTexture(runtime:page(page))
   end
  end
 end)
 if not built then
  for _,mesh in pairs(gpu) do if mesh.release then mesh:release() end end
  print('TAMU_25D_BINARY_GPU_REJECT '..tostring(err));return false
 end
 local pages={}
 for _,page in ipairs(doc.ground_order) do pages[page]=true end
 chunk._25d_meshes=gpu;chunk._meshes=gpu
 chunk._25d_ground_order=doc.ground_order
 chunk._25d_overlay_order=doc.overlay_order
 chunk._25d_ground_pages=pages;chunk._25d_bounds=doc.bounds
 chunk._25d_reveal_start=love.timer and love.timer.getTime() or 0
 runtime.baked_loaded=(runtime.baked_loaded or 0)+1
 print(string.format('TAMU_25D_BINARY_LOADED cx=%d cy=%d vertices=%d',
  chunk.cx,chunk.cy,total/STRIDE))
 return true
end
function M.load_ready(runtime,chunk,prepared)
 assert(prepared and type(prepared.meta)=='string'
   and type(prepared.raw)=='string','decoded binary payload required')
 return load_binary(runtime,chunk,prepared)
end
function M.load(runtime,chunk)
 if os.getenv('TAMU_25D_FORCE_JSON')~='1' and load_binary(runtime,chunk) then return true end
 local path=M.source_path(chunk)
 if not love.filesystem.getInfo(path,'file') then return false end
 local ok,doc=pcall(function()
  local packed=assert(love.filesystem.read(path))
  local plain=love.data.decompress('string','zlib',packed)
  assert(#plain<8*1024*1024,'oversized baked chunk')
  return Json.decode(plain)
 end)
 if not ok then
  print('TAMU_25D_BAKED_REJECT '..path..' '..tostring(doc))
  return false
 end
 if doc.format~=FORMAT or doc.stamp~=stamp(runtime)
     or doc.cx~=chunk.cx or doc.cy~=chunk.cy or doc.size~=chunk.size
     or type(doc.bounds)~='table' or #doc.bounds~=4
     or not valid_order(doc.ground_order)
     or type(doc.overlay_order)~='table'
     or not valid_order(doc.overlay_order.path)
     or not valid_order(doc.overlay_order.bank)
     or type(doc.meshes)~='table' or #doc.meshes==0 then
  print('TAMU_25D_BAKED_STALE '..path)
  return false
 end
 local meshes,keys={},{};
 for _,item in ipairs(doc.meshes) do
  if type(item.key)~='string' or type(item.vertices)~='table'
      or #item.vertices<3 or #item.vertices%3~=0
      or meshes[item.key] then
   print('TAMU_25D_BAKED_INVALID '..path);return false
  end
  keys[#keys+1]=item
  meshes[item.key]=true
 end
 -- Validate all referenced ground and overlay pages before allocating GPU.
 for _,page in ipairs(doc.ground_order) do
  if not meshes[page] or not runtime.page_metadata[page] then return false end
 end
 for _,layer in ipairs({'path','bank'}) do
  for _,page in ipairs(doc.overlay_order[layer]) do
   if not meshes['!'..layer..':'..page] or not runtime.page_metadata[page] then
    return false
   end
  end
 end
 local gpu={}
 local built,why=pcall(function()
  for _,item in ipairs(keys) do
   local mesh=love.graphics.newMesh(item.vertices,'triangles','static')
   if item.key~='!water' then
    local page=item.key:match('^!%a+:(atlas_%d+%.png)$') or item.key
    mesh:setTexture(runtime:page(page))
   end
   gpu[item.key]=mesh
  end
 end)
 if not built then
  for _,mesh in pairs(gpu) do if mesh.release then mesh:release() end end
  print('TAMU_25D_BAKED_GPU_REJECT '..path..' '..tostring(why))
  return false
 end
 local pages={}
 for _,page in ipairs(doc.ground_order) do pages[page]=true end
 chunk._25d_meshes=gpu;chunk._meshes=gpu
 chunk._25d_ground_order=doc.ground_order
 chunk._25d_overlay_order=doc.overlay_order
 chunk._25d_ground_pages=pages
 chunk._25d_bounds=doc.bounds
 chunk._25d_reveal_start=love.timer and love.timer.getTime() or 0
 runtime.baked_loaded=(runtime.baked_loaded or 0)+1
 return true
end
return M
