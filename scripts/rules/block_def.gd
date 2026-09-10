class_name BlockDef
extends Resource
## Bir blok TÜRÜNÜN kuralı. Kod değil, data (data/blocks/*.tres).
## Aynı kuralı kullanan tüm bloklar aynı davranış kodunu paylaşır.

@export var id: StringName = &""
@export var display_key: String = ""          # çeviri anahtarı: "block.stone"
@export var hardness: float = 1.0             # kazma süresi çarpanı (0 = kırılamaz)
@export var tool_type: StringName = &"hand"   # &"hand" | &"pickaxe" | &"axe" | &"shovel"
@export var solid: bool = true                # çarpışma var mı
@export var gravity_affected: bool = false    # kum gibi düşen bloklar
@export var color: Color = Color(0.6, 0.6, 0.6, 1.0)  # MVP placeholder render
@export var drops: Array[DropRule] = []       # kırılınca ne düşer
