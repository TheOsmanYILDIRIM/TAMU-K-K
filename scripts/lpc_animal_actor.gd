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
    loaded = true
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

func _draw_frame() -> void:
    if sprite == null or sprite.texture == null: return
    var columns := maxi(1, sprite.texture.get_width() / frame_size.x)
    var rows := maxi(1, sprite.texture.get_height() / frame_size.y)
    var row := mini(_direction_row(), rows - 1)
    var frame_count := mini(6, columns)
    var column := int(elapsed * fps) % maxi(1, frame_count)
    sprite.region_rect = Rect2(column * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
