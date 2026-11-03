@tool
class_name PLAuto
extends Node
## Drop under any Sprite2D / AnimatedSprite2D: at runtime it gives the sprite a normal map (found next to the
## texture or generated), adds lights where the sprite (or its night / _emit version) glows, and optionally a
## shadow occluder. No editor step needed - or use the PixelLight dock to bake the same result into the scene.

@export var normal_maps := true
@export var generate_missing := true
@export_range(0.5, 8.0) var strength := 2.0
@export_range(1, 12) var bevel := 3
@export_range(0.0, 1.0) var detail := 0.35
@export var lights := true
@export_range(0.05, 3.0) var light_energy := 0.9
@export_range(0.1, 2.0) var light_radius := 0.35
@export var flicker := true
@export_enum("none", "silhouette", "base") var occluder := "none"
@export_range(2, 128) var occluder_base_px := 16


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_setup.call_deferred()                       # the host is still adding its children during _ready


func _setup() -> void:
	var host := get_parent() as Node2D
	if host == null:
		return
	if normal_maps:
		PixelLight.apply_normals(host, generate_missing, strength, bevel, detail)
	var info := PixelLight.sprite_image(host)
	if info.is_empty():
		return
	if lights:
		var em := PixelLight.emission_image(info.path)
		PixelLight.add_lights(host, em if em else info.image, info.origin, 1.0, light_energy, light_radius, 24.0, flicker, null, info.image if em else null)
	if occluder != "none":
		PixelLight.add_occluder(host, info.image, info.origin, occluder, occluder_base_px)
