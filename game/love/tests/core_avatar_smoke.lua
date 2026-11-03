-- Standalone LÖVE visual acceptance view; deliberately NO source main.lua override.
-- CI copies this file into a TEMP game root to compare core states.
local CoreVisual=require("player.core_visual")
local shot=false
local saved=false
local fpsTotal,fpsSamples=0,0
local frames=0
local font
local viewport
local sample_palette={["test:focus"]={.2,.86,.94},["test:resolve"]={.98,.54,.20}}
function love.load()
  assert(love.window.setMode(720,1100,{resizable=false}))
  viewport={w=720,h=1100}
  font=love.graphics.newFont(20)
end
local function sample_player(y,state,immersion,time)
  return {x=0,y=y,time=time,state=state,radius=5,immersion=immersion}
end
local function make_camera(base_y)
  return {zoom=2.5,project=function(self,x,y,w,h)
    return w/2+x*w*.001,h/2+(y-base_y)*1.5
  end}
end
local function draw_sample(label,row,opts)
  local g=love.graphics
  local y=105+(row-1)*242
  g.setColor(.075,.13,.18,.88)
  g.rectangle("fill",35,y,650,215,18,18)
  g.setColor(.86,.94,.95,1)
  g.setFont(font)
  g.print(label,58,y+14)
  local p=sample_player(0,opts.moving and "walk" or "idle",opts.immersion or 0,frames/50)
  local camera=make_camera(0)
  -- Translate the projected foot into this example panel.
  camera.project=function(self,x,wy,w,h)
    return w/2+x*0.1,y+158+(wy*0.1)
  end
  CoreVisual.draw(g,camera,viewport.w,viewport.h,p,opts)
  if opts.immersion and opts.immersion>0 then
    g.setColor(.23,.54,.62,.35)
    g.rectangle("fill",70,y+156,580,37)
  end
end
function love.update(dt)
  if dt>0 and fpsSamples<120 and frames>20 then
    fpsTotal=fpsTotal+math.min(1000,1/dt)
    fpsSamples=fpsSamples+1
  end
end
function love.draw()
  local g=love.graphics
  g.clear(.03,.075,.10,1)
  g.setColor(.93,.94,.92)
  g.setFont(font)
  g.print("CORE + PLASMA / no human sprite or bone rig",28,22)
  draw_sample("01   BASIC CORE / NEUTRAL",1,{})
  draw_sample("02   TEST STAT MIX / 60:40",2,{
    stats={["test:focus"]=60,["test:resolve"]=40},
    palette=sample_palette,moving=true})
  draw_sample("03   PLASMA CONTROLLED PICKAXE",3,{tool="pickaxe",moving=true})
  draw_sample("04   WATER IMMERSION / 50%",4,{immersion=.5})
  frames=frames+1
  if frames==15 and not shot then
    shot=true
    love.graphics.captureScreenshot(function(data)
      data:encode("png","core-plasma-variants.png")
      saved=true
    end)
  end
  if frames>=240 and not saved then error("core screenshot callback did not finish") end
  if saved and frames>=160 then
    print("CORE_PLASMA_DESKTOP_SAMPLE_FPS="..string.format("%.2f",fpsTotal/math.max(fpsSamples,1)))
    print("LOVE_CORE_VISUAL_SMOKE_OK frames="..frames.." variants=4")
    io.stdout:flush()
    love.event.quit(0)
  end
end
