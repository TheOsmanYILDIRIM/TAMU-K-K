package.path="./?.lua;./?/init.lua;"..package.path
local Aura=require("player.core_aura")
local Visual=require("player.core_visual")
local function near(a,b) assert(math.abs(a-b)<1e-8,tostring(a).." not "..tostring(b)) end
local neutral=Aura.resolve()
assert(neutral.neutral and neutral.primary==nil)
local palette={alpha={.12,.8,.95},beta={.95,.36,.22},gamma={.45,.2,.9}}
local stats={alpha=51,beta=49,gamma=0}
local a=Aura.resolve(stats,palette,nil,{step=10,hysteresis=5})
assert(a.primary=="alpha" and a.secondary=="beta")
assert(a.buckets.alpha==50 and a.buckets.beta==40)
local b=Aura.resolve({alpha=49,beta=51},palette,a,{step=10,hysteresis=5})
assert(b.primary=="alpha","hysteresis must prevent jitter")
local c=Aura.resolve({alpha=44,beta=56},palette,b,{step=10,hysteresis=5})
assert(c.primary=="beta" and c.secondary=="alpha")
assert(Aura.resolve({alpha=0,beta=0},palette).neutral)
assert(Aura.resolve({alpha=1,beta=1},palette).primary=="alpha")
for _,bad in ipairs({
  function() Aura.resolve({alpha=-1},palette) end,
  function() Aura.resolve({alpha=1},{} ) end,
  function() Aura.resolve({alpha=1},palette,nil,{step=0}) end,
  function() Aura.resolve({alpha=math.huge},palette) end
}) do assert(not pcall(bad)) end
local p=Visual.tool_pose("axe",0)
local next=Visual.tool_pose("axe",.25)
assert(p.angle~=next.angle and p.x~=next.x)
assert(Visual.tool_pose("pickaxe",2).tool=="pickaxe")
assert(not pcall(function() Visual.tool_pose("sword",1) end))
-- Mock LOVE graphics: rendering must not mutate player/game state.
local operations={}
local g={}
for _,method in ipairs({"push","pop","setColor","ellipse","polygon","setLineWidth",
  "arc","circle","line","setScissor","translate","rotate","scale"}) do
  g[method]=function(...) operations[#operations+1]={method,...} end
end
local camera={zoom=1.7,project=function(self,x,y,w,h)
  return w/2+(x-y)*.7*self.zoom,h/2+(x+y)*.35*self.zoom end}
local player={x=-13.25,y=17.6,radius=5,time=1.25,state="walk",
  immersion=0.5,facing="NE"}
local copy={x=player.x,y=player.y,time=player.time,immersion=player.immersion}
local v=Visual.draw(g,camera,320,700,player,{tool="pickaxe",
  stats=stats,palette=palette})
assert(v.primary=="alpha" and #operations>15)
assert(copy.x==player.x and copy.y==player.y and copy.time==player.time
  and copy.immersion==player.immersion)
local sawScissor=false
for _,op in ipairs(operations) do
  if op[1]=="setScissor" then sawScissor=true end
end
assert(sawScissor,"immersed player must be clipped at waterline")
operations={}
player.immersion=0
Visual.draw(g,camera,720,1100,player)
for _,op in ipairs(operations) do
  assert(op[1]~="setScissor","dry core must not get water clip")
end
print("CORE_AVATAR_TEST_OK aura buckets hysteresis, tool arcs, water clip, stable foot")
