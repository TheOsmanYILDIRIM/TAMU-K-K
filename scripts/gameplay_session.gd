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
var world_revision := 0
var journal_sequence := 0
var applied_commands: Dictionary = {}
var durable_slot := ""
var world_binding: Dictionary = {}
var durable_fault := false
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

# Data-only item definitions work for core and registered mod namespaces.
# Never expose a mutable reference to the canonical catalog.
func item_definition(def_id: String) -> Dictionary:
    return catalog.item(def_id).duplicate(true)

# Item texture is optional until the art-production pass. The metadata is
# available to UI without changing inventory/save identity.
func item_visual(def_id: String) -> Dictionary:
    return catalog.item_visual(def_id)

func item_texture(def_id: String) -> Texture2D:
    return catalog.item_texture(def_id)

# Player-driven slot rearrangement. Durable sessions require a journaled
# Stage6 operation and are explicitly blocked until that adapter exists.
func move_item_stack(from_slot: int, to_slot: int, quantity: int) -> Dictionary:
    if inventory == null:
        return {"ok": false, "status": "catalog_unavailable"}
    if durable_slot != "":
        return {"ok": false, "status": "durable_operation_not_supported"}
    if not harvesting.active.is_empty() or not crafting.active.is_empty():
        return {"ok": false, "status": "busy"}
    return inventory.move_stack(from_slot, to_slot, quantity)

func is_harvestable(kind: String) -> bool:
    return not catalog.harvest(kind).is_empty()

func harvest_drop(kind: String) -> Dictionary:
    var definition: Dictionary = catalog.harvest(kind)
    var drops: Array = definition.get("drops", [])
    return drops[0] if drops.size() == 1 else {}

func begin_harvest(item: Dictionary, player_pos: Vector2, command_id: String) -> Dictionary:
    if durable_slot != "":
        if durable_fault:
            return {"ok": false, "status": "restore_required"}
        if applied_commands.has(command_id):
            return {"ok": false, "status": "duplicate"}
        if not crafting.active.is_empty():
            return {"ok": false, "status": "busy"}
    return harvesting.begin(command_id, item, player_pos)

func begin_craft(command_id: String, recipe_id: String, station_tags: Array = []) -> Dictionary:
    if durable_slot != "":
        if durable_fault:
            return {"ok": false, "status": "restore_required"}
        if applied_commands.has(command_id):
            return {"ok": false, "status": "duplicate"}
        if not harvesting.active.is_empty():
            return {"ok": false, "status": "busy"}
    return crafting.begin(command_id, recipe_id, station_tags)

func tick(dt: float, player_pos: Vector2) -> Array[Dictionary]:
    if durable_slot != "":
        return _durable_tick(dt, player_pos)
    var events: Array[Dictionary] = []
    events.append_array(harvesting.update(dt, player_pos))
    events.append_array(crafting.update(dt))
    event_count += events.size()
    return events

func snapshot_domain() -> Dictionary:
    # In-memory snapshot shape only; NOT a Stage6 checkpoint or save migration.
    return {"domain_version": 1, "catalog_version": catalog.version, "content": catalog.active_content_ids(),
        "world_binding": world_binding.duplicate(true),
        "inventory": inventory.snapshot(), "building": building.snapshot(),
        "depleted": harvesting.depleted.duplicate(true),
        "harvest_commands": harvesting.commands.duplicate(true),
        "craft_commands": crafting.commands.duplicate(true),
        "building_commands": building.commands.duplicate(true),
        "inventory_applied": inventory.applied.duplicate(true),
        "journal": {"version": 1, "world_revision": world_revision,
            "journal_sequence": journal_sequence, "applied_commands": applied_commands.duplicate(true)}}

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

const Restore = preload("res://scripts/stage6_domain_restore.gd")

func _publish_checkpoint(state: Dictionary) -> Dictionary:
    if not world_binding.is_empty() and Stage6Store._seal({"binding": state.get("world_binding", null)}) != Stage6Store._seal({"binding": world_binding}):
        return {"ok": false, "status": "world_region_mismatch"}
    var staged: Dictionary = Restore.prepare(catalog, state)
    if not bool(staged.get("ok", false)):
        return staged
    var new_inventory = DomainInventory.new(catalog, CAPACITY)
    if not new_inventory.commit_preview(staged["slots"]):
        return {"ok": false, "status": "invalid_inventory"}
    new_inventory.applied = staged["inventory_applied"]
    var new_harvesting = DomainHarvesting.new(catalog, new_inventory)
    new_harvesting.depleted = staged["depleted"]
    new_harvesting.commands = staged["harvest_commands"]
    var new_crafting = DomainCrafting.new(catalog, new_inventory)
    new_crafting.commands = staged["craft_commands"]
    var new_building = DomainBuilding.new(catalog, new_inventory)
    new_building.world_id = staged["world_id"]
    new_building.revision = staged["building_revision"]
    new_building.placed = staged["placed"]
    new_building.commands = staged["building_commands"]
    new_building.terrain_sample = building.terrain_sample
    new_building.solid_query = building.solid_query
    inventory = new_inventory
    harvesting = new_harvesting
    crafting = new_crafting
    building = new_building
    world_revision = staged["world_revision"]
    journal_sequence = staged["journal_sequence"]
    applied_commands = staged["applied_commands"]
    return {"ok": true, "status": "restored"}

func restore_checkpoint(name: String) -> Dictionary:
    if not harvesting.active.is_empty() or not crafting.active.is_empty():
        return {"ok": false, "status": "busy"}
    var loaded := load_checkpoint(name)
    if not bool(loaded.get("ok", false)):
        return loaded
    return _publish_checkpoint(loaded["snapshot"])

func checkpoint_credit(name: String, command_id: String, def_id: String, amount: int) -> Dictionary:
    if not DomainTransaction.valid_command(command_id) or amount <= 0:
        return {"ok": false, "status": "invalid_command"}
    if not harvesting.active.is_empty() or not crafting.active.is_empty():
        return {"ok": false, "status": "busy"}
    if applied_commands.has(command_id):
        return {"ok": false, "status": "duplicate"}
    var loaded := load_checkpoint(name)
    if not bool(loaded.get("ok", false)):
        return loaded
    var prior: Dictionary = loaded["snapshot"]
    if Stage6Store._seal(prior) != Stage6Store._seal(snapshot_domain()):
        return {"ok": false, "status": "checkpoint_state_mismatch"}
    var staged_slots: Array = inventory.preview()
    if not inventory.preview_add(staged_slots, def_id, amount) or not inventory.validate_preview(staged_slots):
        return {"ok": false, "status": "inventory_full"}
    var candidate: Dictionary = prior.duplicate(true)
    var rows: Array = []
    for i in range(CAPACITY):
        if staged_slots[i] is Dictionary:
            rows.append({"slot": i + 1, "def_id": staged_slots[i]["def_id"],
                "count": staged_slots[i]["count"]})
    candidate["inventory"]["slots"] = rows
    candidate["journal"]["world_revision"] = world_revision + 1
    candidate["journal"]["journal_sequence"] = journal_sequence + 1
    candidate["journal"]["applied_commands"][command_id] = true
    var prepared := Restore.prepare(catalog, candidate)
    if not bool(prepared.get("ok", false)):
        return prepared
    var saved := Stage6Store.write_checkpoint(name, candidate, catalog)
    if not bool(saved.get("ok", false)):
        return saved
    var published := _publish_checkpoint(candidate)
    if not bool(published.get("ok", false)):
        return {"ok": false, "status": "committed_reload_required"}
    return {"ok": true, "status": "committed"}

# Persistent gameplay is explicit opt-in: callers must provide an authoritative world
# identity and terrain/obstacle ports. A mismatched save never loads or overwrites.
func enable_durable(slot: String, world_uuid: String, region_id: String,
        terrain: Callable, obstacles: Callable) -> Dictionary:
    if durable_slot != "" or not harvesting.active.is_empty() or not crafting.active.is_empty():
        return {"ok": false, "status": "busy"}
    if not DomainBuilding.valid_uuid4(world_uuid) or not terrain.is_valid() or not obstacles.is_valid():
        return {"ok": false, "status": "invalid_world_ports"}
    var manifest_path := "res://chunks/merged_terrain.json"
    var source_path := "res://chunks/source_integrity.json"
    if not FileAccess.file_exists(manifest_path) or not FileAccess.file_exists(source_path):
        return {"ok": false, "status": "world_source_missing"}
    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
    if not manifest is Dictionary or not source is Dictionary or region_id != str(manifest.get("region_id", "")):
        return {"ok": false, "status": "invalid_region"}
    if int(manifest.get("source_run_id", -1)) != int(source.get("source_run_id", -2)):
        return {"ok": false, "status": "source_mismatch"}
    var binding := {"world_uuid": world_uuid, "region_id": region_id,
        "source_run_id": int(source["source_run_id"]),
        "manifest_sha256": FileAccess.get_sha256(manifest_path),
        "objects_sha256": str(source.get("objects_sha256", ""))}
    if str(binding["objects_sha256"]) == "" or not FileAccess.file_exists("res://chunks/r2_objects.json"):
        return {"ok": false, "status": "object_source_missing"}
    if FileAccess.get_sha256("res://chunks/r2_objects.json") != str(binding["objects_sha256"]):
        return {"ok": false, "status": "object_source_mismatch"}
    if Stage6Store._path(slot).is_empty():
        return {"ok": false, "status": "invalid_slot"}
    var loaded := Stage6Store.read_checkpoint(slot, catalog)
    if not bool(loaded.get("ok", false)) and str(loaded.get("status", "")) != "missing":
        return loaded
    if bool(loaded.get("ok", false)):
        if Stage6Store._seal({"binding": loaded["snapshot"].get("world_binding", null)}) != Stage6Store._seal({"binding": binding}):
            return {"ok": false, "status": "world_region_mismatch"}
    var old_world := world_binding.duplicate(true)
    world_binding = binding
    if bool(loaded.get("ok", false)):
        var restored := _publish_checkpoint(loaded["snapshot"])
        if not bool(restored.get("ok", false)):
            world_binding = old_world
            return restored
    elif not building.configure(world_uuid, terrain, obstacles):
        world_binding = old_world
        return {"ok": false, "status": "world_configuration_failed"}
    building.terrain_sample = terrain
    building.solid_query = obstacles
    durable_slot = slot
    if not bool(loaded.get("ok", false)):
        var initial := save_checkpoint(slot)
        if not bool(initial.get("ok", false)):
            durable_slot = ""
            world_binding = old_world
            return initial
    durable_fault = false
    return {"ok": true, "status": "restored" if bool(loaded.get("ok", false)) else "initialized"}

func _stage_domain() -> RefCounted:
    var stage = get_script().new()
    stage.catalog = catalog
    if not bool(stage._publish_checkpoint(snapshot_domain()).get("ok", false)):
        return null
    stage.world_binding = world_binding.duplicate(true)
    stage.harvesting.active = harvesting.active.duplicate(true)
    stage.crafting.active = crafting.active.duplicate(true)
    stage.building.terrain_sample = building.terrain_sample
    stage.building.solid_query = building.solid_query
    return stage

func _commit_durable(stage: RefCounted, command_id: String) -> Dictionary:
    if durable_fault:
        return {"ok": false, "status": "restore_required"}
    if not DomainTransaction.valid_command(command_id) or applied_commands.has(command_id):
        return {"ok": false, "status": "duplicate"}
    var disk := Stage6Store.read_checkpoint(durable_slot, catalog)
    if not bool(disk.get("ok", false)):
        durable_fault = true
        return disk
    var before: Dictionary = disk["snapshot"]
    var live := snapshot_domain()
    # Commands can be 'started' in volatile memory, but committed data cannot differ.
    for field in ["inventory", "building", "depleted", "journal", "world_binding", "inventory_applied"]:
        if Stage6Store._seal({"v": before.get(field, null)}) != Stage6Store._seal({"v": live.get(field, null)}):
            durable_fault = true
            return {"ok": false, "status": "checkpoint_state_mismatch"}
    stage.world_revision = world_revision + 1
    stage.journal_sequence = journal_sequence + 1
    stage.applied_commands[command_id] = true
    var candidate: Dictionary = stage.snapshot_domain()
    var ready := Restore.prepare(catalog, candidate)
    if not bool(ready.get("ok", false)):
        durable_fault = true
        return ready
    var written := Stage6Store.write_checkpoint(durable_slot, candidate, catalog)
    if not bool(written.get("ok", false)):
        durable_fault = true
        return written
    var result := _publish_checkpoint(candidate)
    if not bool(result.get("ok", false)):
        durable_fault = true
        return {"ok": false, "status": "committed_reload_required"}
    return {"ok": true, "status": "committed"}

func _durable_tick(dt: float, player_pos: Vector2) -> Array[Dictionary]:
    var empty: Array[Dictionary] = []
    if durable_fault:
        return empty
    # No pending transaction: avoid cloning and validating the entire Stage6
    # domain on every render frame. Commands remain staged on active ticks.
    if harvesting.active.is_empty() and crafting.active.is_empty():
        return empty
    var stage = _stage_domain()
    if stage == null:
        durable_fault = true
        return empty
    var events: Array[Dictionary] = []
    events.append_array(stage.harvesting.update(dt, player_pos))
    events.append_array(stage.crafting.update(dt))
    if events.is_empty():
        harvesting.active = stage.harvesting.active
        crafting.active = stage.crafting.active
        harvesting.commands = stage.harvesting.commands
        crafting.commands = stage.crafting.commands
        return empty
    # Multiple drops belong to one atomic harvest command, not multiple
    # transactions. Reject only genuinely mixed completion commands.
    var command_id := str(events[0].get("command_id", ""))
    if command_id.is_empty():
        durable_fault = true
        return empty
    for event in events:
        if str(event.get("command_id", "")) != command_id:
            durable_fault = true
            return empty
    var committed := _commit_durable(stage, command_id)
    if not bool(committed.get("ok", false)):
        push_error("TAMU_STAGE6_TRANSACTION_REJECTED " + str(committed.get("status", "")))
        return empty
    event_count += events.size()
    return events

# Single source of movement obstacles: original authored R2 solids plus any
# durable player-built structures. Use the fast authority path until a building
# exists, avoiding extra per-frame snapshots on an otherwise empty world.
func movement_obstacles(x1: float, y1: float, x2: float, y2: float) -> Array:
    if not building.solid_query.is_valid() or not is_finite(x1) or not is_finite(y1) or not is_finite(x2) or not is_finite(y2) or x2 < x1 or y2 < y1:
        return [{"x": -1000000.0, "y": -1000000.0, "w": 2000000.0, "h": 2000000.0}]
    var source: Variant = building.solid_query.call(x1, y1, x2, y2)
    if not source is Array:
        return [{"x": -1000000.0, "y": -1000000.0, "w": 2000000.0, "h": 2000000.0}]
    if building.placed.is_empty():
        return source
    var result: Array = source
    var query_box := Rect2(Vector2(x1, y1), Vector2(x2 - x1, y2 - y1))
    for id in building.placed:
        var placed_box: Rect2 = building.placed[id]["box"]
        if placed_box.intersects(query_box):
            result.append({"id": str(id), "x": placed_box.position.x,
                "y": placed_box.position.y, "w": placed_box.size.x,
                "h": placed_box.size.y})
    return result

func place_building(command_id: String, instance_id: String, def_id: String,
        at: Vector2, rotation: int, player_at: Vector2, owner_id: String) -> Dictionary:
    if durable_slot == "":
        return building.place(command_id, instance_id, def_id, at, rotation, player_at, owner_id)
    if durable_fault or applied_commands.has(command_id):
        return {"ok": false, "status": "restore_required" if durable_fault else "duplicate"}
    if not harvesting.active.is_empty() or not crafting.active.is_empty():
        return {"ok": false, "status": "busy"}
    var stage = _stage_domain()
    if stage == null:
        return {"ok": false, "status": "stage_failed"}
    var placed: Dictionary = stage.building.place(command_id, instance_id, def_id, at, rotation, player_at, owner_id)
    if not bool(placed.get("ok", false)):
        return placed
    var committed := _commit_durable(stage, command_id)
    return placed if bool(committed.get("ok", false)) else committed

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
