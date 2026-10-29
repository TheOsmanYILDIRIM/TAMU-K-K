package.path='./?.lua;./?/init.lua;'..package.path
local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local draws,updates,textures=0,0,0
local g={newImage=function(path) assert(read(path):sub(1,4)=='\137PNG');textures=textures+1;return {setFilter=function()end} end,
 newMesh=function(vertices,mode,usage)
  assert(mode=='triangles' and usage=='stream' and #vertices>0)
  return {setVertexMap=function(_,t)assert(#t%3==0)end,setTexture=function()end,
   setVertices=function(_,t)assert(#t>0);updates=updates+1 end}
 end,
 draw=function()draws=draws+1 end}
for _,f in ipairs({'push','pop','setColor','setScissor','setLineWidth','ellipse','translate','scale','setMeshCullMode'}) do g[f]=function()end end
love={filesystem={read=read,getInfo=function(p)local f=io.open(p,'rb');if f then f:close();return {} end end},graphics=g}
local V=require('player.rigby_visual')
local player={x=0,y=0,time=0,state='idle',facing='SE',immersion=0}
local camera={zoom=1,project=function()return 200,300 end}
local hands={SE='hand_l',SW='hand_r',NW='back_hand_l',NE='back_hand_r'}
for dir,hand in pairs(hands) do
 player.facing=dir;player.time=player.time+.1
 V.draw(g,camera,400,600,player,{action='punch',animation_time=.37})
 assert(V.right_hand(player).bone==hand)
end
assert(V.direction('E','NE')=='NE' and V.direction('E','SE')=='SE')
assert(V.action('walk','axe')=='chop' and V.action('walk','pickaxe')=='mine')
assert(V.action('run')=='run')
player.state='walk';player.time=player.time+.3
V.draw(g,camera,400,600,player,{})
local initial=V.instance(player).time
player.time=player.time+.017;V.draw(g,camera,400,600,player,{})
assert(V.instance(player).time>initial)
player.immersion=.5;player.time=player.time+.017;V.draw(g,camera,400,600,player,{tool='axe',tool_seconds=.5})
assert(V.instance(player).action=='chop')
V.play(player,'slash',false);player.time=player.time+.1
V.draw(g,camera,400,600,player,{});assert(V.instance(player).action=='slash')
player.time=player.time+2;V.draw(g,camera,400,600,player,{});assert(V.instance(player).action=='walk')
assert(textures==24,'expected 24 unique referenced original part textures')
print('RIGBY_VISUAL_MOCK_OK textures='..textures..' mesh_updates='..updates..' draws='..draws)
