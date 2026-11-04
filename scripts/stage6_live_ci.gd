extends SceneTree
const Session = preload("res://scripts/gameplay_session.gd")

func _initialize() -> void:
    var phase := OS.get_environment("TAMU_LIVE_PHASE")
    var ok := false
    if phase == "create":
        ok = _create()
    elif phase == "reopen":
        ok = _reopen()
    elif phase == "replay":
        ok = _replay()
    elif phase == "reject":
        ok = _reject()
    if ok:
        print("TAMU_STAGE6_LIVE_", phase.to_upper(), "_OK")
    else:
        push_error("TAMU_STAGE6_LIVE_" + phase.to_upper() + "_FAILED")
    quit(0 if ok else 58)

func _create() -> bool:
    if not _item_contract():
        return false
    if DirAccess.dir_exists_absolute("user://saves"):
        return false
    var run = Session.new()
    var first := run.save_checkpoint("live")
    print("TAMU_STAGE6_LIVE_DIAG_SAVE ", first)
    if first.get("status") != "saved":
        return false
    var credited := run.checkpoint_credit("live", "tx:one", "core:wood_log", 3)
    print("TAMU_STAGE6_LIVE_DIAG_CREDIT ", credited)
    if credited.get("status") != "committed":
        return false
    return run.count_item("core:wood_log") == 3 and run.journal_sequence == 1

func _reopen() -> bool:
    var run = Session.new()
    if run.restore_checkpoint("live").get("status") != "restored" or run.count_item("core:wood_log") != 3:
        return false
    if run.checkpoint_credit("live", "tx:one", "core:wood_log", 3).get("status") != "duplicate":
        return false
    if run.checkpoint_credit("live", "tx:two", "core:wood_log", 2).get("status") != "committed":
        return false
    return run.count_item("core:wood_log") == 5 and run.journal_sequence == 2

func _replay() -> bool:
    var run = Session.new()
    if run.restore_checkpoint("live").get("status") != "restored":
        return false
    return run.count_item("core:wood_log") == 5 and run.world_revision == 2 and run.checkpoint_credit("live", "tx:two", "core:wood_log", 5).get("status") == "duplicate"

func _reject() -> bool:
    var run = Session.new()
    if run.restore_checkpoint("live").get("status") != "restored":
        return false
    var before := JSON.stringify(run.snapshot_domain(), "", true)
    var disk := run.load_checkpoint("live")
    if not bool(disk.get("ok", false)):
        return false
    var changed: Dictionary = disk["snapshot"].duplicate(true)
    changed["content"]["packs"].append("missing_mod")
    if run._publish_checkpoint(changed).get("status") != "missing_or_changed_mod":
        return false
    if JSON.stringify(run.snapshot_domain(), "", true) != before:
        return false
    changed = disk["snapshot"].duplicate(true)
    changed["inventory"]["slots"] = [{"slot": 1, "def_id": "core:wood_log", "count": 3},
        {"slot": 1, "def_id": "core:wood_log", "count": 1}]
    if run._publish_checkpoint(changed).get("status") != "duplicate_slot":
        return false
    if JSON.stringify(run.snapshot_domain(), "", true) != before:
        return false
    changed = disk["snapshot"].duplicate(true)
    changed["journal"]["applied_commands"]["injected"] = true
    return run._publish_checkpoint(changed).get("status") == "invalid_journal" and JSON.stringify(run.snapshot_domain(), "", true) == before

# Existing Stage6 smoke covers the in-memory item operations without changing
# the durable v1 save layout or its replay fixtures.
func _item_contract() -> bool:
    var run = Session.new()
    var definition: Dictionary = run.item_definition("core:wood_log")
    if definition.get("id", "") != "core:wood_log":
        return false
    definition["id"] = "tampered"
    if run.item_definition("core:wood_log").get("id", "") != "core:wood_log":
        return false
    if not run.item_definition("unknown:item").is_empty():
        return false
    # Starter resources keep stable save IDs, with texture slots reserved for art.
    for id in ["core:wood_log", "core:wood_plank", "core:stone", "core:workbench"]:
        var visual: Dictionary = run.item_visual(id)
        if str(visual.get("texture_key", "")) != id:
            return false
        var parts := id.split(":")
        if str(visual.get("texture_path", "")) != "res://assets/items/%s/%s.png" % [parts[0], parts[1]]:
            return false
        if str(visual.get("kind", "")) != "primitive":
            return false
        if bool(visual.get("texture_ready", false)) and run.item_texture(id) == null:
            return false
    if not run.item_visual("unknown:item").is_empty() or run.item_texture("unknown:item") != null:
        return false
    var staged: Array = run.inventory.preview()
    if not run.inventory.preview_add(staged, "core:wood_log", 3) or not run.inventory.commit_preview(staged):
        return false
    if run.move_item_stack(0, 1, 2).get("status") != "moved":
        return false
    if run.slots[0]["count"] != 1 or run.slots[1]["count"] != 2:
        return false
    var before := JSON.stringify(run.inventory.snapshot())
    if run.move_item_stack(0, 1, 99).get("status") != "insufficient_items":
        return false
    if JSON.stringify(run.inventory.snapshot()) != before:
        return false
    if run.move_item_stack(1, 0, 2).get("status") != "moved":
        return false
    if run.slots[1] != null or run.count_item("core:wood_log") != 3:
        return false
    var crafted: Dictionary = run.crafting.execute("item-smoke:one", "core:planks_from_log")
    if not bool(crafted.get("ok", false)):
        return false
    if run.count_item("core:wood_log") != 2 or run.count_item("core:wood_plank") != 4:
        return false
    print("TAMU_ITEM_INVENTORY_CRAFTING_OK")
    return true
