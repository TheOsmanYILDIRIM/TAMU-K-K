extends Node2D
class_name LPCSpriteActor
## LPC 64px 4-direction layered actor.
## Uses selected runtime files under assets/lpc; complete upstream source is excluded from PCK.
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
var clip := "walk"
var action := ""
var action_remaining := 0.0
var texture_cache: Dictionary = {}
var visible_frame_cache: Dictionary = {}

func _ready() -> void:
    y_sort_enabled = false
    _load_sheets()
    _apply_clip("idle")

func _asset_path(walk_path: String, requested: String) -> String:
    return walk_path.get_base_dir().path_join(requested + ".png")

func _texture(walk_path: String, requested: String) -> Texture2D:
    var target := _asset_path(walk_path, requested)
    if texture_cache.has(target):
        return texture_cache[target]
    var result: Texture2D = null
    if ResourceLoader.exists(target):
        result = load(target) as Texture2D
    texture_cache[target] = result
    return result

func _load_sheets() -> void:
    for previous in sprites:
        previous.queue_free()
    sprites.clear()
    for walk_path in sheet_paths:
        if not walk_path.begins_with("res://assets/lpc/"):
            push_warning("Only packaged LPC runtime artwork is accepted: " + walk_path)
            continue
        var tex := _texture(walk_path, "walk")
        if tex == null or frame_size.x <= 0 or frame_size.y <= 0:
            push_warning("LPC walk texture missing: " + walk_path)
            continue
        if tex.get_width() % frame_size.x != 0 or tex.get_height() % frame_size.y != 0:
            push_warning("LPC texture size invalid: " + walk_path)
            continue
        if tex.get_height() / frame_size.y != 4:
            push_warning("LPC walk directions require four rows: " + walk_path)
            continue
        var sprite := Sprite2D.new()
        sprite.name = "LPCArtworkLayer"
        sprite.set_meta("walk_path", walk_path)
        sprite.texture = tex
        sprite.hframes = tex.get_width() / frame_size.x
        sprite.vframes = tex.get_height() / frame_size.y
        sprite.centered = true
        sprite.offset.y = -float(frame_size.y) * 0.5 + y_sort_offset
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        add_child(sprite)
        sprites.append(sprite)

func set_layers(paths: PackedStringArray) -> bool:
    # Inventory/equipment UI may update the appearance without touching item IDs.
    for p in paths:
        if not p.begins_with("res://assets/lpc/") or not p.ends_with("/walk.png"):
            return false
        if not ResourceLoader.exists(p):
            return false
    sheet_paths = paths
    _load_sheets()
    _apply_clip("walk")
    return not sprites.is_empty()

func play_action(name: String, seconds: float = 0.45) -> void:
    if name not in ["slash", "thrust", "spellcast", "shoot"]:
        return
    action = name
    action_remaining = maxf(0.1, seconds)
    phase = 0.0
    _apply_clip(name)

func set_motion(world_velocity: Vector2, delta: float) -> void:
    velocity = world_velocity
    if world_velocity.length_squared() > 0.0001:
        if absf(world_velocity.x) > absf(world_velocity.y):
            facing = Vector2.RIGHT if world_velocity.x > 0.0 else Vector2.LEFT
        else:
            facing = Vector2.DOWN if world_velocity.y > 0.0 else Vector2.UP
    if action_remaining > 0.0:
        action_remaining = maxf(0.0, action_remaining - maxf(delta, 0.0))
    var wanted := action if action_remaining > 0.0 else ("walk" if velocity.length_squared() > 0.0001 else "idle")
    if wanted != clip:
        phase = 0.0
        _apply_clip(wanted)
    phase += delta * (walk_fps if wanted != "idle" else 2.0)
    _draw_current_frame()

func _apply_clip(requested: String) -> void:
    clip = requested
    for sprite in sprites:
        var walk_path := str(sprite.get_meta("walk_path", ""))
        var tex := _texture(walk_path, requested)
        if tex == null:
            tex = _texture(walk_path, "walk")
        if tex == null:
            continue
        var columns := tex.get_width() / frame_size.x
        var rows := tex.get_height() / frame_size.y
        if columns < 1 or rows < 4:
            push_warning("Unsupported LPC clip: " + walk_path + " " + requested)
            continue
        sprite.texture = tex
        sprite.hframes = columns
        sprite.vframes = rows
    _draw_current_frame()

func _direction_offset() -> int:
    # Split LPC sources: north, west, south, east.
    if facing == Vector2.UP:
        return 0
    if facing == Vector2.LEFT:
        return 1
    if facing == Vector2.DOWN:
        return 2
    return 3

func _frame_has_alpha(sprite: Sprite2D, row: int, column: int) -> bool:
    if sprite == null or sprite.texture == null:
        return false
    var image := sprite.texture.get_image()
    if image == null or image.is_empty():
        return false
    var key := "%s:%d:%d:%d:%d" % [sprite.texture.resource_path, row, column,
        sprite.hframes, sprite.vframes]
    if visible_frame_cache.has(key):
        return bool(visible_frame_cache[key])
    var x0 := column * frame_size.x
    var y0 := row * frame_size.y
    var found := false
    for y in range(y0, mini(y0 + frame_size.y, image.get_height()), 2):
        for x in range(x0, mini(x0 + frame_size.x, image.get_width()), 2):
            if image.get_pixel(x, y).a > 0.02:
                found = true
                break
        if found:
            break
    visible_frame_cache[key] = found
    return found

func _visible_columns(sprite: Sprite2D, row: int) -> Array[int]:
    var result: Array[int] = []
    var limit := mini(walk_frame_count, sprite.hframes) if clip == "walk" else sprite.hframes
    for column in range(limit):
        if _frame_has_alpha(sprite, row, column):
            result.append(column)
    return result

func _draw_current_frame() -> void:
    for sprite in sprites:
        var row := _direction_offset()
        if sprite.vframes > 4 and clip == "walk":
            row += walk_first_row
        if row >= sprite.vframes:
            sprite.visible = false
            continue
        var columns := _visible_columns(sprite, row)
        if columns.is_empty():
            sprite.visible = false
            continue
        sprite.visible = true
        var logical := 0 if clip == "idle" and action_remaining <= 0.0 else int(phase) % columns.size()
        sprite.frame = row * sprite.hframes + columns[logical]

func verify_animation_contract() -> bool:
    if sprites.size() < 2:
        return false
    var saved_facing := facing
    var saved_clip := clip
    for direction in [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]:
        facing = direction
        for requested in ["idle", "walk", "slash", "spellcast", "thrust", "shoot"]:
            _apply_clip(requested)
            var row := _direction_offset()
            for sprite in sprites:
                if row >= sprite.vframes or _visible_columns(sprite, row).is_empty():
                    facing = saved_facing
                    _apply_clip(saved_clip)
                    return false
    facing = saved_facing
    _apply_clip(saved_clip)
    return true
