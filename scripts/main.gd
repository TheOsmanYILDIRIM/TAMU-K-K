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
var total_cached: int = 0
var chunk_nodes: Dictionary = {}
var available_chunks: Dictionary = {}
var chunk_vertices: Dictionary = {}
var object_visuals_by_chunk: Dictionary = {}
var world_bounds := Rect2(-4096.0, -4096.0, 32768.0, 32768.0)
const MAX_LOADED_PER_FRAME := 1
var avatar: Node2D
var actor_world := Vector2(64.0, 128.0)
var actor_speed := 96.0
var avatar_parts: Dictionary = {}
var avatar_motion := 0.0
var actor_facing_back := false

func _make_avatar() -> void:
    avatar = Node2D.new()
    avatar.name = "OsmanNativeParts"
    avatar.z_index = 0
    # Player and authored objects share one Godot native Y-sorted layer.
    object_layer.add_child(avatar)
    for part in ["leg_L","leg_R","torso","arm_L","arm_R","head"]:
        var sprite := Sprite2D.new()
        sprite.name = part
        sprite.centered = true
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        avatar.add_child(sprite)
        avatar_parts[part] = sprite
    _set_actor_facing(false)
    _update_avatar()

func _set_actor_facing(back: bool) -> void:
    if actor_facing_back == back and avatar_parts["head"].texture != null:
        return
    actor_facing_back = back
    var prefix := "back" if back else "front"
    for part in avatar_parts:
        avatar_parts[part].texture = load("res://assets/osman_rig/images/%s_%s.png" % [prefix,part])

func _update_avatar() -> void:
    avatar.position = Vector2((actor_world.x-actor_world.y)*0.70710678118,
        (actor_world.x+actor_world.y)*0.35355339059)
    avatar_parts["leg_L"].position = Vector2(-7, -10)
    avatar_parts["leg_R"].position = Vector2(7, -10)
    avatar_parts["torso"].position = Vector2(0, -33)
    avatar_parts["head"].position = Vector2(0, -66)
    avatar_parts["arm_L"].position = Vector2(-16, -35)
    avatar_parts["arm_R"].position = Vector2(16, -35)
    for part in avatar_parts:
        avatar_parts[part].scale = Vector2(0.28,0.28)


func _chunk_distance(stem: String) -> float:
    var parts := stem.split("_")
    if parts.size() != 3:
        return INF
    return Vector2(float(parts[1]) * 256.0, float(parts[2]) * 256.0).distance_squared_to(Vector2(0.0, 0.0))


# Native screen-space camera with bounded chunk residency. Geometry
# remains the exact authored source; camera panning never rebuilds vertices.
func _refresh_streaming_requests() -> void:
    var wanted: Dictionary = {}
    var cx := floori(actor_world.x / 256.0)
    var cy := floori(actor_world.y / 256.0)
    for y in range(cy-4, cy+5):
        for x in range(cx-4, cx+5):
            var name := "c_%d_%d" % [x,y]
            if available_chunks.has(name):
                wanted[name] = true
                if not chunk_nodes.has(name) and not pending.has(name):
                    pending.append(name)
    pending = pending.filter(func(name): return wanted.has(name))
    pending.sort_custom(func(a,b): return _chunk_distance_to_actor(a) < _chunk_distance_to_actor(b))
    for name in chunk_nodes.keys():
        if not wanted.has(name):
            var old: Node2D = chunk_nodes[name]
            old.queue_free()
            _set_chunk_visuals_visible(name, false)
            loaded -= 1
            vertices -= int(chunk_vertices.get(name,0))
            chunk_vertices.erase(name)
            chunk_nodes.erase(name)

func _chunk_distance_to_actor(stem: String) -> float:
    var parts := stem.split("_")
    if parts.size() != 3:
        return INF
    return Vector2((float(parts[1]) + 0.5) * 256.0, (float(parts[2]) + 0.5) * 256.0).distance_squared_to(actor_world)

func _ready() -> void:
    terrain_atlas = load("res://assets/terrain25d/atlas_00.png")
    var idx = JSON.parse_string(FileAccess.get_file_as_string("res://chunks/index.json"))
    if idx is not Dictionary or not idx.has("bounds"):
        push_error("Authored map index missing")
        get_tree().quit(5)
        return
    var b: Dictionary = idx["bounds"]
    if int(b["min_x"]) != -4096 or int(b["max_x"]) != 28672 or int(b["min_y"]) != -4096 or int(b["max_y"]) != 28672:
        push_error("Full map bounds mismatch")
        get_tree().quit(6)
        return
    for stem in idx["available"]:
        available_chunks[str(stem)] = true
    total_cached = available_chunks.size()
    assert(total_cached == 156)
    _refresh_streaming_requests()
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
    _make_avatar()
    print("TAMU_GODOT_TERRAIN_START chunks=", pending.size())

func _set_chunk_visuals_visible(stem: String, show: bool) -> void:
    for node in object_visuals_by_chunk.get(stem, []):
        if is_instance_valid(node):
            node.visible = show

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
    var group := Node2D.new()
    var chunk_count := 0
    group.name = stem
    add_child(group)
    chunk_nodes[stem] = group
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
        group.add_child(instance)
        vertices += count
        chunk_count += count
    assert(buf.get_position() == raw.size())
    chunk_vertices[stem] = chunk_count
    loaded += 1
    _set_chunk_visuals_visible(stem, true)

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
    object_layer = Node2D.new()
    object_layer.name = "CanonicalR2Objects"
    object_layer.z_index = 2
    object_layer.y_sort_enabled = true
    add_child(object_layer)
    var shadow_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/terrain25d/static_shadow/objects_shadow_manifest.json"))
    var shadow_atlas: Texture2D = load("res://assets/terrain25d/static_shadow/shadows_12.png")
    var shadow_layer := Node2D.new()
    shadow_layer.name = "CanonicalR2Shadows"
    shadow_layer.z_index = 2
    add_child(shadow_layer)
    object_layer.z_index = 3
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
        var visual_key := "c_%d_%d" % [int(o["cx"]),int(o["cy"])]
        if not object_visuals_by_chunk.has(visual_key):
            object_visuals_by_chunk[visual_key] = []
        var sprite := Sprite2D.new()
        sprite.visible = false
        sprite.texture = tex
        sprite.centered = true
        sprite.position = Vector2(float(o["sx"]), float(o["sy"]))
        sprite.z_index = 0
        var scales := {"oak":1.04,"broadleaf":1.12,"conifer":1.20,"dead_tree":0.94,
            "boulder":0.44,"rock_cluster":0.50,"rock_spire":0.53,
            "shrub":0.30,"reeds":0.28,"stump":0.26,"fallen_log":0.41,"water_rocks":0.38}
        var scale_value := float(scales.get(family, 0.5)) * (0.96 + float(h % 9) * 0.01)
        sprite.scale = Vector2.ONE * scale_value
        sprite.offset = Vector2(0.0, -60.0)
        object_layer.add_child(sprite)
        object_visuals_by_chunk[visual_key].append(sprite)
        if shadow_manifest is Dictionary and shadow_manifest["objects"].has(a["id"]):
            var shadow_index: Dictionary = shadow_manifest["objects"][a["id"]]
            var shadow_tex := AtlasTexture.new()
            shadow_tex.atlas = shadow_atlas
            shadow_tex.region = Rect2(int(shadow_index["u"]), int(shadow_index["v"]), 32, 32)
            var shadow := Sprite2D.new()
            shadow.texture = shadow_tex
            shadow.visible = false
            shadow.position = sprite.position
            shadow.scale = Vector2.ONE * scale_value * 4.0
            shadow.offset = Vector2(0, -8)
            shadow_layer.add_child(shadow)
            object_visuals_by_chunk[visual_key].append(shadow)
        object_count += 1
    print("TAMU_CANONICAL_OBJECTS_LOADED count=", object_count)

var object_count: int = 0
var object_layer: Node2D

func _process(delta: float) -> void:
    frame_no += 1
    elapsed += delta
    var direction := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
    if direction.length_squared() > 0.01:
        actor_world += direction * actor_speed * delta
        actor_world.x = clampf(actor_world.x,world_bounds.position.x,world_bounds.end.x)
        actor_world.y = clampf(actor_world.y,world_bounds.position.y,world_bounds.end.y)
        _set_actor_facing(direction.y < 0.0)
        avatar_motion += delta * 10.0
        avatar_parts["leg_L"].rotation = sin(avatar_motion)*0.16
        avatar_parts["leg_R"].rotation = -sin(avatar_motion)*0.16
    else:
        avatar_parts["leg_L"].rotation = 0.0
        avatar_parts["leg_R"].rotation = 0.0
    _update_avatar()
    if direction.length_squared() > 0.01:
        $Camera2D.position = $Camera2D.position.lerp(avatar.position, minf(delta * 4.0, 1.0))
    if frame_no % 20 == 0:
        _refresh_streaming_requests()
    if not pending.is_empty():
        _load_chunk(pending.pop_front())
    marker.text = "TAMU Godot R2 / authored area\n%d active / %d available | %d verts\nFPS %d | frame %.2f ms" % [loaded, total_cached, vertices, Engine.get_frames_per_second(), delta * 1000.0]
    if frame_no % 120 == 0:
        print("TAMU_GODOT_FRAME frame=", frame_no, " loaded=", loaded, " fps=", Engine.get_frames_per_second())
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and frame_no == 45:
        var image := get_viewport().get_texture().get_image()
        var error := image.save_png("user://tamu-godot-visual.png")
        if error != OK or loaded < 16 or total_cached < 100 or vertices < 1000 or object_count < 10 or avatar_parts.size() != 6:
            push_error("TAMU_VISUAL_GATE_FAILED " + str(error))
            get_tree().quit(3)
        else:
            print("TAMU_VISUAL_CAPTURE_OK chunks=", loaded, " vertices=", vertices, " objects=", object_count, " avatar_parts=", avatar_parts.size())
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
