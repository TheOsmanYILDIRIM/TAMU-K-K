extends Node2D
# Godot native ArrayMesh terrain; binary geometry and atlas are sourced from
# the SAME TAMU compiled LÖVE CI artifact, never resampled.
var terrain_atlas: Texture2D
var pending: Array[String] = []
var loaded: int = 0
var vertices: int = 0
var frame_no: int = 0
var elapsed: float = 0.0
var perf_hud: CanvasLayer
var marker: Label
var drag: bool = false
var joystick_pointer := -1
var joystick_vector := Vector2.ZERO
var joystick_base: Panel
var joystick_knob: Panel
const JOYSTICK_RADIUS := 62.0
var total_cached: int = 0
var chunk_nodes: Dictionary = {}
var available_chunks: Dictionary = {}
var chunk_vertices: Dictionary = {}
var object_visuals_by_chunk: Dictionary = {}
var harvestables: Array[Dictionary] = []
var harvested_count := 0
var shadow_sprites: Array[Sprite2D] = []
var day_clock := 10.5
var sun_direction := Vector2.ZERO
var sun_level := 1.0
var daylight_layer: CanvasModulate
var harvest_button: Button
const DAY_SECONDS := 480.0
var world_bounds := Rect2(-4096.0, -4096.0, 32768.0, 32768.0)
const MAX_LOADED_PER_FRAME := 1
var avatar: Node2D
var actor_world := Vector2(64.0, 128.0)
var actor_speed := 96.0
var avatar_parts: Dictionary = {}
var avatar_motion := 0.0
var actor_facing_back := false
var rig_directions: Dictionary = {}
var rig_animations: Dictionary = {}
var actor_direction := "SE"
var actor_action := "idle"
var active_source_clip := ""
var native_rig: Skeleton2D

func _update_sun(delta: float) -> void:
    day_clock = fposmod(day_clock + delta * 24.0 / DAY_SECONDS, 24.0)
    var arc := (day_clock-6.0)/12.0
    var light := clampf(sin(arc*PI),0.0,1.0)
    var golden := clampf(maxf(0.0,1.0-absf(day_clock-7.7)/2.5)+maxf(0.0,1.0-absf(day_clock-17.2)/2.5),0.0,1.0)
    var azimuth := -PI*0.65+arc*PI*1.3
    var wx := -cos(azimuth)
    var wy := -sin(azimuth)
    sun_direction = Vector2((wx-wy)*sqrt(0.5),(wx+wy)*sqrt(0.5)*0.5).normalized()
    sun_level = light
    var tint := Color(clampf(0.54+0.46*light+0.065*golden,0.0,1.0),clampf(0.62+0.38*light-0.045*golden,0.0,1.0),clampf(0.76+0.24*light-0.13*golden,0.0,1.0))
    daylight_layer.color = tint
    if frame_no % 12 == 0:
        var cast := 0.42+0.58*light
        var length := clampf(0.32+1.05*(1.0-light)/(light+0.31),0.32,2.65)
        for shadow in shadow_sprites:
            if is_instance_valid(shadow):
                shadow.rotation = atan2(-sun_direction.x,sun_direction.y)
                shadow.scale = Vector2.ONE * float(shadow.get_meta("base_scale",1.0)) * length
                shadow.modulate.a = cast * light

func _try_harvest() -> void:
    var nearest: Dictionary = {}
    var best := 38.0 * 38.0
    for item in harvestables:
        if item.get("collected",false):
            continue
        var distance := actor_world.distance_squared_to(item["position"])
        if distance < best:
            best = distance
            nearest = item
    if nearest.is_empty():
        print("TAMU_HARVEST_OUT_OF_RANGE")
        return
    nearest["collected"] = true
    nearest["sprite"].visible = false
    if nearest["shadow"] != null:
        nearest["shadow"].visible = false
    harvested_count += 1
    print("TAMU_HARVEST_OK id=",nearest["id"]," count=",harvested_count)

func _init_harvest_button() -> void:
    var ui := CanvasLayer.new()
    ui.layer = 111
    ui.name = "HarvestTestUI"
    add_child(ui)
    var button := Button.new()
    button.name = "HarvestNearest"
    button.text = "TOPLA"
    button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    button.position = Vector2(-175,-165)
    button.custom_minimum_size = Vector2(140,96)
    button.pressed.connect(_try_harvest)
    ui.add_child(button)
    harvest_button = button

func _init_mobile_joystick() -> void:
    var layer_node := CanvasLayer.new()
    layer_node.name = "TouchMovement"
    layer_node.layer = 110
    add_child(layer_node)
    var root := Control.new()
    root.name = "JoystickArea"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer_node.add_child(root)
    joystick_base = Panel.new()
    joystick_base.name = "JoystickBase"
    joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    joystick_base.position = Vector2(30.0, -188.0)
    joystick_base.size = Vector2(156,156)
    joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var base_style := StyleBoxFlat.new()
    base_style.bg_color = Color(0.08,0.12,0.14,0.48)
    base_style.border_color = Color(0.7,0.92,0.9,0.6)
    base_style.set_border_width_all(3)
    base_style.set_corner_radius_all(78)
    joystick_base.add_theme_stylebox_override("panel",base_style)
    root.add_child(joystick_base)
    joystick_knob = Panel.new()
    joystick_knob.name = "JoystickKnob"
    joystick_knob.position = Vector2(47,47)
    joystick_knob.size = Vector2(62,62)
    joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var knob_style := StyleBoxFlat.new()
    knob_style.bg_color = Color(0.52,0.82,0.76,0.72)
    knob_style.set_corner_radius_all(31)
    joystick_knob.add_theme_stylebox_override("panel",knob_style)
    joystick_base.add_child(joystick_knob)

func _joystick_center() -> Vector2:
    return joystick_base.get_global_rect().get_center()

func _set_joystick(point: Vector2) -> void:
    var relative := point - _joystick_center()
    joystick_vector = relative.limit_length(JOYSTICK_RADIUS) / JOYSTICK_RADIUS
    if joystick_vector.length() < 0.13:
        joystick_vector = Vector2.ZERO
    joystick_knob.position = Vector2(47,47) + joystick_vector * JOYSTICK_RADIUS

func _release_joystick() -> void:
    joystick_pointer = -1
    joystick_vector = Vector2.ZERO
    if joystick_knob != null:
        joystick_knob.position = Vector2(47,47)

func _input(event: InputEvent) -> void:
    if joystick_base == null:
        return
    if event is InputEventScreenTouch:
        if event.pressed and joystick_pointer < 0 and event.position.distance_to(_joystick_center()) <= 105.0:
            joystick_pointer = event.index
            _set_joystick(event.position)
            get_viewport().set_input_as_handled()
        elif not event.pressed and event.index == joystick_pointer:
            _release_joystick()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == joystick_pointer:
        _set_joystick(event.position)
        get_viewport().set_input_as_handled()

func _make_avatar() -> void:
    var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/osman_rig/rig.json"))
    var mapping = JSON.parse_string(FileAccess.get_file_as_string("res://assets/osman_rig/directions.json"))
    if source is not Dictionary or mapping is not Dictionary or not mapping.has("directions"):
        push_error("Original Rigby source or direction profile missing")
        get_tree().quit(8)
        return
    for clip in source.get("animations", []):
        rig_animations[str(clip["name"])] = clip
    rig_directions = mapping["directions"]
    if rig_animations.size() != 44 or rig_directions.size() != 4:
        push_error("Original 44-clip / 4-direction Rigby contract mismatch")
        get_tree().quit(9)
        return
    native_rig = load("res://scripts/rigby_fk.gd").new()
    native_rig.configure(source)
    avatar = Node2D.new()
    avatar.name = "OsmanNativeParts"
    avatar.z_index = 0
    # Player and authored objects share one Godot native Y-sorted layer.
    object_layer.add_child(avatar)
    avatar.add_child(native_rig)
    for part in ["leg_L","leg_R","torso","arm_L","arm_R","head"]:
        var sprite := Sprite2D.new()
        sprite.name = part
        sprite.centered = true
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        avatar.add_child(sprite)
        avatar_parts[part] = sprite
    _set_actor_clip("SE", "idle")
    _update_avatar()

func _set_actor_clip(direction: String, action: String) -> void:
    if not rig_directions.has(direction):
        return
    var clips: Dictionary = rig_directions[direction]["animations"]
    if not clips.has(action):
        return
    var source_name: String = clips[action]
    if not rig_animations.has(source_name):
        push_error("Missing authored Rigby clip: " + source_name)
        return
    actor_direction = direction
    actor_action = action
    active_source_clip = source_name
    if native_rig != null:
        native_rig.play_clip(source_name)
    _set_actor_facing(direction == "NW" or direction == "NE")
    avatar.scale.x = -1.0 if direction == "SW" or direction == "NE" else 1.0

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
    # 10x requested active footprint; actual authored source contains only 156.
    # Retain all 156 real meshes once streamed. No fabricated terrain or overdraw.
    for name in available_chunks:
        if not chunk_nodes.has(name) and not pending.has(name):
            pending.append(name)
    pending.sort_custom(func(a,b): return _chunk_distance_to_actor(a) < _chunk_distance_to_actor(b))

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
    daylight_layer = CanvasModulate.new()
    daylight_layer.name = "TAMUSunTint"
    add_child(daylight_layer)
    _load_objects()
    _make_avatar()
    perf_hud = load("res://scripts/performance_hud.gd").new()
    add_child(perf_hud)
    _init_mobile_joystick()
    _init_harvest_button()
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
        var item_record := {"id":id,"kind":kind,"position":Vector2(float(o["x"]),float(o["y"])),"sprite":sprite,"shadow":null,"collected":false}
        harvestables.append(item_record)
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
            shadow.set_meta("base_scale",scale_value*4.0)
            shadow_layer.add_child(shadow)
            shadow_sprites.append(shadow)
            item_record["shadow"] = shadow
            object_visuals_by_chunk[visual_key].append(shadow)
        object_count += 1
    print("TAMU_CANONICAL_OBJECTS_LOADED count=", object_count)

var object_count: int = 0
var object_layer: Node2D

func _process(delta: float) -> void:
    var frame_start := Time.get_ticks_usec()
    frame_no += 1
    _update_sun(delta)
    elapsed += delta
    var direction := joystick_vector if joystick_vector.length_squared() > 0.01 else Input.get_vector("ui_left","ui_right","ui_up","ui_down")
    if direction.length_squared() > 0.01:
        actor_world += direction * actor_speed * delta
        actor_world.x = clampf(actor_world.x,world_bounds.position.x,world_bounds.end.x)
        actor_world.y = clampf(actor_world.y,world_bounds.position.y,world_bounds.end.y)
        var next_direction := "NW" if direction.y < 0.0 else "SE"
        if direction.x < -0.05:
            next_direction = "NE" if direction.y < 0.0 else "SW"
        _set_actor_clip(next_direction, "walk")
        avatar_motion += delta * 10.0
        avatar_parts["leg_L"].rotation = sin(avatar_motion)*0.16
        avatar_parts["leg_R"].rotation = -sin(avatar_motion)*0.16
    else:
        _set_actor_clip(actor_direction, "idle")
        avatar_parts["leg_L"].rotation = 0.0
        avatar_parts["leg_R"].rotation = 0.0
    _update_avatar()
    if native_rig != null:
        native_rig.advance(delta)
    var rig_end := Time.get_ticks_usec()
    if direction.length_squared() > 0.01:
        $Camera2D.position = $Camera2D.position.lerp(avatar.position, minf(delta * 4.0, 1.0))
    if frame_no % 20 == 0:
        _refresh_streaming_requests()
    if not pending.is_empty():
        _load_chunk(pending.pop_front())
    var stream_end := Time.get_ticks_usec()
    if perf_hud != null:
        perf_hud.record(delta,loaded,total_cached,object_count,vertices,actor_world,stream_end-rig_end,rig_end-frame_start,"walk" if direction.length_squared()>0.01 else "idle")
    marker.text = "TAMU Godot R2 / authored area\n%d active / %d available | %d verts\nFPS %d | frame %.2f ms | Time %.1f | Harvest %d" % [loaded, total_cached, vertices, Engine.get_frames_per_second(), delta * 1000.0,day_clock,harvested_count]
    if frame_no % 120 == 0:
        print("TAMU_GODOT_FRAME frame=", frame_no, " loaded=", loaded, " fps=", Engine.get_frames_per_second())
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and frame_no == 45:
        if harvest_button == null or shadow_sprites.is_empty() or day_clock <= 10.5:
            push_error("TAMU_SUN_HARVEST_BOOT_GATE_FAILED")
            get_tree().quit(11)
            return
        print("TAMU_SUN_HARVEST_BOOT_OK shadows=",shadow_sprites.size()," hour=",day_clock)
        if perf_hud == null or not perf_hud.test_gate():
            push_error("TAMU_PERF_HUD_GATE_FAILED")
            get_tree().quit(10)
            return
        var visible_faults := 0
        for stem in object_visuals_by_chunk:
            for node in object_visuals_by_chunk[stem]:
                if node.visible != chunk_nodes.has(stem):
                    visible_faults += 1
        if visible_faults > 0:
            push_error("TAMU_OBJECT_TERRAIN_REVEAL_FAILED faults=" + str(visible_faults))
            get_tree().quit(7)
            return
        print("TAMU_OBJECT_TERRAIN_REVEAL_OK objects=", object_count, " visible_chunks=", loaded)
        var image := get_viewport().get_texture().get_image()
        var error := image.save_png("user://tamu-godot-visual.png")
        if error != OK or loaded < 16 or total_cached < 100 or vertices < 1000 or object_count < 10 or avatar_parts.size() != 6 or rig_animations.size() != 44 or active_source_clip == "":
            push_error("TAMU_VISUAL_GATE_FAILED " + str(error))
            get_tree().quit(3)
        else:
            print("TAMU_VISUAL_CAPTURE_OK chunks=", loaded, " vertices=", vertices, " objects=", object_count, " avatar_parts=", avatar_parts.size())
            get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.index == joystick_pointer or event.position.distance_to(_joystick_center()) < 110.0:
            return
        drag = event.pressed
    elif event is InputEventScreenDrag and drag:
        $Camera2D.position -= event.relative / $Camera2D.zoom
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        drag = event.pressed
    elif event is InputEventMouseMotion and drag:
        $Camera2D.position -= event.relative / $Camera2D.zoom
