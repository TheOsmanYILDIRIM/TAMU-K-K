extends Node2D
## TAMU top-down gameplay pilot; uses the same canonical domain and R2 IDs.
## 2.5D isometric terrain/foliage/shadow assets deliberately not displayed.
## Never reinterpret saved world coordinates or fabricate new recipes.
const GameplaySession = preload("res://scripts/gameplay_session.gd")
const R2Authority = preload("res://scripts/r2_authority.gd")
const WorldSource = preload("res://scripts/world_source.gd")
const LPCActor = preload("res://scripts/lpc_sprite_actor.gd")
const CraftingBook = preload("res://scripts/crafting_book_ui.gd")
const TERRAIN_MANIFEST := "res://game/love/assets/terrain25d/manifest.json"
const TERRAIN_ATLAS := "res://assets/terrain25d/atlas_00.png"
const TILE := 64.0
const PLAYER_RADIUS := 9.0
const MAX_TILES := 1100
const BUTTON_SIZE := Vector2(138, 72)

var gameplay: RefCounted
var authority: RefCounted
var source: RefCounted
var actor_world := Vector2(64, 128)
var actor_speed := 96.0
var actor: Node2D
var camera: Camera2D
var selection: Dictionary = {}
var objects: Array[Dictionary] = []
var object_index: Dictionary = {}
var available_chunks: Dictionary = {}
var terrain_atlas: Texture2D
var texture_regions: Dictionary = {}
var texture_cache: Dictionary = {}
var buttons_layer: CanvasLayer
var status: Label
var book: CanvasLayer
var command_sequence := 0
var movement_buttons: Dictionary = {}
var last_direction := Vector2.DOWN
var action_hold := 0.0
var terrain_rebuild_at := Vector2(INF, INF)
var world_ready := false

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    source = WorldSource.new()
    authority = R2Authority.new()
    gameplay = GameplaySession.new()
    if gameplay.catalog == null or gameplay.catalog.definitions.is_empty() or not source.initialize() or not authority.initialize():
        push_error("TAMU_TOPDOWN_SOURCE_INVALID: original R2 assets are required")
        _make_failure_overlay("R2 kaynak/veri eksik. Kaydedilmiş dünya değiştirilmedi.")
        return
    available_chunks = source.available.duplicate()
    _load_objects()
    _load_ground_texture()
    var objects_layer := Node2D.new()
    objects_layer.name = "TopdownCharacters"
    objects_layer.y_sort_enabled = true
    add_child(objects_layer)
    actor = LPCActor.new()
    actor.name = "LPCPlayer"
    actor.sheet_paths = PackedStringArray([
        "res://assets/lpc/body/bodies/male/walk.png"
    ])
    objects_layer.add_child(actor)
    actor.position = actor_world
    if actor.sprites.is_empty():
        push_warning("TAMU_LPC_PLAYER_SHEET_MISSING")
    camera = Camera2D.new()
    camera.name = "Camera2D"
    camera.enabled = true
    camera.zoom = Vector2(1.65, 1.65)
    camera.position = actor_world
    add_child(camera)
    _make_ui()
    book = CraftingBook.new()
    book.name = "CanonicalCraftingBook"
    add_child(book)
    book.setup(gameplay, Callable(self, "_begin_craft"))
    gameplay.enable_ground_loot()
    world_ready = true
    queue_redraw()
    print("TAMU_TOPDOWN_GAMEPLAY_READY region=", authority.region_id,
        " objects=", objects.size(), " catalog=", gameplay.catalog.version,
        " lpc_sheets=", actor.sprites.size())

func _load_objects() -> void:
    # Authority already validated the 832 identities and coordinates.
    for id in authority.records:
        var record: Dictionary = authority.records[id]
        var kind := str(record["kind"])
        if kind not in ["tree", "rock"]:
            continue
        var item := {"id": str(id), "kind": kind,
            "position": Vector2(float(record["x"]), float(record["y"])),
            "radius": float(record["radius"]), "collected": false}
        objects.append(item)
        object_index[str(id)] = item
    if objects.is_empty():
        push_error("TAMU_TOPDOWN_NO_RESOURCES")

func _load_ground_texture() -> void:
    if not ResourceLoader.exists(TERRAIN_ATLAS):
        push_warning("TAMU_TOPDOWN_TERRAIN_ATLAS_MISSING: flat R2 colours are used")
        return
    if not FileAccess.file_exists(TERRAIN_MANIFEST):
        push_warning("TAMU_TOPDOWN_TERRAIN_MANIFEST_MISSING")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TERRAIN_MANIFEST))
    if not parsed is Dictionary or not parsed.get("assets", null) is Array:
        return
    terrain_atlas = load(TERRAIN_ATLAS) as Texture2D
    if terrain_atlas == null:
        return
    var size := terrain_atlas.get_size()
    for entry in parsed["assets"]:
        if not entry is Dictionary or entry.get("kind", "") != "terrain":
            continue
        if entry.get("atlas_page", "") != "atlas_00.png" or not entry.get("uv_rect", null) is Array:
            continue
        var uv: Array = entry["uv_rect"]
        if uv.size() != 4:
            continue
        var family := str(entry.get("family", "")).to_lower()
        if texture_regions.has(family):
            continue
        texture_regions[family] = Rect2(float(uv[0]) * size.x, float(uv[1]) * size.y,
            float(uv[2]) * size.x, float(uv[3]) * size.y)
    print("TAMU_TOPDOWN_TERRAIN_TEXTURES_READY families=", texture_regions.keys().size())

func _cell_key(at: Vector2) -> String:
    return "c_%d_%d" % [floori(at.x / 256.0), floori(at.y / 256.0)]

func _terrain(at: Vector2) -> Dictionary:
    if not available_chunks.has(_cell_key(at)):
        return {"walkable": false, "feature": "outside"}
    return authority.surface(at.x, at.y)

func _draw() -> void:
    if not world_ready or camera == null:
        return
    var extent := get_viewport_rect().size * 0.5 / camera.zoom
    var bounds := Rect2(actor_world - extent, extent * 2.0).grow(TILE * 2.0)
    var lo := Vector2i(floori(bounds.position.x / TILE), floori(bounds.position.y / TILE))
    var hi := Vector2i(ceili(bounds.end.x / TILE), ceili(bounds.end.y / TILE))
    var drawn := 0
    for y in range(lo.y, hi.y + 1):
        for x in range(lo.x, hi.x + 1):
            if drawn >= MAX_TILES:
                break
            drawn += 1
            var tile_pos := Vector2(x * TILE, y * TILE)
            var sample := _terrain(tile_pos + Vector2.ONE * TILE * 0.5)
            var feature := str(sample.get("feature", "outside"))
            var color := Color("#6f916a")
            match feature:
                "water": color = Color("#426c87")
                "path": color = Color("#a19066")
                "outside": color = Color("#26372f")
                "grass":
                    var n: int = posmod(x * 101 + y * 53 + x * y * 7, 23)
                    color = Color("#71966b").lerp(Color("#587b58"), float(n) / 45.0)
                _: color = Color("#8b8970")
            var rect := Rect2(tile_pos, Vector2.ONE * TILE)
            draw_rect(rect, color, true)
            var region := Rect2()
            if feature == "grass":
                for key in ["grass", "forest", "meadow"]:
                    if texture_regions.has(key):
                        region = texture_regions[key]
                        break
            elif feature == "path":
                for key in ["dirt", "path"]:
                    if texture_regions.has(key):
                        region = texture_regions[key]
                        break
            if terrain_atlas != null and region.has_area():
                # Albedo crop only: not the old slanted isometric ground mesh.
                draw_texture_rect_region(terrain_atlas, rect, region,
                    Color(1, 1, 1, 0.36))
    # Source trees are intentionally represented as flat markers, never the
    # old tilted tree sprites. Tapping still targets the same authored object.
    for item in objects:
        if bool(item["collected"]):
            continue
        var p: Vector2 = item["position"]
        if not bounds.grow(80).has_point(p):
            continue
        var r: float = clampf(float(item["radius"]) * 0.6, 10, 25)
        if item["kind"] == "tree":
            draw_circle(p, r, Color("#315b3a"))
            draw_arc(p, r - 3.0, 0, TAU, 18, Color("#92b478"), 2.0)
            draw_circle(p, 4.0, Color("#806b4b"))
        else:
            draw_circle(p, r, Color("#747a75"))
            draw_arc(p, r - 3.0, 0, TAU, 12, Color("#abb0a2"), 2.0)
        if not selection.is_empty() and selection["id"] == item["id"]:
            draw_arc(p, r + 9, 0, TAU, 24, Color.GOLD, 3.0)
    for drop in gameplay.pending_ground_loot():
        var p := Vector2(float(drop["x"]), float(drop["y"]))
        if bounds.has_point(p):
            draw_circle(p, 7.0, Color("#f0ca63"))
            draw_circle(p, 3.0, Color("#fff3ae"))

func _input(event: InputEvent) -> void:
    if not world_ready or (book != null and book.is_open()):
        return
    if event is InputEventScreenTouch and event.pressed:
        _select_at_screen(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _select_at_screen(event.position)

func _select_at_screen(screen_pos: Vector2) -> void:
    if _screen_is_on_controls(screen_pos):
        return
    var at := get_global_transform_with_canvas().affine_inverse() * screen_pos
    var nearest := 34.0 * 34.0
    for drop in gameplay.pending_ground_loot():
        var point := Vector2(float(drop["x"]), float(drop["y"]))
        if point.distance_squared_to(at) < nearest:
            _pickup(str(drop["id"]))
            return
    var target: Dictionary = {}
    for item in objects:
        if bool(item["collected"]):
            continue
        var distance := (item["position"] as Vector2).distance_squared_to(at)
        var threshold := pow(maxf(26.0, float(item["radius"]) * 0.8), 2.0)
        if distance < minf(nearest, threshold):
            nearest = distance
            target = item
    selection = target
    status.text = ("SEÇİLDİ: " + str(target["kind"]) + " | TOPLA") if not target.is_empty() else "Kaynak seçilmedi"
    queue_redraw()

func _screen_is_on_controls(point: Vector2) -> bool:
    if buttons_layer == null:
        return false
    var panel := buttons_layer.get_node_or_null("Controls")
    if panel == null:
        return false
    for control in panel.get_children():
        if control is Control and control.visible and control.get_global_rect().has_point(point):
            return true
    return false

func _command(prefix: String) -> String:
    command_sequence += 1
    return "%s:%d" % [prefix, command_sequence]

func _harvest() -> void:
    if not world_ready:
        return
    if not gameplay.active_harvest.is_empty():
        status.text = "TOPLAMA SÜRÜYOR"
        return
    if selection.is_empty():
        _pickup_nearest()
        return
    if not authority.matches_object(selection):
        status.text = "KAYNAK KİMLİĞİ GEÇERSİZ"
        return
    var result: Dictionary = gameplay.begin_harvest(selection, actor_world, _command("topdown_harvest"))
    status.text = "TOPLANIYOR..." if result.get("status") == "started" else "TOPLA: " + str(result.get("status"))
    if result.get("status") == "started":
        action_hold = 0.5
        actor.play_action("slash", 0.65)

func _pickup_nearest() -> void:
    var closest := ""
    var squared := 52.0 * 52.0
    for drop in gameplay.pending_ground_loot():
        var p := Vector2(float(drop["x"]), float(drop["y"]))
        var distance := actor_world.distance_squared_to(p)
        if distance < squared:
            closest = str(drop["id"])
            squared = distance
    if closest.is_empty():
        status.text = "ÖNCE KAYNAK SEÇ VEYA YERDEN EŞYA AL"
    else:
        _pickup(closest)

func _pickup(id: String) -> void:
    var result: Dictionary = gameplay.pickup_ground_loot(id, actor_world, _command("topdown_pickup"))
    status.text = "ALINDI: " + str(result.get("item_id", "")) if result.get("ok", false) else "ALMA: " + str(result.get("status", "failed"))
    queue_redraw()

func _begin_craft(recipe_id: String) -> Dictionary:
    var result: Dictionary = gameplay.begin_craft(_command("topdown_craft"), recipe_id)
    status.text = "ÜRETİM BAŞLADI" if result.get("ok", false) else "ÜRETİM: " + str(result.get("status", "failed"))
    if result.get("status") == "started":
        actor.play_action("spellcast", 0.5)
    return result

func _safe_move(next_position: Vector2) -> bool:
    if not bool(_terrain(next_position).get("walkable", false)):
        return false
    var radius := PLAYER_RADIUS
    var blocks: Array = authority.obstacles(next_position.x - radius,
        next_position.y - radius, next_position.x + radius, next_position.y + radius)
    blocks.append_array(gameplay.movement_obstacles(next_position.x - radius,
        next_position.y - radius, next_position.x + radius, next_position.y + radius))
    for box in blocks:
        var rect := Rect2(Vector2(float(box["x"]), float(box["y"])),
            Vector2(float(box["w"]), float(box["h"]))).grow(radius)
        if rect.has_point(next_position):
            return false
    return true

func _process(delta: float) -> void:
    if not world_ready:
        return
    var manual := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    var touch := Vector2.ZERO
    for key in movement_buttons:
        if movement_buttons[key]:
            match key:
                "left": touch.x -= 1.0
                "right": touch.x += 1.0
                "up": touch.y -= 1.0
                "down": touch.y += 1.0
    var direction := (manual + touch).limit_length(1.0)
    if book != null and book.is_open():
        direction = Vector2.ZERO
    var moving := Vector2.ZERO
    var step := direction * actor_speed * minf(delta, 0.1)
    if step != Vector2.ZERO:
        if _safe_move(actor_world + step):
            actor_world += step
            moving = direction
        else:
            if _safe_move(actor_world + Vector2(step.x, 0)):
                actor_world.x += step.x
                moving.x = direction.x
            if _safe_move(actor_world + Vector2(0, step.y)):
                actor_world.y += step.y
                moving.y = direction.y
    actor.position = actor_world
    actor.set_motion(moving, minf(delta, 0.1))
    camera.position = actor_world
    action_hold = maxf(0.0, action_hold - delta)
    for change in gameplay.tick(minf(delta, 0.1), actor_world):
        if str(change.get("type", "")) == "HarvestCompleted":
            var id := str(change["object_id"])
            if object_index.has(id):
                object_index[id]["collected"] = true
                authority.depleted_ids[id] = true
                if not selection.is_empty() and str(selection["id"]) == id:
                    selection = {}
                status.text = "TOPLANDI — EŞYAYI AL"
        elif str(change.get("type", "")) == "CraftCompleted":
            status.text = "ÜRETİM TAMAMLANDI: " + str(change.get("recipe_id", ""))
    # Small visible sample only. Avoid rebuilding static R2 on every frame.
    if actor_world.distance_squared_to(terrain_rebuild_at) > 16.0 * 16.0:
        terrain_rebuild_at = actor_world
        queue_redraw()

func _make_failure_overlay(message: String) -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var label := Label.new()
    label.text = message
    label.position = Vector2(16, 80)
    ui.add_child(label)

func _make_ui() -> void:
    buttons_layer = CanvasLayer.new()
    buttons_layer.layer = 120
    add_child(buttons_layer)
    var controls := Control.new()
    controls.name = "Controls"
    controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    buttons_layer.add_child(controls)
    status = Label.new()
    status.text = "Kaynağa dokun, TOPLA"
    status.anchor_right = 1.0
    status.offset_left = 22
    status.offset_right = -22
    status.offset_top = 28
    status.offset_bottom = 80
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 22)
    status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    controls.add_child(status)
    _make_button(controls, "TOPLA / AL", Vector2(-196, -180),
        Vector2(174, 94), Callable(self, "_harvest"))
    _make_button(controls, "ÜRETİM", Vector2(-196, -285),
        Vector2(174, 84), func(): book.open_library())
    _make_button(controls, "ÇANTA", Vector2(-196, -382),
        Vector2(174, 84), func(): book.open_inventory())
    var pad := [
        {"key": "up", "name": "▲", "offset": Vector2(104, -275)},
        {"key": "left", "name": "◀", "offset": Vector2(28, -195)},
        {"key": "down", "name": "▼", "offset": Vector2(104, -195)},
        {"key": "right", "name": "▶", "offset": Vector2(180, -195)}
    ]
    for part in pad:
        var key := str(part["key"])
        movement_buttons[key] = false
        var b := Button.new()
        b.text = str(part["name"])
        b.custom_minimum_size = Vector2(74, 74)
        b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
        b.position = part["offset"]
        b.focus_mode = Control.FOCUS_NONE
        b.button_down.connect(_touch_direction.bind(key, true))
        b.button_up.connect(_touch_direction.bind(key, false))
        controls.add_child(b)

func _make_button(parent: Control, name: String, offset: Vector2,
        dimensions: Vector2, callback: Callable) -> void:
    var b := Button.new()
    b.text = name
    b.anchor_left = 1.0
    b.anchor_right = 1.0
    b.anchor_top = 1.0
    b.anchor_bottom = 1.0
    b.offset_left = offset.x
    b.offset_right = offset.x + dimensions.x
    b.offset_top = offset.y
    b.offset_bottom = offset.y + dimensions.y
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 20)
    b.pressed.connect(callback)
    parent.add_child(b)

func _touch_direction(key: String, active: bool) -> void:
    movement_buttons[key] = active
