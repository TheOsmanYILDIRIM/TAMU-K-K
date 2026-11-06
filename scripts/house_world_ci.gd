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
    print("TAMU_PRODUCTION_CONTRACT_OK modules=30 sites=12")
    print("TAMU_HOUSE_CONTRACT_OK exterior=single_png door=marked route=astar room=3x3 save=untouched")
    quit()
