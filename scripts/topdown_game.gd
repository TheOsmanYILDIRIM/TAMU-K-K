extends Node2D
## TAMU top-down gameplay pilot; uses the same canonical domain and R2 IDs.
## 2.5D isometric terrain/foliage/shadow assets deliberately not displayed.
## Never reinterpret saved world coordinates or fabricate new recipes.
const GameplaySession = preload("res://scripts/gameplay_session.gd")
const R2Authority = preload("res://scripts/r2_authority.gd")
const WorldSource = preload("res://scripts/world_source.gd")
const WorldIdentity = preload("res://scripts/world_identity.gd")
const LPCActor = preload("res://scripts/lpc_sprite_actor.gd")
const LPCAnimal = preload("res://scripts/lpc_animal_actor.gd")
const CraftingBook = preload("res://scripts/crafting_book_ui.gd")
const ProductionSandboxUI = preload("res://scripts/production_sandbox_ui.gd")
const ModularHUD = preload("res://scripts/modular_hud.gd")
const ForestHarvestGUI = preload("res://scripts/forest_harvest_gui.gd")
const SelectionShader = preload("res://scripts/harvest_outline.gdshader")
const TERRAIN_MANIFEST := "res://game/love/assets/terrain25d/manifest.json"
const TERRAIN_ATLAS := "res://assets/terrain25d/atlas_00.png"
const OAK = preload("res://assets/trees/tamu_oak.png")
const TILE := 64.0
const PLAYER_RADIUS := 9.0
const MAX_TILES := 1100

var gameplay: RefCounted
var authority: RefCounted
var source: RefCounted
var actor_world := Vector2(64, 128)
var actor_speed := 96.0
var actor: Node2D
var animals: Array[Node2D] = []
var camera: Camera2D
var selection: Dictionary = {}
var objects: Array[Dictionary] = []
var object_index: Dictionary = {}
var available_chunks: Dictionary = {}
var terrain_atlas: Texture2D
var texture_regions: Dictionary = {}
var texture_cache: Dictionary = {}
var modular_hud: CanvasLayer
var forest_gui: CanvasLayer
var selected_harvest: Dictionary = {}
var selected_harvest_outline: Sprite2D
var selection_proxy: Sprite2D
var harvest_outline_material: ShaderMaterial
var selection_outline_texture: Texture2D
var joystick_base: Panel
var joystick_knob: Panel
var joystick_pointer := -1
var joystick_vector := Vector2.ZERO
var sprint_held := false
const JOYSTICK_RADIUS := 62.0
var status: Label
var book: CanvasLayer
var workshop: CanvasLayer
var command_sequence := 0
var last_direction := Vector2.DOWN
var action_hold := 0.0
var terrain_rebuild_at := Vector2(INF, INF)
var world_ready := false
var appearance_signature := ""

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
    gameplay.enable_ground_loot()
    var identity: Dictionary = WorldIdentity.load_or_create()
    if not bool(identity.get("ok", false)):
        push_error("TAMU_TOPDOWN_WORLD_IDENTITY_BLOCKED " + str(identity.get("status", "")))
        _make_failure_overlay("Dünya kimliği doğrulanamadı. Kayıt korunuyor.")
        return
    var durable: Dictionary = gameplay.enable_durable("game", str(identity["id"]),
        str(authority.region_id), Callable(authority, "surface"), Callable(authority, "obstacles"))
    if not bool(durable.get("ok", false)):
        push_error("TAMU_TOPDOWN_STAGE6_BLOCKED " + str(durable.get("status", "")))
        _make_failure_overlay("Stage6 kayıt uyumsuz: " + str(durable.get("status", "")))
        return
    authority.depleted_ids = gameplay.depleted.duplicate(true)
    _load_objects()
    _load_ground_texture()
    var objects_layer := Node2D.new()
    objects_layer.name = "TopdownCharacters"
    objects_layer.y_sort_enabled = true
    add_child(objects_layer)
    actor = LPCActor.new()
    actor.name = "LPCPlayer"
    actor.sheet_paths = PackedStringArray([
        "res://assets/lpc/body/bodies/male/walk.png",
        "res://assets/lpc/head/heads/human/male/walk.png"
    ])
    objects_layer.add_child(actor)
    actor.position = actor_world
    _sync_equipment()
    _spawn_animals(objects_layer)
    if actor.sprites.is_empty():
        push_warning("TAMU_LPC_PLAYER_SHEET_MISSING")
    camera = Camera2D.new()
    camera.name = "Camera2D"
    camera.enabled = true
    camera.zoom = Vector2(1.65, 1.65)
    camera.position = actor_world
    add_child(camera)
    book = CraftingBook.new()
    book.name = "CanonicalCraftingBook"
    add_child(book)
    book.setup(gameplay, Callable(self, "_begin_craft"))
    _make_joystick_authority()
    forest_gui = ForestHarvestGUI.new()
    forest_gui.name = "ForestHarvestInterface"
    add_child(forest_gui)
    forest_gui.call("setup", self)
    modular_hud = ModularHUD.new()
    modular_hud.name = "TAMUModularHUD"
    add_child(modular_hud)
    if not modular_hud.setup(self) or not modular_hud.verify_contract():
        push_error("TAMU_TOPDOWN_MODULAR_HUD_SETUP_FAILED")
        _make_failure_overlay("TAMU HUD yüklenemedi; geçici kontrol arayüzüne dönülmedi.")
        return
    status = modular_hud.get("alert") as Label
    status.text = "Kaynağa dokun, ETKİLEŞİM ile topla"
    world_ready = true
    queue_redraw()
    print("TAMU_TOPDOWN_GAMEPLAY_READY region=", authority.region_id,
        " objects=", objects.size(), " catalog=", gameplay.catalog.version,
        " lpc_sheets=", actor.sprites.size(), " lpc_animals=", animals.size())

func _spawn_animals(layer: Node2D) -> void:
    var offsets := [Vector2(170, 80), Vector2(-120, 130), Vector2(90, -120)]
    for i in range(offsets.size()):
        var animal := LPCAnimal.new()
        animal.name = "LPCWolf%d" % (i + 1)
        layer.add_child(animal)
        animal.configure(actor_world + offsets[i], i)
        if animal.loaded:
            animals.append(animal)
    if animals.size() < 3:
        push_warning("TAMU_LPC_ANIMALS_INCOMPLETE count=" + str(animals.size()))

func _load_objects() -> void:
    # Authority already validated the 832 identities and coordinates.
    for id in authority.records:
        var record: Dictionary = authority.records[id]
        var kind := str(record["kind"])
        if kind != "tree":
            continue
        var item := {"id": str(id), "kind": kind,
            "position": Vector2(float(record["x"]), float(record["y"])),
            "radius": float(record["radius"]), "collected": gameplay.depleted.has(str(id))}
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
        var size := _oak_visual_size(item)
        draw_texture_rect(OAK, Rect2(p - Vector2(size.x * 0.5, size.y), size), false)
    for id in gameplay.building.placed:
        var placed: Dictionary = gameplay.building.placed[id]
        var box: Rect2 = placed["box"]
        if box.intersects(bounds):
            draw_rect(box, Color("#8b6b49"), true)
            draw_rect(box.grow(-3), Color("#c4a16c"), false, 2.0)
    for drop in gameplay.pending_ground_loot():
        var p := Vector2(float(drop["x"]), float(drop["y"]))
        if bounds.has_point(p):
            draw_circle(p, 7.0, Color("#f0ca63"))
            draw_circle(p, 3.0, Color("#fff3ae"))

func _input(event: InputEvent) -> void:
    if not world_ready or (book != null and book.is_open()) or (workshop != null and workshop.visible):
        _release_joystick()
        return
    if event is InputEventScreenTouch:
        if event.pressed and joystick_pointer < 0 and event.position.distance_to(_joystick_center()) <= 105.0:
            joystick_pointer = event.index
            _set_joystick(event.position)
            get_viewport().set_input_as_handled()
            return
        if not event.pressed and event.index == joystick_pointer:
            _release_joystick()
            get_viewport().set_input_as_handled()
            return
        if event.pressed and not _screen_is_on_controls(event.position):
            _select_at_screen(event.position)
    elif event is InputEventScreenDrag and event.index == joystick_pointer:
        _set_joystick(event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if not _screen_is_on_controls(event.position):
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
    if target.is_empty():
        _clear_harvest_selection()
        _harvest_feedback("Kaynak seçilmedi")
    else:
        _select_harvest(target)

func _oak_visual_size(item: Dictionary) -> Vector2:
    var r: float = clampf(float(item["radius"]) * 0.6, 10.0, 25.0)
    return OAK.get_size() * (r * 4.0 / OAK.get_height())

func _ensure_selection_outline_texture() -> Texture2D:
    if selection_outline_texture != null:
        return selection_outline_texture
    var original := OAK.get_image()
    if original == null or original.is_empty():
        return null
    var padding := 5
    var padded := Image.create(original.get_width() + padding * 2,
        original.get_height() + padding * 2, false, Image.FORMAT_RGBA8)
    padded.fill(Color.TRANSPARENT)
    padded.blit_rect(original, Rect2i(Vector2i.ZERO, original.get_size()),
        Vector2i(padding, padding))
    selection_outline_texture = ImageTexture.create_from_image(padded)
    return selection_outline_texture

func _clear_harvest_selection() -> void:
    selection = {}
    selected_harvest = {}
    if forest_gui != null:
        forest_gui.call("close")
    if selection_proxy != null and is_instance_valid(selection_proxy):
        selection_proxy.queue_free()
    selection_proxy = null
    selected_harvest_outline = null
    queue_redraw()

func _select_harvest(item: Dictionary) -> bool:
    if item.is_empty() or bool(item.get("collected", false)):
        return false
    if not gameplay.is_harvestable(str(item.get("kind", ""))):
        return false
    _clear_harvest_selection()
    selection = item
    selected_harvest = item.duplicate(true)
    var size := _oak_visual_size(item)
    selection_proxy = Sprite2D.new()
    selection_proxy.name = "TopdownSelectionProxy"
    selection_proxy.texture = OAK
    selection_proxy.position = (item["position"] as Vector2) - Vector2(0.0, size.y * 0.5)
    selection_proxy.scale = Vector2(size.x / OAK.get_width(), size.y / OAK.get_height())
    selection_proxy.visible = false
    add_child(selection_proxy)
    selected_harvest["sprite"] = selection_proxy
    var outline_texture := _ensure_selection_outline_texture()
    if outline_texture != null:
        if harvest_outline_material == null:
            harvest_outline_material = ShaderMaterial.new()
            harvest_outline_material.shader = SelectionShader
        selected_harvest_outline = Sprite2D.new()
        selected_harvest_outline.name = "HarvestGoldSilhouette"
        selected_harvest_outline.texture = outline_texture
        selected_harvest_outline.material = harvest_outline_material
        selected_harvest_outline.visible = false
        selection_proxy.add_child(selected_harvest_outline)
    if forest_gui != null:
        forest_gui.call("open_for", selected_harvest)
    _harvest_feedback("SEÇİLDİ: AĞAÇ  ·  TOPLA")
    print("TAMU_TOPDOWN_HARVEST_SELECTED id=", item["id"], " main_ui=true")
    queue_redraw()
    return true

func _harvest_feedback(message: String) -> void:
    if status != null:
        status.text = message
    if forest_gui != null:
        forest_gui.call("set_status", message)

func _try_harvest() -> void:
    _harvest()

func _screen_is_on_controls(point: Vector2) -> bool:
    if modular_hud != null and bool(modular_hud.call("blocks_world_input", point)):
        return true
    if forest_gui != null:
        var panel := forest_gui.get("panel") as Control
        if panel != null and panel.visible and panel.get_global_rect().has_point(point):
            return true
    return joystick_base != null and point.distance_to(_joystick_center()) <= 105.0

func _command(prefix: String) -> String:
    command_sequence += 1
    return "%s:%d" % [prefix, command_sequence]

func _harvest() -> void:
    if not world_ready:
        return
    if not gameplay.active_harvest.is_empty():
        _harvest_feedback("TOPLAMA SÜRÜYOR")
        return
    if selection.is_empty():
        _pickup_nearest()
        return
    if not authority.matches_object(selection):
        _harvest_feedback("KAYNAK KİMLİĞİ GEÇERSİZ")
        return
    var result: Dictionary = gameplay.begin_harvest(selection, actor_world, _command("topdown_harvest"))
    _harvest_feedback("TOPLANIYOR..." if result.get("status") == "started" else "TOPLA: " + str(result.get("status")))
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
    if bool(result.get("ok", false)):
        _sync_equipment()
    queue_redraw()

func _begin_craft(recipe_id: String) -> Dictionary:
    var stations: Array = gameplay.building.station_tags_near(actor_world, 48.0)
    var result: Dictionary = gameplay.begin_craft(_command("topdown_craft"), recipe_id, stations)
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
    var direction := (manual + joystick_vector).limit_length(1.0)
    if (book != null and book.is_open()) or (workshop != null and workshop.visible):
        direction = Vector2.ZERO
    var moving := Vector2.ZERO
    var step := direction * actor_speed * (1.65 if sprint_held and joystick_vector != Vector2.ZERO else 1.0) * minf(delta, 0.1)
    if step != Vector2.ZERO:
        last_direction = direction.normalized()
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
                    _clear_harvest_selection()
                _harvest_feedback("TOPLANDI — EŞYAYI AL")
        elif str(change.get("type", "")) == "CraftCompleted":
            status.text = "ÜRETİM TAMAMLANDI: " + str(change.get("recipe_id", ""))
            _sync_equipment()
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

func _make_joystick_authority() -> void:
    joystick_base = Panel.new()
    joystick_base.name = "TopdownJoystickAuthority"
    joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_base.modulate.a = 0.0
    joystick_base.position = Vector2(18, 920)
    joystick_base.size = Vector2(152, 152)
    add_child(joystick_base)
    joystick_knob = Panel.new()
    joystick_knob.name = "TopdownJoystickKnobAuthority"
    joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_knob.modulate.a = 0.0
    joystick_knob.position = Vector2(47, 47)
    joystick_knob.size = Vector2(58, 58)
    joystick_base.add_child(joystick_knob)

func _joystick_center() -> Vector2:
    return joystick_base.get_global_rect().get_center()

func _set_joystick(point: Vector2) -> void:
    var relative := point - _joystick_center()
    joystick_vector = relative.limit_length(JOYSTICK_RADIUS) / JOYSTICK_RADIUS
    if joystick_vector.length() < 0.13:
        joystick_vector = Vector2.ZERO
    if joystick_knob != null:
        joystick_knob.position = Vector2(47, 47) + joystick_vector * JOYSTICK_RADIUS

func _release_joystick() -> void:
    joystick_pointer = -1
    joystick_vector = Vector2.ZERO
    if joystick_knob != null:
        joystick_knob.position = Vector2(47, 47)

func interact_world() -> void:
    _harvest()

func open_crafting_book() -> void:
    _release_joystick()
    if book != null:
        book.open_library()

func open_inventory() -> void:
    _release_joystick()
    if book != null:
        book.open_inventory()

func open_workshop() -> void:
    _release_joystick()
    _open_workshop()

func _play_action_clip(clip: String, seconds: float = 0.65) -> void:
    if actor != null:
        actor.play_action(clip, seconds)

func _new_uuid4() -> String:
    var bytes := Crypto.new().generate_random_bytes(16)
    bytes[6] = (bytes[6] & 15) | 64
    bytes[8] = (bytes[8] & 63) | 128
    var value := bytes.hex_encode()
    return "%s-%s-%s-%s-%s" % [
        value.substr(0,8), value.substr(8,4), value.substr(12,4),
        value.substr(16,4), value.substr(20,12)]

func _place_workbench() -> void:
    if not world_ready:
        return
    var placement := actor_world + last_direction.normalized() * 64.0
    var result: Dictionary = gameplay.place_building(_command("topdown_place"),
        _new_uuid4(), "core:workbench", placement, 0, actor_world, "core:player")
    status.text = "TEZGÂH YERLEŞTİRİLDİ" if result.get("ok", false) else "KUR: " + str(result.get("status", "failed"))
    if bool(result.get("ok", false)):
        _sync_equipment()
        queue_redraw()

func _sync_equipment() -> void:
    if actor == null or gameplay == null:
        return
    var layers := PackedStringArray([
        "res://assets/lpc/body/bodies/male/walk.png",
        "res://assets/lpc/head/heads/human/male/walk.png"
    ])
    # Optional item.visual.lpc_walk_path is purely a rendering hint.
    # Unknown/unpackaged assets never grant an item or change gameplay authority.
    for stack in gameplay.slots:
        if not stack is Dictionary:
            continue
        var visual: Dictionary = gameplay.item_visual(str(stack.get("def_id", "")))
        var art := str(visual.get("lpc_walk_path", ""))
        if art.begins_with("res://assets/lpc/") and art.ends_with("/walk.png") and ResourceLoader.exists(art):
            if not layers.has(art):
                layers.append(art)
    var signature := "|".join(layers)
    if signature == appearance_signature:
        return
    if actor.set_layers(layers):
        appearance_signature = signature

func _open_workshop() -> void:
    # Reuses the established self-contained machinery/farming prototype.
    # Its own UI labels state that its resources are session-only.
    if workshop == null:
        workshop = CanvasLayer.new()
        workshop.layer = 150
        workshop.name = "TAMUWorkshopDemo"
        add_child(workshop)
        var panel := ProductionSandboxUI.new()
        panel.name = "Workshop"
        panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        panel.closed.connect(func() -> void: workshop.visible = false)
        workshop.add_child(panel)
    workshop.visible = true
    status.text = "ATÖLYE: OTURUMLUK ÜRETİM/TARLA DEMOSU"
