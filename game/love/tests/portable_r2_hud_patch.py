#!/usr/bin/env python3
"""Inject R2 Android CPU/viewport diagnostics into the disposable LOVE staging copy.

Production game source and Stage5/6 remain untouched. CPU timers are not GPU queries.
"""
import sys
from pathlib import Path

root=Path(sys.argv[1])

def patch(path, pairs):
    text=path.read_text(encoding="utf-8")
    for old,new in pairs:
        if text.count(old)!=1:
            raise SystemExit("Portable R2 diagnostic anchor mismatch: "+path.name+" "+old[:64])
        text=text.replace(old,new,1)
    path.write_text(text,encoding="utf-8")

main=root/"main.lua"
patch(main,[
("local object_count=0",r'''local object_count=0
-- Package-only, in-memory R2 device probe. No simulation/save changes.
local android_probe=require("core.r2_android_probe").new()
if os.getenv("OSMAN_R2_DIAG_CULL_SMOKE")=="1" then android_probe.mode=2 end
local diag_font,diag_font_size
local base_stream_update=stream.update
function stream:update(...)
  local t=love.timer.getTime()
  local result=base_stream_update(self,...)
  android_probe:add("stream",(love.timer.getTime()-t)*1000)
  return result
end
local base_terrain_draw=Terrain.draw
Terrain.draw=function(...)
  Terrain.diag_skip_render=(android_probe.mode==4)
  local t=love.timer.getTime()
  base_terrain_draw(...)
  android_probe:add("terrain",(love.timer.getTime()-t)*1000)
end
Terrain.on_mesh=function(ms,vertices)
  android_probe:mesh(ms,vertices)
end
-- Time the unchanged production player update separately from the stream.
local base_player_update=Controller.update
Controller.update=function(self,...)
  local started=love.timer.getTime()
  local steps=base_player_update(self,...)
  android_probe:add("player",(love.timer.getTime()-started)*1000)
  android_probe.last_steps=steps
  return steps
end
local base_object_collect=ObjectRenderer.collect
ObjectRenderer.collect=function(...)
  local t=love.timer.getTime()
  local list=base_object_collect(...)
  android_probe:add("collect",(love.timer.getTime()-t)*1000)
  return list
end
local base_object_draw=ObjectRenderer.draw
ObjectRenderer.draw=function(...)
  ObjectRenderer.diag_cull=(android_probe.mode==2)
  local t=love.timer.getTime()
  local count=base_object_draw(...)
  android_probe:add("objects",(love.timer.getTime()-t)*1000)
  return count
end
require("world.chunk_cache").on_read=function(name,ms)
  android_probe:add(name,ms)
end
local preview_frame_ms=0
local preview_spikes=0
local preview_peak=0
local preview_peak_display=0
local preview_window_at=0
'''),
("function love.update(dt)\n",r'''function love.update(dt)
  preview_frame_ms=dt*1000
  preview_peak=math.max(preview_peak,preview_frame_ms)
  if preview_frame_ms>33.333 then preview_spikes=preview_spikes+1 end
  local time=love.timer.getTime()
  if time-preview_window_at>3 then
    preview_peak_display=preview_peak
    preview_peak=0
    preview_window_at=time
  end
'''),
("      boot_ready=true\n",r'''      boot_ready=true
      android_probe:reset()
'''),
("  object_count=ObjectRenderer.draw(objects,stream,camera,w,h,player,selected_target,harvesting)",
r'''  if android_probe.mode==3 then
    object_count=0 -- Diagnostic-only hide; object logic/collisions still run.
  else
    object_count=ObjectRenderer.draw(objects,stream,camera,w,h,player,selected_target,harvesting)
  end'''),
('  if route_status~="" then g.print(route_status,safe_x+18,safe_y+84) end',
r'''  if route_status~="" then g.print(route_status,safe_x+18,safe_y+84) end
  if r2_pilot then
    android_probe:sample(stream,stats,chunk_cache)
    local old_font=g.getFont()
    local new_size=math.max(11,math.floor(11*math.min(safe_w/360,safe_h/780)+.5))
    if not diag_font or diag_font_size~=new_size then
      diag_font=g.newFont(new_size)
      diag_font_size=new_size
    end
    g.setFont(diag_font)
    local lines={
      string.format("FPS %d Frame %.0fms Peak %.0fms drops %d",
        love.timer.getFPS(),preview_frame_ms,preview_peak_display,preview_spikes),
      string.format("Ready %d/%d loaded %d",
        android_probe.ready,stats.needed,stats.loaded),
      string.format("Objects %d culled %d",object_count,
        android_probe.mode==3 and 0 or ObjectRenderer.diag_culled or 0)
    }
    for _,line in ipairs(android_probe:lines()) do lines[#lines+1]=line end
    local top=safe_y+185
    local line_h=diag_font:getHeight()+2
    g.setColor(.02,.07,.09,.89)
    g.rectangle("fill",safe_x+8,top,math.min(safe_w-16,600),
      #lines*line_h+10,8,8)
    g.setColor(.92,.98,.95)
    for i,line in ipairs(lines) do
      g.print(line,safe_x+15,top+4+(i-1)*line_h)
    end
    g.setFont(old_font)
    g.setColor(1,1,1,1)
  end'''),
("  local safe={x=sx,y=sy,w=sw,h=sh}\n  local stat_hit=stat_hud:hit(x,y,safe)",
r'''  local safe={x=sx,y=sy,w=sw,h=sh}
  if r2_pilot and x>=sx+8 and x<=sx+sw-8 and
    y>=sy+185 and y<=sy+185+44 then
    fingers[id].diag=true
    return
  end
  local stat_hit=stat_hud:hit(x,y,safe)'''),
("  if p.button or p.ui or p.stats then return end",
 "  if p.button or p.ui or p.stats or p.diag then return end"),
("  if p.joystick then joystick:release(id)\n  elseif p.stats then",
r'''  if p.diag then
    local sx,sy,sw=safe_area()
    if x>=sx+8 and x<=sx+sw-8 and y>=sy+185 and y<=sy+185+44 then
      android_probe:cycle()
    end
  elseif p.joystick then joystick:release(id)
  elseif p.stats then'''),
("function love.keypressed(key)\n",
r'''function love.keypressed(key)
  if key=="f8" and r2_pilot then android_probe:cycle();return end
''')
])
with main.open("a",encoding="utf-8") as out:
    out.write(r'''
-- Wrap after callback definitions to include CPU update cost (not GPU present/vsync).
local r2_base_love_update=love.update
love.update=function(dt)
  android_probe:begin(dt)
  local t=love.timer.getTime()
  r2_base_love_update(dt)
  android_probe:add("update",(love.timer.getTime()-t)*1000)
end
''')

terrain=root/"world/terrain_renderer.lua"
src=terrain.read_text(encoding="utf-8")
assert src.count("graphics().newMesh(")==4,"unexpected terrain mesh locations"
src=src.replace("graphics().newMesh(","measured_new_mesh(")
assert src.count("lg.newMesh(")==1
src=src.replace("lg.newMesh(","measured_new_mesh(")
old='local function graphics() assert(love and love.graphics,"LOVE graphics required");return love.graphics end'
assert src.count(old)==1
helper=r'''local function measured_new_mesh(vertices,mode,usage)
  local started=love.timer.getTime()
  local mesh=graphics().newMesh(vertices,mode,usage)
  if Terrain.on_mesh then Terrain.on_mesh((love.timer.getTime()-started)*1000,#vertices) end
  return mesh
end'''
src=src.replace(old,old+"\n"+helper,1)
assert src.count("if drawables[name] then lg.draw(drawables[name]) end")==1
src=src.replace("if drawables[name] then lg.draw(drawables[name]) end",
                "if not Terrain.diag_skip_render and drawables[name] then lg.draw(drawables[name]) end",1)
assert src.count("if options.atmosphere~=false then")==1
src=src.replace("if options.atmosphere~=false then",
                "if options.atmosphere~=false and not Terrain.diag_skip_render then",1)
terrain.write_text(src,encoding="utf-8")

cache=root/"world/chunk_cache.lua"
patch(cache,[
('  local encoded=assert(love.filesystem.read(path))',r'''  local started=love.timer.getTime()
  local encoded=assert(love.filesystem.read(path))
  if Cache.on_read then Cache.on_read("read_io",(love.timer.getTime()-started)*1000) end'''),
('  local buffer=love.data.decompress("string","lz4",parts[5])',r'''  local started_decode=love.timer.getTime()
  local buffer=love.data.decompress("string","lz4",parts[5])
  if Cache.on_read then Cache.on_read("lz4",(love.timer.getTime()-started_decode)*1000) end''')
])

obj=root/"objects/renderer.lua"
patch(obj,[
("function R.draw(world,stream,camera,w,h,player,selected_id,harvesting)",r'''-- Screen-only conservative culling experiment. Never removes candidate objects,
-- changes interaction/collision state, or excludes the player's sprite.
-- R2 pilot terrain is bounded (Generator v1 0..24, valley down to -2).
-- Its height displacement is <= 8.4*zoom at scale .35; 32*zoom
-- gives conservative room without calling the costly height query.
-- This is a PACKAGE-ONLY opt-in experiment, not the general renderer.
local Iso=require("world.iso")
local function on_screen(camera,w,h,o)
  local sx,sy=Iso.project(o.x-camera.x,o.y-camera.y)
  local z=camera.zoom
  local x,y=w*.5+sx*z,h*.5+sy*z
  local side=(o.kind=="tree" and 28 or 22)*z+o.radius*z*1.5+12
  local top=(o.kind=="tree" and 82 or 36)*z+12+32*z
  local bottom=o.radius*z*.9+12+32*z
  return x>=-side and x<=w+side and y>=-bottom and y<=h+top
end
function R.draw(world,stream,camera,w,h,player,selected_id,harvesting)
  R.diag_culled=0'''),
("  for _,o in ipairs(all) do order[#order+1]={id=o.id,depth=Depth.key(o.x,o.y),object=o} end",
r'''  for _,o in ipairs(all) do
    if not R.diag_cull or on_screen(camera,w,h,o) then
      order[#order+1]={id=o.id,depth=Depth.key(o.x,o.y),object=o}
    else
      R.diag_culled=R.diag_culled+1
    end
  end'''),
('    if entry.player then player_sprite(g,camera,w,h,player,visual)\n    else object_sprite(g,camera,w,h,entry.object,entry.id==selected_id) end',
r'''    if entry.player then
      player_sprite(g,camera,w,h,player,visual)
    else
      object_sprite(g,camera,w,h,entry.object,entry.id==selected_id)
    end''')
])
print("R2_ANDROID_DIAGNOSTICS_PATCH_OK")
