#!/usr/bin/env python3
"""Build-only portability and FPS diagnostics patch; source main.lua untouched."""
import sys
from pathlib import Path

root=Path(sys.argv[1])
entry=root/"main.lua"
src=entry.read_text(encoding="utf-8")
def replace(old,new):
    global src
    if src.count(old)!=1:
        raise SystemExit("Portable HUD patch anchor mismatch: "+old[:76])
    src=src.replace(old,new,1)

replace("local object_count=0", """local object_count=0
-- Portable preview diagnostics: genuine frame delta and renderer-ready chunks.
local preview_frame_ms=0
local preview_spikes=0
local preview_peak=0
local preview_peak_display=0
local preview_window_at=0
""")
replace("function love.update(dt)\n", """function love.update(dt)
  preview_frame_ms=dt*1000
  preview_peak=math.max(preview_peak,preview_frame_ms)
  if preview_frame_ms>33.333 then preview_spikes=preview_spikes+1 end
  local time=love.timer.getTime()
  if time-preview_window_at>3 then
    preview_peak_display=preview_peak
    preview_peak=0
    preview_window_at=time
  end
""")
replace('  if route_status~="" then g.print(route_status,safe_x+18,safe_y+84) end',
"""  if route_status~="" then g.print(route_status,safe_x+18,safe_y+84) end
  if r2_pilot then
    local ready_meshes=0
    for _,ch in ipairs(stream:visible()) do
      if ch._terrain_meshes then ready_meshes=ready_meshes+1 end
    end
    local cm=chunk_cache and chunk_cache.metrics or {}
    g.setColor(.02,.09,.11,.84)
    g.rectangle("fill",safe_x+8,safe_y+185,math.min(safe_w-16,600),53,8,8)
    g.setColor(.90,.96,.93)
    g.print(string.format("FPS %d  Frame %.0fms  Peak %.0fms  drops %d",
        love.timer.getFPS(),preview_frame_ms,preview_peak_display,preview_spikes),
        safe_x+18,safe_y+188)
    g.print(string.format("Ready %d/%d  loaded %d  cache H%d M%d W%d",
        ready_meshes,stats.needed,stats.loaded,cm.hits or 0,
        cm.misses or 0,cm.writes or 0),safe_x+18,safe_y+212)
  end""")
entry.write_text(src,encoding="utf-8")
print("R2_PORTABLE_FPS_HUD_READY")
