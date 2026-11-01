extends RefCounted
# Canonical LÖVE crafting.lua stage/begin/update/execute semantics.
var catalog: RefCounted
var inventory: RefCounted
var commands: Dictionary = {}
var active: Dictionary = {}

func _init(catalog_source: RefCounted, inventory_source: RefCounted) -> void:
    catalog = catalog_source
    inventory = inventory_source

static func _valid_command(id: String) -> bool:
    return not id.is_empty() and id.length() <= 128

static func _stations_allowed(recipe: Dictionary, tags: Array) -> bool:
    var present := {}
    for tag in tags:
        if not tag is String:
            return false
        present[tag] = true
    for tag in recipe.get("station_tags", []):
        if not present.has(tag):
            return false
    return true

func _stage(recipe: Dictionary, station_tags: Array) -> Dictionary:
    if not _stations_allowed(recipe, station_tags):
        return {"ok": false, "status": "station_required"}
    var candidate: Array = inventory.preview()
    for stack in recipe.get("inputs", []):
        if not inventory.preview_remove(candidate, str(stack["def_id"]), int(stack["count"])):
            return {"ok": false, "status": "insufficient_materials"}
    for stack in recipe.get("outputs", []):
        if not inventory.preview_add(candidate, str(stack["def_id"]), int(stack["count"])):
            return {"ok": false, "status": "inventory_full"}
    if not inventory.validate_preview(candidate):
        return {"ok": false, "status": "invalid_preview"}
    return {"ok": true, "candidate": candidate}

func _perform(recipe: Dictionary, station_tags: Array) -> Dictionary:
    var staged := _stage(recipe, station_tags)
    if not bool(staged.get("ok", false)):
        return staged
    if not inventory.commit_preview(staged["candidate"]):
        return {"ok": false, "status": "invalid_preview"}
    return {"ok": true, "status": "crafted", "recipe_id": str(recipe["id"]),
        "duration_ticks": int(recipe["duration_ticks"])}

func execute(command_id: String, recipe_id: String, station_tags: Array = []) -> Dictionary:
    if not _valid_command(command_id):
        return {"ok": false, "status": "invalid_command"}
    if commands.has(command_id):
        return commands[command_id]
    var recipe: Dictionary = catalog.recipe(recipe_id)
    if recipe.is_empty():
        return {"ok": false, "status": "unsupported_recipe"}
    var result := _perform(recipe, station_tags)
    commands[command_id] = result.duplicate(true)
    return result

func begin(command_id: String, recipe_id: String, station_tags: Array = []) -> Dictionary:
    if not _valid_command(command_id):
        return {"ok": false, "status": "invalid_command"}
    if commands.has(command_id):
        return commands[command_id]
    var recipe: Dictionary = catalog.recipe(recipe_id)
    if recipe.is_empty():
        return {"ok": false, "status": "unsupported_recipe"}
    var result: Dictionary
    if not active.is_empty():
        result = {"ok": false, "status": "busy"}
    else:
        var staged := _stage(recipe, station_tags)
        if not bool(staged.get("ok", false)):
            result = {"ok": false, "status": str(staged["status"])}
        else:
            active = {"command": command_id, "recipe": recipe_id, "ticks": 0.0}
            result = {"ok": true, "status": "started", "recipe_id": recipe_id,
                "duration_ticks": int(recipe["duration_ticks"])}
    commands[command_id] = result.duplicate(true)
    return result

func progress() -> float:
    if active.is_empty():
        return 0.0
    var recipe: Dictionary = catalog.recipe(str(active["recipe"]))
    return minf(1.0, float(active["ticks"]) / float(recipe["duration_ticks"]))

func update(dt: float, tags: Array = []) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    if not is_finite(dt) or dt < 0.0 or active.is_empty():
        return events
    active["ticks"] = float(active["ticks"]) + minf(dt, 0.1) * 60.0
    var id := str(active["recipe"])
    var recipe: Dictionary = catalog.recipe(id)
    if float(active["ticks"]) + 0.00000001 < float(recipe["duration_ticks"]):
        return events
    var command := str(active["command"])
    var outcome := _perform(recipe, tags)
    commands[command] = outcome
    active = {}
    if bool(outcome.get("ok", false)):
        events.append({"type": "CraftCompleted", "recipe_id": id,
            "transaction_id": command, "command_id": command})
    return events
