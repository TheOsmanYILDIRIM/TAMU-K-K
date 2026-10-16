-- Portable SHA-256 (LÖVE's native hash is preferred when available).
local M={}
local U=4294967296
local bitops=bit32 or bit
local function normalize(v) return v%U end
local function bitbinary(a,b,mode)
  local out,p=0,1
  a=normalize(a);b=normalize(b)
  for _=1,32 do
    local x,y=a%2,b%2
    if (mode=="and" and x==1 and y==1)
      or (mode=="xor" and x~=y)
      or (mode=="or" and (x==1 or y==1)) then out=out+p end
    a=math.floor(a/2);b=math.floor(b/2);p=p*2
  end
  return out
end
local function band(a,b)
  if bitops then return normalize(bitops.band(a,b)) end
  return bitbinary(a,b,"and")
end
local function bxor(a,b)
  if bitops then return normalize(bitops.bxor(a,b)) end
  return bitbinary(a,b,"xor")
end
local function bnot(a) return U-1-normalize(a) end
local function shr(a,n) return math.floor(normalize(a)/2^n) end
local function ror(a,n)
  if bitops and bitops.rrotate then return normalize(bitops.rrotate(a,n)) end
  if bitops and bitops.ror then return normalize(bitops.ror(a,n)) end
  return (shr(a,n)+(normalize(a)%2^n)*2^(32-n))%U
end
local K={
0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
local INIT={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
local function pure(data)
  assert(type(data)=="string")
  local length=#data
  local high=math.floor(length/536870912)
  local low=(length*8)%U
  local pad=(56-((length+1)%64))%64
  local function be32(x)
    return string.char(shr(x,24)%256,shr(x,16)%256,shr(x,8)%256,x%256)
  end
  data=data..string.char(128)..string.rep("\0",pad)..be32(high)..be32(low)
  local H={}
  for i=1,8 do H[i]=INIT[i] end
  for pos=1,#data,64 do
    local w={}
    for j=0,15 do
      local a,b,c,d=data:byte(pos+j*4,pos+j*4+3)
      w[j+1]=a*16777216+b*65536+c*256+d
    end
    for i=17,64 do
      local v=w[i-15]
      local s0=bxor(bxor(ror(v,7),ror(v,18)),shr(v,3))
      v=w[i-2]
      local s1=bxor(bxor(ror(v,17),ror(v,19)),shr(v,10))
      w[i]=(w[i-16]+s0+w[i-7]+s1)%U
    end
    local a,b,c,d,e,f,g,h=(table.unpack or unpack)(H)
    for i=1,64 do
      local S1=bxor(bxor(ror(e,6),ror(e,11)),ror(e,25))
      local ch=bxor(band(e,f),band(bnot(e),g))
      local t1=(h+S1+ch+K[i]+w[i])%U
      local S0=bxor(bxor(ror(a,2),ror(a,13)),ror(a,22))
      local maj=bxor(bxor(band(a,b),band(a,c)),band(b,c))
      local t2=(S0+maj)%U
      h=g;g=f;f=e;e=(d+t1)%U;d=c;c=b;b=a;a=(t1+t2)%U
    end
    local vars={a,b,c,d,e,f,g,h}
    for i=1,8 do H[i]=(H[i]+vars[i])%U end
  end
  local out={}
  for i=1,8 do out[i]=string.format("%08x",H[i]) end
  return table.concat(out)
end
function M.sha256(data)
  if love and love.data and love.data.hash and love.data.encode then
    return love.data.encode("string","hex",love.data.hash("sha256",data)):lower()
  end
  return pure(data)
end
M.pure=pure
return M
