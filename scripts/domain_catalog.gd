extends RefCounted
# Canonical LÖVE2D data/catalog JSONs are the only source of game definitions.
# Never manufacture default item, recipe, or object definitions.
const MANIFEST := "res://data/catalog/manifest.json"
const COMPILED := "res://data/catalog/compiled_catalog.res"
const ContentEntry = preload("res://scripts/content_entry.gd")
const ContentPack = preload("res://scripts/content_pack.gd")
var content_packs: Dictionary = {"core": true}
var version := -1
var definitions: Dictionary = {}
var recipes: Dictionary = {}
var object_types: Dictionary = {}

static func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _safe_path(relative: String) -> bool:
    return not relative.is_empty() and not relative.begins_with("/") and not relative.contains("\\") and not relative.contains("..") and relative.ends_with(".json")

const UserMods = preload("res://scripts/user_mod_loader.gd")

func initialize() -> bool:
    var ok := false
    if OS.get_environment("TAMU_CATALOG_FORMAT") != "json" and ResourceLoader.exists(COMPILED):
        ok = _initialize_binary()
    elif OS.get_environment("TAMU_CATALOG_REQUIRE_BINARY") == "1":
        push_error("TAMU_CATALOG_BINARY_REQUIRED_MISSING")
        return false
    else:
        ok = _initialize_json()
    if not ok:
        return false
    if OS.get_environment("TAMU_ENABLE_MODS") == "1" and not UserMods.apply(self):
        push_error("TAMU_USER_MOD_REJECTED")
        return false
    return true

func _legacy_initialize_unused() -> bool:
    if OS.get_environment("TAMU_CATALOG_FORMAT") != "json" and ResourceLoader.exists(COMPILED):
        return _initialize_binary()
    if OS.get_environment("TAMU_CATALOG_REQUIRE_BINARY") == "1":
        push_error("TAMU_CATALOG_BINARY_REQUIRED_MISSING")
        return false
    return _initialize_json()

func _initialize_binary() -> bool:
    var candidate: Variant = ResourceLoader.load(COMPILED)
    if not candidate is Resource or not candidate is ContentPack:
        push_error("TAMU_CATALOG_BINARY_RESOURCE_INVALID")
        return false
    var pack: Resource = candidate
    if pack.pack_namespace != "core" or pack.schema_version != 1 or pack.catalog_version != 1:
        return false
    var manifest: Variant = _read_json(MANIFEST)
    if not manifest is Dictionary or pack.catalog_version != int(manifest.get("catalog_version", -1)):
        return false
    var filenames: Array = ["manifest.json"]
    filenames.append_array(manifest.get("definitions", []))
    filenames.append_array(manifest.get("recipes", []))
    if pack.source_hashes.size() != filenames.size():
        return false
    for file in filenames:
        var relative := str(file)
        if not _safe_path(relative) or not pack.source_hashes.has(relative):
            return false
        if FileAccess.get_sha256("res://data/catalog/" + relative) != str(pack.source_hashes[relative]):
            push_error("TAMU_CATALOG_BINARY_SOURCE_HASH_INVALID " + relative)
            return false
    if pack.definitions.size() != manifest["definitions"].size() or pack.recipes.size() != manifest["recipes"].size():
        return false
    var definitions_next: Dictionary = {}
    var recipes_next: Dictionary = {}
    for entry in pack.definitions:
        if not entry is ContentEntry:
            return false
        var doc: Dictionary = entry.to_document()
        var id := str(doc.get("id", ""))
        if not _valid_content_id(id, "core") or definitions_next.has(id):
            return false
        definitions_next[id] = doc
    for entry in pack.recipes:
        if not entry is ContentEntry or entry.entry_kind != "recipe":
            return false
        var doc: Dictionary = entry.to_document()
        var id := str(doc.get("id", ""))
        if not _valid_content_id(id, "core") or recipes_next.has(id) or definitions_next.has(id):
            return false
        recipes_next[id] = doc
    var world_map := _validate_documents(definitions_next, recipes_next)
    if world_map.is_empty():
        return false
    version = pack.catalog_version
    definitions = definitions_next
    recipes = recipes_next
    object_types = world_map
    print("TAMU_CATALOG_BINARY_OK definitions=", definitions.size(),
        " recipes=", recipes.size(), " namespaces=", content_packs.size())
    return true

static func _valid_namespace(name: String) -> bool:
    return name != "" and RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(name) != null

static func _valid_content_id(id: String, pack_name: String) -> bool:
    if not _valid_namespace(pack_name):
        return false
    var re := RegEx.create_from_string("^[a-z][a-z0-9_]*:[a-z][a-z0-9_]*$")
    return re.search(id) != null and id.begins_with(pack_name + ":")

static func _validate_documents(defs: Dictionary, recs: Dictionary) -> Dictionary:
    var kinds: Dictionary = {}
    for id in defs:
        var def: Dictionary = defs[id]
        if str(def.get("id", "")) != str(id) or int(def.get("schema_version", 0)) != 1:
            return {}
        var components: Variant = def.get("components", null)
        if not components is Dictionary:
            return {}
        if components.has("core:stackable"):
            if int(components["core:stackable"].get("max_count", 0)) <= 0:
                return {}
        if components.has("core:world_resource"):
            var world: Dictionary = components["core:world_resource"]
            var kind := str(world.get("render_kind", ""))
            if kind == "" or kinds.has(kind):
                return {}
            kinds[kind] = id
            if components.has("core:harvestable"):
                var harvest: Dictionary = components["core:harvestable"]
                if int(harvest.get("duration_ticks", 0)) <= 0:
                    return {}
                for drop in harvest.get("drops", []):
                    if not defs.has(str(drop.get("def_id", ""))) or int(drop.get("count", 0)) <= 0:
                        return {}
    for id in recs:
        var recipe: Dictionary = recs[id]
        if str(recipe.get("id", "")) != str(id) or int(recipe.get("schema_version", 0)) != 1 or int(recipe.get("duration_ticks", 0)) <= 0:
            return {}
        if not recipe.get("station_tags", null) is Array:
            return {}
        for side in ["inputs", "outputs"]:
            var stacks: Variant = recipe.get(side, null)
            if not stacks is Array or stacks.is_empty():
                return {}
            for stack in stacks:
                if not stack is Dictionary or not defs.has(str(stack.get("def_id", ""))) or int(stack.get("count", 0)) <= 0:
                    return {}
    return kinds

# Trusted editor/build pack API. Never ResourceLoader.load() an untrusted
# user:// .res/.pck: user mods need a data-only TOML parser and sandbox gate.
func register_trusted_pack(pack: Resource) -> bool:
    if not pack is ContentPack or pack.schema_version != 1 or pack.catalog_version != version:
        return false
    var pack_name: String = str(pack.pack_namespace)
    if pack_name == "core" or not _valid_namespace(pack_name) or content_packs.has(pack_name):
        return false
    var next_defs: Dictionary = definitions.duplicate(true)
    var next_recipes: Dictionary = recipes.duplicate(true)
    for entry in pack.definitions:
        if not entry is ContentEntry or entry.entry_kind == "recipe":
            return false
        var doc: Dictionary = entry.to_document()
        var id := str(doc.get("id", ""))
        if not _valid_content_id(id, pack_name) or next_defs.has(id) or next_recipes.has(id):
            return false
        next_defs[id] = doc
    for entry in pack.recipes:
        if not entry is ContentEntry or entry.entry_kind != "recipe":
            return false
        var doc: Dictionary = entry.to_document()
        var id := str(doc.get("id", ""))
        if not _valid_content_id(id, pack_name) or next_defs.has(id) or next_recipes.has(id):
            return false
        next_recipes[id] = doc
    var kinds: Dictionary = _validate_documents(next_defs, next_recipes)
    if kinds.is_empty():
        return false
    definitions = next_defs
    recipes = next_recipes
    object_types = kinds
    content_packs[pack_name] = true
    return true

func validate_snapshot_content(snapshot: Dictionary) -> Dictionary:
    # Read-only migration gate; no restore/store is performed here.
    var meta: Variant = snapshot.get("content", null)
    if not meta is Dictionary:
        return {"ok": false, "status": "missing_content_manifest"}
    var current := active_content_ids()
    if meta.get("catalog_version", null) != current["catalog_version"]:
        return {"ok": false, "status": "catalog_version_mismatch"}
    for field in ["packs", "definitions", "recipes"]:
        var saved: Variant = meta.get(field, null)
        if not saved is Array:
            return {"ok": false, "status": "invalid_content_manifest"}
        var expected: Array = current[field]
        if saved != expected:
            return {"ok": false, "status": "missing_or_changed_mod"}
    var inv: Variant = snapshot.get("inventory", null)
    if not inv is Dictionary or not inv.get("slots", null) is Array:
        return {"ok": false, "status": "invalid_inventory"}
    for slot in inv["slots"]:
        if not slot is Dictionary or not definitions.has(str(slot.get("def_id", ""))):
            return {"ok": false, "status": "unknown_inventory_id"}
        if int(slot.get("count", 0)) < 1 or int(slot["count"]) > max_stack(str(slot["def_id"])):
            return {"ok": false, "status": "invalid_stack"}
    var buildings: Variant = snapshot.get("building", null)
    if not buildings is Dictionary or not buildings.get("placed", null) is Dictionary:
        return {"ok": false, "status": "invalid_buildings"}
    for id in buildings["placed"]:
        var instance: Variant = buildings["placed"][id]
        if not instance is Dictionary or not definitions.has(str(instance.get("def_id", ""))):
            return {"ok": false, "status": "unknown_building_id"}
    return {"ok": true, "status": "compatible"}

func active_content_ids() -> Dictionary:
    var a: Array = definitions.keys()
    var b: Array = recipes.keys()
    var namespaces: Array = content_packs.keys()
    a.sort()
    b.sort()
    namespaces.sort()
    return {"catalog_version": version, "packs": namespaces, "definitions": a, "recipes": b}

func verify_mod_boundary() -> bool:
    var probe = get_script().new()
    if not probe.initialize() or not UserMods.verify_contract():
        return false
    var pack = ContentPack.new()
    pack.pack_namespace = "example"
    var definition = ContentEntry.new()
    definition.from_definition({"schema_version": 1, "id": "example:gem", "kind": "item",
        "name_key": "item.example_gem",
        "components": {"core:stackable": {"max_count": 16}}, "tags": []})
    var recipe_entry = ContentEntry.new()
    recipe_entry.from_recipe({"schema_version": 1, "id": "example:gem_from_wood",
        "inputs": [{"def_id": "core:wood_log", "count": 1}],
        "outputs": [{"def_id": "example:gem", "count": 2}],
        "station_tags": [], "duration_ticks": 30})
    pack.definitions.append(definition)
    pack.recipes.append(recipe_entry)
    if not probe.register_trusted_pack(pack):
        return false
    if probe.max_stack("example:gem") != 16 or probe.recipe("example:gem_from_wood").is_empty():
        return false
    if probe.register_trusted_pack(pack):
        return false
    var before := JSON.stringify(probe.active_content_ids())
    var spoof = ContentPack.new()
    spoof.pack_namespace = "cheat"
    var duplicate = ContentEntry.new()
    duplicate.from_definition({"schema_version": 1, "id": "core:wood_log",
        "kind": "item", "name_key": "spoof",
        "components": {"core:stackable": {"max_count": 999}}})
    spoof.definitions.append(duplicate)
    if probe.register_trusted_pack(spoof):
        return false
    if JSON.stringify(probe.active_content_ids()) != before:
        return false
    var missing = ContentPack.new()
    missing.pack_namespace = "broken"
    var broken_recipe = ContentEntry.new()
    broken_recipe.from_recipe({"schema_version": 1, "id": "broken:undefined_item",
        "inputs": [{"def_id": "broken:missing", "count": 1}],
        "outputs": [{"def_id": "core:wood_log", "count": 1}],
        "station_tags": [], "duration_ticks": 1})
    missing.recipes.append(broken_recipe)
    if probe.register_trusted_pack(missing):
        return false
    if JSON.stringify(probe.active_content_ids()) != before:
        return false
    print("TAMU_CONTENT_MOD_BOUNDARY_OK registered=example duplicate=rejected core_override=rejected missing_reference=rejected")
    return true

func _initialize_json() -> bool:
    var manifest: Variant = _read_json(MANIFEST)
    if not manifest is Dictionary:
        push_error("TAMU_CATALOG_MANIFEST_MISSING")
        return false
    if int(manifest.get("catalog_version", -1)) <= 0:
        return false
    version = int(manifest["catalog_version"])
    definitions.clear()
    recipes.clear()
    object_types.clear()
    for relative in manifest.get("definitions", []):
        var file := str(relative)
        if not _safe_path(file):
            return false
        var doc: Variant = _read_json("res://data/catalog/" + file)
        if not doc is Dictionary or int(doc.get("schema_version", -1)) != 1:
            return false
        var id := str(doc.get("id", ""))
        if id.is_empty() or definitions.has(id):
            return false
        definitions[id] = doc
        var components: Dictionary = doc.get("components", {})
        var world: Variant = components.get("core:world_resource", null)
        if world is Dictionary:
            var kind := str(world.get("render_kind", ""))
            if kind.is_empty() or object_types.has(kind):
                return false
            object_types[kind] = id
    for relative in manifest.get("recipes", []):
        var file := str(relative)
        if not _safe_path(file):
            return false
        var doc: Variant = _read_json("res://data/catalog/" + file)
        if not doc is Dictionary or int(doc.get("schema_version", -1)) != 1:
            return false
        var id := str(doc.get("id", ""))
        if id.is_empty() or recipes.has(id):
            return false
        for side in ["inputs", "outputs"]:
            if not doc.get(side, null) is Array or doc[side].is_empty():
                return false
            for stack in doc[side]:
                if not stack is Dictionary or not definitions.has(str(stack.get("def_id", ""))) or int(stack.get("count", 0)) <= 0:
                    return false
        if int(doc.get("duration_ticks", 0)) <= 0 or not doc.get("station_tags", null) is Array:
            return false
        recipes[id] = doc
    for id in object_types.values():
        var def: Dictionary = definitions[id]
        var components: Dictionary = def.get("components", {})
        var harvest: Variant = components.get("core:harvestable", null)
        if harvest == null:
            continue
        if not harvest is Dictionary or int(harvest.get("duration_ticks", 0)) <= 0:
            return false
        for drop in harvest.get("drops", []):
            if not definitions.has(str(drop.get("def_id", ""))) or int(drop.get("count", 0)) <= 0:
                return false
    print("TAMU_CATALOG_SOURCE_OK version=", version, " definitions=", definitions.size(),
        " recipes=", recipes.size(), " world_kinds=", object_types.size())
    return true

func item(id: String) -> Dictionary:
    var def: Variant = definitions.get(id, {})
    return def if def is Dictionary else {}

func recipe(id: String) -> Dictionary:
    var def: Variant = recipes.get(id, {})
    return def if def is Dictionary else {}

func max_stack(id: String) -> int:
    var def := item(id)
    if def.is_empty():
        return 0
    var components: Dictionary = def.get("components", {})
    if components.has("core:stackable"):
        return int(components["core:stackable"].get("max_count", 0))
    if str(def.get("kind", "")) == "structure":
        return 1
    return 0

func harvest(kind: String) -> Dictionary:
    var id := str(object_types.get(kind, ""))
    var def := item(id)
    var components: Dictionary = def.get("components", {})
    var h: Variant = components.get("core:harvestable", {})
    return h if h is Dictionary else {}

func world_radius(kind: String) -> float:
    var id := str(object_types.get(kind, ""))
    var components: Dictionary = item(id).get("components", {})
    return float(components.get("core:world_resource", {}).get("radius", 0.0))

func station_tags(def_id: String) -> Array:
    var components: Dictionary = item(def_id).get("components", {})
    return components.get("core:craft_station", {}).get("station_tags", [])

func verify_contract() -> bool:
    if version != 1 or definitions.size() != 7 or recipes.size() != 2:
        return false
    if max_stack("core:wood_log") != 99 or max_stack("core:workbench") != 1:
        return false
    var tree := harvest("tree")
    var rock := harvest("rock")
    if int(tree.get("duration_ticks", 0)) != 90 or int(rock.get("duration_ticks", 0)) != 120:
        return false
    if tree.get("drops", []).size() != 1 or rock.get("drops", []).size() != 1:
        return false
    if str(tree["drops"][0]["def_id"]) != "core:wood_log" or int(tree["drops"][0]["count"]) != 3:
        return false
    if str(rock["drops"][0]["def_id"]) != "core:stone" or int(rock["drops"][0]["count"]) != 2:
        return false
    return int(recipe("core:planks_from_log").get("duration_ticks", 0)) == 30 and int(recipe("core:bench_from_planks").get("duration_ticks", 0)) == 60
