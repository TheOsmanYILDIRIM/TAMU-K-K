extends AnimatedSprite2D
# Optional six-clip side-profile preview. Authoritative physics/world and old Rigby remain unchanged.
const BASE := "res://assets/profile_character/"
const FRAME_COUNT := 12
const CELL := Vector2i(160, 200)

func setup() -> bool:
    var states := ["idle", "walk", "run", "slash", "stab", "die", "sit"]
    var library := SpriteFrames.new()
    for state in states:
        var path := BASE + state + ".png"
        if not ResourceLoader.exists(path):
            push_error("TAMU_PROFILE_MISSING " + path)
            return false
        var atlas: Texture2D = load(path)
        if atlas == null or atlas.get_width() != CELL.x * FRAME_COUNT or atlas.get_height() != CELL.y:
            push_error("TAMU_PROFILE_ATLAS_INVALID " + path)
            return false
        library.add_animation(state)
        library.set_animation_speed(state, 15.0 if state == "run" else 12.0)
        library.set_animation_loop(state, state != "die")
        for i in range(FRAME_COUNT):
            var tile := AtlasTexture.new()
            tile.atlas = atlas
            tile.region = Rect2(i * CELL.x, 0, CELL.x, CELL.y)
            library.add_frame(state, tile)
    sprite_frames = library
    name = "TAMUProfileSprite"
    centered = true
    offset = Vector2(0.0, -CELL.y / 2.0 + 6.0)
    scale = Vector2(0.42, 0.42)
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    play("idle")
    return true

func set_movement(walking: bool, left: bool) -> void:
    flip_h = left
    var next := "walk" if walking else "idle"
    if animation != next:
        play(next)
