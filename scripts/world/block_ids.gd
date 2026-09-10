class_name BlockIds
extends Object
## BlockDef id (StringName) <-> sayısal voxel id eşlemesi.
## Chunk verisi bellek dostu sayısal id tutar (u16 kavramı); 0 her zaman AIR.


static var _map: Dictionary = {}          # StringName -> int
static var _names: Array[StringName] = [] # int -> StringName


static func build(force: bool = false) -> void:
	if not _map.is_empty() and not force:
		return
	_map.clear()
	_names = [&""]  # 0 = AIR
	for b in Registry.all_blocks():  # id'ye göre sıralı -> deterministik
		if b.id == &"air":
			continue
		_names.append(b.id)
	for i in _names.size():
		_map[_names[i]] = i


static func num(id: StringName) -> int:
	build()
	return _map.get(id, 0)


static func name_of(num_id: int) -> StringName:
	build()
	if num_id >= 0 and num_id < _names.size():
		return _names[num_id]
	return &""


static func reverse_map() -> Dictionary:
	build()
	var inv: Dictionary = {}
	for id in _map:
		inv[_map[id]] = id
	return inv
