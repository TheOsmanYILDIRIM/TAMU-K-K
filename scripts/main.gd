extends Node2D
const WorldProjection = preload("res://scripts/world_projection.gd")
const WorldSource = preload("res://scripts/world_source.gd")
const WorldStream = preload("res://scripts/world_stream.gd")
const MergedTerrain = preload("res://scripts/merged_terrain.gd")
const ProfileRig = preload("res://scripts/profile_rig.gd")
const GameplaySession = preload("res://scripts/gameplay_session.gd")
const R2Authority = preload("res://scripts/r2_authority.gd")
const R2Collision = preload("res://scripts/r2_collision.gd")
const HarvestNavigation = preload("res://scripts/harvest_pathfinder.gd")
const WorldIdentity = preload("res://scripts/world_identity.gd")
const AudioCues = preload("res://scripts/audio_cues.gd")
const ImpactEffects = preload("res://scripts/impact_effects.gd")
const SHADOW_SHADER = preload("res://scripts/object_shadow.gdshader")
const SELECTION_SHADER = preload("res://scripts/harvest_outline.gdshader")
const FOREST_GUI = preload("res://scripts/forest_harvest_gui.gd")
const MODULAR_HUD = preload("res://scripts/modular_hud.gd")
const ShadowVolume = preload("res://scripts/shadow_volume.gd")
const PixelLightWorld = preload("res://scripts/pixellight_world.gd")
const VisualEnvironment = preload("res://scripts/visual_environment.gd")
var merged_mode: bool = OS.get_environment("TAMU_TERRAIN_MODE") != "legacy"
# Each independently authored region is a separate logical chunk, not one global world.
var region_chunks: Dictionary = {}
var world_source: RefCounted
# Godot native ArrayMesh terrain; binary geometry and atlas are sourced from
# the SAME TAMU compiled LÖVE CI artifact, never resampled.
var terrain_atlas: Texture2D
var detail_environment: MeshInstance2D
var detail_count := 0
var env_visual_stage := 3
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
var object_chunk_visibility: Dictionary = {}
var harvestables: Array[Dictionary] = []
var harvested_by_id: Dictionary = {}
var gameplay: RefCounted
var authority: RefCounted
var gameplay_sequence := 0
var harvested_count := 0
var shadow_sprites: Array[Polygon2D] = []
var shadow_alpha_cache: Dictionary = {}
var silhouette_shadows: Array[Sprite2D] = []
var silhouette_material: ShaderMaterial
var audio_cues: Node
var impact_effects: Node2D
var day_clock := 10.5
var sun_direction := Vector2.ZERO
var sun_level := 1.0
var daylight_layer: CanvasModulate
var harvest_button: Button
var harvest_hint: Label
var forest_gui: CanvasLayer
var selected_harvest: Dictionary = {}
var selected_harvest_outline: Sprite2D
var modular_hud: CanvasLayer
var ui_touch_ids: Dictionary = {}
var world_touch_pointer := -1
var harvest_navigation = HarvestNavigation.new()
var auto_harvest_id := ""
var auto_route: Array[Vector2] = []
var auto_path_loaded := false
var auto_stuck_time := 0.0
var harvest_alpha_cache: Dictionary = {}
var harvest_outline_material: ShaderMaterial
const DAY_SECONDS := 30.0
var world_bounds := Rect2(-4096.0, -4096.0, 32768.0, 32768.0)
const MAX_LOADED_PER_FRAME := 1
const ACTOR_COLLISION_RADIUS := 9.0
# Exact canonical LÖVE renderer reference, not an arbitrary Godot art resize:
# camera.lua default=1.7; rigby_visual.lua display.height=72;
# terrain25d_sprites.lua sprite foot pivot=(64,124) on 128px source.
const LOVE_CAMERA_ZOOM := 1.7
const LOVE_PLAYER_HEIGHT := 72.0
const LOVE_OBJECT_PIVOT := 124.0 / 128.0
# Original R2 ecology was exported using Iso.project(x,y,height*0.35).
const R2_HEIGHT_SCREEN_SCALE := 0.35
var actor_ground_sample_at := Vector2(INF, INF)
var actor_ground_screen_offset := 0.0
var avatar: Node2D
var actor_world := Vector2(64.0, 128.0)
var actor_speed := 96.0
# Profile art has only left/right sides. Store that choice independently of
# legacy Rigby's four authored clip directions.
var profile_facing_sign := 1.0
var actor_direction := "SE"
var profile_rig: Node2D
var profile_contact_shadow: Polygon2D
var pixellight_world_light: PointLight2D
var fast_cull_visible_nodes := 0
var fast_cull_total_nodes := 0
const ISOLATION_MODES = ["full", "mob_visual_off", "mob_ai_off",
    "mob_all_off", "solar_off", "objects_off", "terrain_off", "player_rig_off"]
var perf_isolation_mode := "full"
var shadow_layer: Node2D

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
        if silhouette_material != null:
            silhouette_material.set_shader_parameter("solar_dir", -sun_direction)
            silhouette_material.set_shader_parameter("solar_length", clampf(0.28 + 1.05 * (1.0-light)/(light+0.31), 0.28, 2.65))
            silhouette_material.set_shader_parameter("opacity", 0.36 * light)
        # One authored alpha silhouette shadow per solid. No second polygon cast.

func _next_gameplay_command(prefix: String) -> String:
    gameplay_sequence += 1
    return "%s:%d" % [prefix, gameplay_sequence]

# Tap an authored opaque sprite first. TOPLA executes the existing
# distance, inventory, Stage6 and depletion rules for that selected ID.
func _harvest_feedback(message: String) -> void:
    if harvest_hint != null:
        harvest_hint.text = message
    if forest_gui != null:
        forest_gui.call("set_status",message)

func _cancel_auto_harvest() -> void:
    auto_harvest_id = ""
    auto_route.clear()
    auto_path_loaded = false
    auto_stuck_time = 0.0
    harvest_navigation.cancel()

func _auto_harvest_direction(_delta: float) -> Vector2:
    if auto_harvest_id.is_empty():
        return Vector2.ZERO
    if selected_harvest.is_empty() or str(selected_harvest.get("id", "")) != auto_harvest_id             or bool(selected_harvest.get("collected", false))             or not authority.matches_object(selected_harvest):
        _cancel_auto_harvest()
        return Vector2.ZERO
    var target_pos: Vector2 = selected_harvest["position"]
    var harvest_radius: float = GameplaySession.HARVEST_RANGE + maxf(0.0, float(selected_harvest.get("radius", 0.0)))
    if actor_world.distance_squared_to(target_pos) <= harvest_radius*harvest_radius:
        _cancel_auto_harvest()
        _try_harvest()
        return Vector2.ZERO
    if harvest_navigation.state == "searching":
        harvest_navigation.advance(32, 900)
    if harvest_navigation.state == "failed":
        var fail_reason: String = harvest_navigation.reason
        _cancel_auto_harvest()
        _harvest_feedback("YOL BULUNAMADI: " + fail_reason)
        return Vector2.ZERO
    if harvest_navigation.state == "searching":
        return Vector2.ZERO
    if harvest_navigation.state == "ready" and not auto_path_loaded:
        auto_route.assign(harvest_navigation.path)
        auto_path_loaded = true
        if auto_route.is_empty():
            _cancel_auto_harvest()
            _harvest_feedback("HEDEFE ULAŞILAMADI")
            return Vector2.ZERO
        _harvest_feedback("KAYNAĞA GİDİLİYOR…")
    while not auto_route.is_empty() and actor_world.distance_squared_to(auto_route[0]) < 2.25:
        auto_route.pop_front()
    if auto_route.is_empty():
        # The next frame either reaches harvesting range or fails explicitly.
        if actor_world.distance_squared_to(target_pos) <= harvest_radius*harvest_radius:
            _cancel_auto_harvest()
            _try_harvest()
        else:
            _cancel_auto_harvest()
            _harvest_feedback("YOL TAMAMLANDI, KAYNAK UZAKTA")
        return Vector2.ZERO
    return (auto_route[0] - actor_world).normalized()

func _clear_harvest_selection() -> void:
    _cancel_auto_harvest()
    selected_harvest = {}
    if forest_gui != null:
        forest_gui.call("close")
    if selected_harvest_outline != null and is_instance_valid(selected_harvest_outline):
        selected_harvest_outline.queue_free()
    selected_harvest_outline = null
    if harvest_button != null:
        harvest_button.text = "TOPLA"

func _selection_art(item: Dictionary) -> Dictionary:
    var key := str(item.get("alpha_key",""))
    if harvest_alpha_cache.has(key):
        return harvest_alpha_cache[key]
    var sprite: Sprite2D = item["sprite"]
    var original: Image = item.get("pixel_alpha_image", null)
    if original == null:
        original = sprite.texture.get_image()
    if original == null or original.is_empty():
        return {}
    var padding := 5
    var padded := Image.create(original.get_width()+2*padding,
        original.get_height()+2*padding,false,Image.FORMAT_RGBA8)
    padded.fill(Color.TRANSPARENT)
    padded.blit_rect(original,Rect2i(Vector2i.ZERO,original.get_size()),
        Vector2i(padding,padding))
    var art := {"image":original,
        "outline":ImageTexture.create_from_image(padded)}
    harvest_alpha_cache[key]=art
    return art

func _alpha_contains(image: Image, x: int, y: int, flipped: bool) -> bool:
    if image == null or x<0 or y<0 or x>=image.get_width() or y>=image.get_height():
        return false
    var px := image.get_width()-1-x if flipped else x
    # Small tolerance for fingers, without accepting empty areas of a crop.
    for delta in [Vector2i.ZERO,Vector2i(2,0),Vector2i(-2,0),
            Vector2i(0,2),Vector2i(0,-2)]:
        var point: Vector2i = Vector2i(px,y)+delta
        if point.x>=0 and point.y>=0 and point.x<image.get_width() and point.y<image.get_height():
            if image.get_pixel(point.x,point.y).a>0.13:
                return true
    return false

func _select_harvest(item: Dictionary) -> bool:
    if item.is_empty() or bool(item.get("collected",false)):
        return false
    var sprite: Sprite2D = item["sprite"]
    if not sprite.visible or not gameplay.is_harvestable(str(item["kind"])):
        return false
    var art := _selection_art(item)
    if art.is_empty():
        return false
    _clear_harvest_selection()
    selected_harvest=item
    if harvest_outline_material == null:
        harvest_outline_material=ShaderMaterial.new()
        harvest_outline_material.shader=SELECTION_SHADER
    var outline := Sprite2D.new()
    outline.name="HarvestGoldSilhouette"
    outline.texture=art["outline"]
    outline.centered=sprite.centered
    outline.offset=sprite.offset
    outline.flip_h=sprite.flip_h
    outline.z_index=1
    outline.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
    outline.material=harvest_outline_material
    sprite.add_child(outline)
    selected_harvest_outline=outline
    if forest_gui != null:
        forest_gui.call("open_for",item)
    _harvest_feedback("SEÇİLDİ: %s  ·  TOPLA" % ("AĞAÇ" if str(item["kind"])=="tree" else "KAYA"))
    print("TAMU_HARVEST_SELECTED id=",item["id"]," alpha_outline=true")
    return true

func _harvest_at_screen(screen_point: Vector2) -> bool:
    if gameplay==null or authority==null:
        return false
    var chosen: Dictionary={}
    var best_depth := -INF
    var best_distance := INF
    for item in harvestables:
        if bool(item.get("collected",false)) or not gameplay.is_harvestable(str(item["kind"])):
            continue
        var sprite: Sprite2D = item["sprite"]
        if not sprite.visible:
            continue
        var transform := sprite.get_global_transform_with_canvas()
        var local := transform.affine_inverse() * screen_point
        var rect := sprite.get_rect()
        if not rect.has_point(local):
            continue
        var art := _selection_art(item)
        if art.is_empty():
            continue
        var image: Image = art["image"]
        var px := floori(local.x-rect.position.x)
        var py := floori(local.y-rect.position.y)
        if not _alpha_contains(image,px,py,sprite.flip_h):
            continue
        var depth: float = sprite.global_position.y
        var distance: float = screen_point.distance_squared_to(transform*rect.get_center())
        if depth>best_depth+0.01 or (absf(depth-best_depth)<=0.01 and distance<best_distance):
            chosen=item
            best_depth=depth
            best_distance=distance
    if chosen.is_empty():
        return false
    return _select_harvest(chosen)

func _try_harvest() -> void:
    if selected_harvest.is_empty():
        _harvest_feedback("ÖNCE BİR AĞACA VEYA KAYAYA DOKUN")
        print("TAMU_HARVEST_NO_SELECTION")
        return
    if not gameplay.active_harvest.is_empty():
        _harvest_feedback("TOPLAMA İŞLEMİ SÜRÜYOR")
        return
    if bool(selected_harvest.get("collected",false)):
        _clear_harvest_selection()
        _harvest_feedback("BU KAYNAK TOPLANMIŞ")
        return
    if not authority.matches_object(selected_harvest):
        push_error("TAMU_HARVEST_SOURCE_MISMATCH")
        return
    var item: Dictionary=selected_harvest
    var harvest_radius: float = GameplaySession.HARVEST_RANGE + maxf(0.0, float(item.get("radius", 0.0)))
    var target_pos: Vector2 = item["position"]
    if actor_world.distance_squared_to(target_pos) > harvest_radius * harvest_radius:
        if auto_harvest_id == str(item["id"]):
            return
        _cancel_auto_harvest()
        if not harvest_navigation.begin(actor_world, target_pos, harvest_radius,
                ACTOR_COLLISION_RADIUS, Callable(gameplay, "movement_obstacles"),
                Callable(authority, "surface"), world_bounds):
            _harvest_feedback("YOL BULUNAMADI: " + harvest_navigation.reason)
            return
        auto_harvest_id = str(item["id"])
        _harvest_feedback("YOL HESAPLANIYOR…")
        print("TAMU_AUTO_HARVEST_ROUTE id=", auto_harvest_id)
        return
    var result: Dictionary=gameplay.begin_harvest(item,actor_world,
        _next_gameplay_command("harvest"))
    var status := str(result.get("status","unknown"))
    if status=="started":
        audio_cues.cue("harvest_start")
        impact_effects.burst(item["sprite"].position,str(item["kind"]),6)
        _harvest_feedback("TOPLANIYOR…")
    elif status=="out_of_range":
        _harvest_feedback("ÇOK UZAK: YAKLAŞ VE TOPLA")
    elif status=="inventory_full":
        _harvest_feedback("ENVANTER DOLU")
    else:
        _harvest_feedback("TOPLAMA: "+status)
    print("TAMU_HARVEST_COMMAND id=",item["id"]," status=",status)

# Minimal gameplay adapter: the canonical DomainBuilding remains authoritative.
# Structures are drawn at world foot positions and restored from Stage6 saves.
func _sync_building_visuals() -> void:
    if gameplay == null or object_layer == null:
        return
    for instance_id in gameplay.building.placed:
        if placed_visuals.has(instance_id):
            continue
        var placed: Dictionary = gameplay.building.placed[instance_id]
        var node := Node2D.new()
        node.name = "Structure_" + str(instance_id)
        node.position = WorldProjection.to_screen(Vector2(float(placed["x"]), float(placed["y"])))
        if authority != null:
            node.position.y -= authority.terrain.height_at(float(placed["x"]), float(placed["y"])) * R2_HEIGHT_SCREEN_SCALE
        var top := Polygon2D.new()
        top.polygon = PackedVector2Array([Vector2(-23,-20),Vector2(0,-32),
            Vector2(23,-20),Vector2(0,-8)])
        top.color = Color(0.69,0.50,0.34)
        node.add_child(top)
        var front := Polygon2D.new()
        front.polygon = PackedVector2Array([Vector2(-23,-20),Vector2(0,-8),
            Vector2(0,0),Vector2(-23,-12)])
        front.color = Color(0.40,0.28,0.21)
        node.add_child(front)
        var side := Polygon2D.new()
        side.polygon = PackedVector2Array([Vector2(0,-8),Vector2(23,-20),
            Vector2(23,-12),Vector2(0,0)])
        side.color = Color(0.52,0.36,0.25)
        node.add_child(side)
        object_layer.add_child(node)
        placed_visuals[instance_id] = node
    for instance_id in placed_visuals.keys():
        if not gameplay.building.placed.has(instance_id):
            placed_visuals[instance_id].queue_free()
            placed_visuals.erase(instance_id)

func _place_workbench() -> void:
    _cancel_auto_harvest()
    if gameplay == null or authority == null:
        return
    # Use real domain validation: distance, terrain, collision, inventory and
    # durable journal all decide success; no debug resource injection.
    var target := actor_world + Vector2(48.0,0.0)
    var uid := "%08x-%04x-4%03x-a%03x-%012x" % [
        randi(), randi() & 0xffff, randi() & 0xfff,
        randi() & 0xfff, (int(randi()) << 16) | (randi() & 0xffff)]
    var result: Dictionary = gameplay.place_building(_next_gameplay_command("build"),
        uid, "core:workbench", target, 0, actor_world, "player")
    if str(result.get("status","")) == "placed":
        _sync_building_visuals()
        audio_cues.cue("craft_complete")
    print("TAMU_BUILD_COMMAND status=",result.get("status","unknown"))

func _begin_craft(recipe_id: String) -> void:
    _cancel_auto_harvest()
    var result: Dictionary = gameplay.begin_craft(_next_gameplay_command("craft"), recipe_id)
    print("TAMU_CRAFT_COMMAND recipe=", recipe_id, " status=", result["status"])

func _tick_gameplay(dt: float) -> void:
    var changes: Array[Dictionary] = gameplay.tick(dt, actor_world)
    for change in changes:
        if change["type"] == "HarvestCompleted":
            var id: String = change["object_id"]
            if not harvested_by_id.has(id):
                push_error("TAMU_GAMEPLAY_HARVEST_ID_MISSING " + id)
                continue
            var item: Dictionary = harvested_by_id[id]
            # One resource may produce several drop events; remove its world
            # visual and emit completion FX only on the first event.
            if bool(item.get("collected", false)):
                continue
            item["collected"] = true
            if not selected_harvest.is_empty() and str(selected_harvest["id"])==id:
                _clear_harvest_selection()
                _harvest_feedback("KAYNAK TOPLANDI")
            var sprite: Sprite2D = item["sprite"]
            sprite.set_meta("tamu_collected", true)
            sprite.visible = false
            if item["shadow"] != null:
                var shadow: Polygon2D = item["shadow"]
                shadow.set_meta("tamu_collected", true)
                shadow.visible = false
            if item.has("silhouette"):
                item["silhouette"].set_meta("tamu_collected", true)
                item["silhouette"].visible = false
            harvested_count += 1
            authority.depleted_ids[id] = true
            audio_cues.cue("harvest_complete")
            impact_effects.burst(sprite.position, str(item["kind"]), 14)
            print("TAMU_HARVEST_OK id=", id, " count=", harvested_count,
                " item=", change["item_id"], " amount=", change["amount"])
        elif change["type"] == "CraftCompleted":
            audio_cues.cue("craft_complete")
            impact_effects.burst(WorldProjection.to_screen(actor_world), "craft", 12)
            print("TAMU_CRAFT_OK recipe=", change["recipe_id"])

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
    harvest_button=button
    var status := Label.new()
    status.name="HarvestSelectionStatus"
    status.anchor_left=0.0
    status.anchor_right=1.0
    status.offset_left=18.0
    status.offset_right=-18.0
    status.offset_top=44.0
    status.offset_bottom=90.0
    status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    status.mouse_filter=Control.MOUSE_FILTER_IGNORE
    status.add_theme_font_size_override("font_size",19)
    status.add_theme_color_override("font_color",Color(1.0,0.85,0.26))
    status.add_theme_color_override("font_shadow_color",Color(0.02,0.02,0.02,0.92))
    status.add_theme_constant_override("shadow_offset_y",2)
    status.text="OBJEYE DOKUN, SONRA TOPLA"
    root.add_child(status)
    harvest_hint=status
    for option in [
        {"name": "CraftPlanks", "text": "TAHTA", "recipe": "core:planks_from_log", "top": -308.0, "bottom": -210.0},
        {"name": "CraftWorkbench", "text": "TEZGAH", "recipe": "core:bench_from_planks", "top": -420.0, "bottom": -322.0}
    ]:
        var crafting_button := Button.new()
        crafting_button.name = str(option["name"])
        crafting_button.text = str(option["text"])
        crafting_button.anchor_left = 1.0
        crafting_button.anchor_right = 1.0
        crafting_button.anchor_top = 1.0
        crafting_button.anchor_bottom = 1.0
        crafting_button.offset_left = -190.0
        crafting_button.offset_right = -24.0
        crafting_button.offset_top = float(option["top"])
        crafting_button.offset_bottom = float(option["bottom"])
        crafting_button.mouse_filter = Control.MOUSE_FILTER_STOP
        crafting_button.add_theme_font_size_override("font_size", 22)
        crafting_button.add_theme_stylebox_override("normal", style)
        crafting_button.pressed.connect(_begin_craft.bind(str(option["recipe"])))
        root.add_child(crafting_button)
    var place_button := Button.new()
    place_button.name = "PlaceWorkbench"
    place_button.text = "KUR"
    place_button.anchor_left = 1.0
    place_button.anchor_right = 1.0
    place_button.anchor_top = 1.0
    place_button.anchor_bottom = 1.0
    place_button.offset_left = -190.0
    place_button.offset_right = -24.0
    place_button.offset_top = -532.0
    place_button.offset_bottom = -434.0
    place_button.mouse_filter = Control.MOUSE_FILTER_STOP
    place_button.add_theme_font_size_override("font_size", 22)
    place_button.add_theme_stylebox_override("normal",style)
    place_button.pressed.connect(_place_workbench)
    root.add_child(place_button)
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
    # Preserve joystick physics and touch handling, replace only its skin.
    joystick_base.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
    root.add_child(joystick_base)
    var leather_ring := TextureRect.new()
    leather_ring.name = "CarvedJoystickRing"
    leather_ring.texture = load("res://assets/gui/joystick_base.png")
    leather_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    leather_ring.stretch_mode = TextureRect.STRETCH_SCALE
    leather_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_base.add_child(leather_ring)
    leather_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    joystick_knob = Panel.new()
    joystick_knob.name = "JoystickKnob"
    joystick_knob.position = Vector2(47,47)
    joystick_knob.size = Vector2(62,62)
    joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var knob_style := StyleBoxFlat.new()
    knob_style.bg_color = Color(0.52,0.82,0.76,0.72)
    knob_style.set_corner_radius_all(31)
    joystick_knob.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
    joystick_base.add_child(joystick_knob)
    var engraved_knob := TextureRect.new()
    engraved_knob.name = "EngravedStoneKnob"
    engraved_knob.texture = load("res://assets/gui/joystick_knob.png")
    engraved_knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    engraved_knob.stretch_mode = TextureRect.STRETCH_SCALE
    engraved_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_knob.add_child(engraved_knob)
    engraved_knob.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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

func _world_ui_hit(point: Vector2) -> bool:
    # Decorative HUD textures are IGNORE for Godot GUI dispatch, but they
    # must still shield the authored world from pointer selection/drag.
    if modular_hud != null and bool(modular_hud.call("blocks_world_input", point)):
        return true
    if forest_gui != null:
        var popup: Control = forest_gui.get("panel") as Control
        if popup != null and popup.is_visible_in_tree() and popup.get_global_rect().has_point(point):
            return true
    var legacy: Control = get_node_or_null("HarvestTestUI/HarvestOverlay") as Control
    if legacy != null:
        for child in legacy.get_children():
            if child is Control and child.is_visible_in_tree() and child.get_global_rect().has_point(point):
                return true
    if perf_hud != null:
        var perf_panel: Control = perf_hud.get("panel") as Control
        if perf_panel != null and perf_panel.is_visible_in_tree() and perf_panel.get_global_rect().has_point(point):
            return true
    if joystick_base != null and point.distance_to(_joystick_center()) <= 105.0:
        return true
    return false

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if _world_ui_hit(event.position):
                ui_touch_ids[event.index] = true
        else:
            ui_touch_ids.erase(event.index)
            if world_touch_pointer == event.index:
                world_touch_pointer = -1
                drag = false
    if joystick_base == null:
        return
    if event is InputEventScreenTouch:
        if event.pressed and joystick_pointer < 0                 and event.position.distance_to(_joystick_center()) <= 105.0:
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
    # One production character: 23-bone weighted side-profile. No legacy Rigby
    # nodes, hidden six-sprite renderer, duplicate animation loop or CI-only art.
    avatar = Node2D.new()
    avatar.name = "OsmanProfile"
    avatar.z_index = 0
    object_layer.add_child(avatar)
    profile_rig = ProfileRig.new()
    profile_rig.name = "TAMUProfileWeightedRig"
    avatar.add_child(profile_rig)
    if not profile_rig.setup() or not profile_rig.verify_contract():
        push_error("TAMU_PROFILE_GAMEPLAY_SETUP_FAILED")
        get_tree().quit(73)
        return
    avatar.scale = Vector2.ONE
    if not profile_rig.visible or absf(profile_rig.scale.y / ProfileRig.SOURCE_SCALE - 1.0) > 0.025:
        push_error("TAMU_PROFILE_GAMEPLAY_SCALE_FAILED")
        get_tree().quit(75)
        return
    print("TAMU_PROFILE_VIEW_SCALE_OK world_height=72")
    print("TAMU_PROFILE_GAMEPLAY_RIG_ACTIVE bones=23 parts=6")
    print("TAMU_PROFILE_ONLY_VISIBLE_OK legacy_sprites=0")
    profile_contact_shadow = Polygon2D.new()
    profile_contact_shadow.name = "ProfileGroundContact"
    var footprint := PackedVector2Array()
    for i in range(20):
        var angle := TAU * float(i) / 20.0
        footprint.append(Vector2(cos(angle) * ACTOR_COLLISION_RADIUS * 1.3,
            sin(angle) * ACTOR_COLLISION_RADIUS * 0.34))
    profile_contact_shadow.polygon = footprint
    profile_contact_shadow.color = Color(0.05, 0.07, 0.06, 0.27)
    profile_contact_shadow.z_index = -1
    object_layer.add_child(profile_contact_shadow)
    _update_avatar()
    print("TAMU_PROFILE_FOOT_CONTACT_READY radius=", ACTOR_COLLISION_RADIUS)


func _set_actor_clip(direction: String, action: String) -> void:
    actor_direction = direction
    if profile_rig != null:
        profile_rig.set_clip(action)
    avatar.scale.x = profile_facing_sign


func _update_avatar() -> void:
    if authority != null and actor_world.distance_squared_to(actor_ground_sample_at) > 0.000001:
        var ground_height: float = float(authority.terrain.height_at(actor_world.x, actor_world.y))
        if is_finite(ground_height):
            actor_ground_screen_offset = ground_height * R2_HEIGHT_SCREEN_SCALE
            actor_ground_sample_at = actor_world
    var ground_anchor := WorldProjection.to_screen(actor_world)
    if profile_contact_shadow != null:
        profile_contact_shadow.position = ground_anchor - Vector2(0.0, actor_ground_screen_offset)
    avatar.position = ground_anchor
    if profile_rig != null:
        profile_rig.position.y = -689.0 * ProfileRig.SOURCE_SCALE - actor_ground_screen_offset

# A drawable can straddle an authored source cell; cull by its actual
# projected bounds and keep a conservative shadow-margin against popping.
# Region geometry and IDs remain one logical authored region.
func _fast_view_rect() -> Rect2:
    var camera: Camera2D = $Camera2D
    var half_size := get_viewport_rect().size * 0.5 / camera.zoom
    return Rect2(camera.get_screen_center_position() - half_size, half_size * 2.0)

func _set_perf_isolation(mode: String) -> void:
    if not ISOLATION_MODES.has(mode):
        push_error("TAMU_PERF_ISOLATION_INVALID " + mode)
        return
    perf_isolation_mode = mode
    var mobs: Node = get_node_or_null("MobWorld")
    if mobs != null:
        mobs.call("set_isolation_mode", mode)
    if shadow_layer != null:
        shadow_layer.visible = mode != "solar_off"
    if profile_rig != null:
        profile_rig.visible = mode != "player_rig_off"
    if detail_environment != null:
        detail_environment.visible = mode != "terrain_off"
    for region_id in region_chunks:
        var terrain_node: Node2D = region_chunks[region_id]
        if is_instance_valid(terrain_node):
            terrain_node.visible = mode != "terrain_off"
    if object_layer != null and not object_visuals_by_chunk.is_empty():
        _refresh_streaming_requests()
    if perf_hud != null:
        perf_hud.call("set_isolation_mode", mode)
    print("TAMU_PERF_ISOLATION_APPLIED profile=", mode,
        " regions=", region_chunks.size(), " authored_objects=", object_count)

func _fast_node_in_view(node: Node2D, view: Rect2) -> bool:
    if not node is Sprite2D:
        return true
    var sprite := node as Sprite2D
    if sprite.texture == null:
        return false
    var source := sprite.get_rect()
    var render_bounds := Rect2(sprite.position + source.position * sprite.scale, source.size * sprite.scale)
    # Solar silhouette vertex shader sweeps further than its source crop.
    var margin := 180.0 if sprite.material == silhouette_material else 54.0
    return render_bounds.grow(margin).intersects(view)

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
        var fast_mode := VisualEnvironment.mobile_fast_mode()
        var fast_view := _fast_view_rect() if fast_mode else Rect2()
        # The terrain stays one authored region mesh, but its individual
        # foliage/rock sprites and alpha shadows are culled by visible source cell.
        for stem in object_visuals_by_chunk:
            var show: bool = view_required.has(stem)
            # A world reload/harvest can change CanvasItem.visible without
            # changing the camera cell. Heal stale visibility using the first
            # authored item as a low-cost sentinel; avoid rewriting 832
            # objects on every camera plan when they are already correct.
            var nodes: Array = object_visuals_by_chunk[stem]
            var stale: bool = not nodes.is_empty() and is_instance_valid(nodes[0]) and                 nodes[0].visible != (show and not bool(nodes[0].get_meta("tamu_collected", false)))
            # Camera motion within a 256-unit authored cell also changes
            # per-object visibility; don't rely on a single cell sentinel.
            if fast_mode or stale or not object_chunk_visibility.has(stem) or bool(object_chunk_visibility[stem]) != show:
                _set_chunk_visuals_visible(str(stem), show, fast_view)
                object_chunk_visibility[stem] = show
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
    if VisualEnvironment.mobile_fast_mode():
        # canvas_items renders at the full Android display resolution.
        # viewport renders into the 720x1280 base, then upscales once.
        var root_window: Window = get_tree().root
        root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
        root_window.content_scale_size = Vector2i(720, 1280)
        print("TAMU_MOBILE_FAST_MODE renderer=viewport base=720x1280 texture_tier=source")
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
    audio_cues = AudioCues.new()
    add_child(audio_cues)
    audio_cues.play_music("forest")
    impact_effects = ImpactEffects.new()
    add_child(impact_effects)
    silhouette_material = ShaderMaterial.new()
    silhouette_material.shader = SHADOW_SHADER
    terrain_atlas = load("res://assets/terrain25d/atlas_00.png")
    env_visual_stage = VisualEnvironment.level()
    var terrain_hires := not VisualEnvironment.mobile_fast_mode() and OS.get_environment("TAMU_TERRAIN_HIRES") != "0" and ResourceLoader.exists("res://assets/terrain25d/atlas_00_hires.png")
    if terrain_hires:
        var terrain_path := "res://assets/terrain25d/atlas_00_mix_hires.png" if env_visual_stage >= 1 else "res://assets/terrain25d/atlas_00_hires.png"
        if ResourceLoader.exists(terrain_path):
            terrain_atlas = load(terrain_path)
            print("TAMU_TERRAIN_HIRES_ACTIVE size=", terrain_atlas.get_size(), " stage=", env_visual_stage)
        else:
            push_error("TAMU_TERRAIN_HIRES_MIX_MISSING")
            get_tree().quit(32)
            return
    if env_visual_stage >= 1 and not terrain_hires:
        # Build-time packed derivative: one texture fetch rather than the
        # four-lookups-per-pixel prototype shader, with no extra draw calls.
        var mixed_path := "res://assets/terrain25d/atlas_00_mix.png"
        if ResourceLoader.exists(mixed_path):
            terrain_atlas = load(mixed_path)
            print("TAMU_TERRAIN_MIX_TEXTURE_READY")
        else:
            push_warning("TAMU_TERRAIN_MIX_NOT_BAKED: run scripts/bake_terrain_mix.py for authored blend; source atlas used")
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
    camera.zoom = Vector2.ONE * LOVE_CAMERA_ZOOM
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
    gameplay = GameplaySession.new()
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and not gameplay.verify_contract():
        push_error("TAMU_GAMEPLAY_DOMAIN_GATE_FAILED")
        get_tree().quit(23)
        return
    _load_objects()
    authority = R2Authority.new()
    if not authority.initialize():
        push_error("TAMU_R2_AUTHORITY_UNAVAILABLE")
        get_tree().quit(24)
        return
    if object_count != authority.records.size():
        push_error("TAMU_R2_AUTHORED_OBJECT_COUNT_MISMATCH")
        get_tree().quit(24)
        return
    for item in harvestables:
        if not authority.matches_object(item):
            push_error("TAMU_R2_AUTHORED_OBJECT_ID_MISMATCH " + str(item["id"]))
            get_tree().quit(24)
            return
    if OS.get_environment("TAMU_VISUAL_CI") != "1" and merged_mode:
        var world: Dictionary = WorldIdentity.load_or_create()
        if not bool(world.get("ok", false)):
            push_error("TAMU_WORLD_IDENTITY_GATE_FAILED " + str(world.get("status", "")))
            get_tree().quit(24)
            return
        var enabled: Dictionary = gameplay.enable_durable("game", str(world["id"]), authority.region_id,
            Callable(authority, "surface"), Callable(authority, "obstacles"))
        if not bool(enabled.get("ok", false)):
            push_error("TAMU_STAGE6_PRODUCTION_GATE_FAILED " + str(enabled.get("status", "")))
            get_tree().quit(24)
            return
        for item in harvestables:
            if gameplay.depleted.has(str(item["id"])):
                item["collected"] = true
                item["sprite"].visible = false
                item["sprite"].set_meta("tamu_collected", true)
                if item["shadow"] != null:
                    item["shadow"].visible = false
                if item.has("silhouette"):
                    item["silhouette"].set_meta("tamu_collected", true)
                    item["silhouette"].visible = false
        authority.depleted_ids = gameplay.depleted.duplicate(true)
        print("TAMU_STAGE6_PRODUCTION_ACTIVE world=",world["id"]," region=",authority.region_id)
        if OS.get_environment("TAMU_PRODUCTION_SMOKE") == "1":
            print("TAMU_STAGE6_PRODUCTION_SMOKE_OK status=",enabled["status"]," identity=",world["status"],
                " objects=",authority.records.size()," region=",authority.region_id)
            set_process(false)
            get_tree().quit()
            return
    if env_visual_stage >= 3 and not VisualEnvironment.mobile_fast_mode():
        var decor_manifest: Variant = JSON.parse_string(
            FileAccess.get_file_as_string("res://assets/terrain25d/manifest.json"))
        var decor_hires_active: bool = VisualEnvironment.apply_highres_object_uvs(decor_manifest)
        var decor_atlas: Texture2D = load(VisualEnvironment.HIRES_OBJECT_ATLAS if decor_hires_active else "res://assets/terrain25d/atlas_01.png")
        var decor: Dictionary = VisualEnvironment.detail_mesh(decor_manifest, decor_atlas, harvestables, authority)
        detail_count = int(decor.get("count",0))
        detail_environment = decor.get("node",null)
        if detail_environment != null:
            add_child(detail_environment)
        print("TAMU_ENV_DETAIL_OK quads=",detail_count,
            " vertices=",decor.get("vertices",0)," max=",VisualEnvironment.MAX_DETAIL_QUADS)
    # The object index is constructed after the first camera plan at boot.
    # Cull off-screen authored visuals before the first gameplay frame.
    if merged_mode:
        _refresh_streaming_requests()
    _make_avatar()
    _sync_building_visuals()
    perf_hud = load("res://scripts/performance_hud.gd").new()
    add_child(perf_hud)
    perf_hud.layer = 118 # HUD _ready sets 100; override after attachment.
    perf_hud.connect("isolation_requested", Callable(self, "_set_perf_isolation"))
    _set_perf_isolation("full")
    _init_mobile_joystick()
    _init_harvest_button()
    forest_gui=FOREST_GUI.new()
    forest_gui.name="ForestHarvestInterface"
    add_child(forest_gui)
    forest_gui.call("setup",self)
    print("TAMU_FOREST_GUI_READY")
    modular_hud = MODULAR_HUD.new()
    modular_hud.name = "ModularReferenceHUD"
    add_child(modular_hud)
    if modular_hud.setup(self):
        print("TAMU_MODULAR_HUD_READY")
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
    node.visible = perf_isolation_mode != "terrain_off"
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

func _set_chunk_visuals_visible(stem: String, show: bool, viewport_bounds: Rect2 = Rect2()) -> void:
    var fast_mode := VisualEnvironment.mobile_fast_mode()
    var bounds := viewport_bounds if viewport_bounds.has_area() else (_fast_view_rect() if fast_mode else Rect2())
    for node in object_visuals_by_chunk.get(stem, []):
        if not is_instance_valid(node):
            continue
        var visible_now := show and not bool(node.get_meta("tamu_collected", false)) \
            and not bool(node.get_meta("tamu_pixellight_replaced_shadow", false))
        if visible_now and perf_isolation_mode == "objects_off":
            visible_now = false
        if visible_now and fast_mode:
            visible_now = _fast_node_in_view(node, bounds)
        if node.visible != visible_now:
            node.visible = visible_now

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
    if avatar.get_parent() != object_layer or profile_rig == null:
        return false
    if not profile_rig.visible and perf_isolation_mode != "player_rig_off":
        return false
    var expected_zoom := 0.82 if OS.get_environment("TAMU_VISUAL_CASE") == "zoom" else (2.0 if OS.get_environment("TAMU_VISUAL_CASE") == "grounding" else LOVE_CAMERA_ZOOM)
    if not is_equal_approx($Camera2D.zoom.x, expected_zoom):
        return false
    if authority != null:
        var projected_foot := WorldProjection.to_screen(actor_world)
        if profile_rig != null:
            if profile_contact_shadow == null or profile_contact_shadow.get_parent() != object_layer:
                return false
            if profile_contact_shadow.z_index != -1 or profile_contact_shadow.polygon.size() != 20:
                return false
            if profile_contact_shadow.position.distance_to(projected_foot - Vector2(0.0, actor_ground_screen_offset)) > 0.01:
                return false
            if avatar.position.distance_to(projected_foot) > 0.01:
                return false
            if absf(profile_rig.position.y + 689.0 * ProfileRig.SOURCE_SCALE + actor_ground_screen_offset) > 0.01:
                return false
        elif absf(avatar.position.y - (projected_foot.y - actor_ground_screen_offset)) > 0.01:
            return false
    for item in harvestables:
        var sprite: Sprite2D = item["sprite"]
        if sprite.get_parent() != object_layer or sprite.z_index != 0:
            return false
        if absf(sprite.offset.y - sprite.texture.get_height() * (0.5 - LOVE_OBJECT_PIVOT)) > 0.01:
            return false
        if item["shadow"] != null:
            var shadow: Polygon2D = item["shadow"]
            if shadow.get_parent().z_index >= object_layer.z_index:
                return false
            if not shadow.position.is_equal_approx(sprite.position):
                return false
            var silhouette: Sprite2D = item["silhouette"]
            if not silhouette.position.is_equal_approx(sprite.position) or not silhouette.offset.is_equal_approx(sprite.offset):
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
    var object_hires_active: bool = VisualEnvironment.apply_highres_object_uvs(manifest)
    print("TAMU_OBJECT_HIRES_ACTIVE active=",object_hires_active," atlas=",("4096" if object_hires_active else "1056"))
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
    # Solar silhouettes use the actual authored AtlasTexture. The old
    # separate baked shadow atlas/manifest were unused resident resources.
    shadow_layer = Node2D.new()
    shadow_layer.name = "CanonicalR2Shadows"
    shadow_layer.z_index = 2
    add_child(shadow_layer)
    object_layer.z_index = 3
    var atlas: Texture2D = load(VisualEnvironment.HIRES_OBJECT_ATLAS if object_hires_active else "res://assets/terrain25d/atlas_01.png")
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
        var scales := {"oak":1.18,"broadleaf":1.28,"conifer":1.34,"dead_tree":1.06,
            "boulder":0.44,"rock_cluster":0.50,"rock_spire":0.53,
            "shrub":0.30,"reeds":0.28,"stump":0.26,"fallen_log":0.41,"water_rocks":0.38}
        var visual_jitter := (0.96 + float(h % 9) * 0.01)
        if env_visual_stage >= 2:
            visual_jitter = VisualEnvironment.variation(h, kind)
        var scale_value := float(scales.get(family, 0.5)) * visual_jitter
        if object_hires_active:
            scale_value *= 128.0 / (size.x / 8.0) # Preserve 128px logical footprint across 512/384/256 atlas tiers
        sprite.scale = Vector2.ONE * scale_value
        if env_visual_stage >= 2:
            sprite.flip_h = posmod(h, 2) == 0
        # Local ground anchor follows the atlas region height, never a fixed 60 px.
        sprite.offset = Vector2(0.0, area.size.y * (0.5 - LOVE_OBJECT_PIVOT))
        object_layer.add_child(sprite)
        object_visuals_by_chunk[visual_key].append(sprite)
        var item_record := {"id":id,"kind":kind,"radius":float(o["radius"]),"position":Vector2(float(o["x"]),float(o["y"])),"sprite":sprite,"shadow":null,"collected":false}
        harvestables.append(item_record)
        item_record["alpha_key"]=str(a["id"])
        item_record["family"]=family
        harvested_by_id[id] = item_record
        # Single alpha silhouette cast, one shared solar material.
        if kind == "tree" or kind == "rock":
            # Exact object atlas alpha silhouette projected in the sun direction.
            var silhouette := Sprite2D.new()
            silhouette.name = "AuthoredSilhouetteShadow"
            silhouette.texture = tex
            silhouette.flip_h = sprite.flip_h
            silhouette.centered = sprite.centered
            silhouette.offset = sprite.offset
            silhouette.scale = sprite.scale
            silhouette.position = sprite.position
            silhouette.material = silhouette_material
            silhouette.visible = merged_mode
            shadow_layer.add_child(silhouette)
            silhouette_shadows.append(silhouette)
            object_visuals_by_chunk[visual_key].append(silhouette)
            item_record["silhouette"] = silhouette
            item_record["shadow"] = null
        object_count += 1
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and OS.get_environment("TAMU_VISUAL_CASE") == "gui":
        for candidate in harvestables:
            if candidate["kind"] == "tree" and str(candidate.get("family","")) in ["oak","broadleaf"]:
                $Camera2D.position = candidate["sprite"].position + Vector2(0.0,-35.0)
                _refresh_streaming_requests()
                break
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and OS.get_environment("TAMU_VISUAL_CASE") == "grounding":
        for item in harvestables:
            if item["kind"] == "tree":
                $Camera2D.position = item["sprite"].position + Vector2(0.0, -30.0)
                $Camera2D.zoom = Vector2(2.0, 2.0)
                _refresh_streaming_requests()
                break
    if OS.get_environment("TAMU_PIXELLIGHT_WORLD") == "1":
        var pl_result: Dictionary = PixelLightWorld.install(harvestables, object_layer, actor_world)
        pixellight_world_light = pl_result.get("light") as PointLight2D
        if int(pl_result.get("count", 0)) == 0:
            push_warning("TAMU_PIXELLIGHT_WORLD_NO_SAMPLES")
    print("TAMU_CANONICAL_OBJECTS_LOADED count=", object_count)

var object_count: int = 0
var object_layer: Node2D
var placed_visuals: Dictionary = {}

func _process(delta: float) -> void:
    # A Stage6 startup smoke can request quit before _make_avatar().
    # Godot may dispatch one more frame before the queued quit completes.
    if avatar == null or not is_instance_valid(avatar):
        return
    var frame_start := Time.get_ticks_usec()
    frame_no += 1
    var visual_delta: float = 1.0 / 60.0 if OS.get_environment("TAMU_VISUAL_CI") == "1" else delta
    _update_sun(visual_delta)
    elapsed += visual_delta
    var manual_direction: Vector2 = joystick_vector if joystick_vector.length_squared() > 0.01 else Input.get_vector("ui_left","ui_right","ui_up","ui_down")
    if manual_direction.length_squared() > 0.01 and not auto_harvest_id.is_empty():
        _cancel_auto_harvest()
        _harvest_feedback("OTOMATİK YÜRÜYÜŞ DURDURULDU")
    var automatic_direction: Vector2 = _auto_harvest_direction(delta) if manual_direction.length_squared() <= 0.01 else Vector2.ZERO
    var direction: Vector2 = manual_direction if manual_direction.length_squared() > 0.01 else automatic_direction
    if direction.length_squared() > 0.01:
        var intended := direction * actor_speed * delta
        if not auto_harvest_id.is_empty() and not auto_route.is_empty():
            intended = intended.limit_length(actor_world.distance_to(auto_route[0]))
        var position_before: Vector2 = actor_world
        if authority != null and OS.get_environment("TAMU_VISUAL_CI") != "1":
            var moved: Dictionary = R2Collision.move(actor_world,intended,ACTOR_COLLISION_RADIUS,
                Callable(gameplay,"movement_obstacles"))
            if bool(moved.get("ok", false)):
                actor_world = moved["position"]
        else:
            actor_world += intended
        actor_world.x = clampf(actor_world.x,world_bounds.position.x,world_bounds.end.x)
        actor_world.y = clampf(actor_world.y,world_bounds.position.y,world_bounds.end.y)
        if not auto_harvest_id.is_empty() and not auto_route.is_empty():
            if actor_world.distance_squared_to(position_before) < 0.01:
                auto_stuck_time += delta
                if auto_stuck_time >= 0.9:
                    _cancel_auto_harvest()
                    _harvest_feedback("YOL ENGELLENDİ")
            else:
                auto_stuck_time = 0.0
        var next_direction := "NW" if direction.y < 0.0 else "SE"
        if direction.x < -0.05:
            next_direction = "NE" if direction.y < 0.0 else "SW"
        if profile_rig != null:
            # The real Cartesian movement is projected through the existing
            # 45-degree iso transform; diagonal and depth-only movement need
            # no new front/back art. A blocked player keeps their last side.
            profile_facing_sign = WorldProjection.profile_facing_sign(actor_world - position_before, profile_facing_sign)
        _set_actor_clip(next_direction, "walk")
    else:
        _set_actor_clip(actor_direction, "idle")
    _update_avatar()
    if pixellight_world_light != null:
        pixellight_world_light.position = (profile_contact_shadow.position if profile_contact_shadow != null else avatar.position) + Vector2(0.0, -45.0)
    _tick_gameplay(delta)
    if profile_rig != null and perf_isolation_mode != "player_rig_off":
        profile_rig.advance(visual_delta)
    var rig_end := Time.get_ticks_usec()
    if direction.length_squared() > 0.01:
        # Follow the painted ground-contact point on elevated terrain, not the
        # unprojected Y-sort anchor; this prevents apparent height drift.
        var camera_target: Vector2 = profile_contact_shadow.position if profile_contact_shadow != null else avatar.position
        $Camera2D.position = $Camera2D.position.lerp(camera_target, minf(delta * 4.0, 1.0))
    var camera_center: Vector2 = $Camera2D.get_screen_center_position()
    var fast_mode := VisualEnvironment.mobile_fast_mode()
    var plan_period := 3 if fast_mode else 10
    var plan_threshold := 36.0 if fast_mode else 96.0
    if frame_no % plan_period == 0 or camera_center.distance_squared_to(last_plan_camera) > plan_threshold * plan_threshold or $Camera2D.zoom != last_plan_zoom:
        _refresh_streaming_requests()
    if not merged_mode:
        if not pending.is_empty():
            _load_chunk(pending.pop_front())
        if frame_no % 10 == 0:
            _enforce_resident_budget()
    var stream_end := Time.get_ticks_usec()
    if perf_hud != null:
        var mob_node: Node = get_node_or_null("MobWorld")
        var mob_usec: int = int(mob_node.get("last_process_usec")) if mob_node != null else 0
        perf_hud.record(delta,loaded,total_cached,object_count,vertices,actor_world,
            stream_end-rig_end,rig_end-frame_start,"walk" if direction.length_squared()>0.01 else "idle",
            mob_usec,int(mob_node.get("last_think_usec")) if mob_node != null else 0,
            int(mob_node.get("last_scan_usec")) if mob_node != null else 0,
            int(mob_node.get("last_navigation_usec")) if mob_node != null else 0,
            int(mob_node.get("last_movement_usec")) if mob_node != null else 0)
    # HUD string formatting and inventory queries are diagnostic only;
    # avoid running them every frame on Android.
    if frame_no % 15 == 0:
        marker.text = "TAMU Godot R2 / authored area\n%d resident / %d source | %d verts\nViewport missing %d | Mesh est %.1f MiB\nFPS %d | frame %.2f ms | Time %.1f | Harvest %d\nOdun %d | Tas %d | Tahta %d | Tezgah %d" % [loaded, total_cached, vertices, camera_missing, float(vertices * WorldStream.ESTIMATED_BYTES_PER_VERTEX)/1048576.0, Engine.get_frames_per_second(), delta * 1000.0,day_clock,harvested_count, gameplay.count_item("core:wood_log"),gameplay.count_item("core:stone"),gameplay.count_item("core:wood_plank"),gameplay.count_item("core:workbench")]
    if frame_no % 120 == 0:
        print("TAMU_GODOT_FRAME frame=", frame_no, " loaded=", loaded, " fps=", Engine.get_frames_per_second())
    if OS.get_environment("TAMU_PERF_ISOLATION_CI") == "1":
        if frame_no % 12 == 0 and frame_no >= 12 and frame_no <= 96:
            var next_index := mini(floori(float(frame_no) / 12.0), ISOLATION_MODES.size() - 1)
            _set_perf_isolation(ISOLATION_MODES[next_index])
        if frame_no == 108:
            var tagged := {}
            for entry in perf_hud.get("samples"):
                tagged[str(entry.get("isolation_profile", ""))] = true
            for required in ISOLATION_MODES:
                if not tagged.has(required):
                    push_error("TAMU_PERF_ISOLATION_CI_MISSING " + required)
                    get_tree().quit(84)
                    return
                var frame_ms: Array[float] = []
                var draws: Array[float] = []
                var mobs_ms: Array[float] = []
                var mob_think_ms: Array[float] = []
                var mob_nav_ms: Array[float] = []
                var mob_move_ms: Array[float] = []
                for entry in perf_hud.get("samples"):
                    if str(entry.get("isolation_profile", "")) != required or float(entry.get("isolation_elapsed_ms", 0)) < 200.0:
                        continue
                    frame_ms.append(float(entry.get("frame_ms", 0)))
                    draws.append(float(entry.get("draw_calls", 0)))
                    mobs_ms.append(float(entry.get("mob_cpu_ms_previous_frame", 0)))
                    mob_think_ms.append(float(entry.get("mob_think_ms_previous_frame", 0)))
                    mob_nav_ms.append(float(entry.get("mob_navigation_ms_previous_frame", 0)))
                    mob_move_ms.append(float(entry.get("mob_movement_ms_previous_frame", 0)))
                frame_ms.sort()
                draws.sort()
                mobs_ms.sort()
                mob_think_ms.sort()
                mob_nav_ms.sort()
                mob_move_ms.sort()
                if not frame_ms.is_empty():
                    var middle: int = frame_ms.size() / 2
                    print("TAMU_PERF_ISOLATION_METRIC profile=", required,
                        " frames=", frame_ms.size(), " frame_p50_ms=", frame_ms[middle],
                        " draw_p50=", draws[mini(middle, draws.size()-1)],
                        " mob_cpu_p50_ms_prev=", mobs_ms[mini(middle, mobs_ms.size()-1)],
                        " think_p50_ms_prev=", mob_think_ms[mini(middle, mob_think_ms.size()-1)],
                        " nav_p50_ms_prev=", mob_nav_ms[mini(middle, mob_nav_ms.size()-1)],
                        " movement_p50_ms_prev=", mob_move_ms[mini(middle, mob_move_ms.size()-1)],
                        " think_p95_ms_prev=", mob_think_ms[clampi(ceili(0.95 * mob_think_ms.size())-1,0,mob_think_ms.size()-1)],
                        " nav_p95_ms_prev=", mob_nav_ms[clampi(ceili(0.95 * mob_nav_ms.size())-1,0,mob_nav_ms.size()-1)],
                        " movement_p95_ms_prev=", mob_move_ms[clampi(ceili(0.95 * mob_move_ms.size())-1,0,mob_move_ms.size()-1)])
            _set_perf_isolation("full")
            if shadow_layer == null or not shadow_layer.visible or profile_rig == null or not profile_rig.visible or object_count != 832 or region_chunks.size() != 1:
                push_error("TAMU_PERF_ISOLATION_RESTORE_FAILED")
                get_tree().quit(85)
                return
            print("TAMU_PERF_ISOLATION_GATE_OK profiles=", ISOLATION_MODES.size(),
                " objects=", object_count, " region=", region_chunks.size())
            get_tree().quit()
            return
    if fast_mode and frame_no == 90:
        var visible_nodes := 0
        var total_nodes := 0
        for stem in object_visuals_by_chunk:
            for node in object_visuals_by_chunk[stem]:
                total_nodes += 1
                if node.visible:
                    visible_nodes += 1
        fast_cull_visible_nodes = visible_nodes
        fast_cull_total_nodes = total_nodes
        print("TAMU_MOBILE_CULL_OK visible_nodes=", visible_nodes, " total_nodes=", total_nodes)
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and OS.get_environment("TAMU_VISUAL_CASE") == "gui" and frame_no == 54:
        for candidate in harvestables:
            if str(candidate["kind"]) == "tree" and str(candidate.get("family","")) in ["oak","broadleaf"] and candidate["sprite"].visible:
                if _select_harvest(candidate):
                    print("TAMU_GUI_VISUAL_SELECTION_OK id=",candidate["id"])
                    break
    if OS.get_environment("TAMU_VISUAL_CI") == "1" \
            and OS.get_environment("TAMU_VISUAL_CASE") == "gui" and frame_no == 60:
        var art_origin: Vector2 = modular_hud.get("joystick_origin")
        var art_span: float = float(modular_hud.get("joystick_span"))
        var gui_tap := art_origin + Vector2.ONE * (art_span * 0.5)
        var popup: Control = forest_gui.get("panel") as Control
        if selected_harvest.is_empty() or not _world_ui_hit(gui_tap) or popup == null \
                or not _world_ui_hit(popup.get_global_rect().get_center()):
            push_error("TAMU_UI_POINTER_SHIELD_FAILED")
            get_tree().quit(37)
            return
        var old_selected: String = str(selected_harvest["id"])
        var fake_tap := InputEventScreenTouch.new()
        fake_tap.index = 6
        fake_tap.pressed = true
        fake_tap.position = gui_tap
        _unhandled_input(fake_tap)
        if selected_harvest.is_empty() or str(selected_harvest["id"]) != old_selected:
            push_error("TAMU_UI_LEAKED_TO_WORLD")
            get_tree().quit(38)
            return
        print("TAMU_UI_POINTER_SHIELD_OK joystick=true popup=true selection_unchanged=true")
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
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and frame_no >= 90 and camera_missing == 0:
        if harvest_button == null or silhouette_shadows.is_empty() or (day_clock <= 10.5 and OS.get_environment("TAMU_VISUAL_CASE") != "dawn") or harvest_button.get_global_rect().size.x < 100:
            push_error("TAMU_SUN_HARVEST_BOOT_GATE_FAILED")
            get_tree().quit(11)
            return
        var drawn := 0
        for sh in silhouette_shadows:
            if sh.visible and sh.texture != null:
                drawn += 1
        if drawn < 10 or not shadow_sprites.is_empty():
            push_error("TAMU_SINGLE_SHADOW_VISIBILITY_FAILED visible=" + str(drawn))
            get_tree().quit(14)
            return
        if silhouette_shadows.size() < 100 or audio_cues == null or impact_effects == null:
            push_error("TAMU_FX_SYSTEM_MISSING")
            get_tree().quit(25)
            return
        for i in range(mini(silhouette_shadows.size(), 16)):
            var sh: Sprite2D = silhouette_shadows[i]
            if sh.texture == null or sh.material != silhouette_material:
                push_error("TAMU_AUTHORED_SILHOUETTE_MISMATCH")
                get_tree().quit(25)
                return
        print("TAMU_FX_SYSTEM_OK silhouettes=",silhouette_shadows.size()," audio=true particles=true")
        print("TAMU_GROUND_SHADOW_VISIBILITY_OK visible=",drawn)
        print("TAMU_SUN_HARVEST_BOOT_OK shadows=",silhouette_shadows.size()," hour=",day_clock)
        if perf_hud == null or not perf_hud.test_gate():
            push_error("TAMU_PERF_HUD_GATE_FAILED")
            get_tree().quit(10)
            return
        # Gate the current viewport plan, not the historical all-visible
        # merged-region assumption or an outdated dictionary sentinel.
        if merged_mode:
            _refresh_streaming_requests()
        var visible_faults := 0
        var visible_fail_examples: Array[String] = []
        var fast_view := _fast_view_rect() if fast_mode else Rect2()
        for stem in object_visuals_by_chunk:
            for node in object_visuals_by_chunk[stem]:
                var source_visible: bool = view_required.has(stem) if merged_mode else (chunk_nodes.has(stem) and chunk_nodes[stem].visible)
                var expected: bool = source_visible and not bool(node.get_meta("tamu_collected", false)) and not bool(node.get_meta("tamu_pixellight_replaced_shadow", false))
                if expected and fast_mode:
                    expected = _fast_node_in_view(node, fast_view)
                if node.visible != expected:
                    visible_faults += 1
                    if visible_fail_examples.size() < 3:
                        visible_fail_examples.append("%s expected=%s actual=%s" % [str(stem), str(expected), str(node.visible)])
        if visible_faults > 0:
            print("TAMU_OBJECT_VISIBILITY_DIAGNOSTIC ", visible_fail_examples)
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
        if OS.get_environment("TAMU_VISUAL_CASE") == "gui":
            var panel_node: NinePatchRect = forest_gui.get("panel")
            if selected_harvest.is_empty() or panel_node == null or not panel_node.visible:
                push_error("TAMU_FOREST_GUI_SELECTION_NOT_VISIBLE")
                get_tree().quit(56)
                return
            var modular := get_node_or_null("ModularReferenceHUD")
            if modular == null or not modular.call("verify_contract"):
                push_error("TAMU_HUD_REFERENCE_PARTS_NOT_LOADED")
                get_tree().quit(57)
                return
            print("TAMU_MODULAR_HUD_VISUAL_OK portrait=true hotbar=true joystick=true")
            if ResourceLoader.exists("res://assets/ui/selection/parts/panel.png"):
                var card = forest_gui.get("premium_card")
                if card == null or not card.call("verify_contract"):
                    push_error("TAMU_SELECTION_CARD_VISUAL_GATE_FAILED")
                    get_tree().quit(58)
                    return
                print("TAMU_SELECTION_CARD_VISUAL_OK buttons=3 source=real_parts")
            print("TAMU_FOREST_GUI_VISUAL_OK panel=true target=true")
        print("TAMU_ENV_STAGE_METRICS stage=",env_visual_stage,
            " drawcalls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
            " fps=",Engine.get_frames_per_second()," detail_quads=",detail_count,
            " source_vertices=",vertices)
        print("TAMU_VISUAL_VARIANT mode=", "merged" if merged_mode else "legacy",
            " case=", OS.get_environment("TAMU_VISUAL_CASE"))
        if error != OK or loaded < 16 or total_cached < 100 or vertices < 1000 or object_count < 10 or profile_rig == null or not profile_rig.configured:
            push_error("TAMU_VISUAL_GATE_FAILED " + str(error))
            get_tree().quit(3)
        else:
            print("TAMU_VISUAL_CAPTURE_OK chunks=", loaded, " vertices=", vertices, " objects=", object_count, " profile_parts=", profile_rig.source.get("order", []).size())
            if harvestables.is_empty():
                push_error("TAMU_HARVEST_TEST_EMPTY")
                get_tree().quit(12)
                return
            var target: Dictionary = {}
            for candidate in harvestables:
                if gameplay.is_harvestable(str(candidate["kind"])) and candidate["sprite"].visible:
                    target = candidate
                    break
            if target.is_empty():
                push_error("TAMU_HARVEST_TEST_NO_RESOURCE")
                get_tree().quit(12)
                return
            # A bare TOPLA press must never harvest an arbitrary nearest item.
            harvest_button.emit_signal("pressed")
            if not gameplay.active_harvest.is_empty():
                push_error("TAMU_HARVEST_UNSELECTED_COMMAND_FAILED")
                get_tree().quit(13)
                return
            print("TAMU_HARVEST_NO_SELECTION_GATE_OK")
            # Simulate a real screen tap on an OPAQUE pixel of an authored
            # object. This covers camera zoom, flip, hit geometry and UI order.
            var target_sprite: Sprite2D = target["sprite"]
            var target_art: Dictionary = _selection_art(target)
            if target_art.is_empty():
                push_error("TAMU_HARVEST_ALPHA_IMAGE_MISSING")
                get_tree().quit(13)
                return
            var alpha_image: Image = target_art["image"]
            var tapped := false
            var target_rect := target_sprite.get_rect()
            for yy in range(2,alpha_image.get_height()-2,3):
                if tapped:
                    break
                for xx in range(2,alpha_image.get_width()-2,3):
                    if alpha_image.get_pixel(xx,yy).a < 0.65:
                        continue
                    var xhit := alpha_image.get_width()-1-xx if target_sprite.flip_h else xx
                    var at: Vector2 = target_rect.position+Vector2(float(xhit)+0.5,float(yy)+0.5)
                    var screen: Vector2 = target_sprite.get_global_transform_with_canvas()*at
                    if _harvest_at_screen(screen):
                        tapped = true
                        break
            if not tapped or selected_harvest_outline == null or selected_harvest.is_empty():
                push_error("TAMU_HARVEST_SELECTION_FAILED")
                get_tree().quit(13)
                return
            actor_world = selected_harvest["position"]
            if not gameplay.active_harvest.is_empty():
                push_error("TAMU_HARVEST_PREMATURE_COMMAND")
                get_tree().quit(13)
                return
            print("TAMU_HARVEST_SELECTION_OK id=", selected_harvest["id"],
                " outline=gold alpha=true")
            harvest_button.emit_signal("pressed")
            if gameplay.active_harvest.is_empty():
                push_error("TAMU_HARVEST_NOT_STARTED")
                get_tree().quit(13)
                return
            var completed_id: String = gameplay.active_harvest["id"]
            for i in range(21):
                _tick_gameplay(0.1)
            var completed: Dictionary = harvested_by_id[completed_id]
            var drop: Dictionary = gameplay.harvest_drop(str(completed["kind"]))
            if harvested_count != 1 or not bool(completed["collected"]) or completed["sprite"].visible or gameplay.count_item(str(drop["def_id"])) != int(drop["count"]) or not selected_harvest.is_empty():
                push_error("TAMU_HARVEST_BUTTON_GATE_FAILED")
                get_tree().quit(13)
                return
            if completed.has("silhouette"):
                var stem: String = str(authority.records[completed_id]["stem"])
                _set_chunk_visuals_visible(stem, false)
                _set_chunk_visuals_visible(stem, true)
                if completed["silhouette"].visible or not bool(completed["silhouette"].get_meta("tamu_collected", false)):
                    push_error("TAMU_COLLECTED_SILHOUETTE_REVEAL_FAILED")
                    get_tree().quit(13)
                    return
                print("TAMU_COLLECTED_SILHOUETTE_REVEAL_OK")
            print("TAMU_GAMEPLAY_HARVEST_INVENTORY_OK id=", completed_id, " item=", drop["def_id"], " count=", drop["count"])
            print("TAMU_HARVEST_BUTTON_GATE_OK count=", harvested_count)
            get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
    # Only a pointer started on the authored world may select or pan it.
    # Controls and art may belong to separate CanvasLayers; dispatch alone
    # cannot prevent all ScreenTouch/mouse-emulation leaks on Android.
    if event is InputEventScreenTouch:
        if event.pressed:
            if ui_touch_ids.has(event.index) or _world_ui_hit(event.position)                     or world_touch_pointer >= 0:
                return
            world_touch_pointer = event.index
            if _harvest_at_screen(event.position):
                drag = false
                get_viewport().set_input_as_handled()
                return
            if not selected_harvest.is_empty():
                _clear_harvest_selection()
                print("TAMU_HARVEST_DISMISSED_ON_EMPTY")
            drag = true
        return
    if event is InputEventScreenDrag:
        if drag and event.index == world_touch_pointer:
            if _world_ui_hit(event.position):
                drag = false
                world_touch_pointer = -1
                return
            $Camera2D.position -= event.relative / $Camera2D.zoom
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if _world_ui_hit(event.position):
                drag = false
                return
            if _harvest_at_screen(event.position):
                drag = false
                get_viewport().set_input_as_handled()
                return
            if not selected_harvest.is_empty():
                _clear_harvest_selection()
                print("TAMU_HARVEST_DISMISSED_ON_EMPTY")
            drag = true
        else:
            drag = false
    elif event is InputEventMouseMotion and drag:
        if _world_ui_hit(event.position):
            drag = false
            return
        $Camera2D.position -= event.relative / $Camera2D.zoom
