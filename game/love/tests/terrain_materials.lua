-- Run from game/love with lua5.4 or luajit.
package.path="./?.lua;./?/init.lua;"..package.path
local M=require("world.materials")
assert(#M.order==18,"expected 18 procedural material variants")
local seen={}
for _,id in ipairs(M.order) do assert(not seen[id]);seen[id]=true end
for _,id in ipairs({"meadow","forest","rocky"}) do
 local p=M.color(id,256,128)
 for _,value in ipairs(p) do assert(value>=0 and value<=1) end
 local q=M.color(id,256,128)
 for i=1,3 do assert(p[i]==q[i],"nondeterministic terrain tint") end
 local near=M.color(id,256+1e-5,128)
 for i=1,3 do assert(math.abs(p[i]-near[i])<1e-4,"chunk seam discontinuity") end
end
M.register("meadow","test",{height="h.png",normal="n.png"})
assert(M.get("meadow","test").normal=="n.png")
print("terrain material tests OK")
