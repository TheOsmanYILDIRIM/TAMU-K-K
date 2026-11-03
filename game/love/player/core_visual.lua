-- Rigless magical-technological core / controlled-plasma avatar.
-- All pixel geometry is temporary; no sprite, humanoid rig or mesh animation.
-- Inputs are ground-foot world coordinates, current movement/immersion,
-- optional aura (external stats) and a harvesting tool pose.
local Aura=require("player.core_aura")
local Plasma=require("player.core_plasma_sheet")
local V={}
-- User-uploaded Core is the production visual candidate, not historical 121222.
local CORE_PATH="assets/file_000000007cf082119c4dde3e346c2bcb.png"
local coreImage
local crystalEffect
local crystalAttempted=false
local function getCoreImage()
  if coreImage then return coreImage end
  assert(love and love.graphics and love.filesystem and love.filesystem.getInfo(CORE_PATH),
    "approved user Core PNG missing")
  coreImage=love.graphics.newImage(CORE_PATH)
  coreImage:setFilter("linear","linear")
  return coreImage
end
local TAU=math.pi*2
local function color(g,c,alpha)
  g.setColor(c[1],c[2],c[3],alpha or 1)
end
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function cap(n,low,high) return math.max(low,math.min(high,n)) end

-- Normalized tool animation driven by a time curve; no bones or UV projection.
function V.tool_pose(tool,seconds)
  assert(tool=="axe" or tool=="pickaxe","unknown autonomous tool")
  assert(finite(seconds),"invalid tool time")
  local phase=(seconds*.95)%1
  local rise=math.sin(phase*TAU)
  local angle=-.85+1.65*(.5+.5*rise)
  local radial=25+3*math.sin(phase*TAU)
  return {angle=angle,x=radial*math.cos(angle),y=radial*.42*math.sin(angle)-10,
    phase=phase,tool=tool}
end

local function tool_draw(g,tool,seconds,px,py,z,alpha)
  local p=V.tool_pose(tool,seconds)
  local bx,by=px+p.x*z,py+p.y*z
  g.push()
  g.translate(bx,by)
  g.rotate(p.angle)
  g.scale(z)
  g.setLineWidth(2.2)
  g.setColor(.50,.37,.24,alpha)
  g.line(0,-14,0,15)
  g.setColor(.73,.82,.84,alpha)
  if tool=="axe" then
    g.polygon("fill",-4,-15,6,-15,13,-10,10,-3,-5,-5)
    g.setColor(.38,.51,.57,alpha)
    g.polygon("line",-4,-15,6,-15,13,-10,10,-3,-5,-5)
  else
    g.polygon("fill",-15,-14,15,-14,10,-9,-10,-9)
    g.setColor(.38,.51,.57,alpha)
    g.polygon("line",-15,-14,15,-14,10,-9,-10,-9)
  end
  g.pop()
end

-- Preserves existing world-foot depth ordering. All visual state is derived;
-- no terrain seed or inventory state is mutated during draw.
function V.draw(g,camera,width,height,player,context)
  context=context or {}
  assert(g and camera and player and finite(player.x) and finite(player.y),
    "invalid core character render input")
  assert(finite(width) and finite(height) and width>0 and height>0,
    "invalid viewport")
  local immersion=cap(player.immersion or 0,0,1)
  assert(finite(player.immersion or 0),"invalid immersion")
  local z=camera.zoom
  assert(finite(z) and z>0,"invalid camera zoom")
  local px,foot_y=camera:project(player.x,player.y,width,height)
  local t=finite(player.time) and player.time or 0
  local moving=player.state=="walk"
  local bob=(moving and 1.3 or .55)*math.sin(t*TAU*1.75)
  local cy=foot_y-(21+bob)*z
  local aura= Aura.resolve(context.stats,context.palette,context.previous,context.options)

  g.push("all")
  -- Foot anchor remains at original projected world point (not visual bob).
  g.setColor(.015,.06,.10,.25*(1-.6*immersion))
  g.ellipse("fill",px,foot_y+2*z,13*z,5*z)

  local function draw_core(alpha)
    -- 32-frame independent back layer; Core crystal shader stays intact.
    Plasma.draw(g,"back",t,px,cy,z,alpha)
    -- Original user-drawn Core PNG; no fabricated crystal mask or shader.
    local img=getCoreImage()
    local iw,ih=img:getDimensions()
    local fit=25*z/math.max(iw,ih)
    g.setColor(1,1,1,alpha)
    if not crystalAttempted then
      crystalAttempted=true
      local maskPath="assets/core_crystal_mask_aligned.png"
      if love.filesystem.getInfo(maskPath) then
        local ok, result=pcall(function()
          local Crystal=require("player.core_crystal_shader")
          local mask=love.graphics.newImage(maskPath)
          assert(mask:getWidth()==iw and mask:getHeight()==ih,"crystal mask mismatch")
          mask:setFilter("linear","linear")
          return Crystal.new(img,mask)
        end)
        if ok then crystalEffect=result
        else print("Core crystal shader unavailable: "..tostring(result)) end
      else
        print("Core crystal mask missing; static Core fallback")
      end
    end
    if crystalEffect then
      require("player.core_crystal_shader").draw(crystalEffect,px,cy,0,fit,fit,iw/2,ih/2,t,alpha)
    else
      g.draw(img,px,cy,0,fit,fit,iw/2,ih/2)
    end
    -- Place front overlay after crystal/Core and before independent tools.
    Plasma.draw(g,"front",t,px,cy,z,alpha)
    if context.tool then
      tool_draw(g,context.tool,context.tool_seconds or t,px,cy,z,alpha)
    end
  end

  if immersion>0 then
    -- The water surface passes through the middle of the core in shallow water.
    local waterline=foot_y-(2+35*immersion)*z
    local cut=cap(math.floor(waterline+.5),0,height)
    g.setScissor(0,0,width,cut)
    draw_core(1)
    g.setScissor(0,cut,width,height-cut)
    draw_core(.16)
    g.setScissor()
    g.setColor(.40,.79,.86,.72)
    g.setLineWidth(math.max(1,z))
    g.ellipse("line",px,waterline,13*z,4*z)
  else
    draw_core(1)
  end
  g.pop()
  return aura
end
return V
