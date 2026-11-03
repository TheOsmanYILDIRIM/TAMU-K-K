-- Provisional geometric workbench and non-mutating ghost renderer.
-- Visual mesh is never serialized; placement uses world coordinates.
local R={}
function R.draw(building,camera,w,h,ghost)
  local g=love.graphics
  g.push("all")
  for _,instance in pairs(building.placed) do
    local sx,sy=camera:project(instance.x,instance.y,w,h)
    local z=camera.zoom
    g.setColor(.1,.09,.07,.6)
    g.ellipse("fill",sx,sy+3*z,19*z,9*z)
    g.setColor(.48,.27,.14)
    g.polygon("fill",sx-16*z,sy-14*z,sx,sy-23*z,sx+16*z,sy-14*z,sx,sy-4*z)
    g.setColor(.68,.43,.22)
    g.rectangle("fill",sx-13*z,sy-15*z,26*z,15*z)
    g.setColor(.92,.69,.35)
    g.line(sx-16*z,sy-14*z,sx,sy-23*z,sx+16*z,sy-14*z)
  end
  if ghost then
    local sx,sy=camera:project(ghost.x,ghost.y,w,h)
    local z=camera.zoom
    if ghost.ok then g.setColor(.43,.91,.64,.65)
    else g.setColor(1,.30,.25,.68) end
    g.polygon("fill",sx,sy-13*z,sx+21*z,sy,sx,sy+13*z,sx-21*z,sy)
    g.setLineWidth(math.max(1,2*z))
    g.polygon("line",sx,sy-13*z,sx+21*z,sy,sx,sy+13*z,sx-21*z,sy)
  end
  g.pop()
end
return R
