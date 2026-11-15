extends Node2D
class_name LPCAnimalActor
@export var texture_path := "res://assets/lpc/animals/wolf/walk.png"
@export var frame_size := Vector2i(64, 64)
@export var fps := 7.0
var sprite: Sprite2D
var loaded := false
var elapsed := 0.0
var home := Vector2.ZERO
var seed_offset := 0.0
var facing := Vector2.DOWN
var visible_columns_by_row: Dictionary = {}

func _ready() -> void:
    if not ResourceLoader.exists(texture_path):
        push_warning("TAMU_LPC_ANIMAL_TEXTURE_MISSING " + texture_path)
        return
    var tex := load(texture_path) as Texture2D
    if tex == null or tex.get_width() < frame_size.x or tex.get_height() < frame_size.y:
        push_warning("TAMU_LPC_ANIMAL_TEXTURE_INVALID " + texture_path)
        return
    sprite = Sprite2D.new()
    sprite.name = "LPCWolfArtwork"
    sprite.texture = tex
    sprite.region_enabled = true
    sprite.centered = true
    sprite.offset.y = -float(frame_size.y) * 0.5
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    _scan_visible_frames()
    loaded = verify_animation_contract()
    if not loaded:
        push_warning("TAMU_LPC_ANIMAL_EMPTY_WALK_FRAMES " + texture_path)
        return
    _draw_frame()

func configure(anchor: Vector2, index: int) -> void:
    home = anchor
    position = anchor
    seed_offset = float(index) * 2.09439510239

func _process(delta: float) -> void:
    if not loaded:
        return
    elapsed += minf(delta, 0.1)
    var angle := elapsed * 0.45 + seed_offset
    var target := home + Vector2(cos(angle) * 36.0, sin(angle * 0.73) * 24.0)
    var motion := target - position
    position = target
    if motion.length_squared() > 0.0001:
        if absf(motion.x) > absf(motion.y):
            facing = Vector2.RIGHT if motion.x > 0.0 else Vector2.LEFT
        else:
            facing = Vector2.DOWN if motion.y > 0.0 else Vector2.UP
    _draw_frame()

func _direction_row() -> int:
    if facing == Vector2.UP: return 0
    if facing == Vector2.LEFT: return 1
    if facing == Vector2.DOWN: return 2
    return 3

func _cell_has_alpha(image: Image, row: int, column: int) -> bool:
    var x0 := column * frame_size.x
    var y0 := row * frame_size.y
    for y in range(y0, mini(y0 + frame_size.y, image.get_height()), 2):
        for x in range(x0, mini(x0 + frame_size.x, image.get_width()), 2):
            if image.get_pixel(x, y).a > 0.02:
                return true
    return false

func _scan_visible_frames() -> void:
    visible_columns_by_row.clear()
    if sprite == null or sprite.texture == null:
        return
    var image := sprite.texture.get_image()
    if image == null or image.is_empty():
        return
    var columns := sprite.texture.get_width() / frame_size.x
    var rows := sprite.texture.get_height() / frame_size.y
    # William/Redshrike wolf walk starts at the left of each direction row.
    # Keep the contiguous visible walk cycle only; stop before later animation slots.
    for row in range(mini(4, rows)):
        var frames: Array[int] = []
        for column in range(columns):
            var visible := _cell_has_alpha(image, row, column)
            if visible:
                frames.append(column)
            elif not frames.is_empty():
                break
        visible_columns_by_row[row] = frames

func verify_animation_contract() -> bool:
    if sprite == null or sprite.texture == null:
        return false
    if visible_columns_by_row.size() < 4:
        return false
    for row in range(4):
        var frames: Array = visible_columns_by_row.get(row, [])
        if frames.size() < 2:
            return false
    return true

func _draw_frame() -> void:
    if sprite == null or sprite.texture == null:
        return
    var row := _direction_row()
    var frames: Array = visible_columns_by_row.get(row, [])
    if frames.is_empty():
        sprite.visible = false
        return
    sprite.visible = true
    var column := int(elapsed * fps) % frames.size()
    sprite.region_rect = Rect2(int(frames[column]) * frame_size.x,
        row * frame_size.y, frame_size.x, frame_size.y)
