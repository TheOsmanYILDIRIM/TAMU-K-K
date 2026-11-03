local Strike=require("player.axe_strike")
local image,time,paused
function love.load()
  love.window.setMode(720,540,{resizable=true})
  love.window.setTitle("Metal Core - Axe Strike FX isolated demo")
  image=love.graphics.newImage("assets/axe_121227.png")
  image:setFilter("linear","linear")
  time=0;paused=false
end
function love.update(dt)
  if not paused then time=time+math.min(dt,.05) end
end
function love.keypressed(key)
  if key=="space" then paused=not paused elseif key=="r" then time=0 end
end
function love.draw()
  local g=love.graphics
  g.clear(.075,.10,.13)
  local core={x=225,y=270}
  local target={x=510,y=325}
  g.setColor(.17,.23,.25)
  for y=350,540,35 do g.line(0,y,720,y) end
  g.setColor(.32,.24,.18)
  g.rectangle("fill",474,327,73,95,10,10)
  g.setColor(.58,.41,.26)
  g.ellipse("fill",510,325,44,19)
  g.setColor(.24,.29,.32)
  g.circle("fill",core.x,core.y,55)
  g.setColor(.58,.43,.28)
  g.setLineWidth(5)
  g.circle("line",core.x,core.y,55)
  g.setColor(.12,.55,.68)
  g.circle("fill",core.x,core.y,20)
  local pose=Strike.draw(g,image,time,core,target,.18)
  g.setColor(1,1,1)
  g.print("Axe strike: "..pose.phase.." | SPACE pause | R restart",15,16)
end
