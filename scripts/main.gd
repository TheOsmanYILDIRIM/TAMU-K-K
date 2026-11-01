extends Node2D
const WorldProjection = preload("res://scripts/world_projection.gd")
const WorldSource = preload("res://scripts/world_source.gd")
const WorldStream = preload("res://scripts/world_stream.gd")
const MergedTerrain = preload("res://scripts/merged_terrain.gd")
const RigbySkinned = preload("res://scripts/rigby_skinned.gd")
var rigby_skin: Dictionary = {}
var merged_mode: bool = OS.get_environment("TAMU_TERRAIN_MODE") != "legacy"
# Each independently authored region is a separate logical chunk, not one global world.
var region_chunks: Dictionary = {}
var world_source: RefCounted
# Godot native ArrayMesh terrain; binary geometry and atlas are sourced from
# the SAME TAMU compiled LÖVE CI artifact, never resampled.
var terrain_atlas: Texture2D
var pending: Array[String] = []
var view_required: Dictionary = {}
var last_plan_camera := Vector2(INF, INF)
var last_plan_zoom := Vector2.ONE
var evicted_total := 0
var camera_missing := 0
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
var shadow_sprites: Array[Polygon2D] = []
var day_clock := 10.5
var sun_direction := Vector2.ZERO
var sun_level := 1.0
var daylight_layer: CanvasModulate
var harvest_button: Button
const DAY_SECONDS := 30.0
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
    nearest["sprite"].set_meta("tamu_collected", true)
    nearest["sprite"].visible = false
    if nearest["shadow"] != null:
        nearest["shadow"].set_meta("tamu_collected", true)
        nearest["shadow"].visible = false
    harvested_count += 1
    print("TAMU_HARVEST_OK id=",nearest["id"]," count=",harvested_count)

func _init_harvest_button() -> void:
    var ui := CanvasLayer.new()
    ui.layer = 111
    ui.name = "HarvestTestUI"
    add_child(ui)
    var root := Control.new()
    root.name = "HarvestOverlay"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(root)
    var button := Button.new()
    button.name = "HarvestNearest"
    button.text = "TOPLA"
    button.anchor_left = 1.0
    button.anchor_right = 1.0
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    button.offset_left = -190.0
    button.offset_right = -24.0
    button.offset_top = -194.0
    button.offset_bottom = -74.0
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.40, 0.32, 0.94)
    style.border_color = Color(0.65, 0.97, 0.81)
    style.set_border_width_all(3)
    style.set_corner_radius_all(20)
    button.add_theme_stylebox_override("normal",style)
    button.add_theme_font_size_override("font_size",26)
    button.pressed.connect(_try_harvest)
    root.add_child(button)
    harvest_button = button
    print("TAMU_HARVEST_UI_READY")

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
    # Keep the old six PNGs as visible renderer until complete Rigby pose parity.
    if OS.get_environment("TAMU_VISUAL_CI") == "1" or OS.get_environment("TAMU_RIGBY_SKIN_PREVIEW") == "1":
        rigby_skin = RigbySkinned.build(source, native_rig)
        if rigby_skin.is_empty():
            push_error("TAMU_RIGBY_SKIN_BUILD_FAILED")
            get_tree().quit(21)

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
    avatar.position = WorldProjection.to_screen(actor_world)
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
    var camera: Camera2D = $Camera2D
    var center := camera.get_screen_center_position()
    var view_size := get_viewport_rect().size
    view_required = WorldStream.required_chunks(available_chunks, center, view_size, camera.zoom)
    if merged_mode:
        pending.clear()
        camera_missing = 0
        last_plan_camera = center
        last_plan_zoom = camera.zoom
        return
    pending = WorldStream.schedule(available_chunks, chunk_nodes, actor_world, center, view_size, camera.zoom)
    for stem in chunk_nodes:
        var show: bool = view_required.has(stem)
        var node: Node2D = chunk_nodes[stem]
        if node.visible != show:
            node.visible = show
            _set_chunk_visuals_visible(str(stem), show)
    camera_missing = 0
    for stem in view_required:
        if not chunk_nodes.has(stem):
            camera_missing += 1
    last_plan_camera = center
    last_plan_zoom = camera.zoom

func _chunk_distance_to_actor(stem: String) -> float:
    var parts := stem.split("_")
    if parts.size() != 3:
        return INF
    return WorldProjection.chunk_center_from_key(stem).distance_squared_to(actor_world)

func _ready() -> void:
    if OS.get_environment("TAMU_VISUAL_CI") == "1":
        if not WorldProjection.verify_contract():
            push_error("TAMU_WORLD_PROJECTION_GATE_FAILED")
            get_tree().quit(15)
            return
        print("TAMU_WORLD_PROJECTION_GATE_OK")
        if not WorldStream.verify_contract():
            push_error("TAMU_STREAM_SCHEDULER_GATE_FAILED")
            get_tree().quit(16)
            return
        print("TAMU_STREAM_SCHEDULER_OK")
    terrain_atlas = load("res://assets/terrain25d/atlas_00.png")
    world_source = WorldSource.new()
    if not world_source.initialize():
        push_error("TAMU_WORLD_SOURCE_GATE_FAILED")
        get_tree().quit(5)
        return
    available_chunks = world_source.available.duplicate()
    total_cached = available_chunks.size()
    print("TAMU_WORLD_SOURCE_READY chunks=", total_cached)
    var camera := Camera2D.new()
    camera.name = "Camera2D"
    camera.enabled = true
    camera.position = Vector2(0.0, 0.0)
    if OS.get_environment("TAMU_VISUAL_CI") == "1":
        match OS.get_environment("TAMU_VISUAL_CASE"):
            "east":
                camera.position = WorldProjection.to_screen(Vector2(550.0, 320.0))
            "west":
                camera.position = WorldProjection.to_screen(Vector2(-400.0, -220.0))
            "zoom":
                camera.position = WorldProjection.to_screen(Vector2(200.0, 200.0))
                camera.zoom = Vector2(0.82, 0.82)
            "north":
                camera.position = WorldProjection.to_screen(Vector2(400.0, -750.0))
            "dawn":
                camera.position = WorldProjection.to_screen(Vector2(120.0, 180.0))
    add_child(camera)
    _refresh_streaming_requests()
    if merged_mode and not _load_region("res://chunks/merged_terrain.json"):
        push_error("TAMU_MERGED_TERRAIN_LOAD_FAILED")
        get_tree().quit(19)
        return
    marker = Label.new()
    marker.position = Vector2(8.0, 8.0)
    marker.add_theme_color_override("font_color", Color.WHITE)
    add_child(marker)
    daylight_layer = CanvasModulate.new()
    daylight_layer.name = "TAMUSunTint"
    add_child(daylight_layer)
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and OS.get_environment("TAMU_VISUAL_CASE") == "dawn":
        day_clock = 6.0
    _load_objects()
    _make_avatar()
    if OS.get_environment("TAMU_VISUAL_CI") == "1":
        if native_rig == null or not native_rig.verify_curve_reference("res://chunks/rigby_curve_reference.txt"):
            push_error("TAMU_RIGBY_CURVE_GATE_FAILED")
            get_tree().quit(20)
            return
        native_rig.advance(0.0)
        if not RigbySkinned.update_pose(rigby_skin, native_rig, native_rig.bones) or not RigbySkinned.verify(rigby_skin):
            push_error("TAMU_RIGBY_WEIGHTED_MESH_GATE_FAILED")
            get_tree().quit(22)
            return
        print("TAMU_RIGBY_WEIGHTED_MESH_OK meshes=", rigby_skin["records"].size(),
            " vertices=", rigby_skin["vertices"], " triangles=", rigby_skin["triangles"],
            " influences=", rigby_skin["influences"])
    perf_hud = load("res://scripts/performance_hud.gd").new()
    add_child(perf_hud)
    _init_mobile_joystick()
    _init_harvest_button()
    print("TAMU_GODOT_TERRAIN_START chunks=", pending.size())

func _load_region(manifest_path: String) -> bool:
    var started: int = Time.get_ticks_usec()
    var unified: Dictionary = MergedTerrain.build_region(terrain_atlas, manifest_path)
    if unified.is_empty():
        return false
    var region_id: String = str(unified["region_id"])
    if region_chunks.has(region_id):
        # Prevent a second instance from covering the same authored region.
        unified["root"].free()
        push_error("TAMU_DUPLICATE_REGION " + region_id)
        return false
    var node: Node2D = unified["root"]
    add_child(node)
    region_chunks[region_id] = node
    loaded = int(unified["source_cells"])
    vertices = int(unified["vertices"])
    for stem in object_visuals_by_chunk:
        _set_chunk_visuals_visible(str(stem), true)
    var prepared_ms := float(Time.get_ticks_usec() - started) / 1000.0
    print("TAMU_REGION_LOAD_OK region=", region_id, " source_cells=", loaded,
        " vertices=", vertices, " native_nodes=", int(unified["surfaces"]),
        " prepare_ms=", snappedf(prepared_ms, 0.01),
        " decode_ms=", snappedf(float(unified["decode_ms"]), 0.01),
        " mesh_ms=", snappedf(float(unified["mesh_ms"]), 0.01))
    print("TAMU_MERGED_TERRAIN_OK sources=", total_cached,
        " vertices=", vertices, " draw_nodes=", int(unified["surfaces"]))
    return true

func _unload_region(region_id: String) -> bool:
    if not region_chunks.has(region_id):
        return false
    var region_node: Node2D = region_chunks[region_id]
    region_chunks.erase(region_id)
    # Detach immediately; deferred free must never render a duplicate.
    remove_child(region_node)
    region_node.queue_free()
    loaded = 0
    vertices = 0
    for stem in object_visuals_by_chunk:
        _set_chunk_visuals_visible(str(stem), false)
    print("TAMU_REGION_UNLOAD_OK region=", region_id, " remaining=", region_chunks.size())
    return true

func _set_chunk_visuals_visible(stem: String, show: bool) -> void:
    for node in object_visuals_by_chunk.get(stem, []):
        if is_instance_valid(node):
            node.visible = show and not bool(node.get_meta("tamu_collected", false))

func _load_chunk(stem: String) -> void:
    var payload: Dictionary = world_source.read_chunk(stem)
    if payload.is_empty():
        push_error("TAMU_WORLD_SOURCE_LOAD_FAILED " + stem)
        get_tree().quit(2)
        return
    var raw: PackedByteArray = payload["raw"]
    var meta: Dictionary = payload["meta"]
    if raw.is_empty():
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
    var show_now: bool = view_required.has(stem)
    group.visible = show_now
    _set_chunk_visuals_visible(stem, show_now)

func _enforce_resident_budget() -> void:
    var budget := WorldStream.RESIDENT_BUDGET_BYTES
    if WorldStream.estimate_bytes(chunk_vertices) <= budget:
        return
    var candidates := WorldStream.eviction_candidates(chunk_vertices, view_required,
        $Camera2D.get_screen_center_position(), budget)
    var removed := 0
    for stem in candidates:
        if removed >= 2: # bound node destruction work per frame
            break
        var node: Node2D = chunk_nodes.get(stem)
        if node == null:
            continue
        # Never evict visible terrain: object/shadow reveal follows its chunk.
        _set_chunk_visuals_visible(stem, false)
        node.queue_free()
        chunk_nodes.erase(stem)
        vertices -= int(chunk_vertices[stem])
        chunk_vertices.erase(stem)
        loaded -= 1
        removed += 1
        evicted_total += 1
    if removed > 0:
        _refresh_streaming_requests()

func _verify_visual_order() -> bool:
    if not object_layer.y_sort_enabled or object_layer.z_index <= 2:
        return false
    if avatar.get_parent() != object_layer:
        return false
    for item in harvestables:
        var sprite: Sprite2D = item["sprite"]
        if sprite.get_parent() != object_layer or sprite.z_index != 0:
            return false
        if item["shadow"] != null:
            var shadow: Polygon2D = item["shadow"]
            if shadow.get_parent().z_index >= object_layer.z_index:
                return false
            if not shadow.position.is_equal_approx(sprite.position + Vector2(0, 3)):
                return false
    return true

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
        sprite.visible = merged_mode
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
        # Native Godot shadow geometry: atlas's tiny low-res alpha should not
        # make ground shadows invisible. Respect the original object footprint.
        if kind == "tree" or kind == "rock":
            var shadow := Polygon2D.new()
            shadow.name = "GroundShadow"
            var outline := PackedVector2Array()
            var radius := 10.0 if kind == "rock" else 20.0
            for n in range(24):
                var angle := TAU * float(n) / 24.0
                outline.append(Vector2(cos(angle)*radius, sin(angle)*radius*0.45))
            shadow.polygon = outline
            shadow.color = Color(0.025,0.045,0.04,0.72)
            shadow.visible = merged_mode
            shadow.position = sprite.position + Vector2(0.0,3.0)
            shadow.set_meta("base_scale",maxf(0.7,scale_value*2.5))
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
    var visual_delta: float = 1.0 / 60.0 if OS.get_environment("TAMU_VISUAL_CI") == "1" else delta
    _update_sun(visual_delta)
    elapsed += visual_delta
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
        native_rig.advance(visual_delta)
    var rig_end := Time.get_ticks_usec()
    if direction.length_squared() > 0.01:
        $Camera2D.position = $Camera2D.position.lerp(avatar.position, minf(delta * 4.0, 1.0))
    var camera_center: Vector2 = $Camera2D.get_screen_center_position()
    if frame_no % 10 == 0 or camera_center.distance_squared_to(last_plan_camera) > 96.0 * 96.0 or $Camera2D.zoom != last_plan_zoom:
        _refresh_streaming_requests()
    if not merged_mode:
        if not pending.is_empty():
            _load_chunk(pending.pop_front())
        if frame_no % 10 == 0:
            _enforce_resident_budget()
    var stream_end := Time.get_ticks_usec()
    if perf_hud != null:
        perf_hud.record(delta,loaded,total_cached,object_count,vertices,actor_world,stream_end-rig_end,rig_end-frame_start,"walk" if direction.length_squared()>0.01 else "idle")
    marker.text = "TAMU Godot R2 / authored area\n%d resident / %d source | %d verts\nViewport missing %d | Mesh est %.1f MiB\nFPS %d | frame %.2f ms | Time %.1f | Harvest %d" % [loaded, total_cached, vertices, camera_missing, float(vertices * WorldStream.ESTIMATED_BYTES_PER_VERTEX)/1048576.0, Engine.get_frames_per_second(), delta * 1000.0,day_clock,harvested_count]
    if frame_no % 120 == 0:
        print("TAMU_GODOT_FRAME frame=", frame_no, " loaded=", loaded, " fps=", Engine.get_frames_per_second())
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and frame_no == 60 and merged_mode and OS.get_environment("TAMU_VISUAL_CASE") == "reload":
        var previous_node: Node2D = region_chunks.get("fisilti_ormani")
        var previous_id: int = previous_node.get_instance_id() if previous_node != null else -1
        if not _unload_region("fisilti_ormani") or not _load_region("res://chunks/merged_terrain.json"):
            push_error("TAMU_REGION_RELOAD_FAILED")
            get_tree().quit(21)
            return
        var new_node: Node2D = region_chunks.get("fisilti_ormani")
        if new_node == null or new_node.get_instance_id() == previous_id or region_chunks.size() != 1 or vertices != 220254:
            push_error("TAMU_REGION_RELOAD_IDENTITY_FAILED")
            get_tree().quit(22)
            return
        print("TAMU_REGION_RELOAD_OK id_replaced=true region_count=", region_chunks.size(),
            " vertices=", vertices)
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and frame_no == 180:
        if harvest_button == null or shadow_sprites.is_empty() or (day_clock <= 10.5 and OS.get_environment("TAMU_VISUAL_CASE") != "dawn") or harvest_button.get_global_rect().size.x < 100:
            push_error("TAMU_SUN_HARVEST_BOOT_GATE_FAILED")
            get_tree().quit(11)
            return
        var drawn := 0
        for sh in shadow_sprites:
            if sh.visible and sh.modulate.a > 0.1 and sh.polygon.size() >= 16:
                drawn += 1
        if drawn < 10:
            push_error("TAMU_SHADOW_VISIBILITY_FAILED visible=" + str(drawn))
            get_tree().quit(14)
            return
        print("TAMU_GROUND_SHADOW_VISIBILITY_OK visible=",drawn)
        print("TAMU_SUN_HARVEST_BOOT_OK shadows=",shadow_sprites.size()," hour=",day_clock)
        if perf_hud == null or not perf_hud.test_gate():
            push_error("TAMU_PERF_HUD_GATE_FAILED")
            get_tree().quit(10)
            return
        var visible_faults := 0
        for stem in object_visuals_by_chunk:
            for node in object_visuals_by_chunk[stem]:
                var source_visible: bool = merged_mode or (chunk_nodes.has(stem) and chunk_nodes[stem].visible)
                var expected: bool = source_visible and not bool(node.get_meta("tamu_collected", false))
                if node.visible != expected:
                    visible_faults += 1
        if visible_faults > 0:
            push_error("TAMU_OBJECT_TERRAIN_REVEAL_FAILED faults=" + str(visible_faults))
            get_tree().quit(7)
            return
        print("TAMU_OBJECT_TERRAIN_REVEAL_OK objects=", object_count, " visible_chunks=", loaded)
        _refresh_streaming_requests()
        if camera_missing != 0:
            push_error("TAMU_CAMERA_VISIBLE_CHUNK_GAP missing=" + str(camera_missing))
            get_tree().quit(17)
            return
        if not _verify_visual_order():
            push_error("TAMU_YDEPTH_SHADOW_ORDER_FAILED")
            get_tree().quit(18)
            return
        print("TAMU_VIEWPORT_COVERAGE_OK missing=0 required=", view_required.size(), " resident=", loaded)
        print("TAMU_YDEPTH_SHADOW_ORDER_OK objects=", object_count)
        print("TAMU_RESIDENT_BUDGET_OK estimated_bytes=", vertices * WorldStream.ESTIMATED_BYTES_PER_VERTEX,
            " cap_bytes=", WorldStream.RESIDENT_BUDGET_BYTES, " evicted=", evicted_total)

        var image := get_viewport().get_texture().get_image()
        var error := image.save_png("user://tamu-godot-visual.png")
        print("TAMU_VISUAL_VARIANT mode=", "merged" if merged_mode else "legacy",
            " case=", OS.get_environment("TAMU_VISUAL_CASE"))
        if error != OK or loaded < 16 or total_cached < 100 or vertices < 1000 or object_count < 10 or avatar_parts.size() != 6 or rig_animations.size() != 44 or active_source_clip == "":
            push_error("TAMU_VISUAL_GATE_FAILED " + str(error))
            get_tree().quit(3)
        else:
            print("TAMU_VISUAL_CAPTURE_OK chunks=", loaded, " vertices=", vertices, " objects=", object_count, " avatar_parts=", avatar_parts.size())
            if harvestables.is_empty():
                push_error("TAMU_HARVEST_TEST_EMPTY")
                get_tree().quit(12)
                return
            actor_world = harvestables[0]["position"]
            harvest_button.emit_signal("pressed")
            if harvested_count != 1 or harvestables[0]["sprite"].visible:
                push_error("TAMU_HARVEST_BUTTON_GATE_FAILED")
                get_tree().quit(13)
                return
            print("TAMU_HARVEST_BUTTON_GATE_OK count=",harvested_count)
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
