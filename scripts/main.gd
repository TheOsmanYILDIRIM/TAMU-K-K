extends Node2D
# Godot native ArrayMesh terrain; binary geometry and atlas are sourced from
# the SAME TAMU compiled LÖVE CI artifact, never resampled.
var terrain_atlas: Texture2D
var pending: Array[String] = []
var loaded: int = 0
var vertices: int = 0
var frame_no: int = 0
var elapsed: float = 0.0
var marker: Label
var drag: bool = false

func _ready() -> void:
    terrain_atlas = load("res://assets/terrain25d/atlas_00.png")
    for cx in range(-1, 3):
        for cy in range(-1, 3):
            pending.append("c_%d_%d" % [cx, cy])
    var camera := Camera2D.new()
    camera.name = "Camera2D"
    camera.enabled = true
    camera.position = Vector2(0.0, 0.0)
    add_child(camera)
    marker = Label.new()
    marker.position = Vector2(8.0, 8.0)
    marker.add_theme_color_override("font_color", Color.WHITE)
    add_child(marker)
    _load_objects()
    print("TAMU_GODOT_TERRAIN_START chunks=", pending.size())

func _load_chunk(stem: String) -> void:
    var file := "res://chunks/%s.verts" % stem
    var raw := FileAccess.get_file_as_bytes(file)
    var meta = JSON.parse_string(FileAccess.get_file_as_string("res://chunks/%s.json" % stem))
    if meta == null or raw.is_empty():
        push_error("missing terrain chunk " + stem)
        get_tree().quit(2)
        return
    var buf := StreamPeerBuffer.new()
    buf.big_endian = false
    buf.data_array = raw
    for surf in meta["meshes"]:
        var count := int(surf["count"])
        var points := PackedVector2Array()
        var uvs := PackedVector2Array()
        var colors := PackedColorArray()
        points.resize(count)
        uvs.resize(count)
        colors.resize(count)
        for i in range(count):
            var x := buf.get_float()
            var y := buf.get_float()
            var u := buf.get_float()
            var v := buf.get_float()
            var packed := buf.get_u32()
            points[i] = Vector2(x, y)
            uvs[i] = Vector2(u, v)
            colors[i] = Color8(packed & 255, (packed >> 8) & 255, (packed >> 16) & 255, (packed >> 24) & 255)
        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = points
        arrays[Mesh.ARRAY_TEX_UV] = uvs
        arrays[Mesh.ARRAY_COLOR] = colors
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        var instance := MeshInstance2D.new()
        instance.mesh = mesh
        instance.texture = terrain_atlas
        instance.z_index = 0 if str(surf["key"]).begins_with("!") else 1
        add_child(instance)
        vertices += count
    assert(buf.get_position() == raw.size())
    loaded += 1

func _load_objects() -> void:
    var path := "res://chunks/r2_objects.json"
    var data = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not data is Dictionary or not data.has("objects"):
        push_error("Canonical R2 object data missing")
        get_tree().quit(4)
        return
    var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/terrain25d/manifest.json"))
    var variants := {}
    for item in manifest["assets"]:
        if item.get("kind") == "object" and item.get("atlas_page") == "atlas_01.png" and item.has("uv_rect"):
            var fam: String = item["family"]
            if not variants.has(fam):
                variants[fam] = []
            variants[fam].append(item)
    for fam in variants:
        variants[fam].sort_custom(func(a,b): return a["id"] < b["id"])
    var atlas: Texture2D = load("res://assets/terrain25d/atlas_01.png")
    var size := atlas.get_size()
    for o in data["objects"]:
        var id: String = o["id"]
        var kind: String = o["kind"]
        var h: int = 19
        for c in id.to_utf8_buffer():
            h = (h * 33 + int(c)) % 2147483647
        var family := "shrub"
        var variant := h % 12
        if kind == "tree":
            family = "broadleaf" if variant == 0 else ("conifer" if variant <= 2 else "oak")
        elif kind == "rock":
            family = "rock_spire" if variant == 0 else ("rock_cluster" if variant == 1 else "boulder")
        elif variants.has(kind):
            family = kind
        if not variants.has(family):
            family = "shrub"
        var choices: Array = variants[family]
        if choices.is_empty():
            continue
        var a: Dictionary = choices[h % choices.size()]
        var uv: Array = a["uv_rect"]
        var area := Rect2(round(float(uv[0]) * size.x), round(float(uv[1]) * size.y), round(float(uv[2]) * size.x), round(float(uv[3]) * size.y))
        var tex := AtlasTexture.new()
        tex.atlas = atlas
        tex.region = area
        var sprite := Sprite2D.new()
        sprite.texture = tex
        sprite.centered = false
        sprite.position = Vector2(float(o["x"]) - 64.0, float(o["y"]) - 124.0)
        sprite.z_index = clampi(int(float(o["y"]) / 16.0), -4096, 4096)
        var scales := {"oak":1.04,"broadleaf":1.12,"conifer":1.20,"dead_tree":0.94,
            "boulder":0.44,"rock_cluster":0.50,"rock_spire":0.53,
            "shrub":0.30,"reeds":0.28,"stump":0.26,"fallen_log":0.41,"water_rocks":0.38}
        var scale_value := float(scales.get(family, 0.5)) * (0.96 + float(h % 9) * 0.01)
        sprite.scale = Vector2.ONE * scale_value
        sprite.offset = Vector2.ZERO
        add_child(sprite)
        object_count += 1
    print("TAMU_CANONICAL_OBJECTS_LOADED count=", object_count)

var object_count: int = 0

func _process(delta: float) -> void:
    frame_no += 1
    elapsed += delta
    if not pending.is_empty():
        _load_chunk(pending.pop_front())
    marker.text = "TAMU | Godot 4 terrain parity\n%d / 16 chunks | %d verts\nFPS %d | frame %.2f ms" % [loaded, vertices, Engine.get_frames_per_second(), delta * 1000.0]
    if frame_no % 120 == 0:
        print("TAMU_GODOT_FRAME frame=", frame_no, " loaded=", loaded, " fps=", Engine.get_frames_per_second())
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and frame_no == 45:
        var image := get_viewport().get_texture().get_image()
        var error := image.save_png("user://tamu-godot-visual.png")
        if error != OK or loaded != 16 or vertices < 1000 or object_count < 10:
            push_error("TAMU_VISUAL_GATE_FAILED " + str(error))
            get_tree().quit(3)
        else:
            print("TAMU_VISUAL_CAPTURE_OK chunks=", loaded, " vertices=", vertices, " objects=", object_count)
            get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        drag = event.pressed
    elif event is InputEventScreenDrag and drag:
        $Camera2D.position -= event.relative / $Camera2D.zoom
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        drag = event.pressed
    elif event is InputEventMouseMotion and drag:
        $Camera2D.position -= event.relative / $Camera2D.zoom
