-- TAMU Diagnostics v1: bounded, structured, append-only JSONL in LÖVE save dir.
-- Never logs player identifiers, inventory content, secrets or filesystem paths.
local Json=require('save.json')
local M={enabled=false,frame=0,records={},bytes=0,last_flush=0,last_summary=0,
  last_phase=nil,clock=nil,stalled=0,dropped=0,write_ms=0,session='',
  window={},window_start=0,window_frames=0,window_slow=0,window_phases={},
  recent={},recent_cursor=0,recent_limit=120,closed=false,
  writer=nil,writer_req=nil,writer_ack=nil}
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
  if kind=='frame' then
    M.recent_cursor=M.recent_cursor%M.recent_limit+1
    M.recent[M.recent_cursor]=encoded
  end
  M.records[#M.records+1]=encoded..'\n'
  M.bytes=M.bytes+#encoded+1
end
local finish_frame
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
local function writer_status()
  if not M.writer_ack then return end
  for _=1,16 do
    local ack=M.writer_ack:pop()
    if not ack then break end
    if ack.ok then M.write_ms=safe(ack.ms or 0)
    else
      M.enabled=false
      M.dropped=M.dropped+#M.records
      M.records={};M.bytes=0
      print('TAMU_DIAGNOSTICS_WORKER_FAILED')
      break
    end
  end
end
function M.flush(force)
  if not M.enabled or #M.records==0 then return end
  local start=now()
  if M.writer_req then
    writer_status()
    if not M.enabled then return false end
    if M.writer.getError and M.writer:getError() then
      M.enabled=false;M.dropped=M.dropped+#M.records
      M.records={};M.bytes=0
      print('TAMU_DIAGNOSTICS_WORKER_FAILED')
      return false
    end
    -- Never block gameplay on flash I/O. A full four-chunk queue drops
    -- telemetry instead; closing may enqueue the final marker then wait.
    if not force and M.writer_req:getCount()>=4 then
      M.dropped=M.dropped+#M.records
      M.records={};M.bytes=0;M.last_flush=now()
      return false
    end
    M.writer_req:push(table.concat(M.records))
  else
    -- Unit-test/headless fallback only: production LÖVE uses its thread.
    rotate()
    local called,ok=pcall(love.filesystem.append,trace_path(),table.concat(M.records))
    if not called or not ok then
      M.dropped=M.dropped+#M.records;M.records={};M.bytes=0
      M.enabled=false;return false
    end
    M.write_ms=safe((now()-start)*1000)
  end
  M.records={};M.bytes=0;M.last_flush=now()
  return true
end
function M.start()
  local android=love.system and love.system.getOS and love.system.getOS()=='Android'
  M.enabled=os.getenv('TAMU_DIAGNOSTICS')~='0' and
    (android or os.getenv('TAMU_DIAGNOSTICS')=='1')
  if not M.enabled then return end
  love.filesystem.createDirectory('diagnostics')
  M.records={};M.bytes=0;M.recent={};M.recent_cursor=0
  M.frame=0;M.window={};M.window_phases={};M.window_frames=0
  M.window_slow=0;M.stalled=0;M.dropped=0;M.closed=false
  M.started=now();M.last_flush=M.started;M.last_summary=M.started;M.window_start=M.started
  M.file_index=0
  M.writer=nil;M.writer_req=nil;M.writer_ack=nil
  M.pending_sample=nil;M.pending_gpu=nil
  M.session=os.date('!%Y%m%dT%H%M%SZ')..'-'..tostring(math.floor(M.started*1000))
  if love.thread and love.thread.newThread and love.thread.getChannel then
    local ok=pcall(function()
      local channel='tamu:diagnostics:'..M.session
      M.writer_req=love.thread.getChannel(channel..':req')
      M.writer_ack=love.thread.getChannel(channel..':ack')
      M.writer_req:clear();M.writer_ack:clear()
      M.writer=love.thread.newThread('core/diagnostics_worker.lua')
      M.writer:start(channel)
    end)
    if not ok then
      M.enabled=false;M.writer=nil;M.writer_req=nil;M.writer_ack=nil
      print('TAMU_DIAGNOSTICS_WORKER_START_FAILED')
      return
    end
  end
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
  -- Do not mutate caller-owned tables; keep event fields restricted to scalars.
  local data={name=tostring(name):sub(1,64)}
  for k,v in pairs(fields or {}) do
    if type(k)=='string' and #k<=48 and
      (type(v)=='number' or type(v)=='boolean') then data[k]=v end
  end
  if name=='fatal_error' and type(fields)=='table' and type(fields.message)=='string' then
    -- Stable correlation without saving potentially sensitive stack text.
    local hash=5381
    for i=1,#fields.message do hash=(hash*33+fields.message:byte(i))%2147483647 end
    data.error_hash=hash;data.error_length=#fields.message
  end
  row('event',data)
end
-- Explicit on-device export. It never transmits data or touches save files.
function M.export()
  if not M.enabled then return false,'disabled' end
  if M.pending_sample then
    finish_frame(M.pending_sample,M.pending_gpu,now(),nil)
    M.pending_sample=nil;M.pending_gpu=nil
  end
  M.flush()
  local lines={}
  for i=1,M.recent_limit do
    local idx=(M.recent_cursor+i-1)%M.recent_limit+1
    if M.recent[idx] then lines[#lines+1]=M.recent[idx] end
  end
  local name='diagnostics/tamu-export-recent.jsonl'
  local called,ok,err=pcall(love.filesystem.write,name,table.concat(lines,'\n')..'\n')
  return called and ok,called and ok and name or tostring(err or ok)
end
function M.begin(dt)
  if not M.enabled then return end
  -- The arriving dt measures the preceding completed frame, not this one.
  if M.pending_sample then
    finish_frame(M.pending_sample,M.pending_gpu,now(),safe(dt*1000))
    M.pending_sample=nil;M.pending_gpu=nil
  end
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
  local sample={update_ms=M.update_ms or 0,draw_ms=draw_ms,
    drawcalls=gpu.drawcalls or 0,drawcalls_batched=gpu.drawcallsbatched or 0,
    shader_switches=gpu.shaderswitches or 0,texture_mib=safe((gpu.texturememory or 0)/1048576),
    lua_kib=safe(collectgarbage('count')),phases=M.phases or {},
    chunks=extra.chunks or 0,objects=extra.objects or 0,
    missing=extra.missing or 0,pending=extra.pending or 0,
    shadow_rebuilds=extra.shadow_rebuilds or 0,shadow_reuses=extra.shadow_reuses or 0,
    object_cache_rebuilds=extra.object_cache_rebuilds or 0,
    object_cache_reuses=extra.object_cache_reuses or 0,
    mesh_uploads=extra.mesh_uploads or 0,
    mesh_prepare_ms=safe(extra.mesh_prepare_ms or 0),
    mesh_resumes=extra.mesh_resumes or 0,
    contact_rebuilds=extra.contact_rebuilds or 0,contact_reuses=extra.contact_reuses or 0,
    trace_write_ms=M.write_ms}
  M.pending_sample=sample
  M.pending_gpu=gpu
end
finish_frame=function(sample,gpu,t,dt_ms)
  -- Vsync/presentation dt is confirmed on the following love.update.
  -- Session's last frame is CPU-only, never marked as a confirmed dt.
  sample.dt_ms=dt_ms
  sample.dt_confirmed=dt_ms~=nil
  local frame_ms=math.max(dt_ms or 0,sample.update_ms+sample.draw_ms)
  local samples=M.window
  samples[#samples+1]=frame_ms
  M.window_frames=M.window_frames+1
  if frame_ms>16.667 then M.window_over16=(M.window_over16 or 0)+1 end
  if frame_ms>33.333 then M.window_over33=(M.window_over33 or 0)+1 end
  for name,ms in pairs(sample.phases or {}) do
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
  local object_delta=sample.object_cache_rebuilds-
    (M.last_object_cache_rebuilds or sample.object_cache_rebuilds)
  if object_delta>0 then
    row('object_cache_rebuilt',{count=object_delta,objects=sample.objects,
      mesh_uploads=sample.mesh_uploads})
  end
  M.last_object_cache_rebuilds=sample.object_cache_rebuilds
  if sample.mesh_uploads>0 then
    row('mesh_upload',{count=sample.mesh_uploads,
      prepare_ms=sample.mesh_prepare_ms,resumes=sample.mesh_resumes,
      missing=sample.missing})
  end
  M.last_missing=sample.missing;M.last_pending=sample.pending
  M.last_shadow_rebuilds=sample.shadow_rebuilds
  if (dt_ms or 0)>=34 or sample.draw_ms>=25 or sample.update_ms>=12 then
    M.stalled=M.stalled+1;M.window_slow=M.window_slow+1
    local culprit,culprit_ms=worst_phase(sample.phases)
    row('slow_frame',{suspect=culprit,suspect_ms=culprit_ms,
      dt_ms=dt_ms,frame_ms=sample.frame_ms,draw_ms=sample.draw_ms,
      update_ms=sample.update_ms,phases=sample.phases or {},drawcalls=sample.drawcalls,objects=sample.objects,
      shadow_rebuilds=sample.shadow_rebuilds,contact_rebuilds=sample.contact_rebuilds,
      object_cache_rebuilds=sample.object_cache_rebuilds,
      mesh_uploads=sample.mesh_uploads,mesh_prepare_ms=sample.mesh_prepare_ms,
      mesh_resumes=sample.mesh_resumes})
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
  if not M.enabled or M.closed then return end
  M.closed=true
  if M.pending_sample then
    finish_frame(M.pending_sample,M.pending_gpu,now(),nil)
    M.pending_sample=nil;M.pending_gpu=nil
  end
  summarize_window(now(),{})
  row('session_end',{frames=M.frame,slow_frames=M.stalled,dropped=M.dropped})
  M.flush(true)
  if M.writer then
    M.writer_req:push('!stop')
    M.writer:wait() -- Only during shutdown, never during frame rendering.
    writer_status()
    M.writer=nil;M.writer_req=nil;M.writer_ack=nil
  end
end
return M
