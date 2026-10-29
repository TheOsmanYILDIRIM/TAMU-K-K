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
function M.load(runtime,chunk)
 local path=M.source_path(chunk)
 if not love.filesystem.getInfo(path,'file') then return false end
 local trace=os.getenv('TAMU_BOOT_TRACE')=='1'
 local clock=love.timer.getTime
 local stats={}
 local function timed(name,fn)
  local t=clock();local result=fn();stats[name]=(stats[name] or 0)+(clock()-t)*1000;return result
 end
 local ok,doc=pcall(function()
  local packed=timed('read',function() return assert(love.filesystem.read(path)) end)
  local plain=timed('zlib',function() return love.data.decompress('string','zlib',packed) end)
  assert(#plain<8*1024*1024,'oversized baked chunk')
  return timed('json',function() return Json.decode(plain) end)
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
   local mesh=timed('newMesh',function() return love.graphics.newMesh(item.vertices,'triangles','static') end)
   if item.key~='!water' then
    local page=item.key:match('^!%a+:(atlas_%d+%.png)$') or item.key
    local texture=timed('page',function() return runtime:page(page) end)
    timed('setTexture',function() mesh:setTexture(texture) end)
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
 if trace then
  print(string.format('TAMU_BAKED_PHASE cx=%d cy=%d read=%.3f zlib=%.3f json=%.3f newMesh=%.3f page=%.3f setTexture=%.3f meshes=%d',chunk.cx,chunk.cy,stats.read or 0,stats.zlib or 0,stats.json or 0,stats.newMesh or 0,stats.page or 0,stats.setTexture or 0,#keys))
  io.stdout:flush()
 end
 return true
end
return M
