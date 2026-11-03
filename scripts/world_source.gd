extends RefCounted
# Runtime contract: exact compiled R2 source, never synthetic world geometry.
const EXPECTED_CHUNKS := 156
const SOURCE_RUN_ID := 41234831527
var index: Dictionary = {}
var available: Dictionary = {}
var integrity: Dictionary = {}

static func _sha_matches(path: String, expected: String) -> bool:
    return FileAccess.file_exists(path) and FileAccess.get_sha256(path) == expected

func initialize() -> bool:
    var idx = JSON.parse_string(FileAccess.get_file_as_string("res://chunks/index.json"))
    var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://chunks/source_integrity.json"))
    if not idx is Dictionary or not manifest is Dictionary:
        push_error("TAMU_WORLD_SOURCE_INDEX_MISSING")
        return false
    if not idx.has("available") or not idx["available"] is Array or not idx.has("bounds"):
        return false
    var bounds: Dictionary = idx["bounds"]
    if int(bounds.get("min_x", 0)) != -4096 or int(bounds.get("max_x", 0)) != 28672 or int(bounds.get("min_y", 0)) != -4096 or int(bounds.get("max_y", 0)) != 28672:
        return false
    if int(manifest.get("source_run_id", -1)) != SOURCE_RUN_ID:
        return false
    if not _sha_matches("res://chunks/index.json", str(manifest.get("index_sha256", ""))):
        return false
    if not _sha_matches("res://chunks/r2_objects.json", str(manifest.get("objects_sha256", ""))):
        return false
    var sources = manifest.get("chunks", {})
    if not sources is Dictionary or sources.size() != EXPECTED_CHUNKS:
        return false
    for item in idx["available"]:
        var stem := str(item)
        var parts := stem.split("_")
        if parts.size() != 3 or parts[0] != "c" or not parts[1].is_valid_int() or not parts[2].is_valid_int():
            return false
        if available.has(stem) or not sources.has(stem):
            return false
        available[stem] = true
    if available.size() != EXPECTED_CHUNKS:
        return false
    index = idx
    integrity = manifest
    return true

func read_chunk(stem: String) -> Dictionary:
    if not available.has(stem):
        push_error("TAMU_UNKNOWN_AUTHORED_CHUNK " + stem)
        return {}
    var record: Dictionary = integrity["chunks"][stem]
    var bytes_path := "res://chunks/%s.verts" % stem
    var meta_path := "res://chunks/%s.json" % stem
    if not _sha_matches(bytes_path, str(record.get("verts", ""))) or not _sha_matches(meta_path, str(record.get("meta", ""))):
        push_error("TAMU_AUTHORED_CHUNK_HASH_FAILED " + stem)
        return {}
    var raw := FileAccess.get_file_as_bytes(bytes_path)
    var meta = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
    if not meta is Dictionary or not meta.has("meshes") or not meta["meshes"] is Array:
        return {}
    var count := 0
    for surf in meta["meshes"]:
        if not surf is Dictionary or int(surf.get("count", 0)) <= 0:
            return {}
        count += int(surf["count"])
    if raw.size() != count * 20 or count % 3 != 0:
        push_error("TAMU_CHUNK_VERTEX_LENGTH_FAILED " + stem)
        return {}
    return {"raw": raw, "meta": meta}
