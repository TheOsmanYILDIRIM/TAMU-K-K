-- Small, opt-out, render-only Android performance panel.
-- FPS is presentation cadence (love.timer.getFPS), CPU times omit GPU wait.
local M={visible=os.getenv('TAMU_PERF_HUD')~='0',
  elapsed=0,frames=0,smoothed=0,update_ms=0,draw_ms=0,
  last_fps=0,last_gap=0,last_needed=0,last_pending=0}
function M.toggle() M.visible=not M.visible end
function M.update(dt,elapsed_ms,stats)
 if not M.visible then return end
 M.update_ms=elapsed_ms or 0
 M.last_pending=stats and stats.pending or 0
 -- Track real frame pacing, never infer actual GPU FPS from CPU work.
 if type(dt)=='number' and dt>0 and dt<1 then
   M.elapsed=M.elapsed+dt
   M.frames=M.frames+1
   if M.elapsed>=.5 then
     M.smoothed=M.frames/M.elapsed
     M.frames,M.elapsed=0,0
   end
 end
end
function M.draw(runtime,w,h,safe_x,safe_y,safe_w,draw_ms)
 if not M.visible then return end
 M.draw_ms=draw_ms or 0
 M.last_gap=runtime and runtime.missing_visible or 0
 M.last_needed=runtime and runtime.required_visible or 0
 local g=love.graphics
 local fps=(love.timer and love.timer.getFPS and love.timer.getFPS()) or 0
 local shown=M.smoothed>0 and M.smoothed or fps
 local x=safe_x+math.max(8,safe_w-186)
 local y=safe_y+142
 local width=178
 g.push('all')
 g.setColor(.025,.07,.075,.84)
 g.rectangle('fill',x,y,width,91,7,7)
 g.setColor(1,1,1,1)
 g.print('TAMU PERF  [F9]',x+7,y+5)
 g.print(string.format('FPS %.0f  %4.1f ms',shown,shown>0 and 1000/shown or 0),x+7,y+25)
 g.print(string.format('CPU update %.1f draw %.1f',M.update_ms,M.draw_ms),x+7,y+45)
 local gap=M.last_gap
 g.setColor(gap>0 and 1 or .6,gap>0 and .42 or 1,gap>0 and .38 or .7,1)
 g.print(string.format('Eksik %d/%d  Bekleyen %d',gap,M.last_needed,M.last_pending),x+7,y+65)
 g.pop()
end
return M
