extends Node2D
class_name LPCAnimalActor
@export var texture_path := "res://assets/lpc/animals/wolf/walk.png"
@export var frame_size := Vector2i(32, 64)
@export var fps := 7.0
const WALK_FRAMES_PER_DIRECTION := 6
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

func _cell_visible_bounds(image: Image, row: int, column: int) -> Rect2i:
    var region := image.get_region(Rect2i(column * frame_size.x, row * frame_size.y,
        frame_size.x, frame_size.y))
    if region == null or region.is_empty():
        return Rect2i()
    return region.get_used_rect()

func _cell_opaque_pixels(image: Image, row: int, column: int) -> int:
    var count := 0
    var x0 := column * frame_size.x
    var y0 := row * frame_size.y
    for y in range(y0, mini(y0 + frame_size.y, image.get_height())):
        for x in range(x0, mini(x0 + frame_size.x, image.get_width())):
            if image.get_pixel(x, y).a > 0.02:
                count += 1
    return count

func _cell_is_full_sprite(image: Image, row: int, column: int) -> bool:
    var used := _cell_visible_bounds(image, row, column)
    # Reject separators, stray paws/tails and sparse animation fragments.
    return used.has_area() and used.size.x >= 24 and used.size.y >= 18 \
        and used.size.x * used.size.y >= 600 \
        and _cell_opaque_pixels(image, row, column) >= 160

func _scan_visible_frames() -> void:
    visible_columns_by_row.clear()
    if sprite == null or sprite.texture == null:
        return
    var image := sprite.texture.get_image()
    if image == null or image.is_empty():
        return
    var columns := sprite.texture.get_width() / frame_size.x
    var rows := sprite.texture.get_height() / frame_size.y
    # Redshrike/William wolf sheet: 32x64 cells, six walk frames per direction,
    # progressing horizontally from the left. Never bleed into run/bite/howl/death.
    if columns < WALK_FRAMES_PER_DIRECTION or rows < 4:
        return
    for row in range(4):
        var frames: Array[int] = []
        for column in range(WALK_FRAMES_PER_DIRECTION):
            if _cell_is_full_sprite(image, row, column):
                frames.append(column)
        visible_columns_by_row[row] = frames

func verify_animation_contract() -> bool:
    if sprite == null or sprite.texture == null:
        return false
    if visible_columns_by_row.size() < 4:
        return false
    var image := sprite.texture.get_image()
    if image == null or image.is_empty():
        return false
    for row in range(4):
        var frames: Array = visible_columns_by_row.get(row, [])
        if frames.size() < 2:
            return false
        for column in frames:
            if not _cell_is_full_sprite(image, row, int(column)):
                return false
    return true

func current_frame_visible_bounds() -> Rect2i:
    if sprite == null or sprite.texture == null:
        return Rect2i()
    var row := _direction_row()
    var frames: Array = visible_columns_by_row.get(row, [])
    if frames.is_empty():
        return Rect2i()
    var column := int(elapsed * fps) % frames.size()
    return _cell_visible_bounds(sprite.texture.get_image(), row, int(frames[column]))

func current_frame_opaque_pixels() -> int:
    if sprite == null or sprite.texture == null:
        return 0
    var row := _direction_row()
    var frames: Array = visible_columns_by_row.get(row, [])
    if frames.is_empty():
        return 0
    var column := int(elapsed * fps) % frames.size()
    return _cell_opaque_pixels(sprite.texture.get_image(), row, int(frames[column]))

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
