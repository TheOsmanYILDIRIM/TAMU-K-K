extends SceneTree
## Fast source-only contract; device visuals and physical navigation are separate.
const Cabin = preload("res://scripts/single_house_world.gd")
const Production = preload("res://scripts/production_engine.gd")
const WorldProjection = preload("res://scripts/world_projection.gd")

func _initialize() -> void:
    if not Cabin.verify_geometry():
        push_error("TAMU_HOUSE_PROJECTION_FAILED")
        quit(91)
        return
    var d: Dictionary = Cabin.definition()
    if str(d.get("id", "")) != "tamu:house_wood_lv1" \
            or d.get("footprint_cells") != [3, 3] \
            or d.get("interior_cells") != [3, 3] \
            or d.get("cell_world_units") != 32 \
            or str(d.get("interior_id", "")) != "tamu:interior_house_wood_lv1":
        push_error("TAMU_HOUSE_METADATA_FAILED")
        quit(92)
        return
    var cabin = Cabin.new()
    cabin.footprint_box = Rect2(-48.0, -48.0, 96.0, 96.0)
    var near: Array = cabin.collision_shapes(40.0, -12.0, 70.0, 12.0)
    var far: Array = cabin.collision_shapes(120.0, 120.0, 140.0, 140.0)
    if near.size() != 1 or far.size() != 0:
        push_error("TAMU_HOUSE_COLLISION_FAILED")
        quit(93)
        return
    var image_px: Vector2 = Cabin.SOURCE_DOOR - Cabin.SOURCE_GROUND_PIVOT
    if image_px.x <= 0.0 or image_px.y <= 0.0:
        push_error("TAMU_HOUSE_DOOR_NOT_FRONT_FACADE")
        quit(94)
        return
    var entrance: Vector2 = Cabin.APPROACH_WORLD
    var door_world: Vector2 = Cabin.DOOR_WORLD
    if entrance.distance_to(door_world) > 40.0 or entrance.x <= 48.0 + 9.0:
        push_error("TAMU_HOUSE_ENTRY_CLEARANCE_FAILED")
        quit(95)
        return
    if WorldProjection.to_world(WorldProjection.to_screen(door_world)).distance_to(door_world) > 0.0001:
        push_error("TAMU_HOUSE_DOOR_PROJECTION_FAILED")
        quit(96)
        return
    if not Cabin.fallback_contains_source(Cabin.SOURCE_DOOR):
        push_error("TAMU_HOUSE_FALLBACK_DOOR_HIT_FAILED")
        quit(104)
        return
    if Cabin.fallback_contains_source(Vector2(-1000.0,-1000.0)):
        push_error("TAMU_HOUSE_FALLBACK_HIT_LEAK")
        quit(105)
        return
    cabin._create_procedural_exterior()
    if cabin.exterior_fallback == null or cabin.exterior_fallback.get_child_count() < 15:
        push_error("TAMU_HOUSE_FALLBACK_DRAW_FAILED")
        quit(106)
        return
    print("TAMU_HOUSE_FALLBACK_CONTRACT_OK drawing=procedural door_hit=true")
    cabin.free()
    var p = Production.new()
    if not p.initialize() or p.definitions["modules"].size() < 30 or p.definitions["sites"].size() < 12:
        push_error("TAMU_PRODUCTION_CATALOG_FAILED")
        quit(97)
        return
    if not p.place("furnace",Vector2i(0,0)) or not p.place("crucible",Vector2i(1,0)) or not p.place("mold",Vector2i(2,0)):
        push_error("TAMU_PRODUCTION_PLACEMENT_FAILED")
        quit(98)
        return
    if not p.joined(Vector2i(0,0),Vector2i(1,0),"heat") or not p.joined(Vector2i(1,0),Vector2i(2,0),"molten"):
        push_error("TAMU_PRODUCTION_SOCKETS_FAILED")
        quit(99)
        return
    p.activate(true)
    for i in range(20):
        p.step()
    if p.stock["ingot"] <= 0 or p.heat <= 0:
        push_error("TAMU_PRODUCTION_SMELTING_FAILED")
        quit(100)
        return
    p.use_site("field")
    if not p.plant(Vector2i(0,0)):
        push_error("TAMU_PRODUCTION_FARM_FAILED")
        quit(101)
        return
    p.activate(true)
    for i in range(38):
        p.step()
        if i % 8 == 0:
            p.water(Vector2i(0,0))
    if not p.harvest(Vector2i(0,0)) or p.stock["food"] != 3:
        push_error("TAMU_PRODUCTION_HARVEST_FAILED")
        quit(102)
        return
    if not _production_extended_contract():
        push_error("TAMU_PRODUCTION_EXTENDED_FAILED")
        quit(103)
        return
    print("TAMU_PRODUCTION_EXTENDED_OK pipes=connected ore=preserved sites=retained hazards=local")
    print("TAMU_PRODUCTION_CONTRACT_OK modules=30 sites=12")
    print("TAMU_HOUSE_CONTRACT_OK exterior=single_png door=marked route=astar room=3x3 save=untouched")
    quit()


func _production_extended_contract() -> bool:
    var m = Production.new()
    if not m.initialize():
        return false
    if not m.place("furnace",Vector2i(0,0)) or not m.place("crucible",Vector2i(1,0)):
        return false
    m.activate(true)
    for i in range(12):
        m.step()
    if m.stock["ore"]!=30 or m.stock["ingot"]!=0:
        return false
    if not m.place("mold",Vector2i(2,0)):
        return false
    for i in range(8):
        m.step()
    if m.stock["ingot"]<=0 or m.stock["ore"]>=30:
        return false
    if not m.use_site("field") or not m.use_site("wood_cabin") or m.at(Vector2i(0,0)).get("kind","")!="furnace":
        return false

    var loose = Production.new()
    var joined_vent = Production.new()
    if not loose.initialize() or not joined_vent.initialize():
        return false
    for sim in [loose,joined_vent]:
        sim.place("furnace",Vector2i(0,0))
        sim.activate(true)
    loose.place("vent",Vector2i(2,2))
    joined_vent.place("vent",Vector2i(0,1))
    for i in range(8):
        loose.step()
        joined_vent.step()
    if joined_vent.smoke>=loose.smoke:
        return false

    var unsafe = Production.new()
    var relieved = Production.new()
    if not unsafe.initialize() or not relieved.initialize():
        return false
    for sim in [unsafe,relieved]:
        sim.use_site("stone_foundry")
        sim.place("boiler",Vector2i(0,0))
        sim.activate(true)
    unsafe.place("valve",Vector2i(3,3))
    relieved.place("valve",Vector2i(1,0))
    for i in range(8):
        unsafe.step()
        relieved.step()
    if relieved.pressure>=unsafe.pressure:
        return false

    var garden = Production.new()
    if not garden.initialize() or not garden.use_site("field"):
        return false
    if not garden.place("pump",Vector2i(0,1)) or not garden.place("pipe",Vector2i(1,1)) or not garden.place("sprinkler",Vector2i(2,1)):
        return false
    if not garden.supplied_by(Vector2i(2,1),"pump","water") or not garden.plant(Vector2i(2,2),"roots"):
        return false
    var first_water: int = int(garden.stock["water"])
    garden.activate(true)
    for i in range(34):
        garden.step()
    if garden.stock["water"]>=first_water or not garden.harvest(Vector2i(2,2)):
        return false
    garden.remove(Vector2i(1,1))
    if garden.supplied_by(Vector2i(2,1),"pump","water"):
        return false

    var hazard = Production.new()
    if not hazard.initialize() or not hazard.place("alloy_furnace",Vector2i(0,0)):
        return false
    hazard.activate(true)
    for i in range(35):
        hazard.step()
    if hazard.fire<=0.0 or hazard.integrity>=100.0:
        return false
    var fire_before: float = hazard.fire
    if not hazard.extinguish() or hazard.running or hazard.fire>=fire_before:
        return false
    var damage_before: float = hazard.integrity
    if not hazard.repair() or hazard.integrity<=damage_before:
        return false

    var electric = Production.new()
    if not electric.initialize():
        return false
    if not electric.place("generator",Vector2i(0,0)) or not electric.place("battery",Vector2i(1,0)) or not electric.place("robot_arm",Vector2i(2,0)):
        return false
    if not electric.supplied_by(Vector2i(2,0),"generator","electric"):
        return false
    if not electric.rotate(Vector2i(1,0)) or electric.supplied_by(Vector2i(2,0),"generator","electric"):
        return false
    return true
