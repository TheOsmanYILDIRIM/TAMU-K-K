class_name ItemDef
extends Resource
## Bir item TÜRÜNÜN kuralı (data/items/*.tres).
## place_block_id doluysa item dünyaya blok olarak yerleştirilebilir.

@export var id: StringName = &""
@export var display_key: String = ""
@export var stack_size: int = 64
@export var place_block_id: StringName = &""  # boşsa yerleştirilemez
@export var tool_type: StringName = &"none"   # &"none" | &"pickaxe" | &"axe" | &"shovel"
@export var tool_power: float = 1.0           # kazma hızı çarpanı
@export var color: Color = Color(0.8, 0.8, 0.8, 1.0)  # MVP placeholder render
