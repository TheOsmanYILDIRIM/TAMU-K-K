-- Runtime-only atlas page assembler for the user-authored 128px PNG archive.
-- Baked pages can be substituted later without changing manifest UVs or IDs.
-- Never loads all sources: only the requested material/object page.
local Atlas={}
local ROOT="assets/terrain25d/"
local function valid_path(path)
 return type(path)=="string" and
   path:match("^source_png/[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+%.png$") and
   not path:find("..",1,true)
end
function Atlas.load(page)
 local path=ROOT..page.filename
 if not page.generated_from_sources or love.filesystem.getInfo(path,"file") then
   return love.graphics.newImage(path)
 end
 assert(type(page.sources)=="table" and #page.sources>0 and #page.sources<=16,
   "invalid sourced 25D atlas page")
 local target=love.image.newImageData(page.width,page.height)
 for _,src in ipairs(page.sources) do
   assert(valid_path(src.path) and type(src.x)=="number" and
     src.x==math.floor(src.x) and type(src.y)=="number" and
     src.y==math.floor(src.y) and
     src.x>=0 and src.y>=0 and src.x+128<=page.width and
     src.y+128<=page.height,"invalid atlas source placement")
   local tile=love.image.newImageData(ROOT..src.path)
   local w,h=tile:getDimensions()
   assert(w==128 and h==128,"25D source is not 128x128: "..src.path)
   target:paste(tile,src.x,src.y,0,0,128,128)
   tile:release()
 end
 local image=love.graphics.newImage(target)
 target:release()
 return image
end
return Atlas
