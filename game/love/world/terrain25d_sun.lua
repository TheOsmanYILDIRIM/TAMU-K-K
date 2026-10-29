-- Opt-in visual sunlight clock for the LÖVE2D 2.5D renderer.
-- No wall clock, gameplay calendar, terrain physics or save mutations.
local Sun={}
local pi,sqrt,sin,cos=math.pi,math.sqrt,math.sin,math.cos
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function atan2(y,x)
 if math.atan2 then return math.atan2(y,x) end -- LuaJIT
 if x>0 then return math.atan(y/x) end
 if x<0 then return math.atan(y/x)+(y>=0 and pi or -pi) end
 if y>0 then return pi/2 end
 if y<0 then return -pi/2 end
 return 0
end
function Sun.at(hour)
 assert(finite(hour),"finite 25D visual hour required")
 local h=hour%24
 local arc=(h-6)/12
 local daylight=clamp(sin(arc*pi),0,1)
 local golden=math.max(0,1-math.abs(h-7.7)/2.5)
   +math.max(0,1-math.abs(h-17.2)/2.5)
 golden=clamp(golden,0,1)
 -- Sun moves along a continuous east-to-west world-space azimuth.
 local azimuth=-pi*.65+arc*pi*1.3
 local wx,wy=-cos(azimuth),-sin(azimuth) -- cast away from the sun
 local sx,sy=(wx-wy)*sqrt(.5),(wx+wy)*sqrt(.5)/2
 local length=sqrt(sx*sx+sy*sy)
 sx,sy=sx/length,sy/length
 local cast=daylight>0 and (.42+.58*daylight) or 0
 local tint={
   clamp(.54+.46*daylight+.065*golden,0,1),
   clamp(.62+.38*daylight-.045*golden,0,1),
   clamp(.76+.24*daylight-.13*golden,0,1)
 }
 return {hour=h,daylight=daylight,cast=cast,
   rotation=atan2(-sx,sy),
   length=clamp(.32+1.05*(1-daylight)/(daylight+.31),.32,2.65),
   direction_x=sx,direction_y=sy,tint=tint}
end
-- Default eight-minute render-only day, with an explicit fixed-hour QA mode.
Sun.day_seconds=480
Sun.initial_hour=10.5
return Sun
