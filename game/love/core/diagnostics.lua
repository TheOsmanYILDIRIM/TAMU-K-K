-- TAMU Diagnostics v1: bounded, structured, append-only JSONL in LÖVE save dir.
-- Never logs player identifiers, inventory content, secrets or filesystem paths.
local Json=require('save.json')
local M={enabled=false,frame=0,records={},bytes=0,last_flush=0,last_summary=0,
  last_phase=nil,clock=nil,stalled=0,dropped=0,write_ms=0,session='',
  window={},window_start=0,window_frames=0,window_slow=0,window_phases={}}
local function now() return love.timer.getTime() end
local function safe(n)
  if type(n)~='number' or n~=n or n==math.huge or n==-math.huge then return 0 end
  return math.floor(n*1000+.5)/1000
end
local function row(kind,fields)
  if not M.enabled then return end
  fields=fields or {}
  fields.kind=kind;fields.schema=2;fields.session=M.session
  fields.t=safe(now()-M.started)
  fields.frame=M.frame
  local ok,encoded=pcall(Json.encode,fields)
  if not ok then M.dropped=M.dropped+1;return end
  M.records[#M.records+1]=encoded..'\n'
  M.bytes=M.bytes+#encoded+1
end
local function trace_path()
  return 'diagnostics/tamu-trace-'..tostring(M.file_index or 0)..'.jsonl'
end
local function rotate()
  local fs=love.filesystem
  local info=fs.getInfo(trace_path())
  if not info or info.size<4*1024*1024 then return end
  -- Constant-time ring rotation, without a 4MB rename/copy in love.draw.
  M.file_index=((M.file_index or 0)+1)%3
  fs.remove(trace_path())
end
function M.flush()
  if not M.enabled or #M.records==0 then return end
  local start=now()
  rotate()
  local ok=love.filesystem.append(trace_path(),table.concat(M.records))
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
  M.started=now();M.last_flush=M.started;M.last_summary=M.started;M.window_start=M.started
  M.file_index=0
  M.session=os.date('!%Y%m%dT%H%M%SZ')..'-'..tostring(math.floor(M.started*1000))
  local w,h=love.graphics.getDimensions()
  local pw,ph=love.graphics.getPixelDimensions()
  row('session_start',{os=love.system.getOS(),love_major=love.getVersion(),
    display_w=w,display_h=h,pixel_w=pw,pixel_h=ph,
    dpi=love.window.getDPIScale and safe(love.window.getDPIScale()) or 1})
  M.flush()
  print('TAMU_DIAGNOSTICS_START save_dir='..tostring(love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory() or 'unknown')..' file=diagnostics/tamu-trace-*.jsonl')
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
function M.measure(name,elapsed_ms)
  if not M.enabled or not M.phases then return end
  M.phases[name]=safe((M.phases[name] or 0)+(elapsed_ms or 0))
end
function M.update_done()
  if not M.enabled then return end
  M.update_ms=safe((now()-M.frame_start)*1000)
end
function M.draw_begin()
  if not M.enabled then return end
  M.draw_start=now();M.mark=M.draw_start
end
local function quantile(sorted,p)
 if #sorted==0 then return 0 end
 return safe(sorted[math.max(1,math.ceil(#sorted*p))])
end
local function worst_phase(phases)
 local key,value='unattributed',0
 for name,ms in pairs(phases or {}) do
   if ms>value then key,value=name,ms end
 end
 return key,safe(value)
end
local function summarize_window(t,gpu)
 local samples=M.window
 if #samples==0 then return end
 table.sort(samples)
 local phases={}
 for name,record in pairs(M.window_phases) do
   phases[name]={sum=safe(record.sum),max=safe(record.max),
     avg=safe(record.sum/math.max(1,M.window_frames))}
 end
 row('window_summary',{seconds=safe(t-M.window_start),
   count=M.window_frames,slow_frames=M.window_slow,
   frame_p50_ms=quantile(samples,.5),frame_p95_ms=quantile(samples,.95),
   frame_p99_ms=quantile(samples,.99),frame_max_ms=quantile(samples,1),
   frame_over_16ms= M.window_over16 or 0,
   frame_over_33ms= M.window_over33 or 0,
   phases=phases,drawcalls=gpu.drawcalls or 0,
   shader_switches=gpu.shaderswitches or 0,
   dropped=M.dropped,trace_write_ms=M.write_ms})
 M.window={};M.window_phases={};M.window_frames=0
 M.window_slow=0;M.window_over16=0;M.window_over33=0
 M.window_start=t
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
  -- True dt includes frame pacing and presentation; update+draw is
  -- not a GPU timer, so keep both measurements explicitly separate.
  local frame_ms=math.max(M.dt or 0,(M.update_ms or 0)+draw_ms)
  local samples=M.window
  samples[#samples+1]=frame_ms
  M.window_frames=M.window_frames+1
  if frame_ms>16.667 then M.window_over16=(M.window_over16 or 0)+1 end
  if frame_ms>33.333 then M.window_over33=(M.window_over33 or 0)+1 end
  for name,ms in pairs(M.phases or {}) do
    local rec=M.window_phases[name] or {sum=0,max=0}
    rec.sum=rec.sum+ms
    if ms>rec.max then rec.max=ms end
    M.window_phases[name]=rec
  end
  sample.frame_ms=safe(frame_ms)
  sample.fps=frame_ms>0 and safe(1000/frame_ms) or 0
  row('frame',sample)
  if M.last_missing~=nil and sample.missing~=M.last_missing then
    row('chunk_coverage_changed',{before=M.last_missing,after=sample.missing,
      chunks=sample.chunks,pending=sample.pending})
  end
  if M.last_pending~=nil and sample.pending~=M.last_pending then
    row('chunk_pending_changed',{before=M.last_pending,after=sample.pending})
  end
  local shadow_delta=sample.shadow_rebuilds-(M.last_shadow_rebuilds or sample.shadow_rebuilds)
  if shadow_delta>0 then row('shadow_rebuilt',{count=shadow_delta,objects=sample.objects}) end
  M.last_missing=sample.missing;M.last_pending=sample.pending
  M.last_shadow_rebuilds=sample.shadow_rebuilds
  if M.dt>=34 or draw_ms>=25 or (M.update_ms or 0)>=12 then
    M.stalled=M.stalled+1;M.window_slow=M.window_slow+1
    local culprit,culprit_ms=worst_phase(M.phases)
    row('slow_frame',{suspect=culprit,suspect_ms=culprit_ms,
      dt_ms=M.dt,frame_ms=sample.frame_ms,draw_ms=draw_ms,update_ms=M.update_ms,
      phases=M.phases or {},drawcalls=sample.drawcalls,objects=sample.objects,
      shadow_rebuilds=sample.shadow_rebuilds,contact_rebuilds=sample.contact_rebuilds})
  end
  if t-M.last_summary>=5 then
    summarize_window(t,gpu)
    row('summary',{frames=M.frame,slow_frames=M.stalled,dropped=M.dropped,
      trace_write_ms=M.write_ms,lua_kib=sample.lua_kib,
      texture_mib=sample.texture_mib,drawcalls=sample.drawcalls})
    M.last_summary=t
  end
  if M.bytes>=64*1024 or t-M.last_flush>=2 then M.flush() end
end
function M.close()
  if not M.enabled then return end
  summarize_window(now(),{})
  row('session_end',{frames=M.frame,slow_frames=M.stalled,dropped=M.dropped})
  M.flush()
end
return M
