class_name MobDef
extends Resource
## Mob kuralı — SONRAKİ AŞAMA için iskelet. İçerik (zombie vb.) sonra eklenir;
## sistem (Registry + Behavior) şimdiden mob'a hazır.

@export var id: StringName = &""
@export var display_key: String = ""
@export var max_health: float = 20.0
@export var move_speed: float = 3.0
@export var hostile: bool = false
@export var drops: Array[DropRule] = []
