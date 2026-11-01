extends RefCounted
# Native translation of canonical LÖVE Generator v1 Field, R2 valley and
# TopographySurface sampling. No intent-only visual polygon is treated as a
# verified ford/bridge; full authored source identity is checked at bootstrap.
const SEED := 20261018
const PRIME := 2147483647
const MAP := "res://data/worldbuild/fisilti_ormani.r2.v1.json"
const OVERWORLD := "res://data/worldbuild/osman_overworld.v2.json"
const MAX_BUILD_GRADE := 0.12
const MAX_BUILD_DELTA := 0.8
var features: Array[Dictionary] = []
var ready := false

static func _lattice(ix: int, iy: int, salt: int) -> float:
    var h: int = posmod(SEED * 97 + posmod(ix, PRIME) * 16807
        + posmod(iy, PRIME) * 48271 + salt * 1013, PRIME)
    h = posmod(h * 48271 + 1, PRIME)
    h = posmod(h * 69621 + 1, PRIME)
    return float(h) / float(PRIME)

static func _noise(x: float, y: float, scale: float, salt: int) -> float:
    var px := x / scale
    var py := y / scale
    var ix := floori(px)
    var iy := floori(py)
    var fx := px - float(ix)
    var fy := py - float(iy)
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)
    var a := lerpf(_lattice(ix, iy, salt), _lattice(ix + 1, iy, salt), fx)
    var b := lerpf(_lattice(ix, iy + 1, salt), _lattice(ix + 1, iy + 1, salt), fx)
    return lerpf(a, b, fy)

static func _elevation(x: float, y: float) -> float:
    return 0.52 * _noise(x, y, 720.0, 11) + 0.32 * _noise(x, y, 270.0, 12) + 0.16 * _noise(x, y, 100.0, 13)

static func _base_water(x: float, y: float) -> float:
    return 0.29 - _elevation(x, y) + 0.08 * (_noise(x, y, 180.0, 31) - 0.5)

func initialize() -> bool:
    if not FileAccess.file_exists(MAP) or not FileAccess.file_exists(OVERWORLD):
        return false
    var map: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP))
    var world: Variant = JSON.parse_string(FileAccess.get_file_as_string(OVERWORLD))
    if not map is Dictionary or not world is Dictionary:
        return false
    if map.get("format") != "osman-worldbuild-v1" or map.get("schema_version") != 1:
        return false
    if world.get("format") != "osman-worldmap-v2" or world.get("schema_version") != 2:
        return false
    if int(map.get("seed", -1)) != SEED or int(world.get("seed", -1)) != SEED:
        return false
    if map.get("coordinate_space") != "world" or map.get("projection") != "iso-45":
        return false
    if not map.get("features", null) is Array or not world.get("authored_maps", null) is Array:
        return false
    if world["authored_maps"].size() != 1 or world["authored_maps"][0].get("id") != map.get("map_id"):
        return false
    var output: Array[Dictionary] = []
    var ids := {}
    for raw in map["features"]:
        if not raw is Dictionary or raw.get("intent_only") != true:
            return false
        var id := str(raw.get("id", ""))
        var kind := str(raw.get("kind", ""))
        var width := float(raw.get("width", -1.0))
        var coords: Variant = raw.get("points", null)
        if ids.has(id) or not kind in ["water", "path"] or width <= 0 or width > 64 or not coords is Array:
            return false
        if coords.size() < 2 or coords.size() > 96:
            return false
        var points := PackedVector2Array()
        for value in coords:
            if not value is Array or value.size() != 2:
                return false
            var pos := Vector2(float(value[0]), float(value[1]))
            if not is_finite(pos.x) or not is_finite(pos.y):
                return false
            if not points.is_empty() and pos.distance_squared_to(points[-1]) <= 0.00000000000001:
                return false
            points.append(pos)
        output.append({"id": id, "kind": kind, "width": width, "points": points})
        ids[id] = true
    if not ids.has("feature:fisilti-dere-izi"):
        return false
    var river: Dictionary = output.filter(func(v): return v["id"] == "feature:fisilti-dere-izi")[0]
    var river_pts: PackedVector2Array = river["points"]
    if float(river["width"]) != 22.0 or river_pts.size() != 4 or river_pts[2].distance_to(Vector2(704, 128)) > 0.000001:
        return false
    features = output
    ready = true
    return true

func _distance(x: float, y: float, kind: String) -> float:
    var best := INF
    var world := Vector2(x, y)
    for feature in features:
        if feature["kind"] != kind:
            continue
        var points: PackedVector2Array = feature["points"]
        for i in range(points.size()-1):
            var a := points[i]
            var b := points[i + 1]
            var v := b - a
            var t := clampf((world-a).dot(v)/v.length_squared(), 0.0, 1.0)
            best = minf(best, world.distance_to(a + v * t))
    return best

func water_signed(x: float, y: float) -> float:
    return maxf(_base_water(x, y), 11.0 - _distance(x, y, "water"))

func height_at(x: float, y: float) -> float:
    var distance := _distance(x, y, "water")
    var depression := 0.0
    if distance < 47.0:
        var t := distance/47.0
        depression = -2.0 * pow(1.0 - t*t, 2.0)
    return 24.0 * _elevation(x, y) + depression

func sample(x: float, y: float) -> Dictionary:
    if not ready or not is_finite(x) or not is_finite(y):
        return {"walkable": false, "feature": "unverified_terrain"}
    var height := height_at(x, y)
    var gx := (height_at(x+1.0,y) - height_at(x-1.0,y)) * 0.5
    var gy := (height_at(x,y+1.0) - height_at(x,y-1.0)) * 0.5
    var grade := sqrt(gx*gx+gy*gy)
    var water := water_signed(x,y) > 0.0
    var path := _distance(x, y, "path") < 8.0
    return {"walkable": not water and grade <= MAX_BUILD_GRADE,
        "feature": "water" if water else ("path" if path else "grass"),
        "height": height, "grade": grade, "water_body": water,
        "topography_class": "gentle" if grade <= 0.10 else ("moderate" if grade <= 0.45 else "cliff")}
