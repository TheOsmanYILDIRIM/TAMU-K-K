extends SceneTree
const Session = preload("res://scripts/gameplay_session.gd")
const Building = preload("res://scripts/domain_building.gd")
const Store = preload("res://scripts/stage6_checkpoint.gd")
const WORLD := "123e4567-e89b-42d3-a456-426614174000"
const REGION := "fisilti_ormani"
const INSTANCE := "123e4567-e89b-42d3-a456-426614174001"

func _new_session() -> RefCounted:
    var run = Session.new()
    var result: Dictionary = run.enable_durable("durable", WORLD, REGION,
        Callable(Building, "test_dry"), Callable(Building, "test_obstacles"))
    if not bool(result.get("ok", false)):
        print("TAMU_AUTOSAVE_ENABLE_FAILED ", result)
        return null
    return run

func _initialize() -> void:
    var phase := OS.get_environment("TAMU_DURABLE_PHASE")
    var ok := false
    if phase == "harvest":
        ok = _harvest()
    elif phase == "craft":
        ok = _craft()
    elif phase == "build":
        ok = _build()
    elif phase == "replay":
        ok = _replay()
    if ok:
        print("TAMU_STAGE6_DURABLE_", phase.to_upper(), "_OK")
    else:
        push_error("TAMU_STAGE6_DURABLE_" + phase.to_upper() + "_FAILED")
    quit(0 if ok else 65)

func _harvest() -> bool:
    if DirAccess.dir_exists_absolute("user://saves"):
        return false
    var run = _new_session()
    if run == null:
        return false
    var item := {"id": "worldobj:v1:20261018:-10:-11", "kind": "rock",
        "radius": 12.0, "position": Vector2(50, 0)}
    if run.begin_harvest(item, Vector2(50, 0), "harvest:one").get("status") != "started":
        return false
    for i in range(22):
        run.tick(0.1, Vector2(50, 0))
    if run.count_item("core:stone") != 2 or run.journal_sequence != 1:
        return false
    return run.begin_harvest(item, Vector2(50, 0), "harvest:one").get("status") == "duplicate"

func _craft() -> bool:
    var run = _new_session()
    if run == null:
        return false
    print("TAMU_DURABLE_CRAFT_START stone=",run.count_item("core:stone")," seq=",run.journal_sequence)
    if run.count_item("core:stone") != 2 or run.journal_sequence != 1:
        return false
    var seed: Dictionary = run.checkpoint_credit("durable", "seed:wood", "core:wood_log", 3)
    print("TAMU_DURABLE_SEED ",seed)
    if seed.get("status") != "committed":
        return false
    var begin: Dictionary = run.begin_craft("craft:planks", "core:planks_from_log")
    print("TAMU_DURABLE_PLANK_BEGIN ",begin)
    if begin.get("status") != "started":
        return false
    for i in range(7):
        run.tick(0.1, Vector2.ZERO)
    print("TAMU_DURABLE_PLANK_RESULT ",run.count_item("core:wood_plank")," seq=",run.journal_sequence)
    if run.count_item("core:wood_plank") != 4 or run.journal_sequence != 3:
        return false
    var bench: Dictionary = run.begin_craft("craft:bench", "core:bench_from_planks")
    print("TAMU_DURABLE_BENCH_BEGIN ",bench)
    if bench.get("status") != "started":
        return false
    for i in range(12):
        run.tick(0.1, Vector2.ZERO)
    print("TAMU_DURABLE_BENCH_RESULT count=",run.count_item("core:workbench")," seq=",run.journal_sequence)
    return run.count_item("core:workbench") == 1 and run.journal_sequence == 4

func _build() -> bool:
    var run = _new_session()
    if run == null or run.count_item("core:workbench") != 1:
        return false
    var result: Dictionary = run.place_building("build:one", INSTANCE, "core:workbench",
        Vector2(50, 0), 0, Vector2.ZERO, "test:player")
    if result.get("status") != "placed" or run.journal_sequence != 5:
        return false
    return run.building.placed.has(INSTANCE) and run.count_item("core:workbench") == 0

func _replay() -> bool:
    var run = _new_session()
    if run == null or run.journal_sequence != 5 or not run.building.placed.has(INSTANCE):
        return false
    var before: String = Store._seal(run.snapshot_domain())
    var reject: Dictionary = run.place_building("build:one", INSTANCE, "core:workbench",
        Vector2(50, 0), 0, Vector2.ZERO, "test:player")
    if reject.get("status") != "duplicate" or run.checkpoint_credit("durable", "seed:wood", "core:wood_log", 3).get("status") != "duplicate":
        return false
    var changed: Dictionary = run.snapshot_domain()
    changed["world_binding"]["region_id"] = "other_region"
    if run._publish_checkpoint(changed).get("status") != "world_region_mismatch":
        return false
    return Store._seal(run.snapshot_domain()) == before
