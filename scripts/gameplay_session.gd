extends RefCounted
# Thin Godot native domain composition. Canonical content: data/catalog/*.json.
# LÖVE contracts: catalogue -> inventory -> harvest/craft -> building -> Stage6 tx.
# The current gameplay is session-memory only; durable store is not connected.
const DomainCatalog = preload("res://scripts/domain_catalog.gd")
const DomainInventory = preload("res://scripts/domain_inventory.gd")
const DomainHarvesting = preload("res://scripts/domain_harvesting.gd")
const DomainCrafting = preload("res://scripts/domain_crafting.gd")
const DomainBuilding = preload("res://scripts/domain_building.gd")
const DomainTransaction = preload("res://scripts/domain_transaction.gd")
const CAPACITY := 12
const HARVEST_RANGE := 38.0

var catalog: RefCounted
var inventory: RefCounted
var harvesting: RefCounted
var crafting: RefCounted
var building: RefCounted
var event_count := 0
# Compatibility with existing live TOPLA/TAHTA/TEZGAH UI and CI.
var slots: Array:
    get: return inventory.slots
var depleted: Dictionary:
    get: return harvesting.depleted
var harvest_commands: Dictionary:
    get: return harvesting.commands
var craft_commands: Dictionary:
    get: return crafting.commands
var active_harvest: Dictionary:
    get: return harvesting.active
var active_craft: Dictionary:
    get: return crafting.active

func _init() -> void:
    catalog = DomainCatalog.new()
    if not catalog.initialize():
        push_error("TAMU_CANONICAL_GAMEPLAY_CATALOG_INVALID")
        return
    inventory = DomainInventory.new(catalog, CAPACITY)
    harvesting = DomainHarvesting.new(catalog, inventory)
    crafting = DomainCrafting.new(catalog, inventory)
    building = DomainBuilding.new(catalog, inventory)

func count_item(id: String) -> int:
    return inventory.count_item(id)

func is_harvestable(kind: String) -> bool:
    return not catalog.harvest(kind).is_empty()

func harvest_drop(kind: String) -> Dictionary:
    var definition: Dictionary = catalog.harvest(kind)
    var drops: Array = definition.get("drops", [])
    return drops[0] if drops.size() == 1 else {}

func begin_harvest(item: Dictionary, player_pos: Vector2, command_id: String) -> Dictionary:
    return harvesting.begin(command_id, item, player_pos)

func begin_craft(command_id: String, recipe_id: String, station_tags: Array = []) -> Dictionary:
    return crafting.begin(command_id, recipe_id, station_tags)

func tick(dt: float, player_pos: Vector2) -> Array[Dictionary]:
    var events: Array[Dictionary] = []
    events.append_array(harvesting.update(dt, player_pos))
    events.append_array(crafting.update(dt))
    event_count += events.size()
    return events

func snapshot_domain() -> Dictionary:
    # In-memory snapshot shape only; NOT a Stage6 checkpoint or save migration.
    return {"catalog_version": catalog.version, "content": catalog.active_content_ids(),
        "inventory": inventory.snapshot(), "building": building.snapshot(),
        "depleted": harvesting.depleted.duplicate(true),
        "harvest_commands": harvesting.commands.duplicate(true),
        "craft_commands": crafting.commands.duplicate(true)}

func validate_snapshot_content(snapshot: Dictionary) -> Dictionary:
    # Stage 6 restore must call this before publishing any recovered state.
    return catalog.validate_snapshot_content(snapshot)

const Stage6Store = preload("res://scripts/stage6_checkpoint.gd")

func save_checkpoint(name: String) -> Dictionary:
    # In-flight transactions cannot be snapshotted as committed.
    if not harvesting.active.is_empty() or not crafting.active.is_empty():
        return {"ok": false, "status": "busy"}
    return Stage6Store.write_checkpoint(name, snapshot_domain(), catalog)

func load_checkpoint(name: String) -> Dictionary:
    # Validated detached state. Never publish or mutate the live domain here.
    return Stage6Store.read_checkpoint(name, catalog)

func verify_contract() -> bool:
    if not catalog.verify_contract() or not catalog.verify_mod_boundary() or not DomainTransaction.verify_contract():
        return false
    var proof = get_script().new()
    var tree := {"id": "test:tree", "kind": "tree", "radius": 11.0, "position": Vector2(50.0, 0.0)}
    var rock := {"id": "test:rock", "kind": "rock", "radius": 12.0, "position": Vector2(50.0, 0.0)}
    if proof.begin_harvest(tree, Vector2.ZERO, "h1").get("status") != "out_of_range":
        return false
    if proof.begin_harvest(tree, Vector2(50, 0), "h2").get("status") != "started":
        return false
    for i in range(15):
        proof.tick(0.1, Vector2(50, 0))
    if proof.count_item("core:wood_log") != 3 or not proof.depleted.has("test:tree"):
        return false
    if proof.begin_harvest(tree, Vector2(50, 0), "h2").get("status") != "complete":
        return false
    if proof.inventory.snapshot()["slots"].size() != 1 or proof.inventory.snapshot()["slots"][0]["slot"] != 1:
        return false
    if proof.begin_craft("c1", "core:planks_from_log").get("status") != "started":
        return false
    for i in range(5):
        proof.tick(0.1, Vector2(50, 0))
    if proof.count_item("core:wood_plank") != 4 or proof.count_item("core:wood_log") != 2:
        return false
    if proof.begin_craft("c2", "core:bench_from_planks").get("status") != "started":
        return false
    for i in range(10):
        proof.tick(0.1, Vector2(50, 0))
    if proof.count_item("core:workbench") != 1 or proof.count_item("core:wood_plank") != 0:
        return false
    if proof.begin_craft("c2", "core:bench_from_planks").get("status") != "crafted":
        return false
    if proof.begin_harvest(rock, Vector2(50, 0), "h3").get("status") != "started":
        return false
    proof.tick(0.1, Vector2(500, 0))
    if proof.harvest_commands["h3"]["status"] != "interrupted" or proof.depleted.has("test:rock"):
        return false
    var full = get_script().new()
    for i in range(CAPACITY):
        full.slots[i] = {"def_id": "core:wood_log", "count": 99}
    full.begin_harvest(rock, Vector2(50, 0), "full1")
    for i in range(20):
        full.tick(0.1, Vector2(50, 0))
    if full.harvest_commands["full1"]["status"] != "inventory_full" or full.depleted.has("test:rock"):
        return false
    # Building requires an explicit authoritative terrain+obstacles interface.
    if proof.building.preview("core:workbench", Vector2(50, 0), 0, Vector2.ZERO).get("status") != "terrain_unavailable":
        return false
    var uuid := "123e4567-e89b-42d3-a456-426614174000"
    if not proof.building.configure(uuid,
            Callable(DomainBuilding, "test_dry"), Callable(DomainBuilding, "test_obstacles")):
        return false
    if proof.building.preview("core:workbench", Vector2(50, 0), 0, Vector2.ZERO).get("status") != "valid":
        return false
    var placed: Dictionary = proof.building.place("b1", "123e4567-e89b-42d3-a456-426614174001",
        "core:workbench", Vector2(50, 0), 0, Vector2.ZERO, "test:player")
    if placed.get("status") != "placed" or proof.count_item("core:workbench") != 0:
        return false
    if proof.building.place("b1", "123e4567-e89b-42d3-a456-426614174001",
        "core:workbench", Vector2(50, 0), 0, Vector2.ZERO, "test:player").get("status") != "placed":
        return false
    if proof.building.snapshot()["world_revision"] != 1:
        return false
    if proof.building.station_tags_near(Vector2(50, 0), 40.0) != ["core:bench"]:
        return false
    print("TAMU_BUILDING_BOUNDARY_OK dry=true rotation=true idempotent=true unresolved_live_terrain=true")
    print("TAMU_GAMEPLAY_DOMAIN_OK inventory_slots=12 harvest_ticks=90/120 craft_ticks=30/60")
    return true
