class_name Placeable
extends Object
## Yerleştirme davranışı — tüm yerleştirilebilir objelerde TEK kod kaynağı.


static func can_place(item: ItemDef, target_is_air: bool) -> bool:
	## Item blok referansı taşıyor VE hedef hücre boşsa yerleştirilebilir.
	if item == null or item.place_block_id == &"":
		return false
	return target_is_air


static func block_id_of(item: ItemDef) -> StringName:
	return item.place_block_id if item != null else &""
