-- BUILD-ONLY: R2 full-fidelity terrain cache preparation. Replaces main.lua
-- in a disposable staging copy and is NEVER the actual packaged game main.
local R2=require("world.r2_playable")
local Chunks=require("world.chunks")
local Terrain=require("world.terrain_renderer")
local Cache=require("world.chunk_cache")
local world,chunker,cache,targets,at,done
local function report()
  cache:poll()
  local m=cache.metrics
  print(string.format("R2_PREBAKE_DONE chunks=%d writes=%d bytes=%d failures=%d",
     #targets,m.writes,cache.bytes,m.write_errors or 0))
  io.stdout:flush()
  assert(m.writes==#targets and (m.write_errors or 0)==0,
    "R2 prebake must persist EVERY specified chunk")
  cache:close()
  love.event.quit(0)
end
function love.load()
  world=R2.new()
  chunker=Chunks.new(world.query,{size=256,step=8})
  cache=Cache.new({seed=world.query.seed,
    stamp="r2-fisilti-20261019-pinned",size=256,step=8,quality="standard"})
  targets={}
  -- Authored forest, stream, path and cliff + significant viewport margin.
  -- 13x12 chunk region. All geometry is deterministic and view-independent.
  for cy=-5,6 do
    for cx=-4,8 do
      targets[#targets+1]={cx,cy}
    end
  end
  table.sort(targets,function(a,b)
    local da=(a[1]*256-64)^2+(a[2]*256-128)^2
    local db=(b[1]*256-64)^2+(b[2]*256-128)^2
    return da<db
  end)
  at=1
  assert(world.query.seed==20261018 and #targets==156,
    "R2 pinning or build region changed")
end
function love.update(dt)
  cache:poll()
  if at>#targets then
    if cache.pending_count==0 then report() end
    return
  end
  if cache.pending_count>=2 then return end
  local xy=targets[at]
  if not cache:has(xy[1],xy[2]) then
    local chunk=chunker:build(xy[1],xy[2])
    Terrain.prepare_cpu(chunk,world.query,world.render_options)
    local ok,reason=cache:write(xy[1],xy[2],chunk._cache_payload)
    assert(ok,reason or "cache persist queue rejected")
  end
  at=at+1
  if at%12==0 then
    print(string.format("R2_PREBAKE_PROGRESS %d/%d queued=%d",
     at-1,#targets,cache.pending_count))
    io.stdout:flush()
  end
end
function love.draw() love.graphics.clear(.04,.08,.08,1) end
