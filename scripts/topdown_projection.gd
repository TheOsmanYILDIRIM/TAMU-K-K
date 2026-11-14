extends RefCounted
# Experimental 2D top-down view adapter. Preserve persisted Cartesian world coordinates.
const CHUNK_SIZE := 256.0

static func to_screen(world: Vector2) -> Vector2:
    return world

static func to_world(screen: Vector2) -> Vector2:
    return screen

static func joystick_to_world(screen_input: Vector2) -> Vector2:
    return screen_input

static func chunk_center_from_key(stem: String) -> Vector2:
    var parts := stem.split("_")
    if parts.size() != 3 or parts[0] != "c":
        return Vector2(INF, INF)
    return Vector2((float(parts[1]) + 0.5) * CHUNK_SIZE,
        (float(parts[2]) + 0.5) * CHUNK_SIZE)

static func verify_contract() -> bool:
    for point in [Vector2.ZERO, Vector2(64, 128), Vector2(-4096, -4096),
            Vector2(256, 0), Vector2(28672, 28672)]:
        if to_world(to_screen(point)) != point:
            return false
    return joystick_to_world(Vector2.UP) == Vector2.UP and \
        chunk_center_from_key("c_-1_0") == Vector2(-128, 128)
