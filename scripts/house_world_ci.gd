extends SceneTree
## Fast source-only contract; device visuals and physical navigation are separate.
const Cabin = preload("res://scripts/single_house_world.gd")
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
    print("TAMU_HOUSE_CONTRACT_OK exterior=single_png door=marked route=astar room=3x3 save=untouched")
    quit()
