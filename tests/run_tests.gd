extends SceneTree
## Headless test suite:  tools/run_tests.sh ile çalıştırılır.
## Kural: makro sayaç değil, HER sistemin semantiği assert edilir (ev kuralı 1.1).

var _passed: int = 0
var _failed: int = 0


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS: %s" % msg)
	else:
		_failed += 1
		printerr("  FAIL: %s" % msg)


func _init() -> void:
	seed(42)  # deterministik drop testleri
	print("=== oyun test suite (headless) ===")
	Registry.load_all()
	test_registry_integrity()
	test_block_ids()
	test_worldgen()
	test_mineable()
	test_placeable()
	test_translations()
	print("=== SONUÇ: %d PASS, %d FAIL ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func test_registry_integrity() -> void:
	print("[Registry]")
	assert_true(Registry.block_count() >= 5, "en az 5 blok tanımı yüklendi (%d)" % Registry.block_count())
	assert_true(Registry.item_count() >= 3, "en az 3 item tanımı yüklendi (%d)" % Registry.item_count())
	assert_true(Registry.all_biomes().size() >= 3, "en az 3 biyom yüklendi (%d)" % Registry.all_biomes().size())
	# Semantik: her blok id'si eşsiz ve display_key dolu
	var ids := {}
	for b in Registry.all_blocks():
		assert_true(not ids.has(b.id), "blok id eşsiz: %s" % b.id)
		assert_true(b.display_key != "", "blok display_key dolu: %s" % b.id)
		ids[b.id] = true
	# Semantik: stone gerçekten kazılabilir ve drop üretir
	var stone: BlockDef = Registry.get_block(&"stone")
	assert_true(stone != null, "stone tanımı mevcut")
	if stone != null:
		assert_true(stone.hardness > 0.0, "stone hardness > 0 (%.1f)" % stone.hardness)
		assert_true(stone.drops.size() > 0 and stone.drops[0].item_id == &"stone_item",
			"stone kırılınca stone_item düşer")
	# Semantik: grass yüzeyi dirt'e oturur (biyom zinciri tutarlı)
	for biome in Registry.all_biomes():
		assert_true(Registry.get_block(biome.surface_block) != null,
			"biyom '%s' surface_block mevcut: %s" % [biome.id, biome.surface_block])
		assert_true(Registry.get_block(biome.deep_block) != null,
			"biyom '%s' deep_block mevcut: %s" % [biome.id, biome.deep_block])


func test_block_ids() -> void:
	print("[BlockIds]")
	BlockIds.build(true)
	assert_true(BlockIds.num(&"air") == 0, "air her zaman 0")
	var stone_num := BlockIds.num(&"stone")
	assert_true(stone_num > 0, "stone sayısal id > 0 (%d)" % stone_num)
	assert_true(BlockIds.name_of(stone_num) == &"stone", "id->name tur dönüşü tutarlı")
	assert_true(BlockIds.name_of(99999) == &"", "geçersiz id -> boş isim (sessiz fallback yok)")


func test_worldgen() -> void:
	print("[WorldGen]")
	var wg := WorldGen.new(1337)
	wg.setup_biomes(Registry.all_biomes())
	var h1 := wg.height_at(10, 10)
	var h2 := wg.height_at(10, 10)
	assert_true(h1 == h2, "deterministik heightmap (%d)" % h1)
	assert_true(h1 >= 2 and h1 <= WorldGen.WORLD_DEPTH - 2, "yükseklik sınır içi: %d" % h1)
	var t := wg.temperature_at(0, 0)
	var hh := wg.humidity_at(0, 0)
	assert_true(t >= 0.0 and t <= 1.0, "sıcaklık [0,1]: %.2f" % t)
	assert_true(hh >= 0.0 and hh <= 1.0, "nem [0,1]: %.2f" % hh)
	assert_true(wg.biome_at(0, 0) != null, "(0,0) için biyom seçildi: %s" % wg.biome_at(0, 0).id)
	# Biyom uzayı kapsaması: [0,1]² her noktaya bir biyom düşmeli (gap yok)
	var gap_free := true
	for ti in 21:
		for hi in 21:
			if wg.biome_at_values(ti / 20.0, hi / 20.0) == null:
				gap_free = false
	assert_true(gap_free, "biyom uzayı gap-free (21x21 grid tarandı)")
	# Chunk semantiği: yüzeyde katı blok, üstünde hava, tabanda bedrock
	var vox := wg.generate_chunk(0, 0, 16, 16)
	assert_true(vox.size() == 16 * 16 * WorldGen.WORLD_DEPTH, "chunk boyutu doğru (%d)" % vox.size())
	var mid := 8
	var sy := wg.height_at(mid, mid)
	var idx_surface := mid + mid * 16 + sy * 16 * 16
	var idx_above := mid + mid * 16 + (sy + 1) * 16 * 16
	var idx_bedrock := mid + mid * 16 + 0
	assert_true(vox[idx_surface] > 0, "yüzeyde katı blok (%s)" % BlockIds.name_of(vox[idx_surface]))
	assert_true(vox[idx_above] == 0, "yüzey üstü hava (gökyüzü)")
	assert_true(vox[idx_bedrock] == BlockIds.num(&"bedrock"), "taban bedrock")
	# İki farklı chunk aynı seed ile aynı üretilir
	var vox2 := wg.generate_chunk(0, 0, 16, 16)
	assert_true(vox == vox2, "chunk üretimi deterministik")


func is_inf(v: float) -> bool:
	return v == INF or is_nan(v)

func test_mineable() -> void:
	print("[Mineable]")
	var stone: BlockDef = Registry.get_block(&"stone")
	var hand: ItemDef = Registry.get_item(&"hand")
	var pick: ItemDef = Registry.get_item(&"wood_pickaxe")
	assert_true(hand != null and pick != null, "hand ve wood_pickaxe tanımlı")
	var t_hand := Mineable.break_time(stone, hand)
	var t_pick := Mineable.break_time(stone, pick)
	assert_true(t_hand > t_pick, "kazma elle kazmadan hızlı: %.1f > %.1f" % [t_hand, t_pick])
	assert_true(is_inf(Mineable.break_time(null, hand)), "null blok kırılamaz (INF)")


func test_placeable() -> void:
	print("[Placeable]")
	var dirt_item: ItemDef = Registry.get_item(&"dirt_item")
	var stick: ItemDef = Registry.get_item(&"stick")
	assert_true(Placeable.can_place(dirt_item, true), "dirt_item boş hücreye yerleşir")
	assert_true(not Placeable.can_place(dirt_item, false), "dolu hücreye yerleşmez")
	assert_true(not Placeable.can_place(stick, true), "block dışı item yerleştirilemez")


func test_translations() -> void:
	print("[Translations]")
	var en := FileAccess.open("res://data/translations/en.csv", FileAccess.READ)
	assert_true(en != null, "en.csv mevcut")
	if en != null:
		var content := en.get_as_text()
		assert_true("block.stone" in content, "en.csv'de block.stone anahtarı var")
		en.close()
	var tr := FileAccess.open("res://data/translations/tr.csv", FileAccess.READ)
	assert_true(tr != null, "tr.csv mevcut")
	if tr != null:
		var content := tr.get_as_text()
		assert_true("block.stone" in content, "tr.csv'de block.stone anahtarı var")
		tr.close()
