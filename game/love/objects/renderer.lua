-- Sorted 45-degree world-foot sprites; GPU-independent placement and mutable state.
local Depth=require("player.depth")
local R={}
local CoreVisual=require("player.core_visual")
local AxeStrike=require("player.axe_strike")
local axe_image=nil
local function player_sprite(g,camera,w,h,player,visual_context)
  return CoreVisual.draw(g,camera,w,h,player,visual_context)
end
local function object_sprite(g,camera,w,h,o,selected)
  local x,y=camera:project(o.x,o.y,w,h)
  local z=camera.zoom
  g.setColor(0,.09,.08,.33)
  g.ellipse("fill",x,y+3*z,o.radius*z*1.25,o.radius*z*.60)
  if o.kind=="tree" then
    g.setColor(.28,.19,.12)
    g.rectangle("fill",x-4*z,y-39*z,8*z,39*z)
    g.setColor(.14,.29,.19)
    g.polygon("fill",x-24*z,y-23*z,x,y-69*z,x+24*z,y-23*z)
    g.setColor(.19,.40,.26)
    g.polygon("fill",x-22*z,y-37*z,x,y-78*z,x+22*z,y-37*z)
    g.setColor(.31,.52,.32)
    g.polygon("fill",x-14*z,y-51*z,x,y-79*z,x+14*z,y-51*z)
  else
    g.setColor(.25,.31,.34)
    g.polygon("fill",x-17*z,y-4*z,x-13*z,y-21*z,x+3*z,y-32*z,x+17*z,y-17*z,x+14*z,y,x-7*z,y+3*z)
    g.setColor(.50,.54,.52)
    g.polygon("fill",x-13*z,y-21*z,x+3*z,y-32*z,x+17*z,y-17*z,x,y-13*z)
    g.setColor(.36,.41,.43)
    g.polygon("fill",x-17*z,y-4*z,x,y-13*z,x+14*z,y,x-7*z,y+3*z)
  end
  if selected then
    g.setColor(1,.82,.3,.9)
    g.setLineWidth(2)
    g.ellipse("line",x,y,o.radius*z*1.5,o.radius*z*.8)
  end
end
function R.collect(world,stream)
  local list,seen={},{}
  for _,chunk in ipairs(stream:visible()) do
    local items=world:objects_in({min_x=chunk.x,min_y=chunk.y,
      max_x=chunk.x+chunk.size,max_y=chunk.y+chunk.size})
    for _,o in ipairs(items) do
      if o.cx==chunk.cx and o.cy==chunk.cy and not seen[o.id] then
        list[#list+1]=o;seen[o.id]=true
      end
    end
  end
  return list
end
function R.draw(world,stream,camera,w,h,player,selected_id,harvesting)
  local all=R.collect(world,stream)
  local order={{id="!player",depth=Depth.key(player.x,player.y),player=true}}
  for _,o in ipairs(all) do order[#order+1]={id=o.id,depth=Depth.key(o.x,o.y),object=o} end
  table.sort(order,Depth.before)
  local g=love.graphics
  g.push("all")
  -- Harvest tools are autonomous plasma-controlled objects, not rigged limbs.
  -- Other game/domain systems remain untouched.
  local visual={}
  if harvesting and harvesting.active then
    local source=world:get(harvesting.active.object_id)
    if source and source.kind=="rock" then visual.tool="pickaxe" end
  end
  for _,entry in ipairs(order) do
    if entry.player then player_sprite(g,camera,w,h,player,visual)
    else object_sprite(g,camera,w,h,entry.object,entry.id==selected_id) end
  end
  -- Visual-only strike on actual tree harvest; never changes inventory or collision.
  if harvesting and harvesting.active then
    local source=world:get(harvesting.active.object_id)
    if source and source.kind=="tree" then
      if not axe_image then axe_image=love.graphics.newImage("assets/axe_121227.png") end
      local px,foot=camera:project(player.x,player.y,w,h)
      local tx,ty=camera:project(source.x,source.y,w,h)
      local elapsed=harvesting.active.elapsed
      -- One independent 0.88s strike cycle, synchronized to harvest elapsed.
      AxeStrike.draw(g,axe_image,elapsed,{x=px,y=foot-21*camera.zoom},
        {x=tx,y=ty-29*camera.zoom},math.min(.18*camera.zoom,.28))
    end
  end
  g.pop()
  return #all
end
function R.pick(world,stream,camera,w,h,sx,sy)
  local closest,best=nil,math.huge
  for _,o in ipairs(R.collect(world,stream)) do
    local x,y=camera:project(o.x,o.y,w,h)
    local height=o.kind=="tree" and 42 or 15
    local dx=(sx-x)/camera.zoom
    local dy=(sy-y)/camera.zoom+height
    local d=dx*dx+(dy*.7)*(dy*.7)
    local threshold=o.kind=="tree" and 32 or 22
    if d<threshold*threshold and d<best then closest,best=o,d end
  end
  return closest
end
return R
