@tool
class_name PLFlicker
extends Node
## Put under a PointLight2D: a soft, never-repeating flicker (fire, candles, old bulbs). Leaves the light alone
## while PLDayNight fades it in or out.

@export_range(0.0, 1.0) var amount := 0.12
@export_range(0.1, 20.0) var speed := 6.0
var _base := -1.0
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	_seed = randf() * 100.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var l := get_parent() as PointLight2D
	if l == null:
		return
	if l.has_meta("pl_target"):
		_base = l.get_meta("pl_target")
	elif _base < 0.0:
		_base = l.energy
	if _base <= 0.0:
		return
	_t += delta * speed
	var n := sin(_t + _seed) * 0.5 + sin(_t * 2.3 + _seed * 1.7) * 0.3 + sin(_t * 5.1 + _seed * 0.3) * 0.2
	l.energy = _base * l.get_meta("pl_fade", 1.0) * (1.0 + n * amount)
