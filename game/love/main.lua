-- Integrated procedural world and playable placeholder player.
local Query=require("world.world_query")
local Stream=require("world.stream")
local Terrain=require("world.terrain_renderer")
local Adapter=require("world.collision_adapter")
local ObjectWorld=require("objects.world")
local ObjectQuery=require("objects.query")
local Harvest=require("objects.harvesting")
local Inventory=require("systems.inventory")
local Craft=require("systems.crafting")
local Building=require("systems.building")
local Uuid=require("systems.uuid")
local StageHUD=require("core.stage5_hud")
local PlacedRenderer=require("systems.placed_renderer")
local ObjectRenderer=require("objects.renderer")
local Controller=require("player.controller")
local Collision=require("physics.collision")
local Joystick=require("player.joystick")
local Camera=require("core.camera")
local Iso=require("world.iso")
local Stage6Session=require("save.production_session")
local Stage6Clone=require("save.stage5_domain_clone")
local CharacterProgression=require("progression.character")
local StatHud=require("progression.hud")
local stage6_enabled=os.getenv("OSMAN_STAGE6_EXPLICIT")=="1"
local stage6_create=os.getenv("OSMAN_STAGE6_CREATE")=="1"
local stage6_reopen_smoke=os.getenv("OSMAN_STAGE6_REOPEN_SMOKE")=="1"
local stat_smoke=os.getenv("OSMAN_LOVE_STAT_SMOKE")=="1"
local stat_viewport=os.getenv("OSMAN_STAT_DISPLAY")
local stage6_world_id=os.getenv("OSMAN_STAGE6_WORLD_ID")
local r2_pilot_enabled=os.getenv("OSMAN_R2_PILOT")=="1"
local cache_pilot_enabled=os.getenv("OSMAN_CHUNK_CACHE_PILOT")=="1"
local terrain25d_enabled=os.getenv("OSMAN_25D_RUNTIME")=="1"
local terrain25d_smoke=os.getenv("OSMAN_25D_SMOKE")=="1"
local shadow_preview=terrain25d_smoke and
  os.getenv("OSMAN_25D_SHADOW_PREVIEW")=="1"
local terrain25d_compare=os.getenv("OSMAN_25D_COMPARE")=="1"
assert(not terrain25d_compare or r2_pilot_enabled,
  "25D comparison requires authored R2 pilot")
assert(not terrain25d_enabled or (r2_pilot_enabled and not cache_pilot_enabled),
  "25D render requires R2 pilot without legacy geometry cache")
assert(not terrain25d_smoke or terrain25d_enabled,"25D smoke requires opt-in renderer")
local Runtime25D=terrain25d_enabled and require("world.terrain25d_runtime") or nil
local Sprites25D=terrain25d_enabled and require("objects.terrain25d_sprites") or nil
assert(not (cache_pilot_enabled and stage6_enabled),
 "experimental geometry cache cannot coexist with Stage6 until accepted")
assert(not (r2_pilot_enabled and (stage6_enabled or stage6_create or stage6_reopen_smoke)),
  "R2 pilot is session-only; Stage6 save/create/reopen flags are forbidden")
local r2_pilot=r2_pilot_enabled and require("world.r2_playable").new() or nil
local r2_pilot_smoke=r2_pilot and os.getenv("OSMAN_R2_G_SMOKE")=="1"
  and require("tests.r2_pilot_smoke") or nil
local stage6_session,stage6_bridge,stage6_domain
-- Declare live bindings before the publisher closure: Lua locals start at
-- their declaration, not at their later initialization.
local objects,solid,inventory,crafting,harvesting,building,player
local function publish_stage6(staged)
  -- All production references are rebound in one non-yielding callback.
  assert(staged and staged.inventory and staged.world and staged.solid
    and staged.crafting and staged.harvesting and staged.building)
  objects=staged.world
  solid=staged.solid
  inventory=staged.inventory
  crafting=staged.crafting
  harvesting=staged.harvesting
  building=staged.building
  if player then
    player.query=building
    player:stop_navigation()
  end
end

local query=r2_pilot and r2_pilot.query or Query.new(20261015)
local water=r2_pilot and r2_pilot.water or Adapter.new(query,8)
objects=r2_pilot and r2_pilot.objects or ObjectWorld.new(query,water)
solid=r2_pilot and r2_pilot.solid or ObjectQuery.new(water,objects)
inventory=Inventory.new(12)
crafting=Craft.new(inventory)
harvesting=Harvest.new(objects,38,inventory)
local stage_hud=StageHUD.new()
local stat_hud=StatHud.new()
local progression -- Session-only until a versioned Stage6 migration is approved.
local placement_target=nil
local placement_rotation=0
local chunk_cache=cache_pilot_enabled and
  require("world.chunk_cache").new({seed=query.seed,
   stamp=r2_pilot and "r2-fisilti-20261019-pinned" or "v1-generator-20261015",
   size=256,step=r2_pilot and 8 or 32,quality="standard"}) or nil
local runtime25d,sprite25d_draw
local shadow_preview_step=0
local shadow_preview_hours={8,12,17}
local stream=Stream.new(query,r2_pilot and
  {size=256,step=8,max_loaded=48,build_budget=8,cache=chunk_cache,
   prefetch_options=cache_pilot_enabled and r2_pilot.render_options or nil} or
  {size=256,step=32,max_loaded=100,build_budget=5,cache=chunk_cache,
   prefetch_options=cache_pilot_enabled and {quality="standard"} or nil})
local long_mode=os.getenv("OSMAN_R2_LONG_TRAVERSAL")
assert(not long_mode or
  (r2_pilot_enabled and not stage6_enabled and
   (long_mode=="baseline" or long_mode=="cold" or long_mode=="warm") and
   cache_pilot_enabled==(long_mode~="baseline")),
  "long traversal requires R2 + matching cache mode, no Stage6")
local long_driver
local boot_ready=not cache_pilot_enabled
local boot_started=0
local camera=Camera.new()
if r2_pilot then r2_pilot:mount_camera(camera) end
local joystick=Joystick.new(64)
local w,h=720,1100
local fingers={}
local pinch_distance=nil
local stage5_runtime_smoke=os.getenv("OSMAN_LOVE_STAGE5_RUNTIME_SMOKE")=="1"
local stage5_display=os.getenv("OSMAN_STAGE5_DISPLAY")
local stage5_smoke_step=0
local stage4_smoke=os.getenv("OSMAN_LOVE_STAGE4_SMOKE")=="1"
local liquid_smoke=os.getenv("OSMAN_LOVE_LIQUID_SMOKE")=="1"
local smoke=stage4_smoke or liquid_smoke or os.getenv("OSMAN_LOVE_SMOKE")=="1" or os.getenv("OSMAN_LOVE_INTEGRATION_SMOKE")=="1"
local frames=0
local perf_sample={update={},draw={},peakKiB=0}
local compare_metrics={update={},draw={},frame={}}
local last_update_ms=0
local function perf_tick(name,started)
 local a=perf_sample[name]
 a[#a+1]=(love.timer.getTime()-started)*1000
 perf_sample.peakKiB=math.max(perf_sample.peakKiB,collectgarbage("count"))
end
local function perf_report(mode)
 local function metrics(a)
  local b={} for i,n in ipairs(a) do b[i]=n end
  table.sort(b)
  local function q(p) return b[math.max(1,math.ceil(#b*p))] or 0 end
  return string.format("p50=%.3f p95=%.3f p99=%.3f max=%.3f",
    q(.5),q(.95),q(.99),q(1))
 end
 collectgarbage("collect")
 print(string.format("CHUNK_CACHE_FRAME_METRICS mode=%s update[%s] draw[%s] peakKiB=%.0f afterGCKiB=%.0f",
  mode,metrics(perf_sample.update),metrics(perf_sample.draw),
  perf_sample.peakKiB,collectgarbage("count")))
end
local screenshot_done=false
local stage5_world_shot=false
local stats={loaded=0,needed=0,pending=0}
local joystick_center
local route_status=""
local selected_target=nil
local command_number=0
local safe_area
local object_count=0
local stage4_before=false
local function next_command(prefix)
  -- Session counters repeat after restart. Persisted command IDs must not.
  if stage6_enabled then return prefix..":"..Uuid.new(love.math.random) end
  command_number=command_number+1
  return prefix..":"..command_number
end
local function begin_recipe(id)
  if stage6_enabled then
    local command=next_command("craft")
    local ok,why=stage6_bridge:run(command,"craft",{
      recipe_id=id,station_tags=building:station_tags_near(player.x,player.y,60),
      player_x=player.x,player_y=player.y})
    route_status=ok and "crafted" or why
    return {ok=ok,status=route_status}
  end
  local result=crafting:begin(next_command("craft"),id,
    building:station_tags_near(player.x,player.y,60))
  route_status=result.status
  return result
end
local function place_workbench()
  if r2_pilot then
    route_status="R2 building unavailable: no approved build zones";return
  end
  if not placement_target then route_status="Tap dry ground to preview";return end
  local target=placement_target
  local allowed,reason=building:preview("core:workbench",target.x,target.y,
    placement_rotation,player.x,player.y)
  if not allowed then route_status=reason;return end
  local result
  local build_command
  if stage6_enabled then
    local ok,why=stage6_bridge:run(next_command("build"),"build",{
      instance_id=Uuid.new(love.math.random),def_id="core:workbench",
      x=target.x,y=target.y,rotation=placement_rotation,
      player_x=player.x,player_y=player.y,owner_id="player:local"})
    result={ok=ok,status=ok and "placed" or why}
  else
    build_command=next_command("place")
    result=building:place(build_command,Uuid.new(love.math.random),
      "core:workbench",target.x,target.y,placement_rotation,player.x,player.y,
      "player:local")
  end
  route_status=result.status
  if result.ok then
    stage_hud.placing=false;placement_target=nil
    if not stage6_enabled and build_command then
      progression:grant("build_complete",build_command)
    end
  end
  return result
end
local function hud_action(id)
  if id=="inventory" then stage_hud.open=not stage_hud.open
  elseif id=="build" then
    if inventory:count("core:workbench")<1 then route_status="Craft a bench first"
    else stage_hud.placing=true;stage_hud.open=false
      placement_target=nil;route_status="Tap dry ground, then CONFIRM" end
  elseif id=="rotate" then placement_rotation=(placement_rotation+1)%4
  elseif id=="confirm" then place_workbench()
  elseif id=="cancel" then stage_hud.placing=false;placement_target=nil
  elseif id:sub(1,5)=="slot:" then
    stage_hud.selected=tonumber(id:sub(6))
  elseif id:sub(1,7)=="recipe:" then
    begin_recipe(id:sub(8))
  end
end
local function stat_action(action)
  if action=="stats_toggle" then
    stat_hud.open=not stat_hud.open
    if stat_hud.open then stage_hud.open=false end
  elseif action:sub(1,10)=="stats_add:" then
    local ok,why=progression:spend(action:sub(11))
    route_status=ok and "Stat allocated (session only)" or why
  end
end
local function smoke_tap(id)
  local sx,sy,sw,sh=safe_area()
  local safe={x=sx,y=sy,w=sw,h=sh}
  for _,b in ipairs(stage_hud:layout(safe)) do
    if b.id==id then
      local x,y=b.x+b.w*.5,b.y+b.h*.5
      assert(stage_hud:hit(x,y,safe)==id,"smoke control overlap: "..id)
      love.touchpressed("stage5_ui_"..id,x,y)
      love.touchreleased("stage5_ui_"..id,x,y)
      return
    end
  end
  error("missing smoke touch control "..id)
end
local debug_view=os.getenv("OSMAN_LOVE_BIOME_SMOKE")=="1"
local function spawn()
  if r2_pilot then return r2_pilot:spawn_player(building) end
  for radius=0,512,16 do
    for y=-radius,radius,16 do for x=-radius,radius,16 do
      if radius==0 or math.max(math.abs(x),math.abs(y))==radius then
        local ok,p=pcall(Controller.new,building,{x=x,y=y,radius=5,speed=96})
        if ok then return p end
      end
    end end
  end
  error("No safe player spawn found within 512 world units")
end
function love.load()
  boot_started=love.timer.getTime()
  if terrain25d_compare then
    local v=os.getenv("OSMAN_25D_COMPARE_DISPLAY") or "360x780"
    local ww,hh=v:match("^(%d+)x(%d+)$")
    assert(ww and hh,"invalid comparable viewport")
    assert(love.window.setMode(tonumber(ww),tonumber(hh),{vsync=0,resizable=false}))
  end
  if terrain25d_enabled then
    runtime25d=Runtime25D.new(r2_pilot)
    local sprites=Sprites25D.new(runtime25d,runtime25d.manifest)
    sprite25d_draw=sprites
  end
  if os.getenv("OSMAN_CACHE_DISPLAY") then
    local ww,hh=os.getenv("OSMAN_CACHE_DISPLAY"):match("^(%d+)x(%d+)$")
    assert(ww and hh and tonumber(ww)>=320 and tonumber(hh)>=480)
    assert(love.window.setMode(tonumber(ww),tonumber(hh),{resizable=false}))
  end
  if stat_smoke and stat_viewport then
    local vw,vh=stat_viewport:match("^(%d+)x(%d+)$")
    assert(vw and vh and tonumber(vw)>=320 and tonumber(vh)>=480,
      "invalid stat smoke viewport")
    assert(love.window.setMode(tonumber(vw),tonumber(vh),{resizable=false}),
      "cannot set stat smoke viewport")
  end
  if stage5_runtime_smoke and stage5_display then
    local vw,vh=stage5_display:match("^(%d+)x(%d+)$")
    assert(vw and vh and tonumber(vw)>=320 and tonumber(vh)>=700,
      "unsupported Stage5 smoke viewport")
    assert(love.window.setMode(tonumber(vw),tonumber(vh),{resizable=false}),
      "unable to set Stage5 portrait viewport")
    if tonumber(vw)==320 then love.graphics.setNewFont(16) end
  end
  w,h=love.graphics.getDimensions()
  progression=CharacterProgression.new({
    player_id="player:local",
    core_instance_id=Uuid.new(love.math.random),
    core_definition_id="core:standard"
  })
  -- Session-local v4 ID: no disk save or network host claim.
  building=Building.new(inventory,query,solid,Uuid.new(love.math.random))
  if stage6_enabled then
    assert(stage6_world_id and #stage6_world_id>0,
      "Stage6 explicit world ID required; no implicit save creation")
    building=Building.new(inventory,query,solid,stage6_world_id)
    stage6_domain={query=query,solid=solid,world=objects,inventory=inventory,
      crafting=crafting,harvesting=harvesting,building=building}
    local session,reason=Stage6Session.open(stage6_domain,{
      world_id=stage6_world_id,create=stage6_create,
      player_id="player:local",x=0,y=0})
    assert(session,"Stage6 refused to open: "..tostring(reason))
    stage6_session=session
    publish_stage6(stage6_domain)
    stage6_bridge=session:bridge(stage6_domain,function(staged)
      -- No fallible work after Store.commit: validate before publishing.
      assert(staged.inventory and staged.world and staged.solid and
        staged.crafting and staged.harvesting and staged.building)
      Stage6Clone.publish(stage6_domain,staged)
      publish_stage6(stage6_domain)
    end)
  end
  player=spawn()
  if long_mode then
    long_driver=require("tests.r2_long_traversal").new(long_mode,stream,chunk_cache)
  end
  -- Cold-boot and baseline must use the SAME R2 spawn camera before draw.
  if cache_pilot_enabled then camera.x,camera.y=player.x,player.y end
  if stage6_session then
    player.query=building
    player.x,player.y=stage6_session.position.x,stage6_session.position.y
    camera.x,camera.y=player.x,player.y
  end
  if liquid_smoke then
    local found=false
    for y=-128,128,32 do
      for x=1408,1792,32 do
        if query:get_feature(x,y)=="water" and Collision.can_stand(building,x,y,player.radius) then
          player=Controller.new(building,{x=x,y=y,radius=5,speed=96})
          found=true
          break
        end
      end
      if found then break end
    end
    assert(found and player.immersion==0.5,"liquid screenshot requires safe wet spawn")
  end
  camera.x,camera.y=player.x,player.y
  if debug_view then camera.x,camera.y=-960,-960 end
  if stat_smoke then
    assert(progression:grant("quest_complete","smoke:stat:quest"))
    assert(progression.state.character_level==2)
    assert(progression:spend("etkime"))
    stat_hud.open=true
  end
  if stage5_runtime_smoke then
    -- Same COLLECT touch callback used by real players; no direct item injection.
    local selected=false
    for _,o in ipairs(objects:objects_in({min_x=-384,min_y=-384,max_x=384,max_y=384})) do
      if o.kind=="tree" then
        for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local x=o.x+d[1]*(o.radius+23)
          local y=o.y+d[2]*(o.radius+23)
          if Collision.can_stand(building,x,y,player.radius) then
            player.x,player.y=x,y
            camera.x,camera.y=x,y
            local sx,sy,sw,sh=safe_area()
            love.touchpressed("stage5_test",sx+sw-75,sy+sh-140)
            love.touchreleased("stage5_test",sx+sw-75,sy+sh-140)
            if selected_target then selected=true;break end
          end
        end
        if selected then break end
      end
    end
    assert(selected,"No Stage5 interactive harvest fixture")
    stage_hud.open=true
  end
  if stage4_smoke then
    -- Exercise the real touch-button interaction callback, not direct deplete.
    local selected=false
    for _,o in ipairs(objects:objects_in({min_x=-384,min_y=-384,max_x=384,max_y=384})) do
      for _,direction in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local x=o.x+direction[1]*(o.radius+23)
        local y=o.y+direction[2]*(o.radius+23)
        if Collision.can_stand(solid,x,y,player.radius) then
          player.x,player.y=x,y
          camera.x,camera.y=x,y
          local sx,sy,sw,sh=safe_area()
          local bx,by=joystick_center()
          love.touchpressed("stage4_joystick",bx,by)
          love.touchpressed("stage4_smoke",sx+sw-75,sy+sh-140)
          love.touchreleased("stage4_smoke",sx+sw-75,sy+sh-140)
          love.touchreleased("stage4_joystick",bx,by)
          assert(joystick.id==nil,"joystick owner stuck after touch collection")
          if selected_target then selected=true;break end
        end
      end
      if selected then break end
    end
    assert(selected,"No valid touch-harvest fixture")
  end
  if r2_pilot_smoke then
    r2_pilot_smoke.load({pilot=r2_pilot,player=player,building=building,
      objects=objects,inventory=inventory,camera=camera,w=w,h=h})
  end
  if stage6_reopen_smoke then
    assert(stage6_enabled and not stage6_create and stage6_session,
      "Stage6 reopen smoke requires an existing explicit world")
    assert(stage6_session.revision>=4 and building.revision==1
      and next(building.placed)~=nil and next(objects.delta)~=nil,
      "Stage6 reopened state lost harvest/craft/build mutations")
    assert(stage6_domain.world==objects and stage6_domain.inventory==inventory
      and stage6_domain.building==building and player.query==building,
      "Stage6 reopened live graph bindings are stale")
    print("LOVE_STAGE6_REOPEN_OK revision="..stage6_session.revision)
    io.stdout:flush()
  end
end
function love.resize(width,height) w,h=width,height end
local function keyboard()
  local sx=(love.keyboard.isDown("d","right") and 1 or 0)-(love.keyboard.isDown("a","left") and 1 or 0)
  local sy=(love.keyboard.isDown("s","down") and 1 or 0)-(love.keyboard.isDown("w","up") and 1 or 0)
  local jx,jy=joystick:axis()
  if joystick.id~=nil then sx,sy=jx,jy end
  local wx,wy=Iso.unproject(sx,sy)
  local mag=math.sqrt(wx*wx+wy*wy)
  if mag>0 and (sx~=0 or sy~=0) then wx,wy=wx/mag,wy/mag end
  return wx,wy
end
function love.update(dt)
  local perf_begin=love.timer.getTime()
  if runtime25d then runtime25d:advance_sun(dt) end
  if cache_pilot_enabled and not boot_ready then
    stats=stream:update(camera,w,h)
    local ready=stats.pending==0 and stats.loaded>0
    for _,c in ipairs(stream:visible()) do
      if not c._terrain_meshes then ready=false;break end
    end
    if ready then
      boot_ready=true
      print(string.format("CHUNK_CACHE_GAME_READY ms=%.2f hits=%d misses=%d",
       (love.timer.getTime()-boot_started)*1000,
       chunk_cache.metrics.hits,chunk_cache.metrics.misses))
      io.stdout:flush()
    end
    perf_tick("update",perf_begin)
    return
  end
  if long_driver then
    long_driver:beforeUpdate(player,camera)
  else
    local ax,ay=keyboard()
    player:update(dt,ax,ay)
    if r2_pilot then
      local nav=player:take_navigation_result()
      if nav then
        if not nav.ok then
          route_status=selected_target and "No approach route" or
            ("No path: "..tostring(nav.reason))
          selected_target=nil
        elseif selected_target then route_status="Approaching resource"
        else route_status="Navigating" end
      end
    end
  end
  if selected_target and not harvesting.active and (not stage4_smoke or stage4_before) then
    local o=objects:get(selected_target)
    if not o or objects:is_depleted(selected_target) then selected_target=nil
    elseif (o.x-player.x)^2+(o.y-player.y)^2<=(harvesting.range+o.radius)^2 then
      local result
      if stage6_enabled then
        local ok,why=stage6_bridge:run(next_command("harvest"),"harvest",{
          object_id=o.id,x=player.x,y=player.y,duration=8,
          player_x=player.x,player_y=player.y})
        result={ok=ok,status=ok and "complete" or why}
      else
        result=harvesting:begin(next_command("harvest"),o.id,player.x,player.y)
      end
      route_status=result.ok and "Gathering "..o.kind or result.status
      selected_target=nil
      player:stop_navigation()
    end
  end
  if not stage6_enabled then harvesting:update(dt,player.x,player.y) end
  for _,event in ipairs(harvesting:drain_events()) do
    -- Harvest already atomically credited the inventory before emitting.
    assert(inventory.applied[event.transaction_id],"uncredited harvest event")
    route_status="Collected "..event.amount.." "..event.item_id
    if not stage6_enabled then
      progression:grant("harvest_complete",event.command_id)
    end
  end
  local craft_command=crafting.active and crafting.active.command_id
  local result=not stage6_enabled and crafting:update(dt,building:station_tags_near(player.x,player.y,60))
  if result then
    route_status=result.status
    if result.ok and craft_command then
      progression:grant("craft_complete",craft_command)
    end
  end
  if stage5_runtime_smoke then
    if stage5_smoke_step==0 and inventory:count("core:wood_log")>=3 then
      stage5_smoke_step=1;smoke_tap("recipe:core:planks_from_log")
    elseif stage5_smoke_step==1 and inventory:count("core:wood_plank")>=4 then
      stage5_smoke_step=2;smoke_tap("recipe:core:bench_from_planks")
    elseif stage5_smoke_step==2 and inventory:count("core:workbench")>=1 then
      stage5_smoke_step=3
      smoke_tap("build")
      local sx,sy,sw,sh=safe_area()
      local safe={x=sx,y=sy,w=sw,h=sh}
      for oy=-80,80,16 do
        for ox=-80,80,16 do
          if ox~=0 or oy~=0 then
            local x=math.floor((player.x+ox)/16+.5)*16
            local y=math.floor((player.y+oy)/16+.5)*16
            local px,py=camera:project(x,y,w,h)
            if px>sx+10 and px<sx+sw-10 and py>sy+150 and py<sy+sh-390
              and not stage_hud:hit(px,py,safe)
              and building:preview("core:workbench",x,y,0,player.x,player.y) then
              love.touchpressed("stage5_ground",px,py)
              love.touchreleased("stage5_ground",px,py)
              if placement_target and placement_target.x==x
                and placement_target.y==y then break end
            end
          end
        end
        if placement_target then break end
      end
      assert(placement_target,"Stage5 smoke no valid touch placement")
      smoke_tap("confirm")
      assert(building.revision==1,"Stage5 smoke placement failed")
      stage_hud.open=true
    end
  end
  if terrain25d_smoke or terrain25d_compare then camera.x,camera.y=704,128
  elseif not debug_view then camera.x,camera.y=player.x,player.y end
  stats=stream:update(camera,w,h)
  if terrain25d_compare then
    last_update_ms=(love.timer.getTime()-perf_begin)*1000
  end
  if long_driver then long_driver:afterUpdate(stats) end
  if os.getenv("OSMAN_CHUNK_CACHE_BASELINE_SMOKE")=="1"
   or os.getenv("OSMAN_CHUNK_CACHE_SMOKE")=="1" then
    perf_tick("update",perf_begin)
  end
end
function love.draw()
  local perf_begin=love.timer.getTime()
  if long_driver and boot_ready and long_driver.frame>0 then long_driver:beforeDraw() end
  if runtime25d then runtime25d:draw(stream,camera,w,h)
  else Terrain.draw(stream,camera,w,h,r2_pilot and r2_pilot.render_options) end
  if cache_pilot_enabled and not boot_ready then
    local g=love.graphics
    local ready=0
    for _,c in ipairs(stream:visible()) do
      if c._terrain_meshes then ready=ready+1 end
    end
    g.clear(.04,.07,.08,1)
    g.setColor(.93,.96,.90)
    g.print("Preparing the world",math.max(20,w*.1),h*.44)
    g.setColor(.19,.39,.38)
    g.rectangle("fill",w*.1,h*.5,w*.8,14)
    g.setColor(.53,.85,.68)
    g.rectangle("fill",w*.1,h*.5,w*.8*ready/math.max(1,stats.needed),14)
    g.setColor(1,1,1)
    g.print(string.format("%d / %d chunks",ready,stats.needed),w*.1,h*.54)
    perf_tick("draw",perf_begin)
    return
  end
  object_count=ObjectRenderer.draw(objects,stream,camera,w,h,player,
    selected_target,harvesting,sprite25d_draw)
  local ghost
  if not r2_pilot and stage_hud.placing and placement_target then
    local ok=building:preview("core:workbench",placement_target.x,placement_target.y,
      placement_rotation,player.x,player.y)
    ghost={x=placement_target.x,y=placement_target.y,ok=ok}
  end
  PlacedRenderer.draw(building,camera,w,h,ghost)
  local g=love.graphics
  local safe_x,safe_y,safe_w,safe_h=safe_area()
  g.setColor(.05,.12,.12,.75)
  g.rectangle("fill",safe_x+8,safe_y+8,math.min(safe_w-16,600),124,12,12)
  g.setColor(1,1,1)
  if safe_w<420 then
    g.print((r2_pilot and "R2 PILOT / " or "WORLD / ")..query.seed,safe_x+18,safe_y+15)
    g.print(string.format("Chunks %d  Objects %d",stats.loaded,object_count),
      safe_x+18,safe_y+38)
    g.print(string.format("Log %d  Plank %d  Bench %d",
      inventory:count("core:wood_log"),inventory:count("core:wood_plank"),
      building.revision),safe_x+18,safe_y+61)
  else
    g.print((r2_pilot and "R2 FISILTI / seed " or "WORLD OBJECTS / seed ")..query.seed,safe_x+18,safe_y+15)
    g.print(string.format("Chunks %d/%d  Objects %d  State %s",stats.loaded,stats.needed,object_count,player.state),safe_x+18,safe_y+38)
    g.print(string.format("Logs %d  Planks %d  Stone %d  Benches %d",
      inventory:count("core:wood_log"),inventory:count("core:wood_plank"),
      inventory:count("core:stone"),building.revision),safe_x+18,safe_y+61)
  end
  if route_status~="" then g.print(route_status,safe_x+18,safe_y+84) end
  if harvesting.active then
    g.setColor(.14,.25,.23,.85)
    g.rectangle("fill",safe_x+18,safe_y+106,190,9)
    g.setColor(.96,.75,.28)
    g.rectangle("fill",safe_x+18,safe_y+106,190*harvesting:progress(),9)
  end
  g.setColor(.12,.30,.31,.76)
  g.rectangle("fill",safe_x+safe_w-136,safe_y+safe_h-175,122,66,13,13)
  g.setColor(1,.95,.83)
  g.print("COLLECT",safe_x+safe_w-120,safe_y+safe_h-149)
  local hud_safe={x=safe_x,y=safe_y,w=safe_w,h=safe_h}
  stage_hud:draw(inventory,crafting,hud_safe,placement_rotation,route_status)
  stat_hud:draw(g,hud_safe,progression)
  local bx,by=joystick_center()
  g.setColor(.2,.3,.34,.6)
  g.circle("fill",bx,by,72)
  g.setColor(.95,.95,.9,.7)
  g.circle("fill",bx+joystick.dx*55,by+joystick.dy*55,22)
  g.setColor(1,1,1)
  frames=frames+1
  if cache_pilot_enabled and os.getenv("OSMAN_CHUNK_CACHE_PREFETCH_SMOKE")=="1"
    and boot_ready and (chunk_cache.metrics.prefetch_writes or 0)>=1 then
    print(string.format("CHUNK_CACHE_PREFETCH_OK prepared=%d bytes=%d",
      chunk_cache.metrics.prefetch_writes,chunk_cache.bytes))
    perf_report("prefetch")
    io.stdout:flush();love.event.quit();return
  end
  if os.getenv("OSMAN_CHUNK_CACHE_BASELINE_SMOKE")=="1" and frames>=60
   and stats.pending==0 then
    local complete=true
    for _,c in ipairs(stream:visible()) do
      if not c._terrain_meshes then complete=false;break end
    end
    if complete then
      love.graphics.captureScreenshot("chunk-cache-baseline.png")
      print(string.format("CHUNK_CACHE_BASELINE_READY ms=%.2f chunks=%d memoryKiB=%.0f",
        (love.timer.getTime()-boot_started)*1000,stats.loaded,collectgarbage("count")))
      perf_report("baseline")
      io.stdout:flush();love.event.quit();return
    end
  end
  if cache_pilot_enabled and os.getenv("OSMAN_CHUNK_CACHE_SMOKE")=="1"
    and frames>=60 and stats.pending==0
    and chunk_cache.metrics.writes+chunk_cache.metrics.hits>=stats.loaded then
    love.graphics.captureScreenshot("chunk-cache-game.png")
    print(string.format("CHUNK_CACHE_GAME_SMOKE_OK hits=%d misses=%d invalid=%d writes=%d prefetch=%d bytes=%d memoryKiB=%.0f",
     chunk_cache.metrics.hits,chunk_cache.metrics.misses,chunk_cache.metrics.invalid,
     chunk_cache.metrics.writes,chunk_cache.metrics.prefetch_writes or 0,
     chunk_cache.bytes,collectgarbage("count")))
    perf_report(chunk_cache.metrics.hits>0 and "warm" or "cold")
    io.stdout:flush()
    love.event.quit()
    return
  end
  if terrain25d_smoke and frames>=90 and stats.loaded>0
     and stats.pending==0 and runtime25d.visible==stats.needed then
    if shadow_preview then
      if shadow_preview_step==0 then
        shadow_preview_step=1
        runtime25d:set_sun_hour(shadow_preview_hours[1])
      else
        -- Capture identical real authored-R2 scenes at three sun positions.
        -- The hour was selected on the preceding fully rendered frame.
        local hour=shadow_preview_hours[shadow_preview_step]
        love.graphics.captureScreenshot(string.format(
          "terrain25d-sun-%02d.png",hour))
        if hour==12 then
          love.graphics.captureScreenshot("terrain25d-runtime.png")
        end
        if shadow_preview_step<3 then
          shadow_preview_step=shadow_preview_step+1
          runtime25d:set_sun_hour(shadow_preview_hours[shadow_preview_step])
        else
          print(string.format(
            "TERRAIN25D_SHADOW_PREVIEW_OK hours=08,12,17 casts=%d calls=%d",
            sprite25d_draw.shadow_objects,sprite25d_draw.shadow_calls))
          print(string.format(
            "TERRAIN25D_RUNTIME_LOVE_OK frames=%d chunks=%d built=%d calls=%d objects=%d",
            frames,stats.loaded,runtime25d.built,
            runtime25d.draw_calls,object_count))
          io.stdout:flush();love.event.quit();return
        end
      end
    else
      love.graphics.captureScreenshot("terrain25d-runtime.png")
      print(string.format(
        "TERRAIN25D_RUNTIME_LOVE_OK frames=%d chunks=%d built=%d calls=%d objects=%d",
        frames,stats.loaded,runtime25d.built,runtime25d.draw_calls,object_count))
      io.stdout:flush();love.event.quit();return
    end
  end
  if stat_smoke and frames>=25 and stats.loaded>0 and stats.pending==0 then
    assert(progression:stat("etkime")==2 and progression.state.unspent_points==1)
    love.graphics.captureScreenshot("core-stat-progression-smoke"
      ..(stat_viewport and "-"..stat_viewport or "")..".png")
    print("LOVE_STAT_SMOKE_OK level="..progression.state.character_level)
    io.stdout:flush()
    love.event.quit()
  end
  if stage5_runtime_smoke and building.revision==1 and frames>=30
    and stats.loaded>0 and stats.pending==0 and not screenshot_done then
    screenshot_done=true
    love.graphics.captureScreenshot("stage5-production-touch"
      ..(stage5_display and "-"..stage5_display or "")..".png")
    stage_hud.open=false
  elseif stage5_runtime_smoke and screenshot_done and not stage5_world_shot then
    stage5_world_shot=true
    love.graphics.captureScreenshot("stage5-production-world"
      ..(stage5_display and "-"..stage5_display or "")..".png")
    if not stage6_enabled then
      -- One completed harvest, two crafts, one placement = 130 prototype XP.
      assert(progression.state.character_level>=2,
        "Stage5 production events failed to award character XP")
      assert(progression.state.unspent_points>=2,
        "Stage5 character level failed to grant stat points")
    else
      assert(progression.state.character_xp==0 and
        progression.state.character_level==1,
        "Stage6 must not split world commit and progression XP")
    end
    print(string.format("LOVE_STAGE5_RUNTIME_SMOKE_OK chunks=%d placed=%d logs=%d",
      stats.loaded,building.revision,inventory:count("core:wood_log")))
    io.stdout:flush()
    love.event.quit()
  end
  if r2_pilot_smoke then
    r2_pilot_smoke.draw({pilot=r2_pilot,player=player,building=building,
      objects=objects,inventory=inventory,camera=camera,stats=stats,w=w,h=h})
  end
  if stage4_smoke and not stage4_before and frames>=20
     and stats.loaded>0 and stats.pending==0 then
    stage4_before=true
    love.graphics.captureScreenshot("world-objects-before.png")
  end
  if stage4_smoke and frames>1800 then error("Harvest smoke timed out before resource credit") end
  if smoke and frames>=20 and stats.loaded>0 and stats.pending==0
    and (not stage4_smoke or (stage4_before and
      inventory:count("core:wood_log")+inventory:count("core:stone")>0)) then
    if not screenshot_done then
      screenshot_done=true
      love.graphics.captureScreenshot(liquid_smoke and "water-immersion-smoke.png" or (stage4_smoke and "world-objects-smoke.png" or (debug_view and "world-player-biome-smoke.png" or "world-player-smoke.png")))
    end
    print(string.format("%s frames=%d chunks=%d objects=%d wood=%d stone=%d player=(%.1f,%.1f)",liquid_smoke and "LOVE_LIQUID_SMOKE_OK" or (stage4_smoke and "LOVE_STAGE4_SMOKE_OK" or "LOVE_INTEGRATION_SMOKE_OK"),frames,stats.loaded,object_count,inventory:count("core:wood_log"),inventory:count("core:stone"),player.x,player.y))
    io.stdout:flush()
    love.event.quit()
  end
  if os.getenv("OSMAN_CHUNK_CACHE_BASELINE_SMOKE")=="1"
   or os.getenv("OSMAN_CHUNK_CACHE_SMOKE")=="1" then
    perf_tick("draw",perf_begin)
  end
  if terrain25d_compare then
    -- Count only fully resident, complete authored R2 scenes in BOTH modes.
    -- Earlier 240-frame samples had legacy 11/42 while 25D drew 42/42,
    -- so they were NOT comparable and must never be used as acceptance.
    local draw_ms=(love.timer.getTime()-perf_begin)*1000
    local a=compare_metrics
    local ready=0
    for _,chunk in ipairs(stream:visible()) do
      if (runtime25d and chunk._25d_meshes) or
         (not runtime25d and chunk._terrain_meshes
           and not chunk._terrain_job) then ready=ready+1 end
    end
    local complete=stats.pending==0 and stats.loaded==stats.needed
      and ready==stats.needed and stats.needed>0
    if complete then
      if not a.ready_since then a.ready_since=frames end
      if frames>a.ready_since+15 then
        a.update[#a.update+1]=last_update_ms
        a.draw[#a.draw+1]=draw_ms
        a.frame[#a.frame+1]=draw_ms+last_update_ms
      end
    else
      -- Never mix provisional chunks with complete-scene measurements.
      a.ready_since=nil
      a.update={};a.draw={};a.frame={}
    end
    if #a.frame>=120 then
      local function quantiles(t)
        table.sort(t)
        local function q(p) return t[math.max(1,math.ceil(#t*p))] end
        return string.format("p50=%.4f,p95=%.4f,p99=%.4f",q(.5),q(.95),q(.99))
      end
      local mode=runtime25d and "runtime" or "legacy"
      print(string.format("TERRAIN25D_COMPARE_COMPLETE mode=%s frames=%d ready=%d/%d update[%s] draw[%s] frame[%s] luaKiB=%.0f calls=%d",
        mode,#a.frame,ready,stats.needed,
        quantiles(a.update),quantiles(a.draw),
        quantiles(a.frame),collectgarbage("count"),
        runtime25d and runtime25d.draw_calls or 0))
      love.graphics.captureScreenshot("terrain25d-compare-"..mode.."-"..w.."x"..h..".png")
      io.stdout:flush();love.event.quit();return
    end
    if frames>=2400 then
      print(string.format("TERRAIN25D_COMPARE_INCOMPLETE mode=%s ready=%d/%d",
        runtime25d and "runtime" or "legacy",ready,stats.needed))
      io.stdout:flush()
      error("comparable benchmark incomplete: not all authored R2 chunks resident")
    end
  end
  if long_driver and boot_ready and long_driver.frame>0 then
    long_driver:afterDraw(object_count)
  end
end
safe_area=function()
  if love.window and love.window.getSafeArea then
    local sx,sy,sw,sh=love.window.getSafeArea()
    if sx and sy and sw and sh and sw>0 and sh>0 then return sx,sy,sw,sh end
  end
  return 0,0,w,h
end
joystick_center=function()
  local sx,sy,sw,sh=safe_area()
  return sx+math.min(94,sw*.25),sy+sh-112
end
local function select_object(o)
  if harvesting.active then route_status="Already gathering";return end
  selected_target=o.id
  local distance=(o.x-player.x)^2+(o.y-player.y)^2
  if distance<=(harvesting.range+o.radius)^2 then return end
  -- Navigate to an approach ring outside the object's shared collision box.
  local goals={}
  for _,d in ipairs({{1,0},{0,1},{-1,0},{0,-1},{1,1},{-1,1},{-1,-1},{1,-1}}) do
    local mag=math.sqrt(d[1]*d[1]+d[2]*d[2])
    local px=o.x+d[1]/mag*(o.radius+24)
    local py=o.y+d[2]/mag*(o.radius+24)
    if math.abs(px-player.x)+math.abs(py-player.y)<2048 then
      goals[#goals+1]={x=px,y=py}
    end
  end
  if r2_pilot then
    if #goals==0 then selected_target=nil;route_status="No approach route"
    else player:navigate_candidates_async(goals,16,1024)
      route_status="Finding approach..." end
  else
    local reached=false
    for _,goal in ipairs(goals) do
      if player:navigate_to(goal.x,goal.y,16,1024) then reached=true;break end
    end
    if not reached then selected_target=nil;route_status="No approach route"
    else route_status="Approaching "..o.kind end
  end
end
local function interact_nearest()
  local best,dist=nil,math.huge
  for _,o in ipairs(objects:objects_in({min_x=player.x-65,min_y=player.y-65,
    max_x=player.x+65,max_y=player.y+65})) do
    local d=(player.x-o.x)^2+(player.y-o.y)^2
    if d<dist and d<=(harvesting.range+o.radius)^2 then best,dist=o,d end
  end
  if best then select_object(best) else route_status="Move closer to a resource" end
end
local function press(id,x,y)
  fingers[id]={x=x,y=y,origin_x=x,origin_y=y,move=false}
  local sx,sy,sw,sh=safe_area()
  local safe={x=sx,y=sy,w=sw,h=sh}
  local stat_hit=stat_hud:hit(x,y,safe)
  if stat_hit then
    fingers[id].stats=stat_hit
    return
  end
  local action=stage_hud:hit(x,y,safe)
  if action then
    fingers[id].ui=action
    return
  end
  if x>=sx+sw-136 and x<=sx+sw-14 and y>=sy+sh-175 and y<=sy+sh-109 then
    fingers[id].button=true
    return
  end
  local bx,by=joystick_center()
  if (x-bx)^2+(y-by)^2<90^2 and joystick.id==nil then
    joystick:press(id,bx,by)
    joystick:move(id,x,y)
    fingers[id].joystick=true
  else
    local n=0
    for _,p in pairs(fingers) do if not p.joystick and not p.button then n=n+1 end end
    if n>=2 then
      for _,p in pairs(fingers) do if not p.joystick and not p.button then p.multi=true end end
      pinch_distance=nil
    end
  end
end
local function move(id,x,y)
  local p=fingers[id];if not p then return end
  if p.joystick then joystick:move(id,x,y);return end
  if p.button or p.ui or p.stats then return end
  if p.multi then
    local partner
    for other,q in pairs(fingers) do if other~=id and not q.joystick and not q.button then partner=q;break end end
    if partner then
      local old=math.sqrt((p.x-partner.x)^2+(p.y-partner.y)^2)
      local new=math.sqrt((x-partner.x)^2+(y-partner.y)^2)
      if old>1 and new>1 then camera:zoom_at(new/old,(x+partner.x)/2,(y+partner.y)/2,w,h) end
    end
  end
  if (x-p.origin_x)^2+(y-p.origin_y)^2>100 then p.move=true end
  p.x,p.y=x,y
end
local function release(id,x,y)
  local p=fingers[id];if not p then return end
  if p.joystick then joystick:release(id)
  elseif p.stats then
    local sx,sy,sw,sh=safe_area()
    if stat_hud:hit(x,y,{x=sx,y=sy,w=sw,h=sh})==p.stats then
      stat_action(p.stats)
    end
  elseif p.ui then
    local sx,sy,sw,sh=safe_area()
    if stage_hud:hit(x,y,{x=sx,y=sy,w=sw,h=sh})==p.ui then
      hud_action(p.ui)
    end
  elseif p.button then interact_nearest()
  elseif not p.move and not p.multi then
    if r2_pilot and stage_hud.placing then
      route_status="R2 building unavailable: no approved build zones"
      fingers[id]=nil;return
    end
    if stage_hud.placing then
      local gx,gy=camera:unproject(x,y,w,h)
      placement_target={x=math.floor(gx/16+.5)*16,y=math.floor(gy/16+.5)*16}
      local ok,reason=building:preview("core:workbench",placement_target.x,
        placement_target.y,placement_rotation,player.x,player.y)
      route_status=ok and "Valid placement: CONFIRM" or reason
      fingers[id]=nil
      return
    end
    local target=ObjectRenderer.pick(objects,stream,camera,w,h,x,y)
    if target then select_object(target)
    else
      selected_target=nil
      local gx,gy=camera:unproject(x,y,w,h)
      if r2_pilot then
        player:navigate_candidates_async({{x=gx,y=gy}},16,1024)
        route_status="Finding route..."
      else
        local ok,reason=player:navigate_to(gx,gy,16,1024)
        route_status=ok and "Navigating" or ("No path: "..tostring(reason))
      end
    end
  end
  fingers[id]=nil
  pinch_distance=nil
  local n=0
  for _,q in pairs(fingers) do n=n+1 end
  if n==1 then for _,q in pairs(fingers) do q.multi=true end end
end
function love.touchpressed(id,x,y) press(id,x,y) end
function love.touchmoved(id,x,y) move(id,x,y) end
function love.touchreleased(id,x,y) release(id,x,y) end
function love.mousepressed(x,y,b,istouch) if b==1 and not istouch then press("mouse",x,y) end end
function love.mousemoved(x,y,_,_,istouch) if not istouch then move("mouse",x,y) end end
function love.mousereleased(x,y,b,istouch) if b==1 and not istouch then release("mouse",x,y) end end
function love.wheelmoved(_,dy)
  local x,y=love.mouse.getPosition()
  camera:zoom_at(1.15^dy,x,y,w,h)
end
function love.keypressed(key)
  if key=="p" then stat_action("stats_toggle");return end
  if stat_hud.open then
    local number=tonumber(key)
    if number and number>=1 and number<=6 then
      local names=require("progression.rules").stats
      stat_action("stats_add:"..names[number])
      return
    end
  end
  if key=="r" then camera.x,camera.y=player.x,player.y;camera.zoom=1.7 end
  if key=="escape" then player:stop_navigation();selected_target=nil end
  if key=="e" then interact_nearest() end
  if key=="i" then hud_action("inventory") end
  if key=="1" then hud_action("recipe:core:planks_from_log") end
  if key=="2" then hud_action("recipe:core:bench_from_planks") end
  if key=="b" then hud_action("build") end
  if key=="return" then hud_action("confirm") end
  if key=="q" then hud_action("rotate") end
  if key=="f5" and stage6_session then
    local ok,why=stage6_session:reload(stage6_domain)
    if ok then
      publish_stage6(stage6_domain)
      player.x,player.y=why.x,why.y
      camera.x,camera.y=player.x,player.y
      route_status="Stage6 checkpoint reloaded"
    else route_status="Stage6 reload refused: "..tostring(why) end
  end
end

-- A worker may still be compressing disposable geometry at shutdown.
-- Drain only after gameplay has stopped, never inside the frame budget.
function love.quit()
 if chunk_cache then chunk_cache:close() end
end
