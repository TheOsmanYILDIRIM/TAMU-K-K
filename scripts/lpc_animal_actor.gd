extends Node2D
class_name LPCAnimalActor
@export var texture_path := "res://assets/lpc/animals/wolf/walk.png"
@export var fps := 7.0
var sprite: Sprite2D
var loaded := false
var elapsed := 0.0
var home := Vector2.ZERO
var seed_offset := 0.0
var facing := Vector2.DOWN
var walk_frames: Dictionary = {}

func _ready() -> void:
    if not ResourceLoader.exists(texture_path):
        push_warning("TAMU_LPC_ANIMAL_TEXTURE_MISSING " + texture_path)
        return
    var tex := load(texture_path) as Texture2D
    if tex == null or tex.get_width() != 640 or tex.get_height() != 384:
        push_warning("TAMU_LPC_ANIMAL_TEXTURE_INVALID " + texture_path)
        return
    sprite = Sprite2D.new()
    sprite.name = "LPCWolfArtwork"
    sprite.texture = tex
    sprite.region_enabled = true
    sprite.centered = true
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    _build_walk_layout()
    loaded = verify_animation_contract()
    if not loaded:
        push_warning("TAMU_LPC_ANIMAL_WALK_LAYOUT_INVALID " + texture_path)
        sprite.visible = false
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

func _direction_key() -> String:
    if facing == Vector2.UP:
        return "up"
    if facing == Vector2.LEFT:
        return "left"
    if facing == Vector2.DOWN:
        return "down"
    return "right"

func _build_walk_layout() -> void:
    # Original Redshrike/William sheet is NOT a uniform frame grid.
    # Proven walk regions: N/S are narrow 23x63 frames on 32px stride;
    # E/W are 64x31 frames. Keep action strips (run/bite/howl/death) out.
    walk_frames = {
        "down": [
            Rect2(5, 128, 23, 63), Rect2(37, 128, 23, 63),
            Rect2(69, 128, 23, 63), Rect2(101, 128, 23, 63)
        ],
        "up": [
            Rect2(164, 128, 23, 63), Rect2(196, 128, 23, 63),
            Rect2(228, 128, 23, 63), Rect2(260, 128, 23, 63)
        ],
        "left": [
            Rect2(320, 289, 64, 31), Rect2(384, 289, 64, 31),
            Rect2(448, 289, 64, 31), Rect2(512, 289, 64, 31),
            Rect2(576, 289, 64, 31)
        ],
        "right": [
            Rect2(320, 97, 64, 31), Rect2(384, 97, 64, 31),
            Rect2(448, 97, 64, 31), Rect2(512, 97, 64, 31),
            Rect2(576, 97, 64, 31)
        ]
    }

func _frame_used_bounds(rect: Rect2) -> Rect2i:
    if sprite == null or sprite.texture == null:
        return Rect2i()
    var image := sprite.texture.get_image()
    if image == null or image.is_empty():
        return Rect2i()
    var region := image.get_region(Rect2i(rect))
    if region == null or region.is_empty():
        return Rect2i()
    return region.get_used_rect()

func _frame_opaque_pixels(rect: Rect2) -> int:
    if sprite == null or sprite.texture == null:
        return 0
    var image := sprite.texture.get_image()
    if image == null or image.is_empty():
        return 0
    var ri := Rect2i(rect)
    var count := 0
    for y in range(ri.position.y, ri.end.y):
        for x in range(ri.position.x, ri.end.x):
            if image.get_pixel(x, y).a > 0.02:
                count += 1
    return count

func _frame_is_full_sprite(rect: Rect2) -> bool:
    var used := _frame_used_bounds(rect)
    return used.has_area() and used.size.x >= 16 and used.size.y >= 18 \
        and _frame_opaque_pixels(rect) >= 120

func verify_animation_contract() -> bool:
    if sprite == null or sprite.texture == null or walk_frames.size() != 4:
        return false
    for key in ["up", "left", "down", "right"]:
        var frames: Array = walk_frames.get(key, [])
        var expected := 5 if key in ["left", "right"] else 4
        if frames.size() != expected:
            return false
        for rect in frames:
            if not _frame_is_full_sprite(rect):
                return false
    return true

func current_frame_rect() -> Rect2:
    var frames: Array = walk_frames.get(_direction_key(), [])
    if frames.is_empty():
        return Rect2()
    return frames[int(elapsed * fps) % frames.size()]

func current_frame_visible_bounds() -> Rect2i:
    return _frame_used_bounds(current_frame_rect())

func current_frame_opaque_pixels() -> int:
    return _frame_opaque_pixels(current_frame_rect())

func _draw_frame() -> void:
    if sprite == null or sprite.texture == null:
        return
    var rect := current_frame_rect()
    if not rect.has_area() or not _frame_is_full_sprite(rect):
        sprite.visible = false
        return
    sprite.visible = true
    sprite.region_rect = rect
    # Align variable-height/wide source regions consistently at their feet.
    sprite.offset = Vector2(0.0, -rect.size.y * 0.5)
