-- Executed ONLY by opted-in production main.lua inside the real LÖVE loop.
-- This is a test driver; it never creates objects, writes saves or invents a ford.
local Collision=require("physics.collision")
local M={}
local stage,stage_frame,frames="spawn",0,0
local initial,river_x,river_y,fixture,approach,walk_touch
local function near(o,x,y) return (o.x-x)^2+(o.y-y)^2 end
local function choose_tree(ctx)
  local list=ctx.objects:objects_in({
    min_x=-256,min_y=-256,max_x=1024,max_y=512})
  for _,o in ipairs(list) do
    if o.kind=="tree" then
      for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local x=o.x+d[1]*(o.radius+22),y=o.y+d[2]*(o.radius+22)
        if Collision.can_stand(ctx.building,x,y,ctx.player.radius) then
          local closest
          for _,n in ipairs(ctx.objects:objects_in({
            min_x=x-65,min_y=y-65,max_x=x+65,max_y=y+65})) do
            if near(n,x,y)<=(38+n.radius)^2 and
              (not closest or near(n,x,y)<near(closest,x,y)) then closest=n end
          end
          if closest and closest.id==o.id then return o,x,y end
        end
      end
    end
  end
  error("R2 G smoke has no reachable existing tree fixture; no object injected")
end
function M.load(ctx)
  assert(ctx.pilot and ctx.pilot.query.seed==20261018)
  assert(ctx.pilot.scene.production_enabled==false)
  assert(#ctx.pilot.routes.crossings==0)
  assert(ctx.player.x==64 and ctx.player.y==128,
    "R2 pilot must start at authored spawn")
  assert(ctx.inventory:count("core:wood_log")==0)
  local sx,sy=ctx.camera:project(ctx.player.x,ctx.player.y,ctx.w,ctx.h)
  local x,y=ctx.camera:unproject(sx,sy,ctx.w,ctx.h)
  assert(math.abs(x-ctx.player.x)<.02 and math.abs(y-ctx.player.y)<.02)
  fixture,approach={choose_tree(ctx)}
end
local function goto_stage(name) stage=name;stage_frame=0 end
function M.draw(ctx)
  frames=frames+1;stage_frame=stage_frame+1
  if frames>1000 then error("R2 production pilot timed out: "..stage) end
  if stage=="spawn" then
    if frames<22 or ctx.stats.loaded<2 then return end
    love.graphics.captureScreenshot("r2-pilot-spawn.png")
    initial={x=ctx.player.x,y=ctx.player.y}
    -- The real production touch/joystick callback drives screen-space movement.
    local bx,by=94,ctx.h-112
    walk_touch={bx,by}
    love.touchpressed("r2-g-walk",bx,by)
    love.touchmoved("r2-g-walk",bx+48,by+20)
    goto_stage("walk")
  elseif stage=="walk" and stage_frame>95 then
    local bx,by=walk_touch[1],walk_touch[2]
    love.touchreleased("r2-g-walk",bx+48,by+20)
    local moved=math.sqrt(near({x=ctx.player.x,y=ctx.player.y},initial.x,initial.y))
    assert(moved>8,"R2 real joystick did not move")
    assert(math.abs(ctx.camera.x-ctx.player.x)<1e-5
      and math.abs(ctx.camera.y-ctx.player.y)<1e-5,
      "R2 camera not following real player")
    assert(Collision.can_stand(ctx.building,ctx.player.x,ctx.player.y,ctx.player.radius))
    print("R2_G_WALK_OK distance="..string.format("%.2f",moved))
    -- Test a real wet centerline, without building a speculative bridge.
    river_x,river_y=704,128
    assert(ctx.pilot.query:surface_at(river_x,river_y).wet)
    assert(Collision.can_stand(ctx.building,river_x,river_y,ctx.player.radius),
      "R2 real river centerline collision blocked")
    ctx.player:stop_navigation()
    ctx.player.x,ctx.player.y=river_x,river_y
    goto_stage("river")
  elseif stage=="river" and stage_frame>30 then
    local s=ctx.building:surface_at(ctx.player.x,ctx.player.y)
    assert(s.wet and s.immersion==.5 and s.speed_multiplier<=.55)
    assert(ctx.player.immersion==.5 and ctx.player.surface_multiplier<=.55,
      "R2 wet traversal not propagated to production controller")
    assert(#ctx.pilot.routes.crossings==0,"fake bridge activated")
    love.graphics.captureScreenshot("r2-pilot-river.png")
    print("R2_G_WET_OK x="..ctx.player.x.." y="..ctx.player.y)
    -- Choose an ACTUAL deterministic R2 tree, not a synthetic Stage5 fixture.
    assert(fixture and approach[1] and approach[2])
    local x,y=approach[1],approach[2]
    ctx.player.x,ctx.player.y=x,y
    ctx.player:stop_navigation()
    ctx.camera.x,ctx.camera.y=x,y
    love.keypressed("e")
    goto_stage("harvest")
  elseif stage=="harvest" then
    if ctx.inventory:count("core:wood_log")>=3 then
      assert(ctx.objects:is_depleted(fixture.id),"real R2 tree not depleted")
      assert(ctx.inventory:count("core:wood_log")==3)
      love.keypressed("1") -- real Stage5 crafting input, no item injection.
      goto_stage("craft")
    elseif stage_frame>360 then error("R2 real harvest did not credit wood") end
  elseif stage=="craft" then
    if ctx.inventory:count("core:wood_plank")>=4 then
      assert(ctx.inventory:count("core:wood_log")>=0)
      love.graphics.captureScreenshot("r2-pilot-harvest.png")
      print("R2_G_PRODUCTION_OK seed="..ctx.pilot.query.seed..
        " tree="..fixture.id.." planks="..ctx.inventory:count("core:wood_plank")..
        " crossings="..#ctx.pilot.routes.crossings)
      io.stdout:flush();love.event.quit(0)
    elseif stage_frame>360 then error("R2 Stage5 crafting regression") end
  end
end
return M
