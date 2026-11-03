extends SceneTree
# Deterministic bounded-work navigation regression: obstacle detour, cancellation,
# reach margin and fail-closed limits. Pure test geometry, no authored world edits.
const Navigator = preload("res://scripts/harvest_pathfinder.gd")
const Collision = preload("res://scripts/r2_collision.gd")

func boxes(x1: float, y1: float, x2: float, y2: float) -> Array:
    var wall := {"x": 72.0, "y": -55.0, "w": 36.0, "h": 110.0}
    if wall["x"] < x2 and wall["x"] + wall["w"] > x1 \
            and wall["y"] < y2 and wall["y"] + wall["h"] > y1:
        return [wall]
    return []

func ground(_x: float, _y: float) -> Dictionary:
    return {"walkable": true}

func _initialize() -> void:
    var nav = Navigator.new()
    var area := Rect2(Vector2(-500, -500), Vector2(1000, 1000))
    if not nav.begin(Vector2.ZERO, Vector2(200, 0), 37.0, 9.0,
            Callable(self, "boxes"), Callable(self, "ground"), area):
        push_error("TAMU_NAV_BEGIN_FAILED")
        quit(71)
        return
    if nav.advance(1, 1000000) != "searching" or nav.expanded != 1:
        push_error("TAMU_NAV_BUDGET_FAILED")
        quit(72)
        return
    for n in range(2000):
        if nav.state != "searching":
            break
        nav.advance(8, 1000000)
    if nav.state != "ready" or nav.path.is_empty() or nav.expanded > nav.MAX_EXPANDED:
        push_error("TAMU_NAV_ASTAR_FAILED " + nav.reason)
        quit(73)
        return
    var last := Vector2.ZERO
    for point in nav.path:
        var move: Dictionary = Collision.move(last, point-last, 9.2, Callable(self,"boxes"))
        if not bool(move.get("ok", false)) or (move["position"] as Vector2).distance_to(point) > 0.5:
            push_error("TAMU_NAV_PATH_CROSSES_OBSTACLE")
            quit(74)
            return
        last = point
    if last.distance_to(Vector2(200, 0)) > 34.1:
        push_error("TAMU_NAV_GOAL_RANGE_FAILED")
        quit(75)
        return
    var count := nav.expanded
    nav.cancel()
    if nav.state != "idle" or not nav.path.is_empty():
        push_error("TAMU_NAV_CANCEL_FAILED")
        quit(76)
        return
    if nav.begin(Vector2.ZERO, Vector2(4000,0), 35.0, 9.0,
            Callable(self, "boxes"), Callable(self, "ground"), area) \
            or nav.reason != "invalid_input":
        # This target lies outside the authored test bounds.
        push_error("TAMU_NAV_INVALID_WORLD_REJECT_FAILED")
        quit(77)
        return
    if nav.begin(Vector2.ZERO, Vector2(450,0), 35.0, 9.0,
            Callable(self, "boxes"), Callable(self, "ground"), area):
        if nav.state != "searching":
            push_error("TAMU_NAV_SEARCH_STATE_FAILED")
            quit(78)
            return
    else:
        push_error("TAMU_NAV_VALID_REQUEST_FAILED")
        quit(78)
        return
    print("TAMU_NAV_INCREMENTAL_ASTAR_OK expanded=",count,
        " obstacles=swept boundary=closed cancellations=true")
    quit(0)
