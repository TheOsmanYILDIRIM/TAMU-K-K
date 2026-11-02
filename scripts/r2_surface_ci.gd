extends SceneTree
# Independent fast source parity before expensive Android scene import.
const Surface = preload("res://scripts/r2_surface.gd")
const Building = preload("res://scripts/domain_building.gd")
const Collision = preload("res://scripts/r2_collision.gd")

func _initialize() -> void:
    var source = Surface.new()
    if not source.initialize():
        push_error("TAMU_R2_SURFACE_SOURCE_INVALID")
        quit(72)
        return
    var ground: Dictionary = source.sample(64.0, 128.0)
    var river: Dictionary = source.sample(704.0, 128.0)
    var rock: Dictionary = source.sample(400.0, 128.0)
    var ground_h := float(ground.get("height", INF))
    if not bool(ground.get("walkable", false)) or absf(ground_h-12.830245) > 0.02:
        push_error("TAMU_R2_SURFACE_FIELD_PARITY_FAILED height=" + str(ground_h))
        quit(72)
        return
    if str(river.get("feature", "")) != "water" or bool(river.get("walkable", true)):
        push_error("TAMU_R2_SURFACE_WATER_GATE_FAILED")
        quit(72)
        return
    if not rock.has("grade") or float(rock["grade"]) < 0.0:
        push_error("TAMU_R2_SURFACE_TOPOGRAPHY_MISSING")
        quit(72)
        return
    var building = Building.new(null, null)
    building.terrain_sample = Callable(source, "sample")
    if not building._dry_and_stable(Rect2(64.0, 128.0, 16.0, 16.0)):
        push_error("TAMU_R2_BUILD_LAND_FAILED")
        quit(72)
        return
    if building._dry_and_stable(Rect2(700.0, 125.0, 12.0, 12.0)):
        push_error("TAMU_R2_BUILD_WATER_ACCEPTED")
        quit(72)
        return
    var sweep: Dictionary = Collision.move(Vector2.ZERO,Vector2(40.0,12.0),5.0,
        Callable(self,"_wall"))
    if not bool(sweep.get("ok",false)) or not bool(sweep.get("collided",false))             or float(sweep["position"].x) > 15.01 or float(sweep["position"].y) < 5.0:
        push_error("TAMU_R2_SWEEP_SLIDE_FAILED "+str(sweep))
        quit(72)
        return
    # Moving into a wall must stop a player-sized body outside the obstacle.
    var clearance: Dictionary = Collision.move(Vector2.ZERO, Vector2(40.0, 0.0), 9.0,
        Callable(self, "_wall"))
    if not bool(clearance.get("ok", false)) or not bool(clearance.get("collided", false)) or float(clearance["position"].x) > 11.01:
        push_error("TAMU_ACTOR_OBJECT_CLEARANCE_FAILED " + str(clearance))
        quit(72)
        return
    print("TAMU_ACTOR_OBJECT_CLEARANCE_OK")
    print("TAMU_R2_SWEEP_SLIDE_OK")
    print("TAMU_R2_SURFACE_PARITY_OK height=",ground_h," river=blocked land=buildable")
    quit(0)

func _wall(_minx: float, _miny: float, _maxx: float, _maxy: float) -> Array:
    return [{"x":20.0,"y":-20.0,"w":10.0,"h":40.0}]
