-- Offline composed shadow atlas: no runtime shadow projection.
package.path='./?.lua;./?/init.lua;'..package.path
local quads=0
love={graphics={newQuad=function(...) quads=quads+1;return {...} end}}
local Sprite=require('objects.terrain25d_sprites')
local source={id='oak-A',page='atlas_01.png',quad='old'}
local object={id='tree-1',x=10,y=20,kind='tree',radius=8}
local calls={}
local batch={
 setColor=function() end,
 add=function(_,quad,x,y,angle,scale,_,pivot_x,pivot_y)
   assert(quad~=source.quad and pivot_x==128 and pivot_y==192)
   calls[#calls+1]={scale=scale,x=x,y=y}
 end,
}
local sprite=setmetatable({
 static_manifest={version=2,width=1024,height=1024,
   objects={['oak-A']={u=0,v=0,width=256,height=256,pivot={128,192},page=0}}},
 provider={sun={hour=10.5},object_reveal=function()return 1 end},
 pending=0,limit=1024,visible=0,culled=0,
 appearance=function()return source,100,200,1.1,'oak' end,
 batch_for=function(_,page)
   assert(page=='staticshadow:objects_shadow_12_0.png',page)
   return batch
 end,
},Sprite)
assert(sprite:draw_shadows({}, {}, 360,780,{object})==0)
sprite:queue({}, {},360,780,object,false)
sprite:queue({}, {},360,780,object,false)
assert(#calls==2 and quads==1 and sprite.shadow_calls==0)
print('TAMU_STATIC_SHADOW_RUNTIME_OK')
