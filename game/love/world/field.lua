-- Deterministic continuous scalar fields; no love.math/random and no local clock.
-- All intermediate hashes are exactly representable in IEEE doubles (LuaJIT).
local Field = {}
Field.__index = Field
local PRIME = 2147483647

local function finite(n)
  return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function lattice(seed, ix, iy, salt)
  -- Modular arithmetic avoids platform-specific bitwise/Lua integer differences.
  local h = (seed * 97 + (ix % PRIME) * 16807
       + (iy % PRIME) * 48271 + salt * 1013) % PRIME
  h = (h * 48271 + 1) % PRIME
  h = (h * 69621 + 1) % PRIME
  return h / PRIME
end

local function smooth(t) return t * t * (3 - 2 * t) end
local function mix(a, b, t) return a + (b - a) * t end

function Field.new(seed)
  assert(finite(seed) and seed >= 0 and seed < PRIME
     and seed == math.floor(seed), "seed must be an integer in [0, 2147483646]")
  return setmetatable({seed = seed, generator_version = 1}, Field)
end

function Field:noise(x, y, scale, salt)
  assert(finite(x) and finite(y) and finite(scale) and scale > 0,
         "invalid noise coordinates/scale")
  assert(finite(salt) and salt == math.floor(salt), "invalid channel salt")
  local px, py = x / scale, y / scale
  local ix, iy = math.floor(px), math.floor(py)
  local fx, fy = smooth(px - ix), smooth(py - iy)
  local tl = lattice(self.seed, ix,     iy,     salt)
  local tr = lattice(self.seed, ix + 1, iy,     salt)
  local bl = lattice(self.seed, ix,     iy + 1, salt)
  local br = lattice(self.seed, ix + 1, iy + 1, salt)
  return mix(mix(tl, tr, fx), mix(bl, br, fx), fy)
end

-- Smooth elevation/moisture fields, plus independent feature scores.
-- Threshold zero means an active biome mask; water takes visual priority.
function Field:scores(x, y)
  assert(finite(x) and finite(y), "invalid world coordinate")
  local elevation = 0.52 * self:noise(x, y, 720, 11)
                  + 0.32 * self:noise(x, y, 270, 12)
                  + 0.16 * self:noise(x, y, 100, 13)
  local moisture = 0.58 * self:noise(x, y, 860, 21)
                 + 0.30 * self:noise(x, y, 330, 22)
                 + 0.12 * self:noise(x, y, 115, 23)
  local forest = moisture - 0.51 + 0.16 * (self:noise(x,y,195,24)-0.5)
  local rocky = elevation - 0.61 + 0.20 * (self:noise(x,y,255,14)-0.5)
  local water = 0.29 - elevation + 0.08 * (self:noise(x,y,180,31)-0.5)
  return {height = elevation * 24, moisture = moisture,
    forest = forest, rocky = rocky, water = water}
end

function Field:channel(x, y, name)
  assert(name == "forest" or name == "rocky" or name == "water",
         "unknown scalar channel")
  return self:scores(x, y)[name]
end

function Field:sample(x, y)
  local scores = self:scores(x, y)
  local biome = "meadow"
  if scores.rocky > 0 then biome = "rocky"
  elseif scores.forest > 0 then biome = "forest" end
  local feature
  if scores.water > 0 then feature = "water"
  elseif math.abs(self:noise(x, y, 390, 42) - 0.5) < 0.023 then
    feature = "path"
  end
  return {
    biome = biome, feature = feature, height = scores.height,
    moisture = scores.moisture, walkable = feature ~= "water"
  }
end

return Field
