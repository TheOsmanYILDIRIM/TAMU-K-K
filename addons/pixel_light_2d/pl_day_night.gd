@tool
class_name PLDayNight
extends Node
## Time of day for a 2D scene: a sun (DirectionalLight2D) that swings across the sky so normal-mapped sprites change
## their shading, a CanvasModulate sky tint, and every light in the "pl_lights" group fading on at dusk one by one
## and off at dawn. AnimatedSprite2D nodes in the "pl_day_night" group switch between "day" and "night" animations.

signal hour_changed(hour: float)
signal nightfall
signal daybreak

@export_range(0.0, 24.0, 0.01) var hour := 10.0:
	set(v):
		hour = fposmod(v, 24.0)
		if is_inside_tree():
			_apply()
@export var running := true
@export_range(1.0, 3600.0) var seconds_per_day := 120.0
@export var dusk_hour := 18.5
@export var dawn_hour := 6.0
@export_range(0.0, 1.0) var sun_height := 0.25     ## low = long, dramatic side light on the normal maps
@export_range(0.0, 2.0) var sun_energy := 0.85
@export var sky := Gradient.new()
## The sky tint. Leave empty: an existing CanvasModulate in the scene is used, one is created only if there is none
## (a scene must have only one CanvasModulate per canvas). Assign your own here, or set it from code / C#.
@export var tint: CanvasModulate
## The sun. Leave empty to use a DirectionalLight2D child or create one.
@export var sun: DirectionalLight2D

var _night := false
var _fade := {}                                     # light -> [target 0/1, delay left]


func _ready() -> void:
	if sky.get_point_count() <= 2 and sky.colors == PackedColorArray([Color(0, 0, 0), Color(1, 1, 1)]):
		sky.offsets = PackedFloat32Array([0.0, 0.22, 0.3, 0.5, 0.72, 0.8, 1.0])
		sky.colors = PackedColorArray([Color(0.16, 0.18, 0.34), Color(0.16, 0.18, 0.34), Color(0.72, 0.5, 0.45),
			Color(0.66, 0.68, 0.74), Color(0.74, 0.54, 0.44), Color(0.22, 0.22, 0.42), Color(0.16, 0.18, 0.34)])
	_resolve_nodes()
	_night = _is_night(hour)
	_apply(true)


## Finds the tint/sun to drive: the exported ones if set, else an existing node, else a new child.
func _resolve_nodes() -> void:
	if not is_instance_valid(tint):
		tint = _child_of_type("CanvasModulate") as CanvasModulate
	if not is_instance_valid(tint):
		tint = _scene_canvas_modulate()
	if not is_instance_valid(tint):
		tint = CanvasModulate.new()
		tint.name = "SkyTint"
		add_child(tint)
	if not is_instance_valid(sun):
		sun = _child_of_type("DirectionalLight2D") as DirectionalLight2D
	if not is_instance_valid(sun):
		sun = DirectionalLight2D.new()
		sun.name = "Sun"
		add_child(sun)


func _scene_canvas_modulate() -> CanvasModulate:
	var root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	if root == null:
		root = get_parent()
	if root == null:
		return null
	for n in root.find_children("*", "CanvasModulate", true, false):
		if not n.is_queued_for_deletion():
			return n as CanvasModulate
	return null


func _child_of_type(t: String) -> Node:
	for c in get_children():
		if c.get_class() == t:
			return c
	return null


func _is_night(h: float) -> bool:
	return h >= dusk_hour or h < dawn_hour


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if running:
		hour = hour + delta * 24.0 / seconds_per_day
	for l in _fade.keys():
		if not is_instance_valid(l):
			_fade.erase(l)
			continue
		var f: Array = _fade[l]
		if f[1] > 0.0:
			f[1] -= delta
			continue
		var cur: float = l.get_meta("pl_fade", 0.0)
		cur = move_toward(cur, f[0], delta * 2.5)
		l.set_meta("pl_fade", cur)
		l.enabled = cur > 0.01
		if not l.get_children().any(func(c): return c is PLFlicker):
			l.energy = l.get_meta("pl_target", l.energy) * cur
		if is_equal_approx(cur, f[0]):
			_fade.erase(l)


func _apply(instant := false) -> void:
	var t := hour / 24.0
	if not is_instance_valid(tint) or not is_instance_valid(sun):     # a node was deleted or not resolved yet
		if not is_inside_tree():
			return
		_resolve_nodes()
	if is_instance_valid(tint):
		tint.color = sky.sample(t)
	if is_instance_valid(sun):
		var day := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)      # 0 at night, 1 at noon
		sun.energy = sun_energy * day
		sun.color = sky.sample(t).lerp(Color(1, 0.95, 0.85), 0.5)
		sun.height = sun_height
		sun.rotation = lerpf(-PI * 0.75, PI * 0.75, clampf((hour - 6.0) / 12.0, 0.0, 1.0))   # rises left, sets right
		sun.enabled = day > 0.01
	var n := _is_night(hour)
	if n != _night or instant:
		_night = n
		_switch_lights(n, instant)
		for s in get_tree().get_nodes_in_group("pl_day_night"):
			if s is AnimatedSprite2D:
				var a := s as AnimatedSprite2D
				var want := "night" if n else "day"
				if a.sprite_frames and a.sprite_frames.has_animation(want):
					a.play(want)
		if not instant:
			emit_signal("nightfall" if n else "daybreak")
	hour_changed.emit(hour)


func _switch_lights(on: bool, instant: bool) -> void:
	for l in get_tree().get_nodes_in_group(PixelLight.LIGHT_GROUP):
		if not (l is PointLight2D):
			continue
		if not l.has_meta("pl_target"):
			l.set_meta("pl_target", l.energy)
		if instant:
			l.set_meta("pl_fade", 1.0 if on else 0.0)
			l.enabled = on
			l.energy = l.get_meta("pl_target") * (1.0 if on else 0.0)
		else:
			_fade[l] = [1.0 if on else 0.0, randf() * 3.0]      # lights come on one by one
