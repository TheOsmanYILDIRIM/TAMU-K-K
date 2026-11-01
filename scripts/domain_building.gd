extends RefCounted
# LÖVE systems/building.lua domain port. No fabricated terrain/query fallback:
# explicit authoritative surface+obstacle ports are mandatory before placement.
var catalog: RefCounted
var inventory: RefCounted
var world_id := ""
var placed: Dictionary = {}
var commands: Dictionary = {}
var revision := 0
var terrain_sample: Callable
var solid_query: Callable

func _init(source: RefCounted, stock: RefCounted) -> void:
    catalog = source
    inventory = stock

static func valid_uuid4(id: String) -> bool:
    if id.length() != 36 or id[8] != "-" or id[13] != "-" or id[18] != "-" or id[23] != "-":
        return false
    if id[14] != "4" or not "89abAB".contains(id[19]):
        return false
    for i in range(id.length()):
        if i in [8, 13, 18, 23]:
            continue
        if not "0123456789abcdefABCDEF".contains(id[i]):
            return false
    return true

func configure(world_uuid: String, terrain: Callable, obstacles: Callable) -> bool:
    if not valid_uuid4(world_uuid) or not terrain.is_valid() or not obstacles.is_valid():
        return false
    if not world_id.is_empty() and world_id != world_uuid:
        return false
    world_id = world_uuid
    terrain_sample = terrain
    solid_query = obstacles
    return true

static func overlap(a: Rect2, b: Rect2) -> bool:
    return a.position.x < b.end.x and b.position.x < a.end.x and a.position.y < b.end.y and b.position.y < a.end.y

func obstacles(box: Rect2) -> Array:
    if not solid_query.is_valid():
        return []
    var list: Variant = solid_query.call(box.position.x, box.position.y, box.end.x, box.end.y)
    if not list is Array:
        return []
    var result: Array = list.duplicate(true)
    for id in placed:
        var p: Rect2 = placed[id]["box"]
        if p.intersects(box, true):
            result.append({"x": p.position.x, "y": p.position.y, "w": p.size.x,
                "h": p.size.y, "id": str(id)})
    return result

func _dry_and_stable(box: Rect2) -> bool:
    if not terrain_sample.is_valid():
        return false
    for ry in [0.01, 0.5, 0.999]:
        for rx in [0.01, 0.5, 0.999]:
            var x: float = box.position.x + box.size.x * float(rx)
            var y: float = box.position.y + box.size.y * float(ry)
            var surface: Variant = terrain_sample.call(x, y)
            if not surface is Dictionary:
                return false
            if not bool(surface.get("walkable", false)) or str(surface.get("feature", "")) == "water":
                return false
    return true

func _box(def: Dictionary, at: Vector2, rotation: int) -> Rect2:
    var placeable: Dictionary = def["components"]["core:placeable"]
    var dims: Array = placeable["footprint"]
    var w := float(dims[0]) * 32.0
    var h := float(dims[1]) * 32.0
    if int(placeable["rotation_steps"]) % 2 == 0 and rotation % 2 == 1:
        var tmp := w
        w = h
        h = tmp
    return Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h))

func preview(def_id: String, at: Vector2, rotation: int, player_at: Vector2) -> Dictionary:
    if world_id.is_empty() or not terrain_sample.is_valid() or not solid_query.is_valid():
        return {"ok": false, "status": "terrain_unavailable"}
    if not is_finite(at.x) or not is_finite(at.y) or not is_finite(player_at.x) or not is_finite(player_at.y):
        return {"ok": false, "status": "invalid_coordinates"}
    var def: Dictionary = catalog.item(def_id)
    var placeable: Dictionary = def.get("components", {}).get("core:placeable", {})
    if str(def.get("kind", "")) != "structure" or placeable.is_empty():
        return {"ok": false, "status": "not_placeable"}
    var steps := int(placeable["rotation_steps"])
    if rotation < 0 or rotation >= steps:
        return {"ok": false, "status": "invalid_rotation"}
    if at.distance_squared_to(player_at) > 96.0 * 96.0:
        return {"ok": false, "status": "out_of_range"}
    var box := _box(def, at, rotation)
    if overlap(box, Rect2(player_at - Vector2(5, 5), Vector2(10, 10))):
        return {"ok": false, "status": "player_overlap"}
    if not _dry_and_stable(box):
        return {"ok": false, "status": "invalid_surface"}
    for solid in obstacles(box):
        var other := Rect2(float(solid["x"]), float(solid["y"]),
            float(solid["w"]), float(solid["h"]))
        if overlap(box, other):
            return {"ok": false, "status": "obstructed"}
    if inventory.count_item(def_id) < 1:
        return {"ok": false, "status": "insufficient_materials"}
    return {"ok": true, "status": "valid", "box": box}

func place(command_id: String, instance_id: String, def_id: String,
        at: Vector2, rotation: int, player_at: Vector2, owner_id: String) -> Dictionary:
    if command_id.is_empty() or command_id.length() > 128:
        return {"ok": false, "status": "invalid_command"}
    if commands.has(command_id):
        return commands[command_id]
    if not valid_uuid4(instance_id) or owner_id.is_empty():
        return {"ok": false, "status": "invalid_identity"}
    var result: Dictionary
    if placed.has(instance_id):
        result = {"ok": false, "status": "instance_id_conflict"}
    else:
        var checked := preview(def_id, at, rotation, player_at)
        if not bool(checked["ok"]):
            result = {"ok": false, "status": str(checked["status"])}
        else:
            var candidate: Array = inventory.preview()
            if not inventory.preview_remove(candidate, def_id, 1):
                result = {"ok": false, "status": "insufficient_materials"}
            elif not inventory.commit_preview(candidate):
                result = {"ok": false, "status": "invalid_preview"}
            else:
                revision += 1
                placed[instance_id] = {"id": instance_id, "def_id": def_id,
                    "x": at.x, "y": at.y, "rotation": rotation, "owner_id": owner_id,
                    "command_id": command_id, "box": checked["box"], "revision": revision}
                result = {"ok": true, "status": "placed", "instance_id": instance_id,
                    "revision": revision}
    commands[command_id] = result.duplicate(true)
    return result

func station_tags_near(at: Vector2, radius: float) -> Array:
    var seen := {}
    for id in placed:
        var instance: Dictionary = placed[id]
        var box: Rect2 = instance["box"]
        var x := clampf(at.x, box.position.x, box.end.x)
        var y := clampf(at.y, box.position.y, box.end.y)
        if at.distance_squared_to(Vector2(x, y)) <= radius * radius:
            for tag in catalog.station_tags(str(instance["def_id"])):
                seen[str(tag)] = true
    var result: Array = seen.keys()
    result.sort()
    return result

func snapshot() -> Dictionary:
    var records := {}
    for id in placed:
        var v: Dictionary = placed[id]
        records[id] = {"id": id, "def_id": v["def_id"], "x": v["x"],
            "y": v["y"], "rotation": v["rotation"], "owner_id": v["owner_id"],
            "command_id": v["command_id"], "revision": v["revision"]}
    return {"version": 1, "world_id": world_id, "world_revision": revision, "placed": records}

static func test_dry(_x: float, _y: float) -> Dictionary:
    return {"walkable": true, "feature": "grass"}

static func test_obstacles(_x: float, _y: float, _xx: float, _yy: float) -> Array:
    return []
