-- Strict JSON codec, with duplicate-key rejection and an explicit empty-array tag.
local M={}
local array_mt={__json_array=true}
function M.array(t) return setmetatable(t or {},array_mt) end
local function utf8(cp)
  if cp<128 then return string.char(cp) end
  if cp<2048 then return string.char(192+math.floor(cp/64),128+cp%64) end
  if cp<65536 then return string.char(224+math.floor(cp/4096),128+math.floor(cp/64)%64,128+cp%64) end
  return string.char(240+math.floor(cp/262144),128+math.floor(cp/4096)%64,128+math.floor(cp/64)%64,128+cp%64)
end
function M.decode(src)
  assert(type(src)=="string" and #src<=8*1024*1024,"JSON size exceeded")
  local pos,len=1,#src
  local function fail() error("invalid JSON at byte "..pos,0) end
  local function ws()
    while pos<=len and src:sub(pos,pos):match("[ \t\r\n]") do pos=pos+1 end
  end
  local parse
  local function str()
    if src:sub(pos,pos)~='"' then fail() end
    pos=pos+1
    local parts={}
    while pos<=len do
      local c=src:byte(pos)
      if c==34 then pos=pos+1;return table.concat(parts) end
      if c<32 then fail() end
      if c==92 then
        pos=pos+1
        local e=src:sub(pos,pos)
        local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
        if escapes[e] then parts[#parts+1]=escapes[e];pos=pos+1
        elseif e=="u" then
          local hex=src:sub(pos+1,pos+4)
          if not hex:match("^%x%x%x%x$") then fail() end
          local cp=tonumber(hex,16)
          pos=pos+5
          if cp>=0xD800 and cp<=0xDBFF then
            if src:sub(pos,pos+1)~="\\u" then fail() end
            local low=src:sub(pos+2,pos+5)
            if not low:match("^%x%x%x%x$") then fail() end
            local lo=tonumber(low,16)
            if lo<0xDC00 or lo>0xDFFF then fail() end
            cp=0x10000+(cp-0xD800)*1024+lo-0xDC00
            pos=pos+6
          elseif cp>=0xDC00 and cp<=0xDFFF then fail() end
          parts[#parts+1]=utf8(cp)
        else fail() end
      else
        parts[#parts+1]=string.char(c)
        pos=pos+1
      end
    end
    fail()
  end
  parse=function(depth)
    if depth>48 then fail() end
    ws()
    local c=src:sub(pos,pos)
    if c=='"' then return str() end
    if c=="{" then
      local out={}
      pos=pos+1;ws()
      if src:sub(pos,pos)=="}" then pos=pos+1;return out end
      while true do
        ws();local key=str()
        if rawget(out,key)~=nil then fail() end
        ws();if src:sub(pos,pos)~=":" then fail() end
        pos=pos+1
        out[key]=parse(depth+1)
        ws();local term=src:sub(pos,pos)
        if term=="}" then pos=pos+1;return out end
        if term~="," then fail() end
        pos=pos+1
      end
    elseif c=="[" then
      local out=M.array()
      pos=pos+1;ws()
      if src:sub(pos,pos)=="]" then pos=pos+1;return out end
      while true do
        out[#out+1]=parse(depth+1)
        ws();local term=src:sub(pos,pos)
        if term=="]" then pos=pos+1;return out end
        if term~="," then fail() end
        pos=pos+1
      end
    elseif c=="t" and src:sub(pos,pos+3)=="true" then pos=pos+4;return true
    elseif c=="f" and src:sub(pos,pos+4)=="false" then pos=pos+5;return false
    elseif c=="n" and src:sub(pos,pos+3)=="null" then fail() -- Null not in save contract.
    else
      -- Anchored-at-pos scan avoids copying the remaining JSON suffix for
      -- every number. The legacy src:sub(pos) parser was quadratic on rigs.
      local from,to=src:find("%-?%d+%.?%d*[eE]?[%+%-]?%d*",pos)
      if from~=pos then fail() end
      local token=src:sub(pos,to)
      if token:match("^%-?0%d") or token:match("%.$") or
         token:match("[eE][%+%-]?$") then fail() end
      if not (token:match("^%-?%d+$") or token:match("^%-?%d+%.%d+$")
        or token:match("^%-?%d+[eE][%+%-]?%d+$")
        or token:match("^%-?%d+%.%d+[eE][%+%-]?%d+$")) then fail() end
      local n=tonumber(token)
      if not n or n~=n or math.abs(n)==math.huge then fail() end
      pos=pos+#token;return n
    end
  end
  local result=parse(0)
  ws();if pos<=len then fail() end
  return result
end
local function quote(s)
  return '"'..s:gsub('[%z\1-\31\\"]',function(c)
    local map={['"']='\\"',['\\']='\\\\',['\b']='\\b',['\f']='\\f',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
    return map[c] or string.format("\\u%04x",c:byte())
  end)..'"'
end
local function encode(v,depth,seen)
  if depth>48 then error("JSON nesting limit",0) end
  local typ=type(v)
  if typ=="string" then return quote(v) end
  if typ=="boolean" then return tostring(v) end
  if typ=="number" then
    if v~=v or math.abs(v)==math.huge then error("nonfinite JSON number",0) end
    return string.format("%.17g",v)
  end
  if typ~="table" then error("unsupported JSON value "..typ,0) end
  if seen[v] then error("cyclic JSON object",0) end
  seen[v]=true
  local parts={}
  if getmetatable(v)==array_mt then
    for k in pairs(v) do if type(k)~="number" or k<1 or k> #v or k~=math.floor(k) then error("invalid JSON array",0) end end
    for i=1,#v do parts[#parts+1]=encode(v[i],depth+1,seen) end
    seen[v]=nil
    return "["..table.concat(parts,",").."]"
  end
  local keys={}
  for k in pairs(v) do
    if type(k)~="string" then error("JSON object keys must be strings",0) end
    keys[#keys+1]=k
  end
  table.sort(keys)
  for _,k in ipairs(keys) do parts[#parts+1]=quote(k)..":"..encode(v[k],depth+1,seen) end
  seen[v]=nil
  return "{"..table.concat(parts,",").."}"
end
function M.encode(value) return encode(value,0,{}) end
return M
