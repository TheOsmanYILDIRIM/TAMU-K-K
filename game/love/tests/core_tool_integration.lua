package.path="./?.lua;./?/init.lua;"..package.path
local A=require("player.axe_strike")
local function near(a,b) assert(math.abs(a-b)<1e-6,a.." ~= "..b) end
local core,target={x=160,y=340},{x=192,y=320}
for _,t in ipairs({0,.1,.28,.4,.53,.55,.6,.72,1}) do
  local pose=A.pose(t,core,target,.12)
  for _,k in ipairs({"x","y","edgeX","edgeY","angle"}) do
    assert(pose[k]==pose[k] and math.abs(pose[k])<math.huge)
  end
end
local contact=A.pose(.55,core,target,.12)
assert(contact.phase=="impact")
near(contact.edgeX,target.x);near(contact.edgeY,target.y)
assert(A.pose(.3,core,target,.12).phase=="strike")
assert(A.pose(.8,core,target,.12).phase=="recover")
-- Isolated renderer-spy asserts no tool selection can mutate harvesting state.
local tools,axes,images={},0,0
package.loaded["player.rigby_visual"]={
  draw=function(g,camera,w,h,player,ctx) tools[#tools+1]=ctx.tool or "none" end
}
package.loaded["player.axe_strike"]={
  draw=function(...) axes=axes+1 end
}
local g={}
for _,method in ipairs({"push","pop","setColor","ellipse","rectangle","polygon","setLineWidth"}) do
  g[method]=function(...) end
end
g.newImage=function(path) assert(path=="assets/axe_121227.png");images=images+1;return {} end
love={graphics=g}
-- This spy checks the production Rigby tool intent without loading rig assets.
-- Rig pose/socket behavior remains covered by the dedicated Rigby tests.
local R=require("objects.renderer")
local fixtures={
  tree={id="tree",kind="tree",def_id="tree",x=2,y=2,radius=10,cx=0,cy=0},
  rock={id="rock",kind="rock",def_id="rock",x=20,y=20,radius=10,cx=0,cy=0},
}
local world={
  objects_in=function(self,bounds) return {fixtures.tree,fixtures.rock} end,
  get=function(self,id) return fixtures[id] end
}
local stream={visible=function(self) return {{x=0,y=0,size=256,cx=0,cy=0}} end}
local camera={zoom=1.7,project=function(self,x,y,w,h) return w/2+x,h/2+y end}
local player={x=10,y=10}
local function draw(active,expected,axeCount)
  local snapshot=active and {object_id=active.object_id,elapsed=active.elapsed} or nil
  local count=R.draw(world,stream,camera,320,700,player,nil,
    active and {active=active} or nil)
  assert(count==2)
  assert(tools[#tools]==expected,tools[#tools].." not "..expected)
  assert(axes==axeCount)
  if snapshot then
    assert(active.object_id==snapshot.object_id and active.elapsed==snapshot.elapsed)
  end
end
draw(nil,"none",0)
draw({object_id="tree",elapsed=.45},"axe",0)
draw({object_id="tree",elapsed=.49},"axe",0)
draw({object_id="rock",elapsed=.49},"pickaxe",0)
local stance=A.pose(0,core,target,.08)
assert(math.abs(stance.x-core.x)<=35,"tool idle handle reach too large")
assert(math.abs(stance.y-core.y)<=25,"tool idle handle height too large")
assert(images==0,"Rigby renderer must not load legacy axe PNG")
print("RIGBY_TOOL_INTEGRATION_OK tree axe, rock pickaxe, no legacy PNG, no harvest state edits")
