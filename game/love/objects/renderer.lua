-- Sorted 45-degree world-foot sprites; GPU-independent placement and mutable state.
local Depth=require("player.depth")
local Diagnostics=require("core.diagnostics")
local R={metrics={collect_calls=0,cold_queries=0,cold_query_ms=0,
 cold_query_max_ms=0,collect_last_ms=0,collect_max_ms=0,
 prepared_chunks=0,prepare_last_ms=0,prepare_max_ms=0}}
-- Rigby is the only production avatar; no legacy plasma fallback.
local CoreVisual=require("player.rigby_visual")
local Direction=require("player.direction")
local function player_sprite(g,camera,w,h,player,visual_context)
  return CoreVisual.draw(g,camera,w,h,player,visual_context)
end
local function object_sprite(g,camera,w,h,o,selected)
  local x,y=camera:project(o.x,o.y,w,h)
  local z=camera.zoom
  g.setColor(0,.09,.08,.33)
  g.ellipse("fill",x,y+3*z,o.radius*z*1.25,o.radius*z*.60)
  if o.kind=="tree" then
    g.setColor(.28,.19,.12)
    g.rectangle("fill",x-4*z,y-39*z,8*z,39*z)
    g.setColor(.14,.29,.19)
    g.polygon("fill",x-24*z,y-23*z,x,y-69*z,x+24*z,y-23*z)
    g.setColor(.19,.40,.26)
    g.polygon("fill",x-22*z,y-37*z,x,y-78*z,x+22*z,y-37*z)
    g.setColor(.31,.52,.32)
    g.polygon("fill",x-14*z,y-51*z,x,y-79*z,x+14*z,y-51*z)
  else
    g.setColor(.25,.31,.34)
    g.polygon("fill",x-17*z,y-4*z,x-13*z,y-21*z,x+3*z,y-32*z,x+17*z,y-17*z,x+14*z,y,x-7*z,y+3*z)
    g.setColor(.50,.54,.52)
    g.polygon("fill",x-13*z,y-21*z,x+3*z,y-32*z,x+17*z,y-17*z,x,y-13*z)
    g.setColor(.36,.41,.43)
    g.polygon("fill",x-17*z,y-4*z,x,y-13*z,x+14*z,y,x-7*z,y+3*z)
  end
  if selected then
    g.setColor(1,.82,.3,.9)
    g.setLineWidth(2)
    g.ellipse("line",x,y,o.radius*z*1.5,o.radius*z*.8)
  end
end
-- Procedural instance coordinates and authored anchors are immutable for
-- generator v1. Cache only candidate membership on resident chunks; depletion
-- and R2 day-based regrowth MUST be read live every draw/pick. Chunk eviction
-- bounds lifetime; different world identities (Stage6 publish) rebuild it.
-- Opt-in mobile: prepare each authored population chunk in four small
-- independent queries while the main loop still updates player/UI input.
-- Immutable candidate membership is cached; depletion is always read live.
local function stable_population(world)
 return type(world.is_depleted)=='function' and
   (world.generator_version==1 or
    (world.query and world.query.generator_version==1))
end
function R.prepare_visible(world,stream,budget_ms,camera,w,h)
 if not stable_population(world) then return 0 end
 local clock=love and love.timer and love.timer.getTime
 if type(clock)~='function' then return 0 end
 local start=clock()
 local deadline=start+(budget_ms or 1.2)/1000
 local resumes=0
 local candidates=stream.render_visible and camera and
   stream:render_visible(camera,w,h,80*camera.zoom+16) or stream:visible()
 for _,chunk in ipairs(candidates) do
  if chunk._25d_meshes and
    (chunk._object_render_world~=world or not chunk._object_render_candidates) then
   local job=chunk._object_render_job
   if not job then
    job=coroutine.create(function()
      local results,seen={},{}
      local half=chunk.size/2
      for y=0,1 do for x=0,1 do
       local x0,y0=chunk.x+x*half,chunk.y+y*half
       local candidates=world:objects_in({min_x=x0,min_y=y0,
         max_x=x0+half,max_y=y0+half},true)
       for _,o in ipairs(candidates) do
        if o.cx==chunk.cx and o.cy==chunk.cy and not seen[o.id] then
         seen[o.id]=true
         results[#results+1]=o
        end
       end
       coroutine.yield()
      end end
      chunk._object_render_candidates=results
      chunk._object_render_world=world
    end)
    chunk._object_render_job=job
   end
   local ok,err=coroutine.resume(job)
   assert(ok,err)
   resumes=resumes+1
   if coroutine.status(job)=='dead' then
     chunk._object_render_job=nil
     R.metrics.prepared_chunks=R.metrics.prepared_chunks+1
   end
   if resumes>=4 or clock()>=deadline then break end
  end
 end
 local elapsed=(clock()-start)*1000
 R.metrics.prepare_last_ms=elapsed
 R.metrics.prepare_max_ms=math.max(R.metrics.prepare_max_ms,elapsed)
 return resumes
end
-- Scratch buffers are only used by the synchronous render path.
-- Public R.collect still returns an independent table for other callers.
local draw_pool={objects={},seen={},order={},entries={},visual={}}
local function clear_array(a)
 for i=#a,1,-1 do a[i]=nil end
 return a
end
local function clear_map(a)
 for k in pairs(a) do a[k]=nil end
 return a
end
function R.collect(world,stream,object_override,scratch)
  local clock=love and love.timer and love.timer.getTime
  local started=clock and clock()
  R.metrics.collect_calls=R.metrics.collect_calls+1
  local list=scratch and clear_array(scratch.objects) or {}
  local seen=scratch and clear_map(scratch.seen) or {}
  local immutable=stable_population(world)
  local onscreen=type(object_override)=="table" and
    object_override.provider and (object_override.provider.object_chunks or
      object_override.provider.rendered_chunks)
  for _,chunk in ipairs(onscreen or stream:visible()) do
    -- Only the opt-in 25D renderer gates visual population by GPU-ready
    -- terrain. Gameplay, harvest state and legacy renderer are unchanged.
    if not (type(object_override)=="table" and not chunk._25d_meshes) then
    -- Portable build never performs a cold ecology query inside love.draw:
    -- a small budgeted coroutine in love.update publishes the candidates.
    local mobile=type(object_override)=="table" and
      object_override.provider and object_override.provider.compact
    if not mobile or (chunk._object_render_world==world and
       chunk._object_render_candidates) then
    local items
    if immutable then
      if chunk._object_render_world~=world or
        not chunk._object_render_candidates then
        local cold_started=clock and clock()
        local all=world:objects_in({min_x=chunk.x,min_y=chunk.y,
          max_x=chunk.x+chunk.size,max_y=chunk.y+chunk.size},true)
        R.metrics.cold_queries=R.metrics.cold_queries+1
        if cold_started then
          local ms=(clock()-cold_started)*1000
          R.metrics.cold_query_ms=R.metrics.cold_query_ms+ms
          R.metrics.cold_query_max_ms=math.max(R.metrics.cold_query_max_ms,ms)
        end
        local owned={}
        for _,o in ipairs(all) do
          if o.cx==chunk.cx and o.cy==chunk.cy then
            owned[#owned+1]=o
          end
        end
        chunk._object_render_candidates=owned
        chunk._object_render_world=world
      end
      items=chunk._object_render_candidates
    else
      items=world:objects_in({min_x=chunk.x,min_y=chunk.y,
        max_x=chunk.x+chunk.size,max_y=chunk.y+chunk.size})
    end
    for _,o in ipairs(items) do
      if (not immutable or not world:is_depleted(o.id)) and
        o.cx==chunk.cx and o.cy==chunk.cy and not seen[o.id] then
        list[#list+1]=o;seen[o.id]=true
      end
    end
    end -- mobile object candidates prepared
    end -- 25D visible/ready gate
  end
  if started then
    local ms=(clock()-started)*1000
    R.metrics.collect_last_ms=ms
    R.metrics.collect_max_ms=math.max(R.metrics.collect_max_ms,ms)
  end
  return list
end
function R.draw(world,stream,camera,w,h,player,selected_id,harvesting,object_override,flags)
  flags=flags or {objects=true,rig=true}
  local perf_clock=Diagnostics.enabled and love.timer.getTime
  local perf_at=perf_clock and perf_clock() or 0
  local rig_elapsed_ms=0
  local all=R.collect(world,stream,object_override,draw_pool)
  if perf_clock then Diagnostics.measure("object_collect_ms",(perf_clock()-perf_at)*1000);perf_at=perf_clock() end
  local order=clear_array(draw_pool.order)
  local entries=draw_pool.entries
  local player_entry=entries[1]
  if not player_entry then
    player_entry={};entries[1]=player_entry
  end
  player_entry.id="!player"
  player_entry.depth=Depth.key(player.x,player.y)
  player_entry.player=true
  player_entry.object=nil
  order[1]=player_entry
  for i,o in ipairs(all) do
    local slot=i+1
    local entry=entries[slot]
    if not entry then entry={};entries[slot]=entry end
    entry.id=o.id
    entry.depth=Depth.key(o.x,o.y)
    entry.player=nil
    entry.object=o
    order[slot]=entry
  end
  table.sort(order,Depth.before)
  if perf_clock then Diagnostics.measure("depth_sort_ms",(perf_clock()-perf_at)*1000);perf_at=perf_clock() end
  -- Same collection/depth sort; eliminate all object/shadow renderer setup.
  if flags.object_collect_only then return #all end
  if type(object_override)=="table" then
    object_override.skip_gpu_draw=flags.skip_object_gpu==true
    if flags.skip_object_gpu then
      assert(object_override.static_manifest,
        'GPU-submit test requires prebaked static shadow atlas')
    end
  end
  local g=love.graphics
  g.push("all")
  if type(object_override)=="table" and flags.objects~=false then
    object_override:begin_frame()
    -- Render projected source-alpha shadows below ALL Y-sorted sprites and
    -- the player, so an afternoon shadow never paints over a closer tree.
    object_override:draw_shadows(g,camera,w,h,all)
    if perf_clock then Diagnostics.measure("shadows_ms",(perf_clock()-perf_at)*1000);perf_at=perf_clock() end
  end
  -- Shadow SpriteBatch was filled, but no sprite queues or GPU draws run.
  if flags.object_shadow_cpu_only then g.pop();return #all end
  local static_cached=type(object_override)=="table"
    and flags.objects~=false and not flags.opaque_objects
    and not flags.skip_object_gpu and not selected_id
    and object_override.prepare_cached_objects
    and object_override:prepare_cached_objects(camera,w,h,order) or false
  -- Only the legacy plasma mode uses autonomous tools. The rig follows the
  -- approved harvest clip and exposes the right-hand socket for future items.
  local visual=clear_map(draw_pool.visual)
  if harvesting and harvesting.active then
    local source=world:get(harvesting.active.object_id)
    if source and (source.kind=="rock" or source.kind=="tree") then
      visual.tool=source.kind=="tree" and "axe" or "pickaxe"
      visual.tool_seconds=harvesting.active.elapsed
      visual.facing=Direction.from_world(source.x-player.x,source.y-player.y,player.facing)
    end
  end
  -- Diagnostic only. Disable GPU alpha blending for the same original
  -- object geometry/count/ordering. Transparent texels will overwrite the
  -- background; this is intentionally NOT a production visual mode.
  -- Shadows above are measured unchanged; Rigby is off in this profile.
  if flags.opaque_objects then g.setBlendMode('replace') end
  for _,entry in ipairs(order) do
    if entry.player then
      if static_cached then object_override:draw_cached_objects(g,camera,w,h,1) end
      if flags.rig~=false then
        if type(object_override)=="table" and flags.objects~=false and not static_cached then object_override:flush(g) end
        if flags.opaque_objects then g.setBlendMode('alpha') end
        local rig_start=perf_clock and perf_clock()
        player_sprite(g,camera,w,h,player,visual)
        if rig_start then
          local elapsed=(perf_clock()-rig_start)*1000
          rig_elapsed_ms=rig_elapsed_ms+elapsed
          Diagnostics.measure("rigby_ms",elapsed)
        end
      end
    elseif not entry.player and flags.objects~=false and type(object_override)=="table" then
      if not static_cached then
        object_override:queue(g,camera,w,h,entry.object,entry.id==selected_id)
      end
    elseif not entry.player and flags.objects~=false then
      (object_override or object_sprite)(g,camera,w,h,entry.object,entry.id==selected_id)
    end
  end
  if static_cached then object_override:draw_cached_objects(g,camera,w,h,2) end
  if type(object_override)=="table" and not static_cached then object_override:flush(g) end
  if perf_clock then
    -- Exclusive sprite queue/flush time: omit player Rigby draw and shadows.
    Diagnostics.measure("sprite_pipeline_ms",math.max(0,
      (perf_clock()-perf_at)*1000-rig_elapsed_ms))
  end
  g.pop()
  return #all
end
function R.pick(world,stream,camera,w,h,sx,sy)
  local closest,best=nil,math.huge
  for _,o in ipairs(R.collect(world,stream)) do
    local x,y=camera:project(o.x,o.y,w,h)
    local height=o.kind=="tree" and 42 or 15
    local dx=(sx-x)/camera.zoom
    local dy=(sy-y)/camera.zoom+height
    local d=dx*dx+(dy*.7)*(dy*.7)
    local threshold=o.kind=="tree" and 32 or 22
    if d<threshold*threshold and d<best then closest,best=o,d end
  end
  return closest
end
return R
