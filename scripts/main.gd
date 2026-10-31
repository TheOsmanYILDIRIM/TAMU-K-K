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
        if error != OK or loaded != 16 or vertices < 1000:
            push_error("TAMU_VISUAL_GATE_FAILED " + str(error))
            get_tree().quit(3)
        else:
            print("TAMU_VISUAL_CAPTURE_OK chunks=", loaded, " vertices=", vertices)
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
