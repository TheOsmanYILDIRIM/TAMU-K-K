class_name DropRule
extends Resource
## Kırılma/düşme sonucu: hangi item, kaç adet, hangi olasılıkla.

@export var item_id: StringName = &""
@export var count_min: int = 1
@export var count_max: int = 1
@export_range(0.0, 1.0) var chance: float = 1.0


func roll_count() -> int:
	return randi_range(count_min, count_max)


func roll_drop() -> Array[StringName]:
	## Olasılık hesabını uygular; düşen item id listesini döndürür.
	if chance < 1.0 and randf() > chance:
		return []
	var out: Array[StringName] = []
	var n := roll_count()
	for i in n:
		out.append(item_id)
	return out
