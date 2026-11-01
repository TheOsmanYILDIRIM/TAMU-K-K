extends SceneTree
# CI/release preflight: compile the unchanged LÖVE JSON catalogue to a typed
# Godot binary Resource. Keep the original authoring inputs and hashes intact.
const Entry = preload("res://scripts/content_entry.gd")
const Pack = preload("res://scripts/content_pack.gd")
const SOURCE := "res://data/catalog/"
const TARGET := "res://data/catalog/compiled_catalog.res"

func _initialize() -> void:
    var passed := _compile()
    quit(0 if passed else 72)

func _read(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _equal_doc(a: Variant, b: Variant) -> bool:
    if a is Dictionary and b is Dictionary:
        if a.size() != b.size():
            return false
        for key in a:
            if not b.has(key) or not _equal_doc(a[key], b[key]):
                return false
        return true
    if a is Array and b is Array:
        if a.size() != b.size():
            return false
        for i in range(a.size()):
            if not _equal_doc(a[i], b[i]):
                return false
        return true
    if (a is int or a is float) and (b is int or b is float):
        return is_finite(float(a)) and is_finite(float(b)) and float(a) == float(b)
    return a == b

func _compile() -> bool:
    var manifest: Variant = _read(SOURCE + "manifest.json")
    if not manifest is Dictionary or int(manifest.get("catalog_version", -1)) != 1:
        push_error("TAMU_CONTENT_SOURCE_MANIFEST_INVALID")
        return false
    var pack = Pack.new()
    pack.namespace = "core"
    pack.catalog_version = int(manifest["catalog_version"])
    pack.source_hashes["manifest.json"] = FileAccess.get_sha256(SOURCE + "manifest.json")
    var known: Dictionary = {}
    for file in manifest.get("definitions", []):
        var path := str(file)
        if not path.begins_with("definitions/") or path.contains("..") or not path.ends_with(".json"):
            return false
        var doc: Variant = _read(SOURCE + path)
        if not doc is Dictionary or int(doc.get("schema_version", -1)) != 1:
            return false
        var name := str(doc.get("id", ""))
        if not name.begins_with("core:") or known.has(name):
            return false
        known[name] = true
        var entry = Entry.new()
        entry.from_definition(doc)
        if not _equal_doc(entry.to_document(), doc):
            push_error("TAMU_TYPED_CONTENT_ROUNDTRIP_FAILED " + name)
            return false
        pack.definitions.append(entry)
        pack.source_hashes[path] = FileAccess.get_sha256(SOURCE + path)
    for file in manifest.get("recipes", []):
        var path := str(file)
        if not path.begins_with("recipes/") or path.contains("..") or not path.ends_with(".json"):
            return false
        var doc: Variant = _read(SOURCE + path)
        if not doc is Dictionary or int(doc.get("schema_version", -1)) != 1:
            return false
        var name := str(doc.get("id", ""))
        if not name.begins_with("core:") or known.has(name):
            return false
        known[name] = true
        var entry = Entry.new()
        entry.from_recipe(doc)
        if not _equal_doc(entry.to_document(), doc):
            push_error("TAMU_TYPED_RECIPE_ROUNDTRIP_FAILED " + name)
            return false
        pack.recipes.append(entry)
        pack.source_hashes[path] = FileAccess.get_sha256(SOURCE + path)
    if pack.definitions.size() != manifest["definitions"].size() or pack.recipes.size() != manifest["recipes"].size():
        return false
    var err := ResourceSaver.save(pack, TARGET, ResourceSaver.FLAG_COMPRESS)
    if err != OK:
        push_error("TAMU_BINARY_CATALOG_SAVE_FAILED " + str(err))
        return false
    var reopened: Variant = ResourceLoader.load(TARGET, "", ResourceLoader.CACHE_MODE_IGNORE)
    if not reopened is Resource or reopened.definitions.size() != pack.definitions.size() or reopened.recipes.size() != pack.recipes.size():
        push_error("TAMU_BINARY_CATALOG_READBACK_FAILED")
        return false
    print("TAMU_CATALOG_BINARY_COMPILE_OK definitions=", pack.definitions.size(),
        " recipes=", pack.recipes.size(),
        " bytes=", FileAccess.get_file_as_bytes(TARGET).size(),
        " path=", TARGET)
    return true
