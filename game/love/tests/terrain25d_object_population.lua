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
print('R2_25D_OBJECT_POPULATION_OK')
