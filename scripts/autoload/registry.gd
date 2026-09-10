class_name Registry
extends Object
## Tüm Def (kural) dosyalarını yükler ve id ile indeksler.
## Statik singleton — autoload sıralamasına ve sahne ağacına bağımlı DEĞİL,
## headless testlerde de güvenle çalışır.
##
## Kullanım:
##   Registry.load_all()
##   var stone: BlockDef = Registry.get_block(&"stone")

const DIRS := {
	&"block": "res://data/blocks",
	&"item": "res://data/items",
	&"biome": "res://data/biomes",
	&"mob": "res://data/mobs",
}

static var _blocks: Dictionary = {}   # StringName -> BlockDef
static var _items: Dictionary = {}    # StringName -> ItemDef
static var _biomes: Dictionary = {}   # StringName -> BiomeDef
static var _mobs: Dictionary = {}     # StringName -> MobDef
static var _loaded: bool = false


static func load_all(force: bool = false) -> void:
	if _loaded and not force:
		return
	_load_dir(DIRS[&"block"], _blocks, "BlockDef")
	_load_dir(DIRS[&"item"], _items, "ItemDef")
	_load_dir(DIRS[&"biome"], _biomes, "BiomeDef")
	_load_dir(DIRS[&"mob"], _mobs, "MobDef")
	_loaded = true


static func _load_dir(dir_path: String, out: Dictionary, expect_class: String) -> void:
	out.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		# Boş kategori (örn. mobs) meşru — sessiz fallback değil, bilinçli boş.
		print("Registry: kategori boş/erişilemedi: %s" % dir_path)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres") and not fname.begins_with("."):
			var res: Resource = load(dir_path + "/" + fname)
			if res == null:
				push_error("Registry: yüklenemedi %s/%s" % [dir_path, fname])
			elif res.get("id") == null or String(res.get("id")).is_empty():
				push_error("Registry: id boş: %s/%s" % [dir_path, fname])
			elif out.has(res.get("id")):
				push_error("Registry: DUPLİKE id '%s' (%s)" % [res.get("id"), fname])
			else:
				out[res.get("id")] = res
		fname = dir.get_next()
	dir.list_dir_end()
	print("Registry: %d %s yüklendi (%s)" % [out.size(), expect_class, dir_path])


static func get_block(id: StringName) -> BlockDef:
	return _blocks.get(id)


static func get_item(id: StringName) -> ItemDef:
	return _items.get(id)


static func get_biome(id: StringName) -> BiomeDef:
	return _biomes.get(id)


static func get_mob(id: StringName) -> MobDef:
	return _mobs.get(id)


static func all_blocks() -> Array:
	return _blocks.values()


static func all_items() -> Array:
	return _items.values()


static func all_biomes() -> Array:
	return _biomes.values()


static func all_mobs() -> Array:
	return _mobs.values()


static func block_count() -> int:
	return _blocks.size()


static func item_count() -> int:
	return _items.size()
