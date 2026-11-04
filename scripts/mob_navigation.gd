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

# Native Godot 4.6 AStarGrid2D replaces the GDScript A* frontier loop.
# Preparation and authoritative edge validation are incremental to avoid frame spikes.
const GRID_PADDING := 4
const MAX_GRID_CELLS := 4096
var native_grid: AStarGrid2D
var native_grid_origin := Vector2.ZERO
var native_grid_size := Vector2i.ZERO
var raster_cursor := 0
var validation_cursor := 0
var staged_path: Array[Vector2] = []
var phase := "idle"

func cancel() -> void:
    super.cancel()
    native_grid = null
    raster_cursor = 0
    validation_cursor = 0
    staged_path.clear()
    phase = "idle"

func begin(from_world: Vector2, target_world: Vector2, harvest_reach: float,
        radius: float, obstacles: Callable, terrain: Callable, bounds: Rect2) -> bool:
    # Reuse the existing input/range/footprint validation; discard its A* work.
    if not super.begin(from_world, target_world, harvest_reach, radius, obstacles, terrain, bounds):
        return false
    if state == "ready":
        return true
    frontier.clear()
    cost.clear()
    parents.clear()
    closed.clear()
    var low := Vector2i(floori(minf(from_world.x, target_world.x) / CELL) - GRID_PADDING,
        floori(minf(from_world.y, target_world.y) / CELL) - GRID_PADDING)
    var high := Vector2i(ceili(maxf(from_world.x, target_world.x) / CELL) + GRID_PADDING,
        ceili(maxf(from_world.y, target_world.y) / CELL) + GRID_PADDING)
    native_grid_size = high - low + Vector2i.ONE
    if native_grid_size.x <= 0 or native_grid_size.y <= 0 or native_grid_size.x * native_grid_size.y > MAX_GRID_CELLS:
        state = "failed"
        reason = "native_grid_limit"
        return false
    native_grid_origin = Vector2(low) * CELL
    native_grid = AStarGrid2D.new()
    native_grid.region = Rect2i(Vector2i.ZERO, native_grid_size)
    native_grid.cell_size = Vector2(CELL, CELL)
    native_grid.offset = native_grid_origin
    # Prevent diagonal corner cutting; final edges also use authored R2 sweeps.
    native_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    native_grid.jumping_enabled = false
    native_grid.update()
    raster_cursor = 0
    validation_cursor = 0
    staged_path.clear()
    phase = "raster"
    return true

func _grid_world(cell: Vector2i) -> Vector2:
    return native_grid_origin + Vector2(cell) * CELL

func _grid_id(at: Vector2) -> Vector2i:
    return Vector2i(roundi((at.x - native_grid_origin.x) / CELL),
        roundi((at.y - native_grid_origin.y) / CELL))

func _choose_native_path() -> void:
    var start_cell := _grid_id(origin)
    if not native_grid.region.has_point(start_cell):
        state = "failed"
        reason = "native_start_outside"
        return
    # The authored origin was already tested by super.begin; its snapped cell
    # must still lead through a validated edge before the actor moves.
    native_grid.set_point_solid(start_cell, false)
    var candidates: Array[Dictionary] = []
    for y in range(native_grid_size.y):
        for x in range(native_grid_size.x):
            var cell := Vector2i(x, y)
            if native_grid.is_point_solid(cell):
                continue
            var p := _grid_world(cell)
            if p.distance_to(target) <= reach:
                candidates.append({"cell": cell, "score": p.distance_squared_to(target)})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a["score"]) < float(b["score"]))
    for candidate in candidates:
        var ids: Array[Vector2i] = native_grid.get_id_path(start_cell, candidate["cell"])
        if ids.is_empty():
            continue
        staged_path.clear()
        for cell in ids:
            var p := _grid_world(cell)
            if staged_path.is_empty() and cell == start_cell:
                continue
            staged_path.append(p)
        if staged_path.is_empty():
            staged_path.append(_grid_world(candidate["cell"]))
        validation_cursor = 0
        phase = "validate"
        return
    state = "failed"
    reason = "native_unreachable"

# Godot C++ pathfinding only runs after a budgeted, authoritative raster.
# This is NOT the HarvestPathfinder.advance GDScript search.
func advance(max_steps: int = 32, max_microseconds: int = 900) -> String:
    if state != "searching":
        return state
    var started := Time.get_ticks_usec()
    var remaining := maxi(1, mini(max_steps, 128))
    if phase == "raster":
        while remaining > 0 and raster_cursor < native_grid_size.x * native_grid_size.y:
            if Time.get_ticks_usec() - started >= max_microseconds:
                return state
            var cell := Vector2i(raster_cursor % native_grid_size.x, raster_cursor / native_grid_size.x)
            native_grid.set_point_solid(cell, not _can_stand(_grid_world(cell)))
            raster_cursor += 1
            remaining -= 1
        if raster_cursor < native_grid_size.x * native_grid_size.y:
            return state
        _choose_native_path()
    if phase == "validate" and state == "searching":
        while remaining > 0 and validation_cursor < staged_path.size():
            if Time.get_ticks_usec() - started >= max_microseconds:
                return state
            var from_world: Vector2 = origin if validation_cursor == 0 else staged_path[validation_cursor - 1]
            if not _clear_edge(from_world, staged_path[validation_cursor]):
                state = "failed"
                reason = "native_edge_blocked"
                staged_path.clear()
                return state
            validation_cursor += 1
            remaining -= 1
        if validation_cursor >= staged_path.size():
            path = staged_path.duplicate()
            staged_path.clear()
            state = "ready"
            phase = "ready"
    return state
