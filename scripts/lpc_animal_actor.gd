extends Node2D
class_name LPCAnimalActor

@export var texture_path := "res://assets/lpc/animals/wolf/walk.png"
@export var fps := 7.0

const CELL := 64
const DIRECTION_ROWS := {
    "left": 1,
    "up": 3,
    "right": 5,
    "down": 7
}
const CLIPS := {
    "stance": {"start": 0, "count": 1, "mode": "hold"},
    "walk": {"start": 0, "count": 5, "mode": "loop"},
    "run": {"start": 5, "count": 5, "mode": "pingpong"},
    "bite": {"start": 10, "count": 5, "mode": "once"},
    "howl": {"start": 15, "count": 4, "mode": "pingpong"},
    "die": {"start": 19, "count": 4, "mode": "once"}
}

var sprite: Sprite2D
var loaded := false
var elapsed := 0.0
var home := Vector2.ZERO
var seed_offset := 0.0
var facing := Vector2.DOWN
var clip := "walk"
var clip_elapsed := 0.0

func _ready() -> void:
    if not ResourceLoader.exists(texture_path):
        push_warning("TAMU_LPC_ANIMAL_TEXTURE_MISSING " + texture_path)
        return
    var tex := load(texture_path) as Texture2D
    if tex == null or tex.get_width() != 1472 or tex.get_height() != 512:
        push_warning("TAMU_LPC_ANIMAL_TEXTURE_INVALID " + texture_path)
        return
    sprite = Sprite2D.new()
    sprite.name = "LPCWolfArtwork"
    sprite.texture = tex
    sprite.region_enabled = true
    sprite.centered = true
    sprite.offset = Vector2(0.0, -32.0)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    loaded = verify_animation_contract()
    if not loaded:
        push_warning("TAMU_LPC_ANIMAL_SEMANTIC_LAYOUT_INVALID " + texture_path)
        sprite.visible = false
        return
    _draw_frame()

func configure(anchor: Vector2, index: int) -> void:
    home = anchor
    position = anchor
    seed_offset = float(index) * 2.09439510239

func set_clip(name: String, restart: bool = true) -> bool:
    if not CLIPS.has(name):
        return false
    clip = name
    if restart:
        clip_elapsed = 0.0
    _draw_frame()
    return true

func _process(delta: float) -> void:
    if not loaded:
        return
    var dt := minf(delta, 0.1)
    elapsed += dt
    clip_elapsed += dt
    var angle := elapsed * 0.45 + seed_offset
    var target := home + Vector2(cos(angle) * 36.0, sin(angle * 0.73) * 24.0)
    var motion := target - position
    position = target
    if motion.length_squared() > 0.0001:
        if absf(motion.x) > absf(motion.y):
            facing = Vector2.RIGHT if motion.x > 0.0 else Vector2.LEFT
        else:
            facing = Vector2.DOWN if motion.y > 0.0 else Vector2.UP
        if clip in ["stance", "walk"]:
            clip = "walk"
    elif clip == "walk":
        clip = "stance"
    _draw_frame()

func _direction_key() -> String:
    if facing == Vector2.UP:
        return "up"
    if facing == Vector2.LEFT:
        return "left"
    if facing == Vector2.DOWN:
        return "down"
    return "right"

func animation_frame_numbers(name: String, direction_key: String = "") -> Array[int]:
    var result: Array[int] = []
    if not CLIPS.has(name):
        return result
    var data: Dictionary = CLIPS[name]
    var start := int(data["start"])
    var count := int(data["count"])
    # The original wolf source is missing the multi-frame north-facing howl.
    # Its authors/users explicitly note that only one upward-facing howl frame exists.
    if name == "howl" and direction_key == "up":
        count = 1
    for i in range(count):
        result.append(start + i)
    return result

func playback_sequence(name: String) -> Array[int]:
    var frames := animation_frame_numbers(name, _direction_key())
    if frames.is_empty():
        return frames
    if str(CLIPS[name]["mode"]) == "pingpong" and frames.size() > 2:
        for i in range(frames.size() - 2, 0, -1):
            frames.append(frames[i])
    return frames

func _direction_row() -> int:
    return int(DIRECTION_ROWS[_direction_key()])

func _frame_rect(column: int, row: int) -> Rect2:
    return Rect2(column * CELL, row * CELL, CELL, CELL)

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

func verify_animation_contract() -> bool:
    if sprite == null or sprite.texture == null:
        return false
    var expected := {
        "walk": [0, 1, 2, 3, 4],
        "run": [5, 6, 7, 8, 9],
        "bite": [10, 11, 12, 13, 14],
        "howl": [15, 16, 17, 18],
        "die": [19, 20, 21, 22]
    }
    for name in expected:
        if animation_frame_numbers(name) != expected[name]:
            return false
    for key in DIRECTION_ROWS:
        var row := int(DIRECTION_ROWS[key])
        for name in expected:
            var frames := animation_frame_numbers(name, str(key))
            if name == "howl" and str(key) == "up":
                if frames != [15]:
                    return false
            elif frames != expected[name]:
                return false
            for column in frames:
                if _frame_opaque_pixels(_frame_rect(int(column), row)) < 80:
                    return false
    return true

func current_frame_number() -> int:
    var sequence := playback_sequence(clip)
    if sequence.is_empty():
        return 0
    var mode := str(CLIPS[clip]["mode"])
    var logical := int(clip_elapsed * fps)
    if mode == "once":
        logical = mini(logical, sequence.size() - 1)
    elif mode == "hold":
        logical = 0
    else:
        logical %= sequence.size()
    return int(sequence[logical])

func current_frame_rect() -> Rect2:
    return _frame_rect(current_frame_number(), _direction_row())

func current_frame_opaque_pixels() -> int:
    return _frame_opaque_pixels(current_frame_rect())

func _draw_frame() -> void:
    if sprite == null or sprite.texture == null:
        return
    var rect := current_frame_rect()
    if _frame_opaque_pixels(rect) < 80:
        sprite.visible = false
        return
    sprite.visible = true
    sprite.region_rect = rect
