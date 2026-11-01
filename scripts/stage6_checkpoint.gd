extends RefCounted
# Stage6 V1 disk checkpoint. Never auto-upgrade pre-existing save files.
# A rejected checkpoint remains untouched. Application/restoration is separate.
const VERSION := 1
const MAX_BYTES := 2097152

static func _json_only(v: Variant, depth: int = 0) -> bool:
    if depth > 16:
        return false
    if v == null or v is bool or v is int or v is String:
        return true
    if v is float:
        return is_finite(v)
    if v is Array:
        if v.size() > 4096:
            return false
        for entry in v:
            if not _json_only(entry, depth + 1):
                return false
        return true
    if v is Dictionary:
        if v.size() > 4096:
            return false
        for key in v:
            if not key is String or not _json_only(v[key], depth + 1):
                return false
        return true
    return false

static func _seal(snapshot: Dictionary) -> String:
    var data := JSON.stringify(snapshot, "", true)
    var envelope := {"format": "tamu.stage6", "version": VERSION,
        "sha256": data.sha256_text(), "snapshot": snapshot}
    return JSON.stringify(envelope, "", true)

static func _decode(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "status": "missing"}
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null or f.get_length() <= 0 or f.get_length() > MAX_BYTES:
        return {"ok": false, "status": "invalid_file"}
    var raw := f.get_as_text()
    var envelope: Variant = JSON.parse_string(raw)
    if not envelope is Dictionary or envelope.get("format", "") != "tamu.stage6" or envelope.get("version", null) != VERSION:
        return {"ok": false, "status": "invalid_version"}
    var snapshot: Variant = envelope.get("snapshot", null)
    if not snapshot is Dictionary or not _json_only(snapshot):
        return {"ok": false, "status": "invalid_snapshot"}
    if str(envelope.get("sha256", "")) != JSON.stringify(snapshot, "", true).sha256_text():
        return {"ok": false, "status": "checksum_mismatch"}
    return {"ok": true, "status": "valid", "snapshot": snapshot}

static func _path(name: String) -> String:
    # Caller may only select one single basename, never an arbitrary path.
    if RegEx.create_from_string("^[a-z][a-z0-9_-]{0,31}$").search(name) == null:
        return ""
    return "user://saves/" + name + ".checkpoint"

static func write_checkpoint(name: String, snapshot: Dictionary, catalog: RefCounted) -> Dictionary:
    var path := _path(name)
    if path.is_empty() or not _json_only(snapshot):
        return {"ok": false, "status": "invalid_input"}
    var gate: Dictionary = catalog.validate_snapshot_content(snapshot)
    if not bool(gate.get("ok", false)):
        return gate
    if DirAccess.make_dir_recursive_absolute("user://saves") != OK:
        return {"ok": false, "status": "directory_failed"}
    var pending := path + ".tmp"
    var backup := path + ".bak"
    # A prior interrupted commit must first be explicitly resolved, never overwritten.
    if FileAccess.file_exists(pending):
        return {"ok": false, "status": "pending_recovery"}
    if not FileAccess.file_exists(path) and FileAccess.file_exists(backup):
        return {"ok": false, "status": "pending_recovery"}
    if FileAccess.file_exists(path) and not bool(_decode(path).get("ok", false)):
        return {"ok": false, "status": "existing_corrupt"}
    var sealed := _seal(snapshot)
    if sealed.to_utf8_buffer().size() > MAX_BYTES:
        return {"ok": false, "status": "too_large"}
    var f := FileAccess.open(pending, FileAccess.WRITE)
    if f == null:
        return {"ok": false, "status": "temp_open_failed"}
    f.store_string(sealed)
    f.flush()
    f.close()
    if not bool(_decode(pending).get("ok", false)):
        return {"ok": false, "status": "temp_verification_failed"}
    # Backup rotation is explicit; never replace a valid latest checkpoint with bad bytes.
    if FileAccess.file_exists(path):
        if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
            return {"ok": false, "status": "backup_cleanup_failed"}
        if DirAccess.rename_absolute(path, backup) != OK:
            return {"ok": false, "status": "backup_rename_failed"}
    if DirAccess.rename_absolute(pending, path) != OK:
        return {"ok": false, "status": "commit_rename_failed"}
    return {"ok": true, "status": "saved"}

static func read_checkpoint(name: String, catalog: RefCounted) -> Dictionary:
    var path := _path(name)
    if path.is_empty():
        return {"ok": false, "status": "invalid_name"}
    var source := path
    var backup := path + ".bak"
    var candidate := _decode(path)
    if not bool(candidate.get("ok", false)):
        # Only structural corruption/missing permits backup; do not mask a mod mismatch.
        if not FileAccess.file_exists(backup):
            return candidate
        var alternate := _decode(backup)
        if not bool(alternate.get("ok", false)):
            return {"ok": false, "status": "no_valid_generation"}
        candidate = alternate
        source = backup
    var gate: Dictionary = catalog.validate_snapshot_content(candidate["snapshot"])
    if not bool(gate.get("ok", false)):
        return gate
    return {"ok": true, "status": "recovered" if source == backup else "loaded",
        "snapshot": candidate["snapshot"], "source": source}
