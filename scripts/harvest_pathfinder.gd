extends RefCounted
# Incremental A* in authored Cartesian world coordinates. Every candidate
# edge uses the same swept collision authority as character movement.
const R2Collision = preload("res://scripts/r2_collision.gd")
const CELL := 24.0
const MAX_EXPANDED := 4096
const MAX_ROUTE_DISTANCE := 1536.0
const DIRECTIONS := [
    Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
    Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]
var state := "idle"
var reason := ""
var origin := Vector2.ZERO
var target := Vector2.ZERO
var reach := 0.0
var actor_radius := 9.0
var limits := Rect2()
var obstacle_query: Callable
var surface_query: Callable
var frontier: Array[Dictionary] = []
var cost: Dictionary = {}
var parents: Dictionary = {}
var closed: Dictionary = {}
var path: Array[Vector2] = []
var expanded := 0

func cancel() -> void:
    state = "idle"
    reason = ""
    frontier.clear()
    cost.clear()
    parents.clear()
    closed.clear()
    path.clear()
    expanded = 0

func begin(from_world: Vector2, target_world: Vector2, harvest_reach: float,
        radius: float, obstacles: Callable, terrain: Callable, bounds: Rect2) -> bool:
    cancel()
    if not obstacles.is_valid() or not terrain.is_valid() or radius <= 0.0 \
            or harvest_reach <= radius or not is_finite(from_world.x) \
            or not is_finite(from_world.y) or not is_finite(target_world.x) \
            or not is_finite(target_world.y) or not bounds.has_point(from_world) \
            or not bounds.has_point(target_world):
        state = "failed"
        reason = "invalid_input"
        return false
    if from_world.distance_to(target_world) > MAX_ROUTE_DISTANCE:
        state = "failed"
        reason = "too_far"
        return false
    origin = from_world
    target = target_world
    reach = harvest_reach - 3.0
    actor_radius = radius
    obstacle_query = obstacles
    surface_query = terrain
    limits = bounds
    if from_world.distance_to(target_world) <= reach:
        state = "ready"
        return true
    if not _can_stand(from_world):
        state = "failed"
        reason = "blocked_start"
        return false
    var start := Vector2i.ZERO
    cost[start] = 0.0
    _push(start, _estimate(start))
    state = "searching"
    return true

func _position(cell: Vector2i) -> Vector2:
    return origin + Vector2(cell) * CELL

func _estimate(cell: Vector2i) -> float:
    return maxf(0.0, _position(cell).distance_to(target) - reach)

func _can_stand(at: Vector2) -> bool:
    if not limits.has_point(at):
        return false
    var sample: Variant = surface_query.call(at.x, at.y)
    if not sample is Dictionary or not bool(sample.get("walkable", false)):
        return false
    var margin := actor_radius + 0.6
    var boxes: Variant = obstacle_query.call(at.x-margin, at.y-margin,
        at.x+margin, at.y+margin)
    if not boxes is Array:
        return false
    for shape in boxes:
        if not shape is Dictionary:
            return false
        var left := float(shape.get("x", NAN)) - margin
        var top := float(shape.get("y", NAN)) - margin
        var right := float(shape.get("x", NAN)) + float(shape.get("w", NAN)) + margin
        var bottom := float(shape.get("y", NAN)) + float(shape.get("h", NAN)) + margin
        if not is_finite(left) or not is_finite(top) or not is_finite(right) \
                or not is_finite(bottom):
            return false
        if at.x > left and at.x < right and at.y > top and at.y < bottom:
            return false
    return true

func _clear_edge(from_world: Vector2, to_world: Vector2) -> bool:
    var moved: Dictionary = R2Collision.move(from_world, to_world-from_world,
        actor_radius + 0.2, obstacle_query)
    return bool(moved.get("ok", false)) \
        and (moved.get("position", from_world) as Vector2).distance_squared_to(to_world) < 0.25

func _push(cell: Vector2i, priority: float) -> void:
    frontier.append({"cell": cell, "priority": priority})
    var pos := frontier.size() - 1
    while pos > 0:
        var parent_index := (pos-1) / 2
        if float(frontier[parent_index]["priority"]) <= priority:
            break
        frontier[pos] = frontier[parent_index]
        pos = parent_index
    frontier[pos] = {"cell": cell, "priority": priority}

func _pop() -> Vector2i:
    var first: Vector2i = frontier[0]["cell"]
    var last: Dictionary = frontier.pop_back()
    if frontier.is_empty():
        return first
    var pos := 0
    while true:
        var left := pos*2+1
        if left >= frontier.size():
            break
        var best := left
        if left+1 < frontier.size() and float(frontier[left+1]["priority"]) \
                < float(frontier[left]["priority"]):
            best = left+1
        if float(last["priority"]) <= float(frontier[best]["priority"]):
            break
        frontier[pos] = frontier[best]
        pos = best
    frontier[pos] = last
    return first

func _build(goal_cell: Vector2i) -> void:
    var cell := goal_cell
    var reversed: Array[Vector2] = []
    while cell != Vector2i.ZERO:
        reversed.append(_position(cell))
        if not parents.has(cell):
            state = "failed"
            reason = "broken_path"
            return
        cell = parents[cell]
    reversed.reverse()
    path = reversed
    frontier.clear()
    state = "ready"

# Run from _process. The budget limits expansions AND wall-clock work per frame.
func advance(max_steps: int = 32, max_microseconds: int = 900) -> String:
    if state != "searching":
        return state
    var start_time := Time.get_ticks_usec()
    for i in range(maxi(0, mini(max_steps, 128))):
        if frontier.is_empty():
            state = "failed"
            reason = "unreachable"
            break
        if expanded >= MAX_EXPANDED:
            state = "failed"
            reason = "search_limit"
            break
        if i > 0 and Time.get_ticks_usec() - start_time >= max_microseconds:
            break
        var cell := _pop()
        if closed.has(cell):
            continue
        closed[cell] = true
        expanded += 1
        if _estimate(cell) <= 0.0:
            _build(cell)
            break
        var at := _position(cell)
        for offset in DIRECTIONS:
            var next: Vector2i = cell + offset
            if closed.has(next):
                continue
            var to := _position(next)
            if to.distance_to(origin) > MAX_ROUTE_DISTANCE or not _can_stand(to):
                continue
            if not _clear_edge(at, to):
                continue
            var candidate := float(cost[cell]) + Vector2(offset).length()*CELL
            if candidate + 0.001 >= float(cost.get(next, INF)):
                continue
            cost[next] = candidate
            parents[next] = cell
            _push(next, candidate + _estimate(next))
    return state
