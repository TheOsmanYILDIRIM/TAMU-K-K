extends RefCounted
# Trusted R2 object query, grounded in the pinned authored population.
# Terrain water/slope semantics are not contained in the compiled visual meshes:
# unverified building footprints fail closed rather than fabricate dry land.
const ROOT := "res://chunks/"
const Projection = preload("res://scripts/world_projection.gd")
const Surface = preload("res://scripts/r2_surface.gd")
var records: Dictionary = {}
var boxes: Array[Dictionary] = []
var region_id := ""
var source_run_id := -1
var terrain: RefCounted

func initialize() -> bool:
    for name in ["source_integrity.json", "merged_terrain.json", "index.json", "r2_objects.json"]:
        if not FileAccess.file_exists(ROOT + name):
            return false
    var integrity: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source_integrity.json"))
    var region: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "merged_terrain.json"))
    var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "index.json"))
    var population: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "r2_objects.json"))
    if not integrity is Dictionary or not region is Dictionary or not index is Dictionary or not population is Dictionary:
        return false
    if FileAccess.get_sha256(ROOT + "r2_objects.json") != str(integrity.get("objects_sha256", "")):
        return false
    if int(integrity.get("source_run_id", -1)) != int(region.get("source_run_id", -2)):
        return false
    if str(region.get("schema", "")) != "tamu.region.terrain.v1" or int(region.get("source_chunks", 0)) != 156:
        return false
    if not population.get("objects", null) is Array or population["objects"].size() != 832:
        return false
    if not index.get("available", null) is Array or index["available"].size() != 156:
        return false
    var next_records: Dictionary = {}
    var next_boxes: Array[Dictionary] = []
    var observed: Dictionary = {}
    for raw in population["objects"]:
        if not raw is Dictionary:
            return false
        var id := str(raw.get("id", ""))
        var kind := str(raw.get("kind", ""))
        if not id.begins_with("worldobj:v1:") or next_records.has(id):
            return false
        for key in ["x", "y", "radius", "cx", "cy", "sx", "sy"]:
            if not raw.has(key):
                return false
        var x := float(raw["x"])
        var y := float(raw["y"])
        var radius := float(raw["radius"])
        if not is_finite(x) or not is_finite(y) or not is_finite(radius) or radius <= 0.0 or radius > 256.0:
            return false
        if floori(x / 256.0) != int(raw["cx"]) or floori(y / 256.0) != int(raw["cy"]):
            return false
        var source_screen_x := float(raw["sx"])
        if not is_finite(source_screen_x) or absf(source_screen_x - Projection.to_screen(Vector2(x,y)).x) > 0.025:
            return false
        var stem := "c_%d_%d" % [int(raw["cx"]), int(raw["cy"])]
        if not index["available"].has(stem):
            return false
        next_records[id] = {"id": id, "kind": kind, "x": x, "y": y, "radius": radius, "stem": stem}
        if kind == "tree" or kind == "rock":
            next_boxes.append({"id": id, "x": x-radius, "y": y-radius,
                "w": radius*2.0, "h": radius*2.0})
        observed[stem] = true
    if next_records.size() != 832 or observed.is_empty():
        return false
    terrain = Surface.new()
    if not terrain.initialize():
        return false
    records = next_records
    boxes = next_boxes
    region_id = str(region.get("region_id", ""))
    source_run_id = int(region["source_run_id"])
    return not region_id.is_empty()

func matches_object(item: Dictionary) -> bool:
    var id := str(item.get("id", ""))
    if not records.has(id):
        return false
    var original: Dictionary = records[id]
    if str(item.get("kind", "")) != original["kind"]:
        return false
    var location: Variant = item.get("position", null)
    return location is Vector2 and location.distance_squared_to(Vector2(original["x"], original["y"])) < 0.000001 and absf(float(item.get("radius", -1)) - float(original["radius"])) < 0.000001

func obstacles(x1: float, y1: float, x2: float, y2: float) -> Array:
    if not is_finite(x1) or not is_finite(y1) or not is_finite(x2) or not is_finite(y2):
        return [{"x": 0, "y": 0, "w": INF, "h": INF}]
    var found: Array = []
    for item in boxes:
        if item["x"] < x2 and item["x"]+item["w"] > x1 and item["y"] < y2 and item["y"]+item["h"] > y1:
            found.append(item)
    return found

func surface(x: float, y: float) -> Dictionary:
    if terrain == null:
        return {"walkable": false, "feature": "unverified_terrain"}
    return terrain.sample(x,y)
