extends Node2D
## One exterior sprite, world-space doorway, proportional top-down interior.
## Session-only demonstration: NEVER writes placed instances or Stage6 saves.
const WorldProjection = preload("res://scripts/world_projection.gd")
const Navigation = preload("res://scripts/harvest_pathfinder.gd")
const HOUSE_ID := "tamu:house_wood_lv1"
const FOOTPRINT_CELLS := Vector2i(3, 3)
const CELL_WORLD := 32.0
const SOURCE_CANVAS := Vector2(1254.0, 1254.0)
const SOURCE_GROUND_PIVOT := Vector2(625.0, 915.0)
const SOURCE_DOOR := Vector2(785.0, 983.0)
const SOURCE_DOOR_HIT := Rect2(695.0, 778.0, 170.0, 302.0)
const DOOR_WORLD := Vector2(34.0, 5.0)
const APPROACH_WORLD := Vector2(65.0, 5.0)
const ART_WORLD_SCALE := 0.14
const ENTER_DISTANCE := 13.0
const TILE_PIXELS := 108.0
const EXTERIOR_PACKED := "res://assets/buildings/house_wood_lv1.png"
const EXTERIOR_OVERRIDE := "user://tamu_buildings/house_wood_lv1.png"

var host
var authority
var gameplay
var exterior: Sprite2D
var exterior_image: Image
var door_marker: Polygon2D
var center_world := Vector2.ZERO
var footprint_box := Rect2()
var selected := false
var approaching := false
var inside := false
var navigator = Navigation.new()
var route: Array[Vector2] = []
var route_loaded := false
var stuck_seconds := 0.0
var canvas: CanvasLayer
var info: PanelContainer
var info_message: Label
var room: Control
var room_floor: Control
var room_avatar_parent: Node2D
var indoor_position := Vector2.ZERO
var indoor_held := Vector2.ZERO

static func definition() -> Dictionary:
    return {"id": HOUSE_ID, "label": "Ahşap Kulübe", "level": 1,
        "footprint_cells": [FOOTPRINT_CELLS.x, FOOTPRINT_CELLS.y],
        "cell_world_units": int(CELL_WORLD), "interior_cells": [3, 3],
        "door_source_px": [int(SOURCE_DOOR.x), int(SOURCE_DOOR.y)],
        "canvas_px": [int(SOURCE_CANVAS.x), int(SOURCE_CANVAS.y)],
        "interior_id": "tamu:interior_house_wood_lv1"}

static func verify_geometry() -> bool:
    if FOOTPRINT_CELLS.x != 3 or FOOTPRINT_CELLS.y != 3:
        return false
    if not Rect2(Vector2.ZERO, SOURCE_CANVAS).has_point(SOURCE_DOOR):
        return false
    if not SOURCE_DOOR_HIT.has_point(SOURCE_DOOR):
        return false
    if DOOR_WORLD.x >= float(FOOTPRINT_CELLS.x) * CELL_WORLD * 0.5:
        return false
    if APPROACH_WORLD.x <= float(FOOTPRINT_CELLS.x) * CELL_WORLD * 0.5 + 9.0:
        return false
    var x_axis := WorldProjection.to_screen(Vector2(CELL_WORLD, 0.0))
    var y_axis := WorldProjection.to_screen(Vector2(0.0, CELL_WORLD))
    return absf(x_axis.y / x_axis.x - 0.5) < 0.00001 and absf(y_axis.y / y_axis.x + 0.5) < 0.00001

func _load_house_image() -> Image:
    var source := EXTERIOR_OVERRIDE if FileAccess.file_exists(EXTERIOR_OVERRIDE) else EXTERIOR_PACKED
    if not FileAccess.file_exists(source):
        push_warning("TAMU_HOUSE_PNG_REQUIRED source=" + EXTERIOR_PACKED)
        return null
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source)
    if bytes.is_empty():
        push_error("TAMU_HOUSE_PNG_EMPTY")
        return null
    var image := Image.new()
    if image.load_png_from_buffer(bytes) != OK:
        push_error("TAMU_HOUSE_PNG_INVALID")
        return null
    if image.detect_alpha() == Image.ALPHA_NONE:
        push_error("TAMU_HOUSE_PNG_NOT_TRANSPARENT")
        return null
    if image.get_width() < 256 or image.get_height() < 256:
        push_error("TAMU_HOUSE_PNG_TOO_SMALL")
        return null
    return image

func _site_acceptable(at: Vector2) -> bool:
    var half := Vector2(FOOTPRINT_CELLS) * CELL_WORLD * 0.5
    var box := Rect2(at - half, half * 2.0)
    if not host.world_bounds.has_point(box.position) or not host.world_bounds.has_point(box.end):
        return false
    var min_height := INF
    var max_height := -INF
    for ix in range(3):
        for iy in range(3):
            var point := at + Vector2(float(ix - 1) * half.x, float(iy - 1) * half.y)
            var surface: Variant = authority.call("surface", point.x, point.y)
            if not surface is Dictionary:
                return false
            if not bool(surface.get("walkable", false)) or str(surface.get("feature", "")) == "water":
                return false
            if float(surface.get("grade", 0.0)) > 0.12:
                return false
            var height: float = float(surface.get("height", NAN))
            if not is_finite(height):
                return false
            min_height = minf(min_height, height)
            max_height = maxf(max_height, height)
    if max_height - min_height > 0.8:
        return false
    var solids: Array = gameplay.movement_obstacles(
        box.position.x, box.position.y, box.end.x, box.end.y)
    for solid in solids:
        var other := Rect2(Vector2(float(solid["x"]), float(solid["y"])),
            Vector2(float(solid["w"]), float(solid["h"])))
        if other.intersects(box):
            return false
    return true

func _find_site(player: Vector2) -> bool:
    # Deterministic local search. Never teleport a house into a known obstacle.
    for distance in [180.0, 240.0, 312.0, 408.0]:
        for direction in [Vector2(1, 0), Vector2(1, -1), Vector2(0, -1),
                Vector2(1, 1), Vector2(0, 1), Vector2(-1, -1),
                Vector2(-1, 1), Vector2(-1, 0)]:
            var at: Vector2 = player + Vector2(direction).normalized() * float(distance)
            if _site_acceptable(at):
                center_world = at
                var half := Vector2(FOOTPRINT_CELLS) * CELL_WORLD * 0.5
                footprint_box = Rect2(at - half, half * 2.0)
                return true
    push_warning("TAMU_HOUSE_NO_VERIFIED_SITE")
    return false

func setup(game: Node2D, layer: Node2D, terrain: RefCounted, session: RefCounted) -> bool:
    host = game
    authority = terrain
    gameplay = session
    if not verify_geometry():
        push_error("TAMU_HOUSE_GEOMETRY_INVALID")
        return false
    var picture := _load_house_image()
    if picture == null or not _find_site(host.actor_world):
        return false
    position = WorldProjection.to_screen(center_world)
    position.y -= authority.terrain.height_at(center_world.x, center_world.y) * 0.35
    exterior_image = picture
    exterior = Sprite2D.new()
    exterior.name = "HouseWoodLevel1"
    exterior.texture = ImageTexture.create_from_image(picture)
    exterior.centered = false
    var image_factor := SOURCE_CANVAS.x / float(picture.get_width())
    exterior.scale = Vector2.ONE * ART_WORLD_SCALE * image_factor
    exterior.offset = -SOURCE_GROUND_PIVOT / image_factor
    exterior.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(exterior)
    door_marker = Polygon2D.new()
    door_marker.name = "MarkedEntrance"
    var marker_center: Vector2 = (SOURCE_DOOR - SOURCE_GROUND_PIVOT) * ART_WORLD_SCALE
    var outline := PackedVector2Array()
    for i in range(24):
        var angle: float = TAU * float(i) / 24.0
        outline.append(marker_center + Vector2(cos(angle), sin(angle) * 0.55) * 9.0)
    door_marker.polygon = outline
    door_marker.color = Color(0.98, 0.73, 0.22, 0.47)
    add_child(door_marker)
    _create_interface()
    print("TAMU_SINGLE_HOUSE_READY id=", HOUSE_ID, " footprint=3x3 door_marked=true")
    return true

func collision_shapes(x1: float, y1: float, x2: float, y2: float) -> Array:
    if footprint_box.has_area() and footprint_box.intersects(
            Rect2(Vector2(x1, y1), Vector2(x2 - x1, y2 - y1))):
        return [{"x": footprint_box.position.x, "y": footprint_box.position.y,
            "w": footprint_box.size.x, "h": footprint_box.size.y, "id": HOUSE_ID}]
    return []

func select_at_screen(point: Vector2) -> bool:
    if inside or exterior == null or not exterior.is_visible_in_tree():
        return false
    var local: Vector2 = exterior.get_global_transform_with_canvas().affine_inverse() * point
    var px: Vector2 = local - exterior.offset
    if px.x < 0.0 or px.y < 0.0 or px.x >= exterior.texture.get_width() or px.y >= exterior.texture.get_height():
        return false
    var alpha: float = exterior_image.get_pixel(
        floori(px.x), floori(px.y)).a
    if alpha <= 0.15:
        return false
    cancel_approach()
    selected = true
    info.visible = true
    info_message.text = "Ahşap Kulübe  ·  Seviye 1\nAlan: 3 × 3 hücre / 96 × 96 birim\nKapı: sarı işaretli giriş\nEtkileşim: kapıya yürüyerek gir"
    door_marker.color = Color(1.0, 0.76, 0.20, 0.9)
    print("TAMU_HOUSE_SELECTED door=", SOURCE_DOOR, " footprint=3x3")
    return true

func deselect() -> void:
    cancel_approach()
    selected = false
    if info != null:
        info.visible = false
    if door_marker != null:
        door_marker.color = Color(0.98, 0.73, 0.22, 0.47)

func info_blocks_input(point: Vector2) -> bool:
    return inside or (info != null and info.visible and info.get_global_rect().has_point(point))

func is_inside() -> bool:
    return inside

func is_approaching() -> bool:
    return approaching

func cancel_approach() -> void:
    approaching = false
    navigator.cancel()
    route.clear()
    route_loaded = false
    stuck_seconds = 0.0

func interact() -> bool:
    if inside:
        leave_house()
        return true
    if not selected:
        return false
    host.call("_cancel_auto_harvest")
    cancel_approach()
    var outside: Vector2 = center_world + APPROACH_WORLD
    if host.actor_world.distance_to(outside) <= ENTER_DISTANCE:
        _enter_house()
        return true
    if not navigator.begin(host.actor_world, outside, ENTER_DISTANCE, 9.0,
            Callable(host, "_house_movement_obstacles"),
            Callable(authority, "surface"), host.world_bounds):
        info_message.text = "Kapıya rota bulunamadı: " + navigator.reason
        return true
    approaching = true
    info_message.text = "Kapıya gidiliyor…"
    return true

func waypoint_distance(world: Vector2) -> float:
    return world.distance_to(route[0] if not route.is_empty()
        else center_world + APPROACH_WORLD)

func auto_direction(_delta: float) -> Vector2:
    if not approaching:
        return Vector2.ZERO
    var exit_at: Vector2 = center_world + APPROACH_WORLD
    if host.actor_world.distance_to(exit_at) <= ENTER_DISTANCE:
        _enter_house()
        return Vector2.ZERO
    if navigator.state == "searching":
        navigator.advance(32, 900)
    if navigator.state == "failed":
        info_message.text = "Kapıya gidilemiyor: " + navigator.reason
        cancel_approach()
        return Vector2.ZERO
    if navigator.state == "searching":
        return Vector2.ZERO
    if navigator.state == "ready" and not route_loaded:
        route.assign(navigator.path)
        route_loaded = true
    while not route.is_empty() and host.actor_world.distance_squared_to(route[0]) <= 9.0:
        route.pop_front()
    if route.is_empty():
        if host.actor_world.distance_to(exit_at) <= ENTER_DISTANCE:
            _enter_house()
        else:
            info_message.text = "Kapıya ulaşılmadı"
            cancel_approach()
        return Vector2.ZERO
    return (route[0] - host.actor_world).normalized()

func on_actor_blocked(delta: float) -> void:
    if not approaching:
        return
    stuck_seconds += delta
    if stuck_seconds >= 0.9:
        info_message.text = "Kapı yolu engellendi"
        cancel_approach()

func on_actor_moved() -> void:
    stuck_seconds = 0.0

func _create_interface() -> void:
    canvas = CanvasLayer.new()
    canvas.name = "CabinInterface"
    canvas.layer = 135
    host.add_child(canvas)
    info = PanelContainer.new()
    info.name = "CabinInfo"
    info.position = Vector2(20.0, 130.0)
    info.custom_minimum_size = Vector2(360.0, 0.0)
    canvas.add_child(info)
    var column := VBoxContainer.new()
    info.add_child(column)
    var close := Button.new()
    close.text = "×  KAPAT"
    close.pressed.connect(deselect)
    column.add_child(close)
    info_message = Label.new()
    info_message.add_theme_font_size_override("font_size", 20)
    column.add_child(info_message)
    info.visible = false

    room = Control.new()
    room.name = "CabinInteriorMap"
    room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    room.mouse_filter = Control.MOUSE_FILTER_STOP
    canvas.add_child(room)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.08, 0.075, 0.07, 0.99)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    room.add_child(backdrop)
    var title := Label.new()
    title.name = "RoomTitle"
    title.text = "AHŞAP KULÜBE  •  3 × 3 ODA"
    title.position = Vector2(26, 40)
    title.add_theme_font_size_override("font_size", 26)
    room.add_child(title)
    room_floor = Control.new()
    room_floor.name = "RoomFloorTiles"
    room_floor.size = Vector2(FOOTPRINT_CELLS) * TILE_PIXELS
    room.add_child(room_floor)
    for y in range(FOOTPRINT_CELLS.y):
        for x in range(FOOTPRINT_CELLS.x):
            var tile := ColorRect.new()
            tile.name = "Floor_%d_%d" % [x, y]
            tile.color = Color(0.43, 0.31, 0.20) if (x+y)%2 == 0 else Color(0.46, 0.34, 0.23)
            tile.position = Vector2(x, y) * TILE_PIXELS + Vector2(2.0, 2.0)
            tile.size = Vector2.ONE * (TILE_PIXELS - 4.0)
            tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
            room_floor.add_child(tile)
    _furniture("NorthWall", Vector2(0, -28), Vector2(room_floor.size.x, 30), Color(0.30, 0.18, 0.11))
    _furniture("WestWall", Vector2(-23, -28), Vector2(25, room_floor.size.y + 30), Color(0.32, 0.20, 0.12))
    _furniture("EastWall", Vector2(room_floor.size.x - 2, -28), Vector2(25, room_floor.size.y + 30), Color(0.32, 0.20, 0.12))
    _furniture("Bed", Vector2(22, 28), Vector2(100, 55), Color(0.65, 0.54, 0.37))
    _furniture("Storage", Vector2(room_floor.size.x - 92, 18), Vector2(72, 48), Color(0.29, 0.20, 0.10))
    _furniture("Table", Vector2(room_floor.size.x - 130, room_floor.size.y - 120), Vector2(82, 60), Color(0.34, 0.22, 0.12))
    room_avatar_parent = Node2D.new()
    room_avatar_parent.name = "InteriorActor"
    room_floor.add_child(room_avatar_parent)
    var exit_button := Button.new()
    exit_button.name = "DoorExit"
    exit_button.text = "KAPIDAN ÇIK"
    exit_button.position = Vector2(24, 98)
    exit_button.custom_minimum_size = Vector2(200, 58)
    exit_button.pressed.connect(leave_house)
    room.add_child(exit_button)
    _add_touch_pad()
    room.resized.connect(_layout_room)
    _layout_room()
    room.visible = false

func _furniture(label: String, at: Vector2, dimensions: Vector2, tint: Color) -> void:
    var object := ColorRect.new()
    object.name = label
    object.position = at
    object.size = dimensions
    object.color = tint
    object.mouse_filter = Control.MOUSE_FILTER_IGNORE
    room_floor.add_child(object)

func _add_touch_pad() -> void:
    for item in [
        {"label": "↑", "direction": Vector2.UP, "at": Vector2(92, -185)},
        {"label": "↓", "direction": Vector2.DOWN, "at": Vector2(92, -80)},
        {"label": "←", "direction": Vector2.LEFT, "at": Vector2(24, -132)},
        {"label": "→", "direction": Vector2.RIGHT, "at": Vector2(160, -132)}
    ]:
        var button := Button.new()
        button.text = str(item["label"])
        button.size = Vector2(64, 56)
        button.anchor_top = 1.0
        button.anchor_bottom = 1.0
        button.position = item["at"]
        button.button_down.connect(Callable(self, "_hold_indoor").bind(item["direction"]))
        button.button_up.connect(_release_indoor)
        room.add_child(button)

func _layout_room() -> void:
    if room_floor != null:
        room_floor.position = (room.size - room_floor.size) * 0.5

func _hold_indoor(direction: Vector2) -> void:
    indoor_held = direction

func _release_indoor() -> void:
    indoor_held = Vector2.ZERO

func _enter_house() -> void:
    if inside or host.avatar == null:
        return
    cancel_approach()
    selected = false
    info.visible = false
    inside = true
    indoor_held = Vector2.ZERO
    room.visible = true
    indoor_position = Vector2(room_floor.size.x * 0.5, room_floor.size.y - 48.0)
    host.avatar.reparent(room_avatar_parent, false)
    host.avatar.position = indoor_position
    host.profile_contact_shadow.visible = false
    host.call("_release_joystick")
    print("TAMU_HOUSE_ENTERED interior_id=tamu:interior_house_wood_lv1 cells=3x3")

func leave_house() -> void:
    if not inside:
        return
    indoor_held = Vector2.ZERO
    inside = false
    room.visible = false
    host.avatar.reparent(host.object_layer, false)
    host.profile_contact_shadow.visible = true
    host.actor_world = center_world + APPROACH_WORLD
    host.call("_update_avatar")
    host.call("_release_joystick")
    print("TAMU_HOUSE_EXITED door_world=", host.actor_world)

func _process(delta: float) -> void:
    if not inside or host == null or host.profile_rig == null:
        return
    var command: Vector2 = indoor_held if indoor_held.length_squared() > 0.01 else Input.get_vector(
        "ui_left", "ui_right", "ui_up", "ui_down")
    if command.length_squared() > 0.01:
        var movement := command.normalized() * minf(delta, 0.05) * 118.0
        indoor_position += movement
        indoor_position.x = clampf(indoor_position.x, 14.0, room_floor.size.x - 14.0)
        indoor_position.y = clampf(indoor_position.y, 14.0, room_floor.size.y - 14.0)
        host.avatar.position = indoor_position
        host.call("_set_actor_clip", "SE", "walk")
        host.profile_rig.advance(delta, movement.length())
    else:
        host.call("_set_actor_clip", "SE", "idle")
        host.profile_rig.advance(delta, 0.0)
