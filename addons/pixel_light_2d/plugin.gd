@tool
extends EditorPlugin
## PixelLight 2D editor dock: bake normal maps, lights and occluders into the selected sprites, save generated
## normal maps as files, add a day / night cycle to the scene.

var dock: VBoxContainer
var opt := {}


func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "PixelLight"
	_make_ui()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	remove_control_from_docks(dock)
	dock.queue_free()


func _row(label: String, ctl: Control) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 110
	h.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctl)
	dock.add_child(h)


func _spin(key: String, v: float, lo: float, hi: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	opt[key] = s
	return s


func _check(key: String, text: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	opt[key] = c
	dock.add_child(c)
	return c


func _button(text: String, f: Callable, tip := "") -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(f)
	dock.add_child(b)


func _make_ui() -> void:
	var t := Label.new()
	t.text = "PixelLight 2D"
	t.add_theme_font_size_override("font_size", 18)
	dock.add_child(t)
	var hint := Label.new()
	hint.text = "Select Sprite2D / AnimatedSprite2D nodes, then:"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	dock.add_child(hint)
	_check("generate", "Generate a normal map when none is found", true)
	_check("save_files", "Save generated maps as name_n.png files (keeps scenes small)", true)
	_row("Strength", _spin("strength", 2.0, 0.5, 8.0, 0.1))
	_row("Bevel (px)", _spin("bevel", 3, 1, 12, 1))
	_row("Detail", _spin("detail", 0.35, 0.0, 1.0, 0.05))
	_button("Add normal maps", _do_normals, "Finds name_n.png / name_normal.png / a normal folder next to each texture, or generates one.")
	dock.add_child(HSeparator.new())
	_row("Light energy", _spin("energy", 0.9, 0.05, 3.0, 0.05))
	_row("Light radius", _spin("radius", 0.35, 0.1, 2.0, 0.05))
	_check("flicker", "Flicker", true)
	_button("Add lights from glowing pixels", _do_lights, "Uses the night / _emit version of the sprite if there is one, else the sprite itself.")
	dock.add_child(HSeparator.new())
	var mode := OptionButton.new()
	for m in ["silhouette", "base"]:
		mode.add_item(m)
	opt["occ_mode"] = mode
	_row("Shadow shape", mode)
	_row("Base rows (px)", _spin("base_px", 16, 2, 128, 1))
	_button("Add shadow occluder", _do_occluder)
	dock.add_child(HSeparator.new())
	_button("Add day / night cycle to scene", _do_day_night)
	_button("Save generated normal maps (FileSystem selection)", _do_save_files, "Select textures in the FileSystem dock: writes name_n.png next to each.")
	_button("Remove PixelLight from selection", _do_remove)
	var info := Label.new()
	info.name = "Info"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	dock.add_child(info)


func _say(t: String) -> void:
	(dock.get_node("Info") as Label).text = t


func _sel() -> Array:
	return EditorInterface.get_selection().get_selected_nodes().filter(func(n): return n is Sprite2D or n is AnimatedSprite2D or n is TextureRect)


func _v(k: String) -> float:
	return (opt[k] as SpinBox).value


func _do_normals() -> void:
	var gen: bool = (opt.generate as CheckBox).button_pressed
	var saved := PackedStringArray()
	var in_memory := 0
	if gen:
		for node in _sel():
			for tex in PixelLight.textures_of(node):
				if PixelLight.find_normal_path(tex.resource_path) != "":
					continue
				if (opt.save_files as CheckBox).button_pressed:
					var p := PixelLight.save_generated_normal(tex, _v("strength"), int(_v("bevel")), _v("detail"))
					if p != "" and not saved.has(p):
						saved.append(p)
						continue
				in_memory += 1
		if saved.size() > 0:                       # import the new files now, so the scene references them
			var fs := EditorInterface.get_resource_filesystem()
			for p in saved:
				fs.update_file(p)
			fs.reimport_files(saved)
			PixelLight.clear_cache()
	var n := 0
	for node in _sel():
		n += PixelLight.apply_normals(node, gen, _v("strength"), int(_v("bevel")), _v("detail"))
	var msg := "Normal maps on %d textures." % n
	if saved.size() > 0:
		msg += " Saved %d new name_n.png files next to the textures." % saved.size()
	if in_memory > 0:
		msg += " %d generated in memory only - they are stored inside the scene file (use textures saved as .png to avoid that)." % in_memory
	_say(msg)


func _do_lights() -> void:
	var root := EditorInterface.get_edited_scene_root()
	var total := 0
	for node in _sel():
		var info := PixelLight.sprite_image(node)
		if info.is_empty():
			continue
		var em := PixelLight.emission_image(info.path)
		total += PixelLight.add_lights(node, em if em else info.image, info.origin, 1.0, _v("energy"), _v("radius"), 24.0,
			(opt.flicker as CheckBox).button_pressed, root, info.image if em else null).size()
	_say("Added %d lights (group \"pl_lights\")." % total)


func _do_occluder() -> void:
	var root := EditorInterface.get_edited_scene_root()
	var total := 0
	var mode: String = (opt.occ_mode as OptionButton).get_item_text((opt.occ_mode as OptionButton).selected)
	for node in _sel():
		var info := PixelLight.sprite_image(node)
		if not info.is_empty():
			total += PixelLight.add_occluder(node, info.image, info.origin, mode, int(_v("base_px")), root)
	_say("Added %d occluder polygons." % total)


func _do_day_night() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var dn := PLDayNight.new()
	dn.name = "DayNight"
	root.add_child(dn)
	dn.owner = root
	_say("DayNight added: set hour / seconds_per_day in the inspector. Lights in group pl_lights fade at dusk.")


func _do_save_files() -> void:
	var n := 0
	for p in EditorInterface.get_selected_paths():
		if not (p.ends_with(".png") or p.ends_with(".webp")) or p.get_basename().ends_with("_n"):
			continue
		var tex: Texture2D = load(p)
		var img := PixelLight.generate_normal(tex.get_image(), _v("strength"), int(_v("bevel")), _v("detail"))
		img.save_png(p.get_basename() + "_n.png")
		n += 1
	EditorInterface.get_resource_filesystem().scan()
	_say("Saved %d normal maps (name_n.png)." % n)


func _do_remove() -> void:
	for node in _sel():
		PixelLight.remove_normals(node)
		for c in node.get_children():
			if c.name.begins_with("PLLight") or c.name.begins_with("PLOccluder"):
				c.queue_free()
	_say("Removed.")
