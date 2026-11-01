extends RefCounted
const Building = preload("res://scripts/domain_building.gd")

static func prepare(catalog: RefCounted, state: Dictionary) -> Dictionary:
    var gate: Dictionary = catalog.validate_snapshot_content(state)
    if not bool(gate.get("ok", false)):
        return gate
    if state.get("domain_version", null) != 1:
        return {"ok": false, "status": "unsupported_domain_version"}
    var journal: Variant = state.get("journal", null)
    if not journal is Dictionary or journal.get("version", null) != 1:
        return {"ok": false, "status": "invalid_journal"}
    if not journal.get("world_revision", null) is int or not journal.get("journal_sequence", null) is int:
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
        if not row is Dictionary or not row.get("slot", null) is int or not row.get("count", null) is int:
            return {"ok": false, "status": "invalid_slot"}
        var index := int(row["slot"]) - 1
        if index < 0 or index >= 12 or slots[index] != null:
            return {"ok": false, "status": "duplicate_slot"}
        var def_id := str(row.get("def_id", ""))
        if catalog.max_stack(def_id) <= 0 or int(row["count"]) < 1 or int(row["count"]) > catalog.max_stack(def_id):
            return {"ok": false, "status": "invalid_slot"}
        slots[index] = {"def_id": def_id, "count": int(row["count"])}
    var building: Dictionary = state["building"]
    if building.get("version", null) != 1 or not building.get("world_revision", null) is int:
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
        if str(row.get("id", "")) != str(id) or not row.get("rotation", null) is int or not row.get("revision", null) is int:
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
    return {"ok": true, "status": "prepared", "slots": slots, "placed": placed,
        "world_id": world_id, "building_revision": building_rev,
        "depleted": depleted.duplicate(true), "inventory_applied": inventory_applied.duplicate(true),
        "harvest_commands": state["harvest_commands"].duplicate(true),
        "craft_commands": state["craft_commands"].duplicate(true),
        "building_commands": state["building_commands"].duplicate(true),
        "world_revision": int(journal["world_revision"]),
        "journal_sequence": int(journal["journal_sequence"]),
        "applied_commands": commands.duplicate(true)}
