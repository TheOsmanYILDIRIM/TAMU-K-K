extends RefCounted
# All 156 authored cells are scheduled proactively; no nearby discovery gate.
# Existing one-mesh-per-frame upload budget remains unchanged until measured.
const Projection = preload("res://scripts/world_projection.gd")

static func schedule(available: Dictionary, resident: Dictionary, actor_world: Vector2) -> Array[String]:
    var result: Array[String] = []
    for stem in available:
        if not resident.has(stem):
            result.append(str(stem))
    result.sort_custom(func(a: String, b: String):
        var da: float = Projection.chunk_center_from_key(a).distance_squared_to(actor_world)
        var db: float = Projection.chunk_center_from_key(b).distance_squared_to(actor_world)
        return a < b if is_equal_approx(da, db) else da < db
    )
    return result

static func verify_contract() -> bool:
    var cells := {"c_0_0": true, "c_-1_0": true, "c_1_0": true}
    var order := schedule(cells, {}, Vector2(64, 128))
    if order.size() != 3 or order[0] != "c_0_0":
        return false
    var loaded := {"c_0_0": true}
    var remaining := schedule(cells, loaded, Vector2(-220, 128))
    return remaining.size() == 2 and remaining[0] == "c_-1_0" and remaining[1] == "c_1_0"
