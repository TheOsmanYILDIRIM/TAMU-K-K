extends RefCounted
# Source/world coordinates are immutable. Camera culling only affects native nodes.
const WorldProjection = preload("res://scripts/world_projection.gd")
const CHUNK_SIZE := 256.0
const VIEW_PADDING := 224.0 # terrain height, sprites and pan prefetch, screen pixels
const RESIDENT_BUDGET_BYTES := 96 * 1024 * 1024
# Conservative CPU+Godot array+driver estimate; this is NOT GPU-measured VRAM.
const ESTIMATED_BYTES_PER_VERTEX := 48

static func chunk_screen_rect(stem: String) -> Rect2:
    var center := WorldProjection.chunk_center_from_key(stem)
    if not is_finite(center.x):
        return Rect2()
    var half := Vector2.ONE * CHUNK_SIZE * 0.5
    var a := WorldProjection.to_screen(center - half)
    var b := WorldProjection.to_screen(center + Vector2(half.x, -half.y))
    var c := WorldProjection.to_screen(center + Vector2(-half.x, half.y))
    var d := WorldProjection.to_screen(center + half)
    var minimum := a.min(b).min(c).min(d)
    var maximum := a.max(b).max(c).max(d)
    return Rect2(minimum, maximum - minimum)

static func required_chunks(available: Dictionary, camera_center: Vector2,
        viewport_size: Vector2, camera_zoom: Vector2, padding: float = VIEW_PADDING) -> Dictionary:
    var zoom := Vector2(maxf(absf(camera_zoom.x), 0.01), maxf(absf(camera_zoom.y), 0.01))
    var half := viewport_size * 0.5 / zoom
    var view := Rect2(camera_center - half, half * 2.0).grow(padding)
    var required := {}
    for stem in available:
        if chunk_screen_rect(str(stem)).intersects(view, true):
            required[stem] = true
    return required

static func schedule(available: Dictionary, resident: Dictionary, actor_world: Vector2,
        camera_center: Vector2, viewport_size: Vector2, camera_zoom: Vector2) -> Array[String]:
    var required := required_chunks(available, camera_center, viewport_size, camera_zoom)
    var result: Array[String] = []
    for stem in available:
        if not resident.has(stem):
            result.append(str(stem))
    result.sort_custom(func(a: String, b: String):
        var in_a := required.has(a)
        var in_b := required.has(b)
        if in_a != in_b:
            return in_a
        var da := chunk_screen_rect(a).get_center().distance_squared_to(camera_center) if in_a else WorldProjection.chunk_center_from_key(a).distance_squared_to(actor_world)
        var db := chunk_screen_rect(b).get_center().distance_squared_to(camera_center) if in_b else WorldProjection.chunk_center_from_key(b).distance_squared_to(actor_world)
        return a < b if is_equal_approx(da, db) else da < db
    )
    return result

static func estimate_bytes(vertex_counts: Dictionary) -> int:
    var total := 0
    for stem in vertex_counts:
        total += int(vertex_counts[stem]) * ESTIMATED_BYTES_PER_VERTEX
    return total

static func eviction_candidates(vertex_counts: Dictionary, pinned: Dictionary,
        camera_center: Vector2, budget_bytes: int) -> Array[String]:
    var excess := estimate_bytes(vertex_counts) - budget_bytes
    var candidates: Array[String] = []
    if excess <= 0:
        return candidates
    for stem in vertex_counts:
        if not pinned.has(stem):
            candidates.append(str(stem))
    candidates.sort_custom(func(a: String, b: String):
        var da := chunk_screen_rect(a).get_center().distance_squared_to(camera_center)
        var db := chunk_screen_rect(b).get_center().distance_squared_to(camera_center)
        return a < b if is_equal_approx(da, db) else da > db
    )
    var result: Array[String] = []
    for stem in candidates:
        if excess <= 0:
            break
        result.append(stem)
        excess -= int(vertex_counts[stem]) * ESTIMATED_BYTES_PER_VERTEX
    return result

static func verify_contract() -> bool:
    var available := {"c_0_0": true, "c_-1_0": true, "c_1_0": true, "c_15_15": true}
    var center := WorldProjection.to_screen(Vector2(64, 128))
    var pinned := required_chunks(available, center, Vector2(320, 500), Vector2.ONE, 0.0)
    if not pinned.has("c_0_0") or pinned.has("c_15_15"):
        return false
    var order := schedule(available, {}, Vector2(64, 128), center, Vector2(320, 500), Vector2.ONE)
    if order.size() != 4 or order[0] != "c_0_0":
        return false
    var relocated := required_chunks(available, WorldProjection.to_screen(Vector2(15.5 * CHUNK_SIZE, 15.5 * CHUNK_SIZE)), Vector2(80, 80), Vector2.ONE, 0.0)
    if not relocated.has("c_15_15") or relocated.has("c_0_0"):
        return false
    var counts := {"c_0_0": 100, "c_15_15": 300, "c_-1_0": 200}
    var victims := eviction_candidates(counts, {"c_0_0": true}, center, 100 * ESTIMATED_BYTES_PER_VERTEX)
    if victims.size() != 2 or victims[0] == "c_0_0":
        return false
    return estimate_bytes(counts) == 600 * ESTIMATED_BYTES_PER_VERTEX
