-- Low-resolution shadow masks must draw under unchanged full-res sprite pages.
package.path='./?.lua;./?/init.lua;'..package.path
local quad_count,shadow_draws,normal_draws=0,0,0
love={graphics={newQuad=function(...) quad_count=quad_count+1;return {...} end}}
local Sprite=require('objects.terrain25d_sprites')
local original={id='oak-A',page='atlas_01.png',quad='source'}
local object={id='tree-1',x=10,y=20,kind='tree',radius=8}
local shadow_batch={
 clear=function() end,setColor=function() end,release=function() end,
 add=function(_,quad,x,y,angle,sx,sy,ox,oy)
   assert(ox==16 and oy==24 and sx==4.4 and sy==4.4)
   assert(type(quad)=='table')
 end
}
love.graphics.newImage=function(path)
 assert(path=='assets/terrain25d/static_shadow/shadows_12.png',path)
 return {setFilter=function() end}
end
love.graphics.newSpriteBatch=function(image)
 assert(type(image)=='table' and image.setFilter)
 return shadow_batch
end
local sprite_batch={
 setColor=function() end,
 add=function(_,quad,_,_,_,_,_,ox,oy)
   assert(quad=='source' and ox==64 and oy==124)
   normal_draws=normal_draws+1
 end
}
local sprite=setmetatable({
 static_manifest={version=3,width=256,height=256,pages={{hour=12}},
   objects={['oak-A']={u=0,v=0}}},
 provider={sun={hour=10.5,cast=1},object_reveal=function() return 1 end},
 limit=1024,pending=0,visible=0,culled=0,
 appearance=function() return original,100,200,1.1,'oak' end,
 batch_for=function(_,page)
   if page=='staticshadow:shadows_12.png' then return shadow_batch end
   assert(page=='atlas_01.png',page)
   return sprite_batch
 end
},Sprite)
local g={setColor=function() end,draw=function(batch)
 if batch==shadow_batch then shadow_draws=shadow_draws+1 end
end}
assert(sprite:draw_shadows(g,{},360,780,{object})==1)
assert(sprite.shadow_objects==1 and shadow_draws==1)
sprite:queue(g,{},360,780,object,false)
assert(normal_draws==1 and quad_count==1)
sprite.provider.sun.cast=0
assert(sprite:draw_shadows(g,{},360,780,{object})==0)
print('TAMU_LOWRES_SHADOW_RUNTIME_OK')
