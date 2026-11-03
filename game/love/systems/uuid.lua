-- Local, ephemeral UUIDv4s for single-player sessions only.
-- NOT authoritative host IDs or cryptographic randomness; Stage 8 owns those.
local U={}
function U.new(random)
  assert(type(random)=="function","UUID RNG required")
  local b={}
  for i=1,16 do
    local v=random(0,255)
    assert(type(v)=="number" and v==math.floor(v) and v>=0 and v<=255,
      "invalid UUID random byte")
    b[i]=v
  end
  b[7]=(b[7]%16)+64
  b[9]=(b[9]%64)+128
  local h={}
  for i=1,16 do h[i]=string.format("%02x",b[i]) end
  return table.concat(h,"",1,4).."-"..table.concat(h,"",5,6).."-"
    ..table.concat(h,"",7,8).."-"..table.concat(h,"",9,10).."-"
    ..table.concat(h,"",11,16)
end
return U
