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
-- Dedicated CI proxy run, deterministic idle camera/seed and 180+ samples.
-- Deliberately excludes Android/GPU/thermal emulation claims.
if os.getenv("OSMAN_R2_PROXY_BENCH")=="1" then
  local base_draw=love.draw
  love.draw=function(...)
    base_draw(...)
    if boot_ready and android_probe.total>=240 and android_probe.ready==stats.needed then
      local fp50,fp95,fp99,fmax=android_probe:quantiles("frame")
      local up50,up95=android_probe:quantiles("update")
      local ob50,ob95=android_probe:quantiles("objects")
      local pl50,pl95=android_probe:quantiles("player")
      print(string.format("R2_PROXY_RESULT mode=%d samples=180 ready=%d needed=%d frame_p50=%.2f frame_p95=%.2f frame_p99=%.2f frame_max=%.2f update_p50=%.2f update_p95=%.2f objects_p50=%.2f objects_p95=%.2f player_p50=%.2f player_p95=%.2f",android_probe.mode,android_probe.ready,stats.needed,fp50,fp95,fp99,fmax,up50,up95,ob50,ob95,pl50,pl95))
      io.stdout:flush()
      love.event.quit(0)
    end
  end
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
old_pass="""   if drawables[name] then
    lg.draw(drawables[name])
    material_calls=material_calls+1
   end"""
new_pass="""   if drawables[name] then
    if not Terrain.diag_skip_render then
     lg.draw(drawables[name])
     material_calls=material_calls+1
    end
   end"""
assert src.count(old_pass)==1,"unexpected terrain material pass"
src=src.replace(old_pass,new_pass,1)
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

# Render-only R2 package switch: never alter production world/logic.
patch(main,[("local preview_frame_ms=0",r'''local viewport_experiment=os.getenv("OSMAN_R2_VIEWPORT_EXPERIMENT")=="1"
if viewport_experiment then
  assert(r2_pilot,"viewport experiment requires R2")
  stream.viewport_cover=true
  r2_pilot.render_options.viewport_cull=true
end
local terrain_visible,terrain_total,terrain_material_calls=0,0,0
Terrain.on_visibility=function(visible,total,calls)
  terrain_visible,terrain_total,terrain_material_calls=visible,total,calls
end
local preview_frame_ms=0''')])
with main.open("a",encoding="utf-8") as out:
    out.write(r'''
-- Disposable fixed camera R2 render/present wall-time bench. LÖVE present
-- calls are timed on CPU; this is NEVER a GPU timestamp or Android FPS.
if os.getenv("OSMAN_R2_RENDER_BENCH")=="1" then
  assert(r2_pilot and cache_pilot_enabled,"requires R2 disposable cache")
  local bench_samples,bench_raw={},0
  local bench_present,bench_draw,bench_calls,bench_batched={},{},{},{}
  local bench_terrain,bench_total,bench_pass={},{},{}
  local bench_draw_ms=0
  local g=love.graphics
  local source_draw=love.draw
  love.draw=function(...)
    local started=love.timer.getTime()
    source_draw(...)
    bench_draw_ms=(love.timer.getTime()-started)*1000
    if bench_raw==209 and g.captureScreenshot then
      g.captureScreenshot(viewport_experiment and "r2-viewport-on.png" or
        "r2-viewport-off.png")
    end
  end
  local source_present=g.present
  g.present=function(...)
    local before=g.getStats()
    local started=love.timer.getTime()
    source_present(...)
    local present_ms=(love.timer.getTime()-started)*1000
    if boot_ready and android_probe.ready==stats.needed and stats.needed>0 then
      bench_raw=bench_raw+1
      if bench_raw>30 and bench_raw<=210 then
        bench_present[#bench_present+1]=present_ms
        bench_draw[#bench_draw+1]=bench_draw_ms
        bench_calls[#bench_calls+1]=before.drawcalls or 0
        bench_batched[#bench_batched+1]=before.drawcallsbatched or 0
        bench_terrain[#bench_terrain+1]=terrain_visible
        bench_total[#bench_total+1]=terrain_total
        bench_pass[#bench_pass+1]=terrain_material_calls
      end
      if bench_raw==210 then
        local function q(a,p)
          table.sort(a)
          return a[math.max(1,math.ceil(#a*p))] or 0
        end
        local px,py=g.getPixelDimensions()
        local ww,hh=g.getDimensions()
        local t50,t95,t99=android_probe:quantiles("terrain")
        print(string.format("R2_RENDER_BENCH mode=%s samples=%d fb=%dx%d logical=%dx%d dpi=%.2f draw_p50=%.3f draw_p95=%.3f draw_p99=%.3f present_p50=%.3f present_p95=%.3f present_p99=%.3f terrain_p50=%.3f terrain_p95=%.3f terrain_p99=%.3f drawcalls_p50=%.0f batched_p50=%.0f terrain_visible_p50=%.0f terrain_resident_p50=%.0f material_calls_p50=%.0f",
          viewport_experiment and "ON" or "OFF",#bench_draw,px,py,ww,hh,
          g.getDPIScale and g.getDPIScale() or 1,
          q(bench_draw,.5),q(bench_draw,.95),q(bench_draw,.99),
          q(bench_present,.5),q(bench_present,.95),q(bench_present,.99),
          t50,t95,t99,
          q(bench_calls,.5),q(bench_batched,.5),
          q(bench_terrain,.5),q(bench_total,.5),q(bench_pass,.5)))
        io.stdout:flush()
        love.event.quit(0)
      end
    end
  end
end
''')
print("R2_VIEWPORT_PACKAGE_OPT_IN_OK")
