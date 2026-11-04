extends "res://scripts/harvest_pathfinder.gd"
# Mob A* keeps the authored terrain and live gameplay obstacle authority.
# Reuse exact terrain samples during one route, never approximate positions.
# One swept obstacle query plus one broadphase batch covers all edge samples.
const MAX_WALKABLE_SAMPLES := 8192
var walkable_samples: Dictionary = {}

func cancel() -> void:
    walkable_samples.clear()
    super.cancel()

func _walkable(at: Vector2) -> bool:
    if not limits.has_point(at):
        return false
    if walkable_samples.has(at):
        return bool(walkable_samples[at])
    var data: Variant = surface_query.call(at.x, at.y)
    var result := false
    if data is Dictionary:
        result = bool(data.get("walkable", false))
    if walkable_samples.size() >= MAX_WALKABLE_SAMPLES:
        walkable_samples.clear()
    walkable_samples[at] = result
    return result

func _terrain_footprint(at: Vector2) -> bool:
    if not _walkable(at):
        return false
    return _walkable(at + Vector2(actor_radius, 0.0)) \
        and _walkable(at - Vector2(actor_radius, 0.0)) \
        and _walkable(at + Vector2(0.0, actor_radius)) \
        and _walkable(at - Vector2(0.0, actor_radius))

func _can_stand(at: Vector2) -> bool:
    if not _terrain_footprint(at):
        return false
    var margin := actor_radius + 0.6
    var shapes: Variant = obstacle_query.call(at.x - margin, at.y - margin,
        at.x + margin, at.y + margin)
    if not shapes is Array:
        return false
    for shape in shapes:
        if not shape is Dictionary:
            return false
        var x := float(shape.get("x", NAN))
        var y := float(shape.get("y", NAN))
        var w := float(shape.get("w", NAN))
        var h := float(shape.get("h", NAN))
        if not is_finite(x) or not is_finite(y) or not is_finite(w) or not is_finite(h):
            return false
        if at.x > x - margin and at.x < x + w + margin \
                and at.y > y - margin and at.y < y + h + margin:
            return false
    return true

func _clear_edge(from_world: Vector2, to_world: Vector2) -> bool:
    # R2Collision.move checks the full swept body (including sliding).
    if not super._clear_edge(from_world, to_world):
        return false
    # Previously each 4-unit sample re-queried the full obstacle system.
    # A single enclosing AABB yields the same candidates for every sample;
    # dynamic blockers remain authoritative for every NEW edge evaluation.
    var margin := actor_radius + 0.6
    var low := from_world.min(to_world) - Vector2.ONE * margin
    var high := from_world.max(to_world) + Vector2.ONE * margin
    var shapes: Variant = obstacle_query.call(low.x, low.y, high.x, high.y)
    if not shapes is Array:
        return false
    var expanded: Array[Rect2] = []
    for shape in shapes:
        if not shape is Dictionary:
            return false
        var x := float(shape.get("x", NAN))
        var y := float(shape.get("y", NAN))
        var w := float(shape.get("w", NAN))
        var h := float(shape.get("h", NAN))
        if not is_finite(x) or not is_finite(y) or not is_finite(w) or not is_finite(h):
            return false
        expanded.append(Rect2(x - margin, y - margin, w + 2.0 * margin, h + 2.0 * margin))
    var steps := maxi(1, ceili(from_world.distance_to(to_world) / 4.0))
    for i in range(steps + 1):
        var at := from_world.lerp(to_world, float(i) / float(steps))
        if not _terrain_footprint(at):
            return false
        # Keep the original strict inside-box test, not Rect2's half-open rule.
        for rect in expanded:
            if at.x > rect.position.x and at.x < rect.end.x \
                    and at.y > rect.position.y and at.y < rect.end.y:
                return false
    return true
