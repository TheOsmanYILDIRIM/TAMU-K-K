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
    if run.count_item("core:wood_log") != 3 or run.journal_sequence != 1:
        return false
    return _ground_durable_contract()

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
    if not _ground_loot_contract():
        return false
    print("TAMU_ITEM_INVENTORY_CRAFTING_OK")
    return true

func _start_ground_harvest(run) -> bool:
    var source := {"id": "worldobj:v1:ground_fixture", "kind": "tree",
        "position": Vector2.ZERO, "radius": 12.0}
    if run.begin_harvest(source, Vector2.ZERO, "harvest:fixture").get("status") != "started":
        return false
    var events: Array[Dictionary] = []
    for i in range(20):
        events.append_array(run.tick(0.1, Vector2.ZERO))
    return events.size() == 1 and bool(events[0].get("ground_drop", false))

func _ground_loot_contract() -> bool:
    var run = Session.new()
    run.enable_ground_loot()
    if not _start_ground_harvest(run):
        return false
    if run.count_item("core:wood_log") != 0 or run.pending_ground_loot().size() != 1:
        return false
    var drop_id := str(run.pending_ground_loot()[0]["id"])
    if run.pickup_ground_loot(drop_id, Vector2(500, 0), "pickup:far").get("status") != "out_of_range":
        return false
    if run.count_item("core:wood_log") != 0 or run.pending_ground_loot().size() != 1:
        return false
    if run.pickup_ground_loot(drop_id, Vector2.ZERO, "pickup:one").get("status") != "picked":
        return false
    if run.count_item("core:wood_log") != 3 or not run.pending_ground_loot().is_empty():
        return false
    if run.pickup_ground_loot(drop_id, Vector2.ZERO, "pickup:two").get("status") != "already_picked":
        return false
    return run.count_item("core:wood_log") == 3

func _ground_durable_contract() -> bool:
    var run = Session.new()
    run.enable_ground_loot()
    if not _start_ground_harvest(run) or run.pending_ground_loot().size() != 1:
        return false
    if run.save_checkpoint("ground_fixture").get("status") != "saved":
        return false
    # This fixture tests the normal Stage6 transaction/reload path without a
    # region port. Real production uses enable_durable() with verified R2 ports.
    run.durable_slot = "ground_fixture"
    var drop_id := str(run.pending_ground_loot()[0]["id"])
    if run.pickup_ground_loot(drop_id, Vector2.ZERO, "pickup:ground_durable").get("status") != "picked":
        return false
    var reopen = Session.new()
    reopen.enable_ground_loot()
    if reopen.restore_checkpoint("ground_fixture").get("status") != "restored":
        return false
    if reopen.count_item("core:wood_log") != 3 or not reopen.pending_ground_loot().is_empty():
        return false
    if reopen.pickup_ground_loot(drop_id, Vector2.ZERO, "pickup:replay").get("status") != "already_picked":
        return false
    print("TAMU_GROUND_LOOT_STAGE6_OK")
    return true
