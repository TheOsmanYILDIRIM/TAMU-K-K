extends SceneTree
# Independent fast source parity before expensive Android scene import.
const Surface = preload("res://scripts/r2_surface.gd")
const Building = preload("res://scripts/domain_building.gd")

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
    print("TAMU_R2_SURFACE_PARITY_OK height=",ground_h," river=blocked land=buildable")
    quit(0)
