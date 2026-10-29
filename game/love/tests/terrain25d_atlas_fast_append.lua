-- Fast append must exactly match the original full generic path.
package.path='./?.lua;./?/init.lua;'..package.path
local G=require('world.terrain25d_geometry')
local rects={{.1,.2,.05,.05},{0,0,.25,.25},{.75,.5,.125,.125}}
for rect_index,rect in ipairs(rects) do
 for n=1,100 do
  local u=math.floor(n/10); local v=math.floor(n/7)
  local a={n*.01,n*.02,u,v,.71,0,0,0,0,0}
  local b={n*.01+3,n*.02+4,u+.5,v,.52,0,0,0,0,0}
  local c={n*.01+3,n*.02+9,u+.5,v+.7,.36,0,0,0,0,0}
  local tri={a,b,c}
  local baseline=G.love_vertices({format='terrain25d-v1',
    vertices=tri,indices={1,2,3}},rect)
  local result={}
  G.append_atlas_triangle(result,tri,rect)
  assert(#result==#baseline)
  for i=1,#baseline do for j=1,#baseline[i] do
    assert(result[i][j]==baseline[i][j],
      string.format('UV mismatch rect=%d iteration=%d vert=%d item=%d',
        rect_index,n,i,j))
  end end
 end
end
local a={0,0,0,0,1};local b={1,0,1.25,0,1};local c={1,1,.5,.5,1}
local ok=pcall(G.append_atlas_triangle,{}, {a,b,c},rects[1])
assert(not ok,'atlas seam guard must remain active')
print('TAMU_ATLAS_FAST_APPEND_PARITY_OK')
