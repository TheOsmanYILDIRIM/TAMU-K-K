-- Exact pass-order and atlas batching regression, with no gameplay state.
package.path='./?.lua;./?/init.lua;'..package.path
local unpack=table.unpack or unpack
local clock=0
local created,released=0,0
love={timer={getTime=function() clock=clock+.00015;return clock end},
 graphics={newMesh=function(vertices,mode,usage)
  assert(mode=='triangles' and usage=='static')
  created=created+1
  local mesh={vertices=vertices}
  function mesh:setTexture(tex) assert(tex=='atlas') end
  function mesh:release() released=released+1 end
  function mesh:getVertexCount() return #self.vertices end
  function mesh:getVertex(i) return unpack(self.vertices[i]) end
  return mesh
 end}}
local Runtime=require('world.terrain25d_runtime')
local runtime=setmetatable({
 compact=true,creation_enabled=true,reveal_seconds=.85,
 page=function() return 'atlas' end,
 chunk_reveal=Runtime.chunk_reveal,
},Runtime)
local function triangle(x)
 local rows={{x,0,0,0,1,1,1,1},
             {x+1,0,1,0,1,1,1,1},
             {x,1,0,1,1,1,1,1}}
 return {
  vertices=rows,
  getVertexCount=function(self)return #self.vertices end,
  getVertex=function(self,i)return unpack(self.vertices[i]) end
 }
end
local function chunk(x)
 local mesh=triangle(x)
 return {cx=x,cy=0,x=x*256,y=0,size=256,
  _25d_reveal_start=0,
  _25d_meshes={['atlas_00.png']=mesh},
  _25d_ground_order={'atlas_00.png'},
  _25d_overlay_order={path={},bank={}}}
end
local c1,c2=chunk(0),chunk(1)
local view={c1,c2}
assert(runtime:update_ground_batch(view,.2)==nil,'animated reveal must remain independent')
local batched
for _=1,40 do
 batched=runtime:update_ground_batch(view,2)
 if batched then break end
end
assert(batched and #batched.ground==1 and created==1,
 'two consecutive same-page meshes must combine into one draw')
assert(#batched.ground[1].mesh.vertices==6,'all vertices preserved')
assert(batched.ground[1].mesh.vertices[1][1]==0 and
 batched.ground[1].mesh.vertices[4][1]==1,
 'original chunk draw order must remain unchanged')
assert(runtime:update_ground_batch(view,2)==batched,'stable view must reuse batch')
runtime:update_ground_batch({c2,c1},2)
assert(released==1,'camera reorder must release previous merged GPU resource')
local rebuilt
for _=1,40 do
 rebuilt=runtime:update_ground_batch({c2,c1},2)
 if rebuilt then break end
end
assert(rebuilt and rebuilt.ground[1].mesh.vertices[1][1]==1,
 'rebuild must retain new draw order')
runtime:invalidate_ground_batch()
assert(released==2,'final cache invalidation must release aggregate')
print('TAMU_TERRAIN_BATCH_ORDER_OK created='..created..' released='..released)
