extends RefCounted
# First creation is persisted once. Missing identity with existing checkpoints
# is never replaced with an unrelated new UUID.
const PATH := "user://saves/world_identity.txt"

static func valid(id: String) -> bool:
    if id.length() != 36:
        return false
    return RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$").search(id) != null

static func load_or_create() -> Dictionary:
    if FileAccess.file_exists(PATH):
        var value := FileAccess.get_file_as_string(PATH).strip_edges()
        if not valid(value):
            return {"ok": false, "status": "world_identity_corrupt"}
        return {"ok": true, "id": value, "status": "existing"}
    if DirAccess.make_dir_recursive_absolute("user://saves") != OK:
        return {"ok": false, "status": "directory_failed"}
    var dir := DirAccess.open("user://saves")
    if dir == null:
        return {"ok": false, "status": "directory_failed"}
    for file in dir.get_files():
        if file.ends_with(".checkpoint") or file.ends_with(".checkpoint.bak") or file.ends_with(".checkpoint.tmp"):
            return {"ok": false, "status": "identity_missing_with_saves"}
    var bytes := Crypto.new().generate_random_bytes(16)
    if bytes.size() != 16:
        return {"ok": false, "status": "random_failed"}
    bytes[6] = (bytes[6] & 15) | 64
    bytes[8] = (bytes[8] & 63) | 128
    var hex := bytes.hex_encode()
    var uuid := "%s-%s-%s-%s-%s" % [hex.substr(0,8),hex.substr(8,4),hex.substr(12,4),hex.substr(16,4),hex.substr(20,12)]
    if not valid(uuid):
        return {"ok": false, "status": "uuid_failed"}
    var pending := PATH + ".tmp"
    if FileAccess.file_exists(pending):
        return {"ok": false, "status": "pending_identity"}
    var f := FileAccess.open(pending, FileAccess.WRITE)
    if f == null:
        return {"ok": false, "status": "identity_open_failed"}
    f.store_string(uuid + "\n")
    f.flush()
    f.close()
    if FileAccess.get_file_as_string(pending).strip_edges() != uuid:
        return {"ok": false, "status": "identity_readback_failed"}
    if DirAccess.rename_absolute(pending, PATH) != OK:
        return {"ok": false, "status": "identity_rename_failed"}
    return {"ok": true, "id": uuid, "status": "created"}
