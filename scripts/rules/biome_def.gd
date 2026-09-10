class_name BiomeDef
extends Resource
## Biyom kuralı: noise değerlerine (sıcaklık/nem) göre seçilir,
## yüzey/alt katman bloklarını tanımlar (data/biomes/*.tres).

@export var id: StringName = &""
@export var display_key: String = ""

# Bu biyomun noise uzayındaki kutusu (Minecraft tarzı sıcaklık/nem)
@export var temp_range: Vector2 = Vector2(0.0, 1.0)     # min..max
@export var humidity_range: Vector2 = Vector2(0.0, 1.0) # min..max

# Katman blokları (BlockDef id referansları)
@export var surface_block: StringName = &"grass_block"
@export var subsurface_block: StringName = &"dirt"
@export var deep_block: StringName = &"stone"

@export var surface_tint: Color = Color(1, 1, 1, 1)  # çim rengi tonu vb.
