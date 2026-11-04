extends RefCounted
# LÖVE objects/harvesting.lua: stable worldobj IDs, timed resource depletion,
# atomic multi-drop inventory staging, exactly-once session events.
const RANGE := 38.0
var catalog: RefCounted
var inventory: RefCounted
var depleted: Dictionary = {}
var commands: Dictionary = {}
var active: Dictionary = {}
# Opt-in world drops; legacy harvest contracts retain instant inventory credit.
var ground_mode := false

func _init(catalog_source: RefCounted, inventory_source: RefCounted) -> void:
    catalog = catalog_source
    inventory = inventory_source

func _within(item: Dictionary, position: Vector2) -> bool:
    var obj_pos: Variant = item.get("position", null)
    if not obj_pos is Vector2 or not is_finite(position.x) or not is_finite(position.y):
        return false
    var radius := maxf(float(item.get("radius", 0.0)), 0.0)
    return position.distance_squared_to(obj_pos) <= pow(RANGE + radius, 2.0)

func begin(command_id: String, item: Dictionary, player_position: Vector2) -> Dictionary:
    if command_id.is_empty() or command_id.length() > 128:
        return {"ok": false, "status": "invalid_command"}
    if commands.has(command_id):
        return commands[command_id]
    var id := str(item.get("id", ""))
    var kind := str(item.get("kind", ""))
    var def: Dictionary = catalog.harvest(kind)
    var response: Dictionary
    if id.is_empty() or def.is_empty():
        response = {"ok": false, "status": "missing_object"}
    elif depleted.has(id) or bool(item.get("collected", false)):
        response = {"ok": false, "status": "depleted"}
    elif not _within(item, player_position):
        response = {"ok": false, "status": "out_of_range"}
    elif not active.is_empty():
        response = {"ok": false, "status": "busy"}
    else:
        active = {"id": id, "item": item, "command": command_id, "elapsed": 0.0}
        response = {"ok": true, "status": "started"}
    commands[command_id] = response.duplicate(true)
    return response

func progress() -> float:
    if active.is_empty():
        return 0.0
    var def: Dictionary = catalog.harvest(str(active["item"]["kind"]))
    return minf(1.0, float(active["elapsed"]) * 60.0 / float(def["duration_ticks"]))

func update(dt: float, player_position: Vector2) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    if not is_finite(dt) or dt < 0.0 or active.is_empty():
        return events
    var item: Dictionary = active["item"]
    var id := str(active["id"])
    var command := str(active["command"])
    var response: Dictionary = {}
    if depleted.has(id) or not _within(item, player_position):
        response = {"ok": false, "status": "interrupted"}
    else:
        active["elapsed"] = float(active["elapsed"]) + minf(dt, 0.1)
        var source: Dictionary = catalog.harvest(str(item["kind"]))
        if float(active["elapsed"]) * 60.0 + 0.00000006 >= float(source["duration_ticks"]):
            if ground_mode:
                # Keep pending drops in the already-versioned harvest command
                # ledger; no untracked world sprites or silent inventory credit.
                var pending: Array = []
                for n in range(source["drops"].size()):
                    var drop: Dictionary = source["drops"][n]
                    var def_id := str(drop.get("def_id", ""))
                    var quantity := int(drop.get("count", 0))
                    if catalog.max_stack(def_id) <= 0 or quantity <= 0 or quantity > catalog.max_stack(def_id):
                        response = {"ok": false, "status": "invalid_drop"}
                        break
                    pending.append({"id": "%s:%d" % [command, n + 1],
                        "def_id": def_id, "count": quantity,
                        "x": float(item["position"].x), "y": float(item["position"].y),
                        "picked": false})
                if response.is_empty():
                    depleted[id] = true
                    response = {"ok": true, "status": "complete",
                        "ground_drops": pending}
                    for drop in pending:
                        events.append({"type": "HarvestCompleted", "object_id": id,
                            "command_id": command, "transaction_id": str(drop["id"]),
                            "item_id": str(drop["def_id"]), "amount": int(drop["count"]),
                            "ground_drop": true})
            else:
                var staged: Array = inventory.preview()
                for n in range(source["drops"].size()):
                    var drop: Dictionary = source["drops"][n]
                    var tx := "%s:%d" % [command, n + 1]
                    if inventory.applied.has(tx):
                        response = {"ok": false, "status": "duplicate_transaction"}
                        break
                    if not inventory.preview_add(staged, str(drop["def_id"]), int(drop["count"])):
                        response = {"ok": false, "status": "inventory_full"}
                        break
                if response.is_empty():
                    if not inventory.commit_preview(staged):
                        response = {"ok": false, "status": "invalid_preview"}
                    else:
                        depleted[id] = true
                        for n in range(source["drops"].size()):
                            var drop: Dictionary = source["drops"][n]
                            var tx := "%s:%d" % [command, n + 1]
                            inventory.applied[tx] = true
                            events.append({"type": "HarvestCompleted", "object_id": id,
                                "command_id": command, "transaction_id": tx,
                                "item_id": str(drop["def_id"]), "amount": int(drop["count"])})
                        response = {"ok": true, "status": "complete"}
    if not response.is_empty():
        commands[command] = response
        active = {}
    return events
