extends RefCounted
# TAMU original LÖVE R2 projection, preserved exactly in Godot world units.
# Gameplay/world IDs remain in Cartesian source coordinates; rendering only
# uses projected pixels. Do not use rendered sprite positions for save keys.
const ISO_X := 0.70710678118
const ISO_Y := 0.35355339059
const CHUNK_SIZE := 256.0

static func to_screen(world: Vector2) -> Vector2:
    return Vector2((world.x - world.y) * ISO_X, (world.x + world.y) * ISO_Y)

static func to_world(screen: Vector2) -> Vector2:
    var difference := screen.x / ISO_X
    var total := screen.y / ISO_Y
    return Vector2((difference + total) * 0.5, (total - difference) * 0.5)

# Manual joystick arrows are in screen coordinates. Convert them back to
# Cartesian world motion; a screen-up input must move visually straight up.
# Use ISO_X as the calibrated nominal screen-speed factor: equal joystick
# magnitude means equal projected speed, regardless of direction.
static func joystick_to_world(screen_input: Vector2) -> Vector2:
    return to_world(screen_input) * ISO_X

# A side-view paper avatar remains upright in this 2D isometric projection.
# Only mirror when actual ground movement has a horizontal screen component;
# depth-only movement preserves the last profile side instead of flickering.
static func profile_facing_sign(world_motion: Vector2, previous_sign: float = 1.0) -> float:
    var projected_x := (world_motion.x - world_motion.y) * ISO_X
    # Hysteresis near diagonal movement: do not flip a single profile
    # drawing because of subpixel joystick jitter. Keep the last side until
    # lateral travel is at least 25% of total ground motion.
    if absf(projected_x) < maxf(0.025, world_motion.length() * 0.25):
        return -1.0 if previous_sign < 0.0 else 1.0
    return -1.0 if projected_x < 0.0 else 1.0

static func chunk_center_from_key(stem: String) -> Vector2:
    var parts := stem.split("_")
    if parts.size() != 3 or parts[0] != "c":
        return Vector2(INF, INF)
    return Vector2((float(parts[1]) + 0.5) * CHUNK_SIZE,
        (float(parts[2]) + 0.5) * CHUNK_SIZE)

# Existing headless/Xvfb smoke calls this; does not require any new asset.
static func verify_contract() -> bool:
    for world in [Vector2.ZERO, Vector2(64, 128), Vector2(-4096, -4096),
        Vector2(28672, 28672), Vector2(256, 0)]:
        if world.distance_to(to_world(to_screen(world))) > 0.001:
            return false
    if to_screen(Vector2(256, 0)).distance_to(Vector2(181.01933598208, 90.50966799104)) > 0.001:
        return false
    if chunk_center_from_key("c_-1_0").distance_to(Vector2(-128, 128)) > 0.001:
        return false
    if profile_facing_sign(Vector2(1, 0)) != 1.0 or profile_facing_sign(Vector2(0, 1)) != -1.0:
        return false
    if profile_facing_sign(Vector2(1, 1), -1.0) != -1.0 or profile_facing_sign(Vector2(1, 1), 1.0) != 1.0:
        return false
    if profile_facing_sign(Vector2(1.0, 0.97), -1.0) != -1.0:
        return false
    if profile_facing_sign(Vector2(0.97, 1.0), 1.0) != 1.0:
        return false
    for input in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
            Vector2(0.70710678, -0.70710678), Vector2(-0.70710678, 0.70710678)]:
        var projected := to_screen(joystick_to_world(input))
        if projected.distance_to(input * ISO_X) > 0.0001:
            return false
    return true
