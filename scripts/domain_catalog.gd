extends RefCounted
# Canonical LÖVE2D data/catalog JSONs are the only source of game definitions.
# Never manufacture default item, recipe, or object definitions.
const MANIFEST := "res://data/catalog/manifest.json"
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

func initialize() -> bool:
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
