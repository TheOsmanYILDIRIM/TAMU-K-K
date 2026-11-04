extends RefCounted
const Building = preload("res://scripts/domain_building.gd")

static func _whole(v: Variant) -> bool:
    if v is int:
        return true
    return v is float and is_finite(v) and v == floorf(v) and absf(v) <= 1000000000000.0

static func prepare(catalog: RefCounted, state: Dictionary) -> Dictionary:
    var gate: Dictionary = catalog.validate_snapshot_content(state)
    if not bool(gate.get("ok", false)):
        return gate
    if state.get("domain_version", null) != 1:
        return {"ok": false, "status": "unsupported_domain_version"}
    var journal: Variant = state.get("journal", null)
    if not journal is Dictionary or journal.get("version", null) != 1:
        return {"ok": false, "status": "invalid_journal"}
    if not _whole(journal.get("world_revision", null)) or not _whole(journal.get("journal_sequence", null)):
        return {"ok": false, "status": "invalid_journal"}
    var commands: Variant = journal.get("applied_commands", null)
    if not commands is Dictionary or commands.size() > 8192 or commands.size() > int(journal["journal_sequence"]):
        return {"ok": false, "status": "invalid_journal"}
    if int(journal["world_revision"]) < 0 or int(journal["journal_sequence"]) < 0:
        return {"ok": false, "status": "invalid_journal"}
    for id in commands:
        if not id is String or id.is_empty() or id.length() > 128 or commands[id] != true:
            return {"ok": false, "status": "invalid_journal"}
    var inv: Dictionary = state["inventory"]
    if inv.get("version", null) != 1 or inv.get("capacity", null) != 12 or inv.get("catalog_version", null) != catalog.version:
        return {"ok": false, "status": "invalid_inventory_header"}
    var slots: Array = []
    slots.resize(12)
    slots.fill(null)
    if inv["slots"].size() > 12:
        return {"ok": false, "status": "invalid_slots"}
    for row in inv["slots"]:
        if not row is Dictionary or not _whole(row.get("slot", null)) or not _whole(row.get("count", null)):
            return {"ok": false, "status": "invalid_slot"}
        var index := int(row["slot"]) - 1
        if index < 0 or index >= 12 or slots[index] != null:
            return {"ok": false, "status": "duplicate_slot"}
        var def_id := str(row.get("def_id", ""))
        if catalog.max_stack(def_id) <= 0 or int(row["count"]) < 1 or int(row["count"]) > catalog.max_stack(def_id):
            return {"ok": false, "status": "invalid_slot"}
        slots[index] = {"def_id": def_id, "count": int(row["count"])}
    var building: Dictionary = state["building"]
    if building.get("version", null) != 1 or not _whole(building.get("world_revision", null)):
        return {"ok": false, "status": "invalid_building"}
    var building_rev := int(building["world_revision"])
    if building_rev < 0 or building_rev > int(journal["world_revision"]):
        return {"ok": false, "status": "invalid_building"}
    var world_id := str(building.get("world_id", ""))
    if not world_id.is_empty() and not Building.valid_uuid4(world_id):
        return {"ok": false, "status": "invalid_world_id"}
    var placed: Dictionary = {}
    var records: Dictionary = building["placed"]
    if records.size() > 4096 or not records.is_empty() and world_id.is_empty():
        return {"ok": false, "status": "invalid_building"}
    var builder = Building.new(catalog, null)
    for id in records:
        var row: Variant = records[id]
        if not id is String or not Building.valid_uuid4(str(id)) or not row is Dictionary:
            return {"ok": false, "status": "invalid_building"}
        if str(row.get("id", "")) != str(id) or not _whole(row.get("rotation", null)) or not _whole(row.get("revision", null)):
            return {"ok": false, "status": "invalid_building"}
        if int(row["revision"]) < 1 or int(row["revision"]) > building_rev:
            return {"ok": false, "status": "invalid_building"}
        var x := float(row.get("x", NAN))
        var y := float(row.get("y", NAN))
        var def: Dictionary = catalog.item(str(row.get("def_id", "")))
        var placeable: Dictionary = def.get("components", {}).get("core:placeable", {})
        if not is_finite(x) or not is_finite(y) or placeable.is_empty() or str(def.get("kind", "")) != "structure":
            return {"ok": false, "status": "invalid_building"}
        if int(row["rotation"]) < 0 or int(row["rotation"]) >= int(placeable.get("rotation_steps", 0)):
            return {"ok": false, "status": "invalid_building"}
        var built: Dictionary = row.duplicate(true)
        built["box"] = builder._box(def, Vector2(x, y), int(row["rotation"]))
        placed[id] = built
    var depleted: Variant = state.get("depleted", null)
    var inventory_applied: Variant = state.get("inventory_applied", null)
    if not depleted is Dictionary or not inventory_applied is Dictionary:
        return {"ok": false, "status": "invalid_ledgers"}
    for k in depleted:
        if not k is String or depleted[k] != true:
            return {"ok": false, "status": "invalid_ledgers"}
    for k in inventory_applied:
        if not k is String or inventory_applied[k] != true:
            return {"ok": false, "status": "invalid_ledgers"}
    for field in ["harvest_commands", "craft_commands", "building_commands"]:
        if not state.get(field, null) is Dictionary:
            return {"ok": false, "status": "invalid_commands"}
    # Ground loot reuses the existing v1 harvest-command journal, so reject
    # tampered/duplicate pending drops before publishing a restored inventory.
    var seen_loot: Dictionary = {}
    for command_id in state["harvest_commands"]:
        var command: Variant = state["harvest_commands"][command_id]
        if not command is Dictionary or not command.has("ground_drops"):
            continue
        if str(command.get("status", "")) != "complete":
            return {"ok": false, "status": "invalid_ground_loot"}
        var drops: Variant = command["ground_drops"]
        if not drops is Array or drops.is_empty() or drops.size() > 16:
            return {"ok": false, "status": "invalid_ground_loot"}
        for row in drops:
            if not row is Dictionary or row.get("picked", null) is not bool:
                return {"ok": false, "status": "invalid_ground_loot"}
            var loot_id := str(row.get("id", ""))
            var def_id := str(row.get("def_id", ""))
            if loot_id.is_empty() or not loot_id.begins_with(str(command_id) + ":") or seen_loot.has(loot_id):
                return {"ok": false, "status": "invalid_ground_loot"}
            if str(row.get("source_id", "")).is_empty() or not _whole(row.get("count", null)):
                return {"ok": false, "status": "invalid_ground_loot"}
            var quantity := int(row["count"])
            if quantity < 1 or quantity > catalog.max_stack(def_id):
                return {"ok": false, "status": "invalid_ground_loot"}
            if not (row.get("x", null) is float or row.get("x", null) is int) or not (row.get("y", null) is float or row.get("y", null) is int):
                return {"ok": false, "status": "invalid_ground_loot"}
            var x := float(row["x"])
            var y := float(row["y"])
            if not is_finite(x) or not is_finite(y) or absf(x) > 1000000.0 or absf(y) > 1000000.0:
                return {"ok": false, "status": "invalid_ground_loot"}
            seen_loot[loot_id] = true
    return {"ok": true, "status": "prepared", "slots": slots, "placed": placed,
        "world_id": world_id, "building_revision": building_rev,
        "depleted": depleted.duplicate(true), "inventory_applied": inventory_applied.duplicate(true),
        "harvest_commands": state["harvest_commands"].duplicate(true),
        "craft_commands": state["craft_commands"].duplicate(true),
        "building_commands": state["building_commands"].duplicate(true),
        "world_revision": int(journal["world_revision"]),
        "journal_sequence": int(journal["journal_sequence"]),
        "applied_commands": commands.duplicate(true)}
