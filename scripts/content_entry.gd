extends Resource
# Typed editable Godot content. The source document preserves non-runtime
# metadata; exported fields override the corresponding gameplay components.
# An ID change is a save migration, not an in-place update.
@export var entry_id: String = ""
@export var entry_kind: String = ""
@export var name_key: String = ""
@export var max_stack: int = 0
@export var harvest_ticks: int = 0
@export var harvest_drops: Array[Dictionary] = []
@export var world_radius: float = 0.0
@export var render_kind: String = ""
@export var footprint: Vector2i = Vector2i.ZERO
@export var rotation_steps: int = 0
@export var station_tags: PackedStringArray = PackedStringArray()
@export var recipe_ticks: int = 0
@export var recipe_inputs: Array[Dictionary] = []
@export var recipe_outputs: Array[Dictionary] = []
@export var source_document: Dictionary = {}

func from_definition(doc: Dictionary) -> void:
    source_document = doc.duplicate(true)
    entry_id = str(doc.get("id", ""))
    entry_kind = str(doc.get("kind", ""))
    name_key = str(doc.get("name_key", ""))
    var components: Dictionary = doc.get("components", {})
    max_stack = int(components.get("core:stackable", {}).get("max_count", 1 if entry_kind == "structure" else 0))
    var harvest: Dictionary = components.get("core:harvestable", {})
    harvest_ticks = int(harvest.get("duration_ticks", 0))
    harvest_drops = harvest.get("drops", []).duplicate(true)
    var world: Dictionary = components.get("core:world_resource", {})
    world_radius = float(world.get("radius", 0.0))
    render_kind = str(world.get("render_kind", ""))
    var place: Dictionary = components.get("core:placeable", {})
    var size: Array = place.get("footprint", [])
    footprint = Vector2i(int(size[0]), int(size[1])) if size.size() == 2 else Vector2i.ZERO
    rotation_steps = int(place.get("rotation_steps", 0))
    station_tags = PackedStringArray(components.get("core:craft_station", {}).get("station_tags", []))

func from_recipe(doc: Dictionary) -> void:
    source_document = doc.duplicate(true)
    entry_id = str(doc.get("id", ""))
    entry_kind = "recipe"
    recipe_ticks = int(doc.get("duration_ticks", 0))
    recipe_inputs = doc.get("inputs", []).duplicate(true)
    recipe_outputs = doc.get("outputs", []).duplicate(true)
    station_tags = PackedStringArray(doc.get("station_tags", []))

func to_document() -> Dictionary:
    if source_document.is_empty() or entry_id != str(source_document.get("id", "")):
        return {}
    var data: Dictionary = source_document.duplicate(true)
    if entry_kind == "recipe":
        if recipe_ticks <= 0:
            return {}
        data["inputs"] = recipe_inputs.duplicate(true)
        data["outputs"] = recipe_outputs.duplicate(true)
        data["duration_ticks"] = recipe_ticks
        data["station_tags"] = Array(station_tags)
        return data
    if entry_kind != str(data.get("kind", "")):
        return {}
    data["name_key"] = name_key
    var components: Dictionary = data.get("components", {}).duplicate(true)
    if components.has("core:stackable"):
        if max_stack <= 0:
            return {}
        components["core:stackable"]["max_count"] = max_stack
    if components.has("core:harvestable"):
        if harvest_ticks <= 0:
            return {}
        components["core:harvestable"]["duration_ticks"] = harvest_ticks
        components["core:harvestable"]["drops"] = harvest_drops.duplicate(true)
    if components.has("core:world_resource"):
        if world_radius < 0.0 or not is_finite(world_radius):
            return {}
        components["core:world_resource"]["radius"] = world_radius
        components["core:world_resource"]["render_kind"] = render_kind
    if components.has("core:placeable"):
        if footprint.x <= 0 or footprint.y <= 0 or rotation_steps <= 0:
            return {}
        components["core:placeable"]["footprint"] = [footprint.x, footprint.y]
        components["core:placeable"]["rotation_steps"] = rotation_steps
    if components.has("core:craft_station"):
        components["core:craft_station"]["station_tags"] = Array(station_tags)
    data["components"] = components
    return data
