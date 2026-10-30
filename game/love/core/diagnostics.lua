-- TAMU Diagnostics v1: bounded, structured, append-only JSONL in LÖVE save dir.
-- Never logs player identifiers, inventory content, secrets or filesystem paths.
local Json=require('save.json')
local M={enabled=false,frame=0,records={},bytes=0,last_flush=0,last_summary=0,
  last_phase=nil,clock=nil,stalled=0,dropped=0,write_ms=0,session=''}
local function now() return love.timer.getTime() end
local function safe(n)
  if type(n)~='number' or n~=n or n==math.huge or n==-math.huge then return 0 end
  return math.floor(n*1000+.5)/1000
end
local function row(kind,fields)
  if not M.enabled then return end
  fields=fields or {}
  fields.kind=kind;fields.schema=1;fields.session=M.session
  fields.t=safe(now()-M.started)
  fields.frame=M.frame
  local ok,encoded=pcall(Json.encode,fields)
  if not ok then M.dropped=M.dropped+1;return end
  M.records[#M.records+1]=encoded..'\n'
  M.bytes=M.bytes+#encoded+1
end
local function rotate()
  local fs=love.filesystem
  local info=fs.getInfo('diagnostics/tamu-trace.jsonl')
  if not info or info.size<6*1024*1024 then return end
  fs.remove('diagnostics/tamu-trace-2.jsonl')
  fs.rename('diagnostics/tamu-trace-1.jsonl','diagnostics/tamu-trace-2.jsonl')
  fs.rename('diagnostics/tamu-trace.jsonl','diagnostics/tamu-trace-1.jsonl')
end
function M.flush()
  if not M.enabled or #M.records==0 then return end
  local start=now()
  rotate()
  local ok=love.filesystem.append('diagnostics/tamu-trace.jsonl',table.concat(M.records))
  if not ok then M.enabled=false;return end
  M.records={};M.bytes=0;M.last_flush=now()
  M.write_ms=safe((M.last_flush-start)*1000)
end
function M.start()
  local android=love.system and love.system.getOS and love.system.getOS()=='Android'
  M.enabled=os.getenv('TAMU_DIAGNOSTICS')~='0' and
    (android or os.getenv('TAMU_DIAGNOSTICS')=='1')
  if not M.enabled then return end
  love.filesystem.createDirectory('diagnostics')
  M.started=now();M.last_flush=M.started;M.last_summary=M.started
  M.session=os.date('!%Y%m%dT%H%M%SZ')..'-'..tostring(math.floor(M.started*1000))
  local w,h=love.graphics.getDimensions()
  local pw,ph=love.graphics.getPixelDimensions()
  row('session_start',{os=love.system.getOS(),love_major=love.getVersion(),
    display_w=w,display_h=h,pixel_w=pw,pixel_h=ph,
    dpi=love.window.getDPIScale and safe(love.window.getDPIScale()) or 1})
  M.flush()
end
function M.event(name,fields)
  if not M.enabled then return end
  fields=fields or {};fields.name=name;row('event',fields)
end
function M.begin(dt)
  if not M.enabled then return end
  M.frame=M.frame+1;M.frame_start=now();M.dt=safe(dt*1000)
  M.phases={};M.mark=now()
end
function M.phase(name)
  if not M.enabled or not M.phases then return end
  local t=now();M.phases[name]=safe((t-M.mark)*1000);M.mark=t
end
function M.update_done()
  if not M.enabled then return end
  M.update_ms=safe((now()-M.frame_start)*1000)
end
function M.draw_begin()
  if not M.enabled then return end
  M.draw_start=now();M.mark=M.draw_start
end
function M.draw_done(extra)
  if not M.enabled then return end
  extra=extra or {}
  local t=now()
  local draw_ms=safe((t-(M.draw_start or t))*1000)
  local gpu=love.graphics.getStats and love.graphics.getStats() or {}
  local sample={dt_ms=M.dt,update_ms=M.update_ms or 0,draw_ms=draw_ms,
    drawcalls=gpu.drawcalls or 0,drawcalls_batched=gpu.drawcallsbatched or 0,
    shader_switches=gpu.shaderswitches or 0,texture_mib=safe((gpu.texturememory or 0)/1048576),
    lua_kib=safe(collectgarbage('count')),phases=M.phases or {},
    chunks=extra.chunks or 0,objects=extra.objects or 0,
    missing=extra.missing or 0,pending=extra.pending or 0,
    shadow_rebuilds=extra.shadow_rebuilds or 0,shadow_reuses=extra.shadow_reuses or 0,
    contact_rebuilds=extra.contact_rebuilds or 0,contact_reuses=extra.contact_reuses or 0,
    trace_write_ms=M.write_ms}
  row('frame',sample)
  if M.dt>=34 or draw_ms>=25 or (M.update_ms or 0)>=12 then
    M.stalled=M.stalled+1
    row('slow_frame',{dt_ms=M.dt,draw_ms=draw_ms,update_ms=M.update_ms,
      phases=M.phases or {},drawcalls=sample.drawcalls,objects=sample.objects,
      shadow_rebuilds=sample.shadow_rebuilds,contact_rebuilds=sample.contact_rebuilds})
  end
  if t-M.last_summary>=5 then
    row('summary',{frames=M.frame,slow_frames=M.stalled,dropped=M.dropped,
      trace_write_ms=M.write_ms,lua_kib=sample.lua_kib,
      texture_mib=sample.texture_mib,drawcalls=sample.drawcalls})
    M.last_summary=t
  end
  if M.bytes>=64*1024 or t-M.last_flush>=2 then M.flush() end
end
function M.close()
  if not M.enabled then return end
  row('session_end',{frames=M.frame,slow_frames=M.stalled,dropped=M.dropped})
  M.flush()
end
return M
