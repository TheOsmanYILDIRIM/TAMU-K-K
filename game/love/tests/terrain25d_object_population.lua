-- Regression: R2 ecology wraps a v1 query without duplicating generator_version.
-- The compact renderer must prepare candidates in update before draw.
package.path='./?.lua;./?/init.lua;'..package.path
local Renderer=require('objects.renderer')
local clock=0
love={timer={getTime=function() clock=clock+.00001;return clock end}}
local hit={id='r2:tree:1',cx=0,cy=0,x=40,y=60,kind='tree',radius=8}
local world={query={generator_version=1},calls=0}
function world:is_depleted(id) return false end
function world:objects_in(bounds,include)
 self.calls=self.calls+1
 assert(include==true)
 return {hit}
end
local chunk={cx=0,cy=0,x=0,y=0,size=256,_25d_meshes={}}
local stream={}
function stream:render_visible() return {chunk} end
function stream:visible() return {chunk} end
local camera={zoom=1}
local overlay={provider={compact=true,object_chunks={chunk}}}
assert(#Renderer.collect(world,stream,overlay)==0,
 'compact draw cannot synchronously query ecology')
for _=1,8 do Renderer.prepare_visible(world,stream,10,camera,720,1100) end
assert(world.calls==4,'R2 must prepare 4 spatial candidate quadrants')
local candidates=Renderer.collect(world,stream,overlay)
assert(#candidates==1 and candidates[1]==hit,'R2 authored object must render')
assert(world.calls==4,'draw must not perform cold queries')
-- Reusable render buffers must retain the identical visible entity references
-- and never force fresh ecology queries on a prepared chunk.
local scratch={objects={},seen={}}
for _=1,30 do
 local current=Renderer.collect(world,stream,overlay,scratch)
 assert(current==scratch.objects and #current==1 and current[1]==hit,
   'pooled visible objects changed or leaked between frames')
end
assert(world.calls==4,'pooled frames must not query ecology')
local independent=Renderer.collect(world,stream,overlay)
assert(independent~=scratch.objects and independent[1]==hit,
  'public nonpooled collect must retain independent result semantics')
print('R2_25D_OBJECT_POPULATION_OK')
print('TAMU_OBJECT_POOL_SEMANTICS_OK')

-- Shadow pass already validated reveal readiness: contact pass must not
-- repeat the potentially costly full-object readiness scan.
local Sprite=require('objects.terrain25d_sprites')
local reveal_scans=0
local sprite=setmetatable({
 provider={objects_fully_revealed=function()
   reveal_scans=reveal_scans+1;return true
 end},contact_batch={},contact_objects=0,
 contact_cache={zoom=1,w=720,h=1100,objects={{hit.id,hit.x,hit.y,hit.kind,hit.radius}}},
 contact_calls=0,contact_reuses=0},Sprite)
sprite:draw_contacts({},camera,720,1100,{hit},true)
assert(reveal_scans==0 and sprite.contact_reuses==1,
 'contact pass must reuse shadow reveal readiness without rescanning')
print('TAMU_SHADOW_CONTACT_READINESS_REUSE_OK')
-- Selection must not bypass the static cache or alter Y-depth ordering.
do
 local old_graphics=love.graphics
 love.graphics={push=function() end,pop=function() end}
 local seen={cached=0,selection=0}
 local override={provider={compact=true,object_chunks={chunk}}}
 function override:begin_frame() end
 function override:draw_shadows() end
 function override:prepare_cached_objects()
   seen.cached=seen.cached+1;return true
 end
 function override:draw_cached_objects() end
 function override:draw_selection(_,_,_,_,o)
   assert(o==hit,'selected object changed identity')
   seen.selection=seen.selection+1
 end
 for _=1,3 do
   local count=Renderer.draw(world,stream,camera,720,1100,
     {x=90,y=90},hit.id,nil,override,{objects=true,rig=false})
   assert(count==1,'selected object disappeared')
 end
 assert(seen.cached==3 and seen.selection==3,
   'selection bypassed cached drawing')
 love.graphics=old_graphics
end
print('TAMU_SELECTED_OBJECT_CACHE_OVERLAY_OK')
-- Moving the player through Y-depth must not rebuild immutable object meshes.
do
 local old_g=love.graphics
 local buffer={data={},range={}}
 function buffer:clear() self.data={} end
 function buffer:setColor() end
 function buffer:add(quad) self.data[#self.data+1]=quad end
 function buffer:setDrawRange(start,count) self.range={start,count} end
 function buffer:release() end
 love.graphics={newSpriteBatch=function() return buffer end}
 local provider={compact_ready=true,
   objects_fully_revealed=function() return true end,
   pin_page=function() end,page=function() return 'image' end}
 local cached=setmetatable({provider=provider,limit=8,
   object_cache_rebuilds=0,object_cache_reuses=0,
   batches=0,visible=0},Sprite)
 function cached:appearance(_,_,_,o)
   return {page='atlas_01.png',quad=o.id},o.x,o.y,1
 end
 local a,b={id='a',x=10,y=10,kind='tree',radius=8},
   {id='b',x=20,y=20,kind='tree',radius=8}
 local ea,eb,ep={object=a},{object=b},{player=true}
 local cam={x=0,y=0,zoom=1,
   project=function(_,x,y) return x,y end}
 assert(cached:prepare_cached_objects(cam,100,100,{ea,ep,eb}))
 assert(cached.object_cache_rebuilds==1 and cached.object_static_cache.split==1)
 assert(cached:prepare_cached_objects(cam,100,100,{ep,ea,eb}))
 assert(cached.object_cache_rebuilds==1 and cached.object_cache_reuses==1
   and cached.object_static_cache.split==0,'player movement rebuilt object cache')
 assert(cached:prepare_cached_objects(cam,100,100,{ea,eb,ep}))
 assert(cached.object_static_cache.split==2)
 local drawn={}
 local g={setColor=function() end,push=function() end,pop=function() end,
   translate=function() end,draw=function()
     drawn[#drawn+1]={buffer.range[1],buffer.range[2]}
   end}
 cached:draw_cached_objects(g,cam,100,100,1)
 cached:draw_cached_objects(g,cam,100,100,2)
 assert(#drawn==1 and drawn[1][1]==1 and drawn[1][2]==2,
   'static range changed depth order')
 love.graphics=old_g
end
print('TAMU_OBJECT_PLAYER_SLOT_RANGE_OK')

