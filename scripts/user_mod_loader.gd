extends RefCounted
# Data-only, opt-in TOML subset. No script/resource/ZIP execution.
# One pack per user://mods/<namespace>/pack.toml. PNGs validated, not loaded as scripts.
const ROOT := "user://mods"
const MAX_TOML := 65536
const MAX_PNG := 2097152
const MAX_PACKS := 32
const MAX_ROWS := 128

static func _name(s: String) -> bool:
    return RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(s) != null

static func _id(s: String, ns: String) -> bool:
    return RegEx.create_from_string("^[a-z][a-z0-9_]*:[a-z][a-z0-9_]*$").search(s) != null and s.begins_with(ns + ":")

static func _scalar(raw: String) -> Variant:
    var s := raw.strip_edges()
    if s.begins_with("\"") and s.ends_with("\"") and s.length() >= 2:
        var inner := s.substr(1, s.length()-2)
        if inner.contains("\\") or inner.contains("\"") or inner.contains("\n") or inner.contains("\r"):
            return null
        return inner
    if RegEx.create_from_string("^[0-9]+$").search(s) != null:
        return int(s)
    if s.begins_with("[") and s.ends_with("]"):
        var content := s.substr(1,s.length()-2).strip_edges()
        var result: Array = []
        if content == "":
            return result
        for part in content.split(","):
            var val: Variant = _scalar(part)
            if not val is String:
                return null
            result.append(val)
        return result
    return null

static func parse_toml(src: String) -> Dictionary:
    if src.to_utf8_buffer().size() > MAX_TOML or src.contains("\r"):
        return {}
    var doc := {"definitions": [], "recipes": []}
    var section := ""
    for line in src.split("\n"):
        var s := line.strip_edges()
        if s.is_empty() or s.begins_with("#"):
            continue
        if s == "[[definitions]]" or s == "[[recipes]]":
            section = s.substr(2, s.length()-4)
            if doc[section].size() >= MAX_ROWS:
                return {}
            doc[section].append({})
            continue
        if s.begins_with("["):
            return {}
        var at := s.find("=")
        if at <= 0:
            return {}
        var key := s.substr(0,at).strip_edges()
        if RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(key) == null:
            return {}
        var val: Variant = _scalar(s.substr(at+1))
        if val == null:
            return {}
        var target: Dictionary = doc if section == "" else doc[section].back()
        if target.has(key):
            return {}
        target[key] = val
    return doc

static func _stacks(values: Variant) -> Array:
    if not values is Array or values.is_empty():
        return []
    var out: Array = []
    for s in values:
        if not s is String:
            return []
        var bits: PackedStringArray = s.rsplit("=", true, 1)
        if bits.size() != 2 or RegEx.create_from_string("^[a-z][a-z0-9_]*:[a-z][a-z0-9_]*$").search(bits[0]) == null:
            return []
        if RegEx.create_from_string("^[1-9][0-9]*$").search(bits[1]) == null:
            return []
        var amount := int(bits[1])
        if amount > 9999:
            return []
        out.append({"def_id": bits[0], "count": amount})
    return out

static func _png_ok(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null or f.get_length() > MAX_PNG or f.get_length() < 33:
        return false
    var data := f.get_buffer(f.get_length())
    var image := Image.new()
    if image.load_png_from_buffer(data) != OK:
        return false
    return image.get_width() > 0 and image.get_height() > 0 and image.get_width() <= 1024 and image.get_height() <= 1024

static func _read(path: String) -> Dictionary:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null or f.get_length() > MAX_TOML:
        return {}
    return parse_toml(f.get_as_text())

static func _docs(doc: Dictionary, ns: String, folder: String) -> Dictionary:
    if not _name(ns) or ns == "core" or int(doc.get("version", 0)) != 1 or int(doc.get("catalog_version", 0)) != 1:
        return {}
    var dependencies: Variant = doc.get("dependencies", [])
    if not dependencies is Array:
        return {}
    var unique := {}
    for dep in dependencies:
        if not dep is String or not _name(dep) or dep == ns or unique.has(dep):
            return {}
        unique[dep] = true
    for key in doc.keys():
        if not key in ["namespace", "version", "catalog_version", "dependencies", "definitions", "recipes"]:
            return {}
    var defs: Array = []
    var recs: Array = []
    for row in doc.get("definitions", []):
        if not row is Dictionary or not _id(str(row.get("id", "")), ns):
            return {}
        for key in row.keys():
            if not key in ["id", "kind", "name_key", "max_stack", "icon"]:
                return {}
        if str(row.get("kind", "")) != "item" or not row.get("max_stack", null) is int:
            return {}
        if int(row["max_stack"]) < 1 or int(row["max_stack"]) > 9999:
            return {}
        var record := {"schema_version": 1, "id": row["id"], "kind": "item",
            "name_key": str(row.get("name_key", "")), "components": {"core:stackable": {"max_count": row["max_stack"]}}, "tags": []}
        var icon := str(row.get("icon", ""))
        if icon != "":
            if RegEx.create_from_string("^[a-zA-Z0-9_-]+\\.png$").search(icon) == null or not _png_ok(folder + "/" + icon):
                return {}
            record["mod_icon"] = ns + "/" + icon
        defs.append(record)
    for row in doc.get("recipes", []):
        if not row is Dictionary or not _id(str(row.get("id", "")), ns):
            return {}
        for key in row.keys():
            if not key in ["id", "inputs", "outputs", "duration_ticks"]:
                return {}
        var inputs := _stacks(row.get("inputs", null))
        var outputs := _stacks(row.get("outputs", null))
        if inputs.is_empty() or outputs.is_empty() or not row.get("duration_ticks", null) is int:
            return {}
        if int(row["duration_ticks"]) <= 0 or int(row["duration_ticks"]) > 100000:
            return {}
        recs.append({"schema_version": 1, "id": row["id"], "inputs": inputs,
            "outputs": outputs, "duration_ticks": row["duration_ticks"], "station_tags": []})
    if defs.is_empty() and recs.is_empty():
        return {}
    return {"dependencies": dependencies, "definitions": defs, "recipes": recs}

static func apply(catalog: RefCounted, root: String = ROOT) -> bool:
    if not DirAccess.dir_exists_absolute(root):
        return true
    var dir := DirAccess.open(root)
    if dir == null:
        return false
    var names := dir.get_directories()
    names.sort()
    if names.size() > MAX_PACKS:
        return false
    var pending := {}
    for ns in names:
        if not _name(ns) or ns == "core":
            return false
        var doc := _read(root + "/" + ns + "/pack.toml")
        if doc.get("namespace", "") != ns:
            return false
        var payload := _docs(doc, ns, root + "/" + ns)
        if payload.is_empty():
            return false
        pending[ns] = payload
    var next_defs: Dictionary = catalog.definitions.duplicate(true)
    var next_recs: Dictionary = catalog.recipes.duplicate(true)
    var done: Dictionary = catalog.content_packs.duplicate(true)
    for ns in pending:
        if done.has(ns):
            return false
    while not pending.is_empty():
        var advanced := false
        for ns in names:
            if not pending.has(ns):
                continue
            var entry: Dictionary = pending[ns]
            var ready := true
            for dep in entry["dependencies"]:
                if not done.has(dep):
                    ready = false
            if not ready:
                continue
            for def in entry["definitions"]:
                if next_defs.has(def["id"]) or next_recs.has(def["id"]):
                    return false
                next_defs[def["id"]] = def
            for recipe in entry["recipes"]:
                if next_defs.has(recipe["id"]) or next_recs.has(recipe["id"]):
                    return false
                next_recs[recipe["id"]] = recipe
            done[ns] = true
            pending.erase(ns)
            advanced = true
        if not advanced:
            return false
    var kinds: Dictionary = catalog._validate_documents(next_defs, next_recs)
    if kinds.is_empty():
        return false
    catalog.definitions = next_defs
    catalog.recipes = next_recs
    catalog.object_types = kinds
    catalog.content_packs = done
    print("TAMU_USER_MODS_OK packs=", done.size()-1)
    return true

static func verify_contract() -> bool:
    var doc := parse_toml("namespace = \"example\"\nversion = 1\ncatalog_version = 1\ndependencies = [\"core\"]\n[[definitions]]\nid = \"example:gem\"\nkind = \"item\"\nmax_stack = 8\n[[recipes]]\nid = \"example:gem_from_log\"\ninputs = [\"core:wood_log=1\"]\noutputs = [\"example:gem=2\"]\nduration_ticks = 30")
    if _docs(doc, "example", "user://mods/example").get("recipes", []).size() != 1:
        return false
    if not parse_toml("namespace = \"one\"\nnamespace = \"two\"").is_empty():
        return false
    if not parse_toml("[[definitions]]\nid = \"test:x\"\nicon = \"../escape.png\"").get("definitions", []).size() == 1:
        return false
    if not _docs(doc, "core", "user://mods/core").is_empty():
        return false
    if not _stacks(["core:wood_log=0"]).is_empty():
        return false
    print("TAMU_USER_MOD_BOUNDARY_OK parser=restricted png=validated namespace=checked")
    return true
