package.path="./?.lua;./?/init.lua;"..package.path
local Hud=require("core.stage5_hud")
local sizes={{320,700},{360,780},{720,1100}}
for _,wh in ipairs(sizes) do
  local w,h=wh[1],wh[2]
  local hud=Hud.new();hud.open=true
  local safe={x=0,y=0,w=w,h=h}
  local buttons=hud:layout(safe)
  assert(hud:layout(safe)==buttons,
    "unchanged safe-area should reuse Stage5 geometry")
  local panel,bar
  local count=0
  for _,b in ipairs(buttons) do
    assert(b.x>=0 and b.y>=0 and b.x+b.w<=w+0.01 and b.y+b.h<=h+0.01,
      "button outside safe area "..b.id)
    if b.id=="panel" then panel=b end
    if b.id=="slot:1" then
      count=count+1
      if not bar or b.y>bar.y then bar=b end
    end
    if b.id=="recipe:core:planks_from_log" then
      assert(hud:hit(b.x+b.w*.5,b.y+b.h*.5,safe)==b.id)
    end
  end
  assert(count==2)
  assert(panel and bar and panel.y+panel.h<bar.y,
    "panel overlaps lower hotbar at "..w.."x"..h)
  hud.open=false;hud.placing=true
  assert(hud:layout(safe)~=buttons,
    "Stage5 mode change must invalidate cached controls")
  local confirm
  for _,b in ipairs(hud:layout(safe)) do if b.id=="confirm" then confirm=b end end
  assert(confirm and hud:hit(confirm.x+10,confirm.y+10,safe)=="confirm")
end
print("STAGE5_HUD_LAYOUT_OK 320x700 360x780 720x1100")
