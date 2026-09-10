class_name WorldGen
extends Object
## Minecraft tarzı katmanlı noise (FastNoiseLite):
##  1) heightmap       -> yüzey yüksekliği
##  2) temperature     -> biyom ekseni 1
##  3) humidity        -> biyom ekseni 2
## 4. katman ( carved/mağara ) sonraki faza.
## Deterministiktir: aynı seed -> aynı dünya (test edilebilirlik şart).

const WORLD_DEPTH := 32       # y: 0 = bedrock, 31 = build limit
const SEA_LEVEL := 12

var _height_noise := FastNoiseLite.new()
var _cave_noise := FastNoiseLite.new()
var _temp_noise := FastNoiseLite.new()
var _hum_noise := FastNoiseLite.new()
var _biomes: Array = []


func _init(seed_value: int = 1337) -> void:
	_height_noise.seed = seed_value
	_height_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_height_noise.frequency = 0.08
	_height_noise.fractal_octaves = 4

	_temp_noise.seed = seed_value + 1001
	_temp_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_temp_noise.frequency = 0.015   # biyomlar geniş alanlar kaplar

	_hum_noise.seed = seed_value + 2002
	_hum_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_hum_noise.frequency = 0.015

	# Mağara oyma noise'u: 3D, yüksek frekans -> küçük oyuklar
	_cave_noise.seed = seed_value + 3003
	_cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_cave_noise.frequency = 0.11


func setup_biomes(biomes: Array) -> void:
	## Registry.all_biomes() sonucu verilir; noise->biyom eşlemesi bunun üzerinden.
	_biomes = biomes


func height_at(x: int, z: int) -> int:
	## Noise [-1,1] -> yüzey yüksekliği [4 .. WORLD_DEPTH-6]
	var n := _height_noise.get_noise_2d(x, z)   # -1..1
	return int(clampf(remap(n, -1.0, 1.0, 4.0, WORLD_DEPTH - 6.0), 2.0, WORLD_DEPTH - 2))


func temperature_at(x: int, z: int) -> float:
	return clampf(remap(_temp_noise.get_noise_2d(x, z), -1.0, 1.0, 0.0, 1.0), 0.0, 1.0)


func humidity_at(x: int, z: int) -> float:
	return clampf(remap(_hum_noise.get_noise_2d(x, z), -1.0, 1.0, 0.0, 1.0), 0.0, 1.0)


func biome_at_values(t: float, h: float) -> BiomeDef:
	## Sıcaklık/nem değerine EN YAKIN biyom kutusu seçilir (merkez mesafesi).
	## Kutu tabanlı eşleşme [0,1]² uzayında boşluk bırakabilir; nearest-center
	## ise her koordinata deterministik biyom atar (boşluk/uyarı yok).
	if _biomes.is_empty():
		return null
	var best: BiomeDef = null
	var best_d := INF
	for b in _biomes:
		var bc := Vector2(
			(b.temp_range.x + b.temp_range.y) * 0.5,
			(b.humidity_range.x + b.humidity_range.y) * 0.5)
		var d := Vector2(t, h).distance_squared_to(bc)
		if d < best_d:
			best_d = d
			best = b
	return best


func biome_at(x: int, z: int) -> BiomeDef:
	return biome_at_values(temperature_at(x, z), humidity_at(x, z))


func is_cave(x: int, y: int, z: int) -> bool:
	## 3D noise ile katı kaya içinde oyuk. Yüzeyi ve bedrock'u delmemeli.
	if y <= 1 or y >= height_at(x, z) - 1:
		return false
	return _cave_noise.get_noise_3d(x, y, z) > 0.32


func generate_chunk(cx: int, cz: int, size_x: int, size_z: int) -> PackedInt32Array:
	## Chunk voxel verisi: index = x + z*size_x + y*size_x*size_z, değer = BlockIds num.
	var voxels := PackedInt32Array()
	voxels.resize(size_x * size_z * WORLD_DEPTH)
	for z in size_z:
		for x in size_x:
			var wx := cx * size_x + x
			var wz := cz * size_z + z
			var biome := biome_at(wx, wz)
			if biome == null:
				continue
			var surface_y := height_at(wx, wz)
			for y in WORLD_DEPTH:
				var idx := x + z * size_x + y * size_x * size_z
				if y == 0:
					voxels[idx] = BlockIds.num(&"bedrock")
				elif y < surface_y - 3:
					voxels[idx] = BlockIds.num(biome.deep_block)
				elif y < surface_y:
					voxels[idx] = BlockIds.num(biome.subsurface_block)
				elif y == surface_y:
					voxels[idx] = BlockIds.num(biome.surface_block)
				# Mağara oyma: bedrock'u ve yüzeyi delmesin
				if voxels[idx] != BlockIds.num(&"bedrock") and y < surface_y \
						and is_cave(wx, y, wz):
					voxels[idx] = 0  # AIR
				# Su doldurma: yüzeyin altında kalan açık hücreler su olur
				if voxels[idx] == 0 and y <= SEA_LEVEL and y > 0:
					voxels[idx] = BlockIds.num(&"water")
	# Ağaçlar: deterministik, chunk kenarına taşmayacak şekilde
	_place_trees(voxels, cx, cz, size_x, size_z)
	return voxels


func _place_trees(voxels: PackedInt32Array, cx: int, cz: int,
		size_x: int, size_z: int) -> void:
	## Deterministik hash tabanlı ağaç yerleşimi: her dünya hücresi için
	## sabit olasılık. Orman biyomunda, çim yüzeyinde, 4 blok gövde + yapraklar.
	var log := BlockIds.num(&"oak_log")
	var leaves := BlockIds.num(&"leaves")
	var grass := BlockIds.num(&"grass_block")
	if log == 0 or leaves == 0:
		return  # tanımlar yoksa sessizce atla (data yoksa davranış yok)
	for z in range(2, size_z - 2):
		for x in range(2, size_x - 2):
			var wx := cx * size_x + x
			var wz := cz * size_z + z
			var biome := biome_at(wx, wz)
			if biome == null or biome.id != &"forest":
				continue
			var sy := height_at(wx, wz)
			var idx_ground := x + z * size_x + sy * size_x * size_z
			if voxels[idx_ground] != grass:
				continue  # mağara/su yüzeyine ağaç dikme
			# Deterministik hash: aynı (wx,wz) her zaman aynı kararı verir
			var h := hash([wx, wz, 777])
			if h % 100 >= 12:  # %12 olasılık
				continue
			# Gövde: 4 blok
			for i in range(1, 5):
				var idx := x + z * size_x + (sy + i) * size_x * size_z
				if sy + i < WORLD_DEPTH:
					voxels[idx] = log
			# Yaprak küre: gövde tepesinde 3x3x2
			for dy in range(3, 6):
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						if dy == 3 and absi(dx) == 1 and absi(dz) == 1:
							continue  # köşeleri kes, daha organik
						var lx := x + dx
						var lz := z + dz
						var ly := sy + dy
						if lx < 0 or lx >= size_x or lz < 0 or lz >= size_z \
								or ly >= WORLD_DEPTH:
							continue
						var idx := lx + lz * size_x + ly * size_x * size_z
						if voxels[idx] == 0:
							voxels[idx] = leaves
