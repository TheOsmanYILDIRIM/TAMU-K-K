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
