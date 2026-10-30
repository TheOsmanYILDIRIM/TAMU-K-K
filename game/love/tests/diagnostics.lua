-- Bounded TAMU diagnostics JSONL regression: pure Lua/LuaJIT, no Android needed.
package.path='./?.lua;./?/init.lua;'..package.path
local clock=0
local files={}
local fs={
 createDirectory=function() return true end,
 getInfo=function(path) return files[path] and {size=#files[path]} end,
 remove=function(path) files[path]=nil;return true end,
 write=function(path,data) files[path]=data;return true end,
 append=function(path,data) files[path]=(files[path] or '')..data;return true end,
}
love={
 timer={getTime=function() return clock end},
 filesystem=fs,
 system={getOS=function() return 'Android' end},
 graphics={
  getDimensions=function() return 360,780 end,
  getPixelDimensions=function() return 360,780 end,
  getStats=function() return {drawcalls=55,drawcallsbatched=12,texturememory=1024*1024} end},
 window={getDPIScale=function() return 1 end},
 getVersion=function() return 11,5,0 end,
}
local Diagnostics=require('core.diagnostics')
Diagnostics.start()
assert(Diagnostics.enabled)
for i=1,90 do
 clock=clock+.016
 Diagnostics.begin(.016)
 clock=clock+.003;Diagnostics.phase('update_gameplay_stream_objects')
 Diagnostics.update_done()
 Diagnostics.draw_begin()
 clock=clock+.020
 Diagnostics.phase('terrain_draw')
 Diagnostics.measure('shadows_ms',2)
 Diagnostics.draw_done({chunks=35,objects=90,missing=0,shadow_rebuilds=2})
end
local exported,name=Diagnostics.export()
assert(exported and name=='diagnostics/tamu-export-recent.jsonl')
local export_lines=0
for line in files[name]:gmatch('[^\\n]+') do
  local v=require('save.json').decode(line)
  assert(v.kind=='frame')
  export_lines=export_lines+1
end
assert(export_lines==90)
Diagnostics.close()
Diagnostics.close() -- shutdown idempotency
local data=table.concat({files['diagnostics/tamu-trace-0.jsonl'] or '',
 files['diagnostics/tamu-trace-1.jsonl'] or '',
 files['diagnostics/tamu-trace-2.jsonl'] or ''})
local Json=require('save.json')
local frames,spikes,starts,ends,summaries=0,0,0,0,0
for line in data:gmatch('[^\n]+') do
 local v=Json.decode(line)
 assert(v.schema==2 and v.session and v.t)
 if v.kind=='frame' then
   frames=frames+1
   assert(v.phases.shadows_ms==2 and v.drawcalls==55 and v.objects==90)
 elseif v.kind=='slow_frame' then spikes=spikes+1
 elseif v.kind=='session_start' then starts=starts+1
 elseif v.kind=='session_end' then ends=ends+1
 elseif v.kind=='window_summary' then
  summaries=summaries+1
  assert(v.frame_p95_ms>=v.frame_p50_ms and v.frame_p99_ms>=v.frame_p95_ms)
 end
end
assert(starts==1 and ends==1 and frames==90 and summaries>=1)
assert(spikes==0,'slow threshold must use update/draw or dt, not sum')
assert(#data>1000 and #data<1024*1024)
-- A slow mobile draw must be independently reported.
Diagnostics.started=clock
Diagnostics.start()
clock=clock+.05
Diagnostics.begin(.05);Diagnostics.update_done();Diagnostics.draw_begin()
clock=clock+.03
Diagnostics.draw_done({objects=100})
Diagnostics.close()
local count=0
for line in (files['diagnostics/tamu-trace-0.jsonl'] or ''):gmatch('[^\n]+') do
 local v=Json.decode(line)
 if v.kind=='slow_frame' then count=count+1 end
end
assert(count>=1)
print('TAMU_DIAGNOSTICS_JSONL_OK frames='..frames..' slow_events='..count)
