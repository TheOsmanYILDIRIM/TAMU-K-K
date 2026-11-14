extends Node2D
class_name LPCSpriteActor
# Standard classic LPC spritesheet adapter; never assumes ownership of player/save logic.
# Import an attributed sheet separately. Body and equipment sheets can be layered.
@export var sheet_paths: PackedStringArray = PackedStringArray()
@export var frame_size := Vector2i(64, 64)
@export var walk_first_row := 0
@export var walk_frame_count := 9
@export var walk_fps := 8.0
@export var idle_frame := 0
@export var y_sort_offset := 0.0

var facing := Vector2.DOWN
var velocity := Vector2.ZERO
var phase := 0.0
var sprites: Array[Sprite2D] = []

func _ready() -> void:
    y_sort_enabled = false
    _load_sheets()
    _draw_current_frame()

func _load_sheets() -> void:
    for old in sprites:
        old.queue_free()
    sprites.clear()
    for sheet_path in sheet_paths:
        if not ResourceLoader.exists(sheet_path):
            push_warning("LPC sheet unavailable: " + sheet_path)
            continue
        var tex := load(sheet_path) as Texture2D
        if tex == null or frame_size.x <= 0 or frame_size.y <= 0:
            push_warning("Invalid LPC texture: " + sheet_path)
            continue
        if tex.get_width() % frame_size.x != 0 or tex.get_height() % frame_size.y != 0:
            push_warning("LPC sheet dimensions not divisible by frame size: " + sheet_path)
            continue
        var sprite := Sprite2D.new()
        sprite.texture = tex
        sprite.hframes = tex.get_width() / frame_size.x
        sprite.vframes = tex.get_height() / frame_size.y
        sprite.centered = true
        sprite.offset.y = -float(frame_size.y) * 0.5 + y_sort_offset
        add_child(sprite)
        sprites.append(sprite)

func set_motion(world_velocity: Vector2, delta: float) -> void:
    velocity = world_velocity
    if world_velocity.length_squared() > 0.0001:
        if absf(world_velocity.x) > absf(world_velocity.y):
            facing = Vector2.RIGHT if world_velocity.x > 0.0 else Vector2.LEFT
        else:
            facing = Vector2.DOWN if world_velocity.y > 0.0 else Vector2.UP
        phase += delta * walk_fps
    else:
        phase = 0.0
    _draw_current_frame()

func _direction_offset() -> int:
    # Direction rows in a per-animation walk.png: north, west, south, east.
    # For a combined sheet set walk_first_row to the actual row (e.g. 7).
    if facing == Vector2.UP:
        return 0
    if facing == Vector2.LEFT:
        return 1
    if facing == Vector2.DOWN:
        return 2
    return 3

func _draw_current_frame() -> void:
    var row := walk_first_row + _direction_offset()
    for sprite in sprites:
        if row >= sprite.vframes:
            push_warning("LPC sheet lacks required walk row")
            continue
        var column := idle_frame if velocity.length_squared() <= 0.0001 else \
            int(phase) % maxi(1, mini(walk_frame_count, sprite.hframes))
        sprite.frame = row * sprite.hframes + mini(column, sprite.hframes - 1)
