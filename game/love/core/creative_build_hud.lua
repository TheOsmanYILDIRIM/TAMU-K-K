-- Small-screen creative controls. Hit geometry and drawing share one layout.
local H={};H.__index=H
function H.new()return setmetatable({},H) end
local function button(out,id,x,y,w,h,label)
 out[#out+1]={id=id,x=x,y=y,w=w,h=h,label=label}
end
function H:layout(s,creative)
 local x,y,w,h=s.x,s.y,s.w,s.h
 local out={}
 button(out,"creative_toggle",x+w-123,y+60,112,37,
   creative.active and "CLOSE BUILD" or "CREATIVE")
 if not creative.active then return out end
 local left=x+8;local width=math.min(w-16,420)
 local top=y+144
 local rowh=math.max(31,math.min(40,(h-370)/5))
 local colw=(width-12)/2
 -- Two compact columns, at most 10 labels per page.
 for k=1,10 do
  local index=(creative.page-1)*10+k
  local part=creative.menu()[index]
  if part then
   local col=(k-1)%2;local row=math.floor((k-1)/2)
   button(out,"creative_item:"..index,left+col*(colw+4),top+row*(rowh+3),colw,rowh,
    part.label)
  end
 end
 local actionY=top+5*(rowh+3)+3
 local gap=4;local half=(width-gap)/2
 button(out,"creative_page_prev",left,actionY,half,31,"< LIST")
 button(out,"creative_page_next",left+half+gap,actionY,half,31,"LIST >")
 actionY=actionY+35
 local qw=(width-12)/4
 button(out,"creative_rotate",left,actionY,qw,35,"TURN")
 button(out,"creative_level_down",left+qw+4,actionY,qw,35,"FLOOR -")
 button(out,"creative_level_up",left+2*(qw+4),actionY,qw,35,"FLOOR +")
 button(out,"creative_undo",left+3*(qw+4),actionY,qw,35,"UNDO")
 actionY=actionY+39
 button(out,"creative_place",left,actionY,width,40,"PLACE / BUILD")
 return out
end
function H:hit(px,py,s,creative)
 local list=self:layout(s,creative)
 for i=#list,1,-1 do local b=list[i]
  if px>=b.x and px<=b.x+b.w and py>=b.y and py<=b.y+b.h then return b.id end
 end
 if creative.active then
  local last=list[#list]
  if px>=s.x+5 and px<=s.x+math.min(s.w-5,430) and
   py>=s.y+140 and last and py<=last.y+last.h then return "creative_panel" end
 end
 return nil
end
function H:action(id,creative)
 if id=="creative_toggle" then creative:toggle();return true end
 local i=id:match("^creative_item:(%d+)$")
 if i then creative:select(tonumber(i));return true end
 if id=="creative_page_prev" then creative.page=math.max(1,creative.page-1)
 elseif id=="creative_page_next" then creative.page=math.min(2,creative.page+1)
 elseif id=="creative_rotate" then creative.rotation=(creative.rotation+1)%4
 elseif id=="creative_level_down" then creative.level=math.max(0,creative.level-1)
 elseif id=="creative_level_up" then creative.level=math.min(3,creative.level+1)
 elseif id=="creative_undo" then creative:undo()
 elseif id=="creative_place" then creative:place()
 else return false end
 if id=="creative_rotate" or id=="creative_level_up" or id=="creative_level_down" then
  creative.message="Direction "..creative.rotation.." / Level "..creative.level
 end
 return true
end
function H:draw(creative,s)
 local g=love.graphics
 g.push("all")
 local list=self:layout(s,creative)
 if creative.active then
  local last=list[#list]
  g.setColor(.04,.08,.095,.89)
  g.rectangle("fill",s.x+5,s.y+139,math.min(s.w-10,427),
   last.y+last.h-s.y-134,10,10)
 end
 for _,b in ipairs(list) do
  local selected=b.id=="creative_item:"..creative.selected
  g.setColor(selected and .21 or .10,selected and .45 or .26,selected and .36 or .32,.96)
  g.rectangle("fill",b.x,b.y,b.w,b.h,6,6)
  g.setColor(selected and .89 or .57,selected and .99 or .79,.77,1)
  g.rectangle("line",b.x+.5,b.y+.5,b.w-1,b.h-1,6,6)
  g.setColor(1,.97,.86)
  g.printf(b.label,b.x+2,b.y+b.h*.5-7,b.w-4,"center")
 end
 if creative.active then
  g.setColor(.03,.08,.09,.82)
  g.rectangle("fill",s.x+7,s.y+100,math.min(s.w-14,420),37,6,6)
  g.setColor(1,.95,.79)
  g.print("BUILD: "..creative:current().label.."  L"..creative.level.."  R"..creative.rotation,s.x+13,s.y+105)
  g.setColor(.79,.94,.79)
  g.print(creative.message,s.x+13,s.y+122)
 end
 g.pop()
end
return H
