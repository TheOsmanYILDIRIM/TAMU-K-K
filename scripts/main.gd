extends Node3D
## Ana sahne — MVP görsel doğrulama: worldgen çıktısını izometrik
## ortografik kamerayla gösterir. CLI'dan screenshot alınabilir:
##   godot --path . -- --screenshot /tmp/preview.png

var _shot_path: String = ""
var _frames: int = 0


func _ready() -> void:
	Registry.load_all()
	BlockIds.build(true)
	_parse_args()
	_build_showcase()


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()  # "--" sonrası argümanlar
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			_shot_path = args[i + 1]


func _build_showcase() -> void:
	var wg := WorldGen.new(1337)
	wg.setup_biomes(Registry.all_biomes())

	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)

	# 24x24 yüzey kolonu: yüzey bloğu + 2 alt katman (hafif, llvmpipe dostu)
	var half := 12
	for z in range(-half, half):
		for x in range(-half, half):
			var h := wg.height_at(x, z)
			var biome := wg.biome_at(x, z)
			if biome == null:
				continue
			for layer in 3:  # 0=yüzey, 1=alt, 2=derin
				var def: BlockDef
				match layer:
					0: def = Registry.get_block(biome.surface_block)
					1: def = Registry.get_block(biome.subsurface_block)
					2: def = Registry.get_block(biome.deep_block)
				if def == null:
					continue
				var mi := MeshInstance3D.new()
				mi.mesh = box
				var mat := StandardMaterial3D.new()
				mat.albedo_color = def.color if layer == 0 else def.color.darkened(0.12 * layer)
				mi.material_override = mat
				mi.position = Vector3(x, -layer, z)
				add_child(mi)

	# Izometrik ortografik kamera (45° yaw, ~35.26° pitch = 2:1 iso)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 30
	cam.position = Vector3(18, 18, 18)  # (1,1,1) yönü -> klasik iso açı
	cam.look_at(Vector3.ZERO, Vector3.UP)
	add_child(cam)
	cam.current = true

	# Işık + gökyüzü rengi
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.75, 0.95)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 8 and _shot_path != "":
		var img := get_viewport().get_texture().get_image()
		var err := img.save_png(_shot_path)
		if err != OK:
			printerr("Screenshot kaydedilemedi: %s (hata %d)" % [_shot_path, err])
		else:
			print("SCREENSHOT_SAVED: %s" % _shot_path)
		get_tree().quit()
