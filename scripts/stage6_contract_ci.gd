extends SceneTree
const Store = preload("res://scripts/stage6_checkpoint.gd")
const Catalog = preload("res://scripts/domain_catalog.gd")
const Session = preload("res://scripts/gameplay_session.gd")

func _catalog() -> RefCounted:
    var c = Catalog.new()
    if not c.initialize():
        return null
    return c

func _snapshot() -> Dictionary:
    var session = Session.new()
    return session.snapshot_domain()

func _initialize() -> void:
    var phase := OS.get_environment("TAMU_SAVE_PHASE")
    var result := false
    if phase == "write":
        result = _write()
    elif phase == "reopen":
        result = _reopen()
    elif phase == "recovery":
        result = _recovery()
    elif phase == "mod_reject":
        result = _mod_reject()
    if result:
        print("TAMU_STAGE6_", phase.to_upper(), "_OK")
    else:
        push_error("TAMU_STAGE6_" + phase.to_upper() + "_FAILED")
    quit(0 if result else 48)

func _write() -> bool:
    if DirAccess.dir_exists_absolute("user://saves"):
        return false
    var catalog = _catalog()
    if catalog == null:
        return false
    var state := _snapshot()
    if state.is_empty():
        return false
    var written := Store.write_checkpoint("test", state, catalog)
    if written.get("status") != "saved":
        print("TAMU_STAGE6_DIAG_WRITE ", written)
        return false
    var invalid: Dictionary = state.duplicate(true)
    invalid["inventory"]["slots"] = [{"slot": 1, "def_id": "removed:missing", "count": 1}]
    if Store.write_checkpoint("test", invalid, catalog).get("status") != "unknown_inventory_id":
        return false
    return Store.read_checkpoint("test", catalog).get("status") == "loaded"

func _reopen() -> bool:
    var catalog = _catalog()
    if catalog == null:
        return false
    var first := Store.read_checkpoint("test", catalog)
    if first.get("status") != "loaded":
        return false
    var snapshot: Dictionary = first["snapshot"]
    if snapshot["inventory"]["slots"] != []:
        return false
    snapshot["inventory"]["slots"] = [{"slot": 1, "def_id": "core:wood_log", "count": 3}]
    if Store.write_checkpoint("test", snapshot, catalog).get("status") != "saved":
        return false
    return Store.read_checkpoint("test", catalog).get("snapshot", {}).get("inventory", {}).get("slots", []).size() == 1

func _recovery() -> bool:
    var catalog = _catalog()
    if catalog == null:
        return false
    var path := "user://saves/test.checkpoint"
    if DirAccess.rename_absolute(path, path + ".tmp") != OK:
        return false
    # Power loss after making previous backup, before promoting staged temp.
    var backup := path + ".bak"
    if not FileAccess.file_exists(backup):
        return false
    var recovered := Store.read_checkpoint("test", catalog)
    if recovered.get("status") != "recovered" or recovered["snapshot"]["inventory"]["slots"] != []:
        return false
    if Store.write_checkpoint("test", recovered["snapshot"], catalog).get("status") != "pending_recovery":
        return false
    return true

func _mod_reject() -> bool:
    var catalog = _catalog()
    if catalog == null:
        return false
    var path := "user://saves/test.checkpoint"
    var checkpoint := Store._decode(path + ".bak")
    if checkpoint.get("status") != "valid":
        return false
    var changed: Dictionary = checkpoint["snapshot"].duplicate(true)
    changed["content"]["packs"].append("removed")
    # Valid sealed bytes but missing mod must be refused, not silently fallback.
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(Store._seal(changed))
    f.flush()
    f.close()
    var rejected := Store.read_checkpoint("test", catalog)
    return rejected.get("status") == "missing_or_changed_mod"
