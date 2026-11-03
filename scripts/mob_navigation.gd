extends "res://scripts/harvest_pathfinder.gd"
# Reuses TAMU's budgeted Cartesian A*. Unlike harvest navigation, every edge
# and the full body footprint must remain on authoritative walkable terrain.
func _can_stand(at: Vector2) -> bool:
    if not super._can_stand(at):
        return false
    for offset in [Vector2(actor_radius, 0), Vector2(-actor_radius, 0),
        Vector2(0, actor_radius), Vector2(0, -actor_radius)]:
        var p: Vector2 = at + offset
        if not limits.has_point(p):
            return false
        var data: Variant = surface_query.call(p.x, p.y)
        if not data is Dictionary or not bool(data.get("walkable", false)):
            return false
    return true

func _clear_edge(from_world: Vector2, to_world: Vector2) -> bool:
    if not super._clear_edge(from_world, to_world):
        return false
    var steps: int = maxi(1, ceili(from_world.distance_to(to_world) / 4.0))
    for i in range(steps + 1):
        if not _can_stand(from_world.lerp(to_world, float(i) / steps)):
            return false
    return true
