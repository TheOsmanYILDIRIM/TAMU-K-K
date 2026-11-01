extends RefCounted
# TAMU Stage 3 in-memory domain bridge. Canonical LÖVE definitions:
# tree 90 ticks -> 3 logs; rock 120 ticks -> 2 stone; 12 inventory slots.
# No Stage6 save import, fabricated region, structure placement, or Rigby change.
const CAPACITY := 12
const HARVEST_RANGE := 38.0
const MAX_STACK := {"core:wood_log": 99, "core:stone": 99, "core:wood_plank": 99, "core:workbench": 1}
const DROPS := {
    "tree": {"def_id": "core:wood_log", "count": 3, "duration_ticks": 90},
    "rock": {"def_id": "core:stone", "count": 2, "duration_ticks": 120}
}
const RECIPES := {
    "core:planks_from_log": {"inputs": {"core:wood_log": 1}, "outputs": {"core:wood_plank": 4}, "duration_ticks": 30},
    "core:bench_from_planks": {"inputs": {"core:wood_plank": 4}, "outputs": {"core:workbench": 1}, "duration_ticks": 60}
}
var slots: Array = []
var depleted: Dictionary = {}
var harvest_commands: Dictionary = {}
var craft_commands: Dictionary = {}
var active_harvest: Dictionary = {}
var active_craft: Dictionary = {}
var event_count := 0

func _init() -> void:
    slots.resize(CAPACITY)
    slots.fill(null)

func count_item(item_id: String) -> int:
    var total := 0
    for item in slots:
        if item is Dictionary and str(item.get("def_id", "")) == item_id:
            total += int(item["count"])
    return total

static func _count_in(records: Array, item_id: String) -> int:
    var result := 0
    for stack in records:
        if stack is Dictionary and str(stack["def_id"]) == item_id:
            result += int(stack["count"])
    return result

static func _try_add(records: Array, item_id: String, count: int) -> bool:
    if not MAX_STACK.has(item_id) or count <= 0:
        return false
    var remaining := count
    var maximum: int = MAX_STACK[item_id]
    for i in range(records.size()):
        var stack: Variant = records[i]
        if stack is Dictionary and str(stack["def_id"]) == item_id:
            var amount := mini(remaining, maximum - int(stack["count"]))
            if amount > 0:
                stack["count"] = int(stack["count"]) + amount
                remaining -= amount
            if remaining == 0:
                return true
    for i in range(records.size()):
        if records[i] == null:
            var amount := mini(remaining, maximum)
            records[i] = {"def_id": item_id, "count": amount}
            remaining -= amount
            if remaining == 0:
                return true
    return false

static func _try_remove(records: Array, item_id: String, count: int) -> bool:
    if not MAX_STACK.has(item_id) or count <= 0 or _count_in(records, item_id) < count:
        return false
    var remaining := count
    for i in range(records.size() - 1, -1, -1):
        var stack: Variant = records[i]
        if stack is Dictionary and str(stack["def_id"]) == item_id:
            var amount := mini(remaining, int(stack["count"]))
            stack["count"] = int(stack["count"]) - amount
            remaining -= amount
            if int(stack["count"]) == 0:
                records[i] = null
            if remaining == 0:
                return true
    return false

func _within(item: Dictionary, player_pos: Vector2) -> bool:
    var radius := maxf(0.0, float(item.get("radius", 0.0)))
    return player_pos.distance_squared_to(item["position"]) <= pow(HARVEST_RANGE + radius, 2.0)

func begin_harvest(item: Dictionary, player_pos: Vector2, command_id: String) -> Dictionary:
    if command_id.is_empty() or command_id.length() > 128:
        return {"ok": false, "status": "invalid_command"}
    if harvest_commands.has(command_id):
        return harvest_commands[command_id]
    var id := str(item.get("id", ""))
    var kind := str(item.get("kind", ""))
    var result: Dictionary = {}
    if id.is_empty() or not DROPS.has(kind):
        result = {"ok": false, "status": "unsupported_object"}
    elif depleted.has(id) or bool(item.get("collected", false)):
        result = {"ok": false, "status": "depleted"}
    elif not _within(item, player_pos):
        result = {"ok": false, "status": "out_of_range"}
    elif not active_harvest.is_empty():
        result = {"ok": false, "status": "busy"}
    else:
        active_harvest = {"id": id, "item": item, "command": command_id, "ticks": 0.0}
        result = {"ok": true, "status": "started"}
    harvest_commands[command_id] = result.duplicate(true)
    return result

func begin_craft(command_id: String, recipe_id: String) -> Dictionary:
    if command_id.is_empty() or command_id.length() > 128:
        return {"ok": false, "status": "invalid_command"}
    if craft_commands.has(command_id):
        return craft_commands[command_id]
    var result: Dictionary = {}
    if not RECIPES.has(recipe_id):
        result = {"ok": false, "status": "unsupported_recipe"}
    elif not active_craft.is_empty():
        result = {"ok": false, "status": "busy"}
    else:
        var recipe: Dictionary = RECIPES[recipe_id]
        var enough := true
        for item_id in recipe["inputs"]:
            if count_item(str(item_id)) < int(recipe["inputs"][item_id]):
                enough = false
        if not enough:
            result = {"ok": false, "status": "insufficient_materials"}
        else:
            active_craft = {"recipe": recipe_id, "command": command_id, "ticks": 0.0}
            result = {"ok": true, "status": "started"}
    craft_commands[command_id] = result.duplicate(true)
    return result

func tick(dt: float, player_pos: Vector2) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    if not is_finite(dt) or dt < 0.0:
        return events
    var delta_ticks := minf(dt, 0.1) * 60.0
    if not active_harvest.is_empty():
        var active := active_harvest
        var item: Dictionary = active["item"]
        var id: String = active["id"]
        var command: String = active["command"]
        var outcome: Dictionary = {}
        if depleted.has(id) or not _within(item, player_pos):
            outcome = {"ok": false, "status": "interrupted"}
        else:
            active["ticks"] = float(active["ticks"]) + delta_ticks
            var drop: Dictionary = DROPS[str(item["kind"])]
            if float(active["ticks"]) + 0.000001 >= float(drop["duration_ticks"]):
                var candidate := slots.duplicate(true)
                if not _try_add(candidate, str(drop["def_id"]), int(drop["count"])):
                    outcome = {"ok": false, "status": "inventory_full"}
                else:
                    slots = candidate
                    depleted[id] = true
                    event_count += 1
                    outcome = {"ok": true, "status": "complete"}
                    events.append({"type": "HarvestCompleted", "object_id": id,
                        "item_id": str(drop["def_id"]), "amount": int(drop["count"]),
                        "transaction_id": command + ":1"})
        if not outcome.is_empty():
            harvest_commands[command] = outcome
            active_harvest = {}
    if not active_craft.is_empty():
        var crafting := active_craft
        crafting["ticks"] = float(crafting["ticks"]) + delta_ticks
        var recipe_id: String = crafting["recipe"]
        var recipe: Dictionary = RECIPES[recipe_id]
        if float(crafting["ticks"]) + 0.000001 >= float(recipe["duration_ticks"]):
            var next_slots := slots.duplicate(true)
            var ok := true
            for item_id in recipe["inputs"]:
                if not _try_remove(next_slots, str(item_id), int(recipe["inputs"][item_id])):
                    ok = false
                    break
            if ok:
                for item_id in recipe["outputs"]:
                    if not _try_add(next_slots, str(item_id), int(recipe["outputs"][item_id])):
                        ok = false
                        break
            var status := "crafted" if ok else "insufficient_materials_or_full"
            if ok:
                slots = next_slots
                event_count += 1
                events.append({"type": "CraftCompleted", "recipe_id": recipe_id,
                    "transaction_id": crafting["command"]})
            craft_commands[str(crafting["command"])] = {"ok": ok, "status": status}
            active_craft = {}
    return events

func verify_contract() -> bool:
    var proof = get_script().new()
    var tree := {"id": "test:tree", "kind": "tree", "radius": 11.0, "position": Vector2(50.0, 0.0)}
    var rock := {"id": "test:rock", "kind": "rock", "radius": 12.0, "position": Vector2(50.0, 0.0)}
    if proof.begin_harvest(tree, Vector2.ZERO, "h1").get("status") != "out_of_range":
        return false
    if proof.begin_harvest(tree, Vector2(50, 0), "h2").get("status") != "started":
        return false
    for i in range(15):
        proof.tick(0.1, Vector2(50, 0))
    if proof.count_item("core:wood_log") != 3 or not proof.depleted.has("test:tree"):
        return false
    if proof.begin_harvest(tree, Vector2(50, 0), "h2").get("status") != "complete":
        return false
    if proof.begin_craft("c1", "core:planks_from_log").get("status") != "started":
        return false
    for i in range(5):
        proof.tick(0.1, Vector2(50, 0))
    if proof.count_item("core:wood_plank") != 4 or proof.count_item("core:wood_log") != 2:
        return false
    proof.begin_craft("c2", "core:bench_from_planks")
    for i in range(10):
        proof.tick(0.1, Vector2(50, 0))
    if proof.count_item("core:workbench") != 1 or proof.count_item("core:wood_plank") != 0:
        return false
    if proof.begin_craft("c2", "core:bench_from_planks").get("status") != "crafted":
        return false
    if proof.begin_harvest(rock, Vector2(50, 0), "h3").get("status") != "started":
        return false
    proof.tick(0.1, Vector2(500, 0))
    if proof.harvest_commands["h3"]["status"] != "interrupted" or proof.depleted.has("test:rock"):
        return false
    var full = get_script().new()
    for i in range(CAPACITY):
        full.slots[i] = {"def_id": "core:wood_log", "count": 99}
    full.begin_harvest(rock, Vector2(50, 0), "full1")
    for i in range(20):
        full.tick(0.1, Vector2(50, 0))
    if full.harvest_commands["full1"]["status"] != "inventory_full" or full.depleted.has("test:rock"):
        return false
    print("TAMU_GAMEPLAY_DOMAIN_OK inventory_slots=12 harvest_ticks=90/120 craft_ticks=30/60")
    return true
