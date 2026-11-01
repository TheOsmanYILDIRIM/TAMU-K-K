extends SceneTree
const Catalog = preload("res://scripts/domain_catalog.gd")
const Mods = preload("res://scripts/user_mod_loader.gd")
const ROOT := "user://mods"

func _initialize() -> void:
    var success := _run()
    if success:
        print("TAMU_USER_MOD_DISK_E2E_OK packs=2 cases=missing_dependency,cycle,duplicate,invalid_png,unknown_save")
    else:
        push_error("TAMU_USER_MOD_DISK_E2E_FAILED")
    quit(0 if success else 42)

func _write(path: String, value: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(value)
    return true

func _pack(ns: String, deps: String, suffix: String = "") -> String:
    return "namespace = \"" + ns + "\"\nversion = 1\ncatalog_version = 1\ndependencies = [" + deps + "]\n[[definitions]]\nid = \"" + ns + ":gem\"\nkind = \"item\"\nmax_stack = 8\n" + suffix

func _catalog() -> RefCounted:
    var c = Catalog.new()
    if not c.initialize():
        return null
    return c

func _clean() -> void:
    for ns in ["alpha", "beta"]:
        for name in ["pack.toml", "gem.png"]:
            DirAccess.remove_absolute(ROOT + "/" + ns + "/" + name)
        DirAccess.remove_absolute(ROOT + "/" + ns)
    DirAccess.remove_absolute(ROOT)

func _run() -> bool:
    # Test only in CI's isolated Godot user://; do not overwrite existing user data.
    if DirAccess.dir_exists_absolute(ROOT):
        return false
    if DirAccess.make_dir_recursive_absolute(ROOT + "/alpha") != OK:
        return false
    if DirAccess.make_dir_recursive_absolute(ROOT + "/beta") != OK:
        _clean()
        return false
    var good := false
    var icon := Image.create(2, 2, false, Image.FORMAT_RGBA8)
    icon.fill(Color.RED)
    if icon.save_png(ROOT + "/alpha/gem.png") != OK:
        _clean()
        return false
    if not _write(ROOT + "/alpha/pack.toml", _pack("alpha", "\"core\"", "icon = \"gem.png\"\n")):
        _clean()
        return false
    if not _write(ROOT + "/beta/pack.toml", _pack("beta", "\"alpha\"")):
        _clean()
        return false
    var c := _catalog()
    if c == null:
        _clean()
        return false
    var prior := JSON.stringify(c.active_content_ids())
    if not Mods.apply(c, ROOT) or c.max_stack("alpha:gem") != 8 or c.max_stack("beta:gem") != 8:
        _clean()
        return false
    var full := {"content": c.active_content_ids(),
        "inventory": {"slots": [{"def_id": "alpha:gem", "count": 1}]},
        "building": {"placed": {}}}
    if c.validate_snapshot_content(full).get("status") != "compatible":
        _clean()
        return false
    var plain := _catalog()
    if plain == null or plain.validate_snapshot_content(full).get("status") != "missing_or_changed_mod":
        _clean()
        return false
    var unknown: Dictionary = full.duplicate(true)
    unknown["inventory"]["slots"][0]["def_id"] = "removed:gem"
    if c.validate_snapshot_content(unknown).get("status") != "unknown_inventory_id":
        _clean()
        return false
    var missing_meta: Dictionary = full.duplicate(true)
    missing_meta.erase("content")
    if c.validate_snapshot_content(missing_meta).get("status") != "missing_content_manifest":
        _clean()
        return false
    # Reject all invalid packs without publishing a partial catalog.
    var before := JSON.stringify(plain.active_content_ids())
    if not _write(ROOT + "/beta/pack.toml", _pack("beta", "\"missing\"")):
        _clean()
        return false
    if Mods.apply(plain, ROOT) or JSON.stringify(plain.active_content_ids()) != before:
        _clean()
        return false
    if not _write(ROOT + "/alpha/pack.toml", _pack("alpha", "\"beta\"")):
        _clean()
        return false
    if not _write(ROOT + "/beta/pack.toml", _pack("beta", "\"alpha\"")):
        _clean()
        return false
    if Mods.apply(plain, ROOT):
        _clean()
        return false
    if not _write(ROOT + "/alpha/pack.toml", _pack("alpha", "\"core\"", "icon = \"gem.png\"\n")):
        _clean()
        return false
    if not _write(ROOT + "/beta/pack.toml", _pack("beta", "\"alpha\"", "id = \"alpha:gem\"\n")):
        _clean()
        return false
    if Mods.apply(plain, ROOT) or JSON.stringify(plain.active_content_ids()) != before:
        _clean()
        return false
    if not _write(ROOT + "/beta/pack.toml", _pack("beta", "\"alpha\"")):
        _clean()
        return false
    if not _write(ROOT + "/alpha/gem.png", "not a png"):
        _clean()
        return false
    if Mods.apply(plain, ROOT) or JSON.stringify(plain.active_content_ids()) != before:
        _clean()
        return false
    good = true
    _clean()
    return good
