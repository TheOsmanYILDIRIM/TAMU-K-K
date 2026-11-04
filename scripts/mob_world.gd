extends Node
# Attach as WorldScaffold/MobWorld. No player rig changes and no Stage6 schema writes.
# Session-only population until an approved durable mob/save contract exists.
signal mob_died(instance_id: String, species_id: String)
signal player_hit_requested(amount: float, from_world: Vector2, command_id: String)
signal mob_event(instance_id: String, event: String)
const Brain = preload("res://scripts/mob_brain.gd")
const LimboBridge = preload("res://scripts/mob_limboai_bridge.gd")
const Navigation = preload("res://scripts/mob_navigation.gd")
const Visual = preload("res://scripts/mob_visual.gd")
const WorldProjection = preload("res://scripts/world_projection.gd")
const VisualEnvironment = preload("res://scripts/visual_environment.gd")
const Collision = preload("res://scripts/r2_collision.gd")
const SPECIES = preload("res://data/catalog/mob_yaprakkulak.tres")
const FIXED_STEP := 0.2
# One shared mobile controller: max one creature decision per 100 ms.
# Animated sprites still update independently of AI; no BTPlayers/AStar on Android.
const LITE_DECISION_INTERVAL := 0.10
const LITE_ACTIVE_RADIUS := 440.0
const LITE_IDLE_INTERVAL := 2.0
const LITE_STEP_CAP := 9.0
const NAV_BUDGET_US := 1200
const MAX_AGENTS := 32
const SENSE_CELL := 128.0
const FORAGE_CELL := 40.0
var host: Node
var agents: Array[Dictionary] = []
var by_id: Dictionary = {}
var spatial: Dictionary = {}
var forage: Dictionary = {}
var noise: Array[Dictionary] = []
var accumulator := 0.0
var elapsed := 0.0
var attack_cooldown := 0.0
var command_sequence := 0
var nav_cursor := 0
var selected_id := ""
var bound := false
var region := ""
var max_frame_ai_usec := 0
var player_last := Vector2.ZERO
var player_velocity := Vector2.ZERO
var rng := RandomNumberGenerator.new()
const RESOURCE_STEP := 64.0
const RESOURCE_BUCKET := 256.0
const RESOURCE_INDEX_BUDGET_US := 650
var resource_chunks: Array = []
var resource_cursor := 0
var resource_index_ready := false
var resource_food: Dictionary = {}
var resource_water: Dictionary = {}
var resource_sample_count := 0
var think_cursor := 0
var movement_cursor := 0
var player_damage_receiver: Callable
# Reversible render/AI isolation, no gameplay IDs/save changes.
var isolation_mode := "full"
var last_process_usec := 0
# Previous-frame CPU phase timings. Keep all simulation and stable IDs unchanged.
var last_think_usec := 0
var last_scan_usec := 0
var last_navigation_usec := 0
var last_movement_usec := 0
var limbo_requested := false
var limbo_enabled := false
var lite_enabled := false
var lite_due := 0.0
var limbo_current_agent: Dictionary = {}
var limbo_current_index := -1
var diagnostic_layer: CanvasLayer
var diagnostic_label: Label
var diagnostic_elapsed := 0.0
var mobile_visibility_checked := false

func set_isolation_mode(mode: String) -> void:
    isolation_mode = mode
    # Restore authored creature visibility immediately on entering AI-off.
    # Otherwise the preceding render-off experiment would contaminate it.
    var resident: bool = host != null and host.get("region_chunks").has(region)
    var camera: Camera2D = null
    if host != null:
        camera = host.get_node_or_null("Camera2D") as Camera2D
    var viewport_rect := Rect2()
    if camera != null and VisualEnvironment.mobile_fast_mode():
        var extent := camera.get_viewport_rect().size * 0.5 / camera.zoom
        viewport_rect = Rect2(camera.get_screen_center_position() - extent, extent * 2.0).grow(160.0)
    for a in agents:
        var show: bool = resident and mode not in ["mob_visual_off", "mob_all_off"]
        if show and viewport_rect.has_area():
            show = viewport_rect.has_point(WorldProjection.to_screen(a["position"]))
        a["visual"].visible = show
    print("TAMU_MOB_ISOLATION mode=", mode, " agents=", agents.size())

func _ready() -> void:
    process_priority = 10
    call_deferred("_bind_host")

func _bind_host() -> void:
    host = get_parent()
    # Render diagnostics before dependency checks: a failed load on real Android
    # must be visible to the player, not silently treated as an empty world.
    if host != null and (OS.has_feature("mobile") or OS.get_environment("TAMU_LIMBOAI") == "1"):
        _install_mob_diagnostics()
        diagnostic_label.text = "MOB starting..."
    if host == null or host.get("authority") == null or host.get("gameplay") == null \
            or host.get("object_layer") == null or not SPECIES.validate():
        if diagnostic_label != null:
            diagnostic_label.text = "MOB ERROR: host/species unavailable"
        push_error("TAMU_MOB_HOST_UNAVAILABLE")
        set_process(false)
        return
    region = str(host.get("authority").region_id)
    if region.is_empty():
        if diagnostic_label != null:
            diagnostic_label.text = "MOB ERROR: invalid region"
        push_error("TAMU_MOB_REGION_INVALID")
        set_process(false)
        return
    rng.seed = 20261103
    player_last = host.get("actor_world")
    resource_chunks = host.get("available_chunks").keys()
    resource_chunks.sort()
    resource_cursor = 0
    resource_food.clear()
    resource_water.clear()
    resource_index_ready = resource_chunks.is_empty()
    # Preserve existing visual parity fixtures, but run mob-enabled case explicitly.
    if OS.get_environment("TAMU_VISUAL_CI") == "1" and OS.get_environment("TAMU_VISUAL_CASE") not in ["mobs", "combo"]:
        set_process(false)
        return
    limbo_requested = OS.get_environment("TAMU_LIMBOAI") == "1" or bool(ProjectSettings.get_setting("tamu/ai/use_limboai", false))
    # Native Android uses a fixed-cost state machine by default; explicit
    # developer override keeps full LimboAI available for A/B profiling.
    lite_enabled = OS.has_feature("mobile") and OS.get_environment("TAMU_AI_CLASSIC") != "1"
    if lite_enabled:
        print("TAMU_MOB_LITE_ACTIVE native_bt=false nav=direct_budgeted decisions=central")
    if diagnostic_layer == null and (limbo_requested or OS.has_feature("mobile")):
        _install_mob_diagnostics()
    # The authored Yaprakkulak population must not disappear when the
    # optional native Android extension cannot be loaded. MobBrain already
    # implements the same data-driven state/decision steps without LimboAI.
    limbo_enabled = limbo_requested and not lite_enabled and LimboBridge.available()
    if limbo_requested and not limbo_enabled and not lite_enabled:
        push_warning("TAMU_LIMBOAI_NATIVE_UNAVAILABLE: MobBrain fallback active")
        print("TAMU_MOB_NATIVE_FALLBACK reason=extension_unavailable")
    bound = true
    var count := 0
    for i in range(int(SPECIES.spawn_count)):
        var at: Vector2 = _find_spawn(player_last, i)
        if at.is_finite() and spawn(SPECIES, at, i):
            count += 1
    if count == 0:
        push_error("TAMU_MOB_NO_VALID_SPAWN: no valid authored terrain around player")
    _update_mob_diagnostics(true)
    if limbo_enabled:
        for agent in agents:
            var player: Node = LimboBridge.install(self, str(agent["id"]))
            if player == null:
                push_warning("TAMU_LIMBOAI_BT_SETUP_FAILED id=" + str(agent["id"]) + " MobBrain fallback active")
                print("TAMU_MOB_NATIVE_FALLBACK reason=bt_setup id=", agent["id"])
                limbo_enabled = false
                break
            agent["limbo_player"] = player
        if limbo_enabled:
            print("TAMU_LIMBOAI_ACTIVE players=", agents.size(), " mode=manual native=true")
    print("TAMU_MOB_READY species=core:yaprakkulak count=", count, " session_only=true")
    if not player_damage_receiver.is_valid():
        print("TAMU_MOB_PLAYER_DAMAGE_PORT_UNBOUND: no fabricated player health")

func _terrain(x: float, y: float) -> Dictionary:
    var p := Vector2(x, y)
    var key := "c_%d_%d" % [floori(x / 256.0), floori(y / 256.0)]
    if not host.get("available_chunks").has(key) or not host.get("world_bounds").has_point(p):
        return {"walkable": false, "feature": "outside_authored_region"}
    return host.get("authority").surface(x, y)

func _obstacles(x1: float, y1: float, x2: float, y2: float) -> Array:
    # Same canonical authored R2 + placed-building collision on Android and CI.
    # No alternate test path; no fail-closed sentinel from an unbound Stage6
    # callback may suppress all authored creature spawns.
    var solids: Array = host.get("authority").obstacles(x1, y1, x2, y2)
    var building = host.get("gameplay").building
    if building.placed.is_empty():
        return solids
    var query_box := Rect2(Vector2(x1, y1), Vector2(x2 - x1, y2 - y1))
    for id in building.placed:
        var placed_box: Rect2 = building.placed[id]["box"]
        if placed_box.intersects(query_box):
            solids.append({"id": str(id), "x": placed_box.position.x,
                "y": placed_box.position.y, "w": placed_box.size.x,
                "h": placed_box.size.y})
    return solids

func _stand(at: Vector2, radius: float) -> bool:
    if not at.is_finite():
        return false
    for offset in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
        var p: Vector2 = at + offset
        if not bool(_terrain(p.x, p.y).get("walkable", false)):
            return false
    for box in _obstacles(at.x-radius-0.5, at.y-radius-0.5, at.x+radius+0.5, at.y+radius+0.5):
        var rect := Rect2(float(box["x"]), float(box["y"]), float(box["w"]), float(box["h"])).grow(radius + 0.5)
        if rect.has_point(at):
            return false
    return true

func _find_spawn(origin: Vector2, index: int) -> Vector2:
    # Prefer safe authored ground inside the actual camera viewport.
    # Previously the 150+ unit search and distant chunk fallback could hide
    # all six creatures on a narrow portrait Android viewport.
    var camera: Camera2D = host.get_node_or_null("Camera2D") as Camera2D
    var screen_rect := Rect2()
    if camera != null:
        var half_size := camera.get_viewport_rect().size * 0.5 / camera.zoom
        screen_rect = Rect2(camera.get_screen_center_position() - half_size,
            half_size * 2.0).grow(-28.0)
    for ring in range(3):
        for attempt in range(24):
            var angle := float(index) * TAU / 6.0 + float(attempt) * TAU / 24.0
            var radius := 64.0 + float(index % 3) * 12.0 + float(ring) * 32.0
            var candidate := origin + Vector2.from_angle(angle) * radius
            if screen_rect.has_area() and not screen_rect.has_point(WorldProjection.to_screen(candidate)):
                continue
            if not _stand(candidate, float(SPECIES.radius)):
                continue
            var separate := true
            for other in agents:
                if candidate.distance_to(other["position"]) < float(SPECIES.radius) * 3.5:
                    separate = false
                    break
            if separate:
                print("TAMU_MOB_VISIBLE_SPAWN index=", index,
                    " world=", candidate, " player_distance=", snappedf(candidate.distance_to(origin), 0.1))
                return candidate
    for attempt in range(32):
        var angle := float(index) * 1.0472 + float(attempt) * 0.47
        var p := origin + Vector2.from_angle(angle) * (150.0 + 16.0 * attempt)
        if not _stand(p, float(SPECIES.radius)):
            continue
        var clear := true
        for other in agents:
            if p.distance_to(other["position"]) < float(SPECIES.radius) * 3.5:
                clear = false
                break
        if clear:
            return p
    # The player's starting shoreline can have no valid local candidates.
    # Fall back only to validated, authored R2 chunk cells; never fake walkability.
    var keys: Array = host.get("available_chunks").keys()
    keys.sort_custom(func(a, b):
        var pa: Vector2 = WorldProjection.chunk_center_from_key(str(a))
        var pb: Vector2 = WorldProjection.chunk_center_from_key(str(b))
        var da: float = pa.distance_squared_to(origin)
        var db: float = pb.distance_squared_to(origin)
        return str(a) < str(b) if is_equal_approx(da, db) else da < db)
    for key in keys:
        var center: Vector2 = WorldProjection.chunk_center_from_key(str(key))
        for offset in [Vector2.ZERO, Vector2(64, 0), Vector2(-64, 0),
                Vector2(0, 64), Vector2(0, -64)]:
            var candidate: Vector2 = center + offset
            if not _stand(candidate, float(SPECIES.radius)):
                continue
            var separate := true
            for other in agents:
                if candidate.distance_to(other["position"]) < float(SPECIES.radius) * 3.5:
                    separate = false
                    break
            if separate:
                print("TAMU_MOB_AUTHORED_SPAWN_FALLBACK key=", key, " species_index=", index)
                return candidate
    return Vector2(INF, INF)

func spawn(definition: Resource, at: Vector2, seed_offset: int = 0) -> bool:
    if not bound or agents.size() >= MAX_AGENTS or definition == null or not definition.validate() \
            or definition.rig == null or not _stand(at, float(definition.radius)):
        return false
    var brain = Brain.new()
    if not brain.setup(definition, 20261103 + seed_offset * 977, at):
        return false
    var visual = Visual.new()
    var instance_id := "mob-session:%s:%d" % [region, agents.size()]
    visual.name = "Yaprakkulak_%d" % agents.size()
    host.get("object_layer").add_child(visual)
    if not visual.configure(definition.rig, float(definition.art_scale)):
        visual.queue_free()
        return false
    var agent := {"id": instance_id, "definition": definition, "brain": brain, "visual": visual,
        "position": at, "velocity": Vector2.ZERO, "heading": Vector2.RIGHT, "navigator": Navigation.new(),
        "intent": {"speed": 0.0, "clip": "idle", "goal": at}, "route": [], "route_ready": false,
        "nav_goal": Vector2(INF, INF), "repath_at": 0.0, "stuck": 0.0, "escape_blocked": false,
        "food": {}, "water": {}, "wander": {}, "scan_at": 0.0, "last_state": "idle", "corpse_food": 1.0,
        "pending_attack": {}, "death_reported": false, "motion_accum": 0.0,
        "lite_next": 0.0, "lite_last": 0.0, "lite_turn": 0, "lite_blocked_until": 0.0}
    agents.append(agent)
    by_id[instance_id] = agent
    _place_visual(agent)
    return true

func _place_visual(a: Dictionary) -> void:
    var p: Vector2 = a["position"]
    var height: float = float(host.get("authority").terrain.height_at(p.x, p.y))
    # Y-sort at the same unraised ground anchor as the player.
    # Separately lift side-view artwork and ground contact by terrain height.
    a["visual"].position = WorldProjection.to_screen(p)
    a["visual"].set_ground_height(height * 0.35)

func _key(p: Vector2, size: float) -> Vector2i:
    return Vector2i(floori(p.x / size), floori(p.y / size))

func _rebuild_spatial() -> void:
    spatial.clear()
    for a in agents:
        var cell := _key(a["position"], SENSE_CELL)
        if not spatial.has(cell):
            spatial[cell] = []
        spatial[cell].append(a)

func _neighbors(at: Vector2, radius: float) -> Array:
    var out: Array = []
    var center := _key(at, SENSE_CELL)
    var n := ceili(radius / SENSE_CELL)
    for y in range(-n, n + 1):
        for x in range(-n, n + 1):
            for a in spatial.get(center + Vector2i(x, y), []):
                if at.distance_squared_to(a["position"]) <= radius * radius:
                    out.append(a)
    return out

func _line_of_sight(a: Vector2, b: Vector2) -> bool:
    var result: Dictionary = Collision.move(a, b - a, 0.0, Callable(self, "_obstacles"))
    return bool(result.get("ok", false)) and (result.get("position", a) as Vector2).distance_squared_to(b) < 1.0

func _perceived(a: Dictionary, at: Vector2, loudness: float) -> bool:
    var from: Vector2 = a["position"]
    var delta := at - from
    var config: Resource = a["definition"]
    var d := delta.length()
    if loudness > 0.0 and d <= float(config.hearing_range) * clampf(loudness, 0.0, 1.0):
        return true
    if d > float(config.vision_range):
        return false
    var heading: Vector2 = a["heading"]
    if d > 0.001 and heading.dot(delta / d) < cos(deg_to_rad(float(config.vision_degrees) * 0.5)):
        return false
    return _line_of_sight(from, at)

func add_noise(at: Vector2, strength: float = 1.0, source_id: String = "player") -> void:
    if not at.is_finite() or not is_finite(strength) or strength <= 0.0:
        return
    noise.append({"position": at, "loudness": minf(strength, 1.0), "id": source_id, "until": elapsed + 1.2})
    while noise.size() > 24:
        noise.pop_front()

func _food_available(p: Vector2) -> bool:
    var cell := _key(p, FORAGE_CELL)
    if not forage.has(cell):
        return true
    return float(forage[cell]["units"]) > 0.05 or elapsed >= float(forage[cell]["regrow_at"])

func _consume_grass(p: Vector2, delta: float) -> void:
    var cell := _key(p, FORAGE_CELL)
    if not forage.has(cell) or elapsed >= float(forage[cell]["regrow_at"]):
        forage[cell] = {"units": 1.0, "regrow_at": elapsed + 90.0}
    forage[cell]["units"] = maxf(0.0, float(forage[cell]["units"]) - delta * 0.07)

func _near_water(p: Vector2, reach: float) -> bool:
    for i in range(8):
        var q := p + Vector2.from_angle(i * TAU / 8.0) * reach
        if str(_terrain(q.x, q.y).get("feature", "")) == "water":
            return true
    return false

# Shared, session-local authored ecology index. Baked cooperatively only
# once, after R2 is ready, in small main-loop slices, without worker threads.
func _build_resource_index_step(budget_us: int = RESOURCE_INDEX_BUDGET_US) -> void:
    if resource_index_ready:
        return
    var started := Time.get_ticks_usec()
    while resource_cursor < resource_chunks.size() * 16:
        var cell: int = resource_cursor / 16
        var sample: int = resource_cursor % 16
        resource_cursor += 1
        var parts: PackedStringArray = str(resource_chunks[cell]).split("_")
        if parts.size() != 3:
            continue
        var chunk_x := int(parts[1])
        var chunk_y := int(parts[2])
        var at := Vector2(float(chunk_x) * 256.0 + (float(sample % 4) + 0.5) * RESOURCE_STEP,
            float(chunk_y) * 256.0 + (float(sample / 4) + 0.5) * RESOURCE_STEP)
        if not host.get("world_bounds").has_point(at):
            continue
        var surface := _terrain(at.x, at.y)
        if bool(surface.get("walkable", false)) and _stand(at, float(SPECIES.radius)):
            var bucket := Vector2i(floori(at.x / RESOURCE_BUCKET), floori(at.y / RESOURCE_BUCKET))
            if surface.get("feature") == "grass":
                if not resource_food.has(bucket):
                    resource_food[bucket] = []
                resource_food[bucket].append(at)
            # Eight shoreline samples are evaluated ONCE per static point.
            if _near_water(at, float(SPECIES.interaction_reach)):
                if not resource_water.has(bucket):
                    resource_water[bucket] = []
                resource_water[bucket].append(at)
        resource_sample_count += 1
        if Time.get_ticks_usec() - started >= budget_us:
            break
    if resource_cursor >= resource_chunks.size() * 16:
        resource_index_ready = true
        print("TAMU_MOB_SHARED_RESOURCE_INDEX_READY samples=", resource_sample_count,
            " food_buckets=", resource_food.size(), " water_buckets=", resource_water.size())


func _nearest_resource(index: Dictionary, at: Vector2, range_cells: int, require_food: bool) -> Dictionary:
    if not resource_index_ready:
        return {}
    var center := Vector2i(floori(at.x / RESOURCE_BUCKET), floori(at.y / RESOURCE_BUCKET))
    var best := INF
    var target := Vector2.ZERO
    for y in range(-range_cells, range_cells + 1):
        for x in range(-range_cells, range_cells + 1):
            for candidate_variant in index.get(center + Vector2i(x, y), []):
                var candidate: Vector2 = candidate_variant
                var distance := at.distance_squared_to(candidate)
                if distance >= best or (require_food and not _food_available(candidate)):
                    continue
                best = distance
                target = candidate
    return {} if not is_finite(best) else {"position": target}


func _refresh_resource_targets(a: Dictionary) -> void:
    if not resource_index_ready or elapsed < float(a["scan_at"]):
        return
    var p: Vector2 = a["position"]
    a["food"] = _nearest_resource(resource_food, p, 2, true)
    a["water"] = _nearest_resource(resource_water, p, 4, false)
    a["wander"] = _nearest_resource(resource_food, a["brain"].home, 2, false)
    a["scan_at"] = elapsed + 2.0


func _escape(a: Dictionary, threat: Vector2) -> Dictionary:
    var p: Vector2 = a["position"]
    # Only recompute the 7x6 ray escape search if threat/actor moved or
    # the 0.6s cache expired. Actual movement still uses live R2 sweeps.
    if limbo_enabled and elapsed < float(a.get("escape_refresh_at", -1.0)) \
            and p.distance_squared_to(a.get("escape_origin", Vector2(INF, INF))) < 18.0 * 18.0 \
            and threat.distance_squared_to(a.get("escape_threat", Vector2(INF, INF))) < 28.0 * 28.0:
        return a.get("escape_cache", {})
    var away := (p - threat).normalized()
    if away.length_squared() < 0.5:
        away = Vector2.RIGHT
    # Prefer the longest clear ray, rather than selecting an unreachable far point.
    var best := -INF
    var target := Vector2(INF, INF)
    for turn in [0.0, 0.45, -0.45, 0.9, -0.9, 1.5, -1.5]:
        var d: Vector2 = away.rotated(turn)
        var q := p
        for step in range(1, 7):
            var next := p + d * float(step) * 20.0
            if not _stand(next, float(a["definition"].radius)) or not _line_of_sight(q, next):
                break
            q = next
        var score := q.distance_to(threat) - absf(turn) * 10.0
        if q.distance_to(p) > 18.0 and score > best:
            best = score
            target = q
    a["escape_blocked"] = not target.is_finite()
    var result: Dictionary = {} if not target.is_finite() else {"position": target}
    if limbo_enabled:
        a["escape_cache"] = result
        a["escape_origin"] = p
        a["escape_threat"] = threat
        a["escape_refresh_at"] = elapsed + 0.6
    return result

func _senses(a: Dictionary) -> Dictionary:
    var p: Vector2 = a["position"]
    var config: Resource = a["definition"]
    var policy: Resource = config.policy
    var threat: Dictionary = {}
    var threat_score := INF
    var player_pos: Vector2 = host.get("actor_world")
    var player_noise := clampf(player_velocity.length() / 180.0, 0.0, 0.7)
    if policy.temperament in ["timid", "defensive", "territorial"] and _perceived(a, player_pos, player_noise):
        threat = {"id": "player", "position": player_pos}
        threat_score = p.distance_squared_to(player_pos)
    var center := Vector2.ZERO
    var count := 0
    var prey: Dictionary = {}
    var prey_distance := INF
    var carrion: Dictionary = {}
    var carrion_distance := INF
    for other in _neighbors(p, maxf(float(config.vision_range), 300.0)):
        if other["id"] == a["id"]:
            continue
        var at: Vector2 = other["position"]
        var d := p.distance_squared_to(at)
        var other_config: Resource = other["definition"]
        var alive: bool = float(other["brain"].health) > 0.0
        if not alive:
            if float(other["corpse_food"]) > 0.0 and d < carrion_distance and _perceived(a, at, 0.0):
                carrion = {"id": other["id"], "position": at}
                carrion_distance = d
            continue
        if other_config.id == config.id and policy.social:
            center += at
            count += 1
            # Alarm spreads a remembered threat location, never an invented omniscient target.
            if other["brain"].state in ["flee", "startle"] and other["brain"].threat_memory > 0.0 and d < 150.0 * 150.0:
                var alarm_at: Vector2 = other["brain"].threat_at
                if p.distance_squared_to(alarm_at) < threat_score:
                    threat = {"id": other["brain"].threat_id, "position": alarm_at}
                    threat_score = p.distance_squared_to(alarm_at)
        if other_config.policy.diet in ["carnivore", "omnivore"] and _perceived(a, at, 0.0) and d < threat_score:
            if policy.diet == "herbivore" or policy.diet == "scavenger":
                threat = {"id": other["id"], "position": at}
                threat_score = d
        if policy.diet in ["carnivore", "omnivore"] and _perceived(a, at, 0.0) and d < prey_distance:
            for tag in policy.prey_tags:
                if tag in other_config.tags:
                    prey = {"id": other["id"], "position": at}
                    prey_distance = d
                    break
    if policy.attack_player and _perceived(a, player_pos, 0.0) and p.distance_squared_to(player_pos) < prey_distance:
        prey = {"id": "player", "position": player_pos}
    for sound in noise:
        if str(sound["id"]) != a["id"] and _perceived(a, sound["position"], float(sound["loudness"])):
            var d: float = p.distance_squared_to(sound["position"])
            if d < threat_score:
                threat = {"id": sound["id"], "position": sound["position"]}
                threat_score = d
    var danger_at: Vector2 = threat.get("position", a["brain"].threat_at)
    var escape: Dictionary = {}
    if not threat.is_empty() or a["brain"].threat_memory > 0.0:
        escape = _escape(a, danger_at)
    var target: String = str(a["brain"].threat_id) if threat.is_empty() else str(threat["id"])
    _refresh_resource_targets(a)
    var food_here: bool = not a["food"].is_empty() and p.distance_to(a["food"]["position"]) <= float(config.interaction_reach) and _food_available(p)
    var water_here: bool = not a["water"].is_empty() and p.distance_to(a["water"]["position"]) <= float(config.interaction_reach)
    return {"position": p, "threat": threat, "escape": escape,
        "escape_blocked": bool(a["escape_blocked"]),
        "can_attack_threat": by_id.has(target) or (target == "player" and player_damage_receiver.is_valid()),
        "food": a["food"], "water": a["water"], "wander": a["wander"],
        "food_here": food_here,
        "water_here": water_here,
        "herd": {"position": center / float(count)} if count > 0 else {},
        "prey": prey, "carrion": carrion,
        "path_failed": a["navigator"].state == "failed",
        "night": float(host.get("day_clock")) < 6.0 or float(host.get("day_clock")) > 20.0}

# Mobile: constant-time sensing; the player's position is already owned by
# WorldScaffold, and resources are shared. Never raycast 7x6 escape rays,
# walk all creatures, or call native BTPlayer for a routine decision.
func _lite_senses(a: Dictionary, player_pos: Vector2) -> Dictionary:
    var at: Vector2 = a["position"]
    var definition: Resource = a["definition"]
    var brain = a["brain"]
    var player_distance2 := at.distance_squared_to(player_pos)
    var threat: Dictionary = {}
    var flee_point: Dictionary = {}
    var temperament: String = str(definition.policy.temperament)
    if temperament in ["timid", "defensive", "territorial"] \
            and player_distance2 <= float(definition.vision_range) * float(definition.vision_range):
        threat = {"id": "player", "position": player_pos}
    if not threat.is_empty() or brain.threat_memory > 0.0:
        var danger: Vector2 = threat.get("position", brain.threat_at)
        var away := (at - danger).normalized()
        if away.length_squared() < 0.1:
            away = Vector2.RIGHT
        flee_point = {"position": at + away * 110.0}
    if resource_index_ready and elapsed >= float(a["scan_at"]):
        # A cheap shared-bucket lookup replaces all live habitat probes.
        _refresh_resource_targets(a)
    var food_here := not a["food"].is_empty() and \
        at.distance_squared_to(a["food"]["position"]) <= pow(float(definition.interaction_reach), 2.0) \
        and _food_available(at)
    var water_here := not a["water"].is_empty() and \
        at.distance_squared_to(a["water"]["position"]) <= pow(float(definition.interaction_reach), 2.0)
    var fallback: Dictionary = a["wander"]
    if fallback.is_empty():
        var turn: int = int(a["lite_turn"])
        fallback = {"position": brain.home + Vector2.from_angle(float(turn % 8) * TAU / 8.0) * 70.0}
    return {"position": at, "threat": threat, "escape": flee_point,
        "escape_blocked": bool(a["escape_blocked"]),
        "can_attack_threat": player_damage_receiver.is_valid(),
        "food": a["food"], "water": a["water"], "wander": fallback,
        "food_here": food_here, "water_here": water_here,
        "herd": {}, "prey": {}, "carrion": {}, "path_failed": false,
        "night": float(host.get("day_clock")) < 6.0 or float(host.get("day_clock")) > 20.0}


func _lite_think() -> void:
    if agents.is_empty():
        return
    var started := Time.get_ticks_usec()
    var index: int = think_cursor % agents.size()
    think_cursor += 1
    var a: Dictionary = agents[index]
    var at: Vector2 = a["position"]
    var player_pos: Vector2 = host.get("actor_world")
    var active: bool = at.distance_squared_to(player_pos) <= LITE_ACTIVE_RADIUS * LITE_ACTIVE_RADIUS
    if elapsed < float(a["lite_next"]):
        last_think_usec = Time.get_ticks_usec() - started
        return
    # Every awake creature has at most a ~0.6s decision cadence with six
    # creatures; far creatures are kept asleep unless damaged or approached.
    a["lite_next"] = elapsed + (LITE_DECISION_INTERVAL if active else LITE_IDLE_INTERVAL)
    var since: float = minf(0.5, maxf(0.01, elapsed - float(a["lite_last"])))
    a["lite_last"] = elapsed
    var senses := _lite_senses(a, player_pos)
    a["intent"] = a["brain"].tick(since, senses)
    limbo_current_agent = a
    limbo_current_index = index
    _limbo_apply_step(since)
    limbo_current_agent = {}
    limbo_current_index = -1
    last_think_usec = Time.get_ticks_usec() - started
    max_frame_ai_usec = maxi(max_frame_ai_usec, last_think_usec)


# Cheap direct steering on Android. No grid generation or A*.
# Check only the next tiny step on the canonical R2; if blocked choose a
# short left/right detour and try again later, never teleport through solids.
func _lite_safe_step(at: Vector2, direction: Vector2, radius: float) -> bool:
    if not at.is_finite() or not host.get("world_bounds").has_point(at):
        return false
    if not bool(_terrain(at.x, at.y).get("walkable", false)):
        return false
    for obstacle in _obstacles(at.x-radius, at.y-radius, at.x+radius, at.y+radius):
        var box := Rect2(float(obstacle["x"]), float(obstacle["y"]),
            float(obstacle["w"]), float(obstacle["h"])).grow(radius)
        if box.has_point(at):
            return false
    return true


func _lite_move_agent(a: Dictionary, dt: float) -> void:
    var from: Vector2 = a["position"]
    var speed := float(a["intent"].get("speed", 0.0))
    var goal: Vector2 = a["intent"].get("goal", from)
    if a["brain"].health <= 0.0 or speed <= 0.0 or not goal.is_finite():
        if a["visual"].visible:
            a["visual"].advance(dt)
        return
    var towards := goal - from
    var reach := float(a["definition"].interaction_reach)
    if towards.length_squared() <= reach * reach:
        if a["visual"].visible:
            a["visual"].advance(dt)
        return
    var direction := towards.normalized()
    var distance := minf(LITE_STEP_CAP, minf(speed * dt, towards.length() - reach))
    var desired := from + direction * distance
    var moved := false
    if _lite_safe_step(desired, direction, float(a["definition"].radius)):
        moved = true
    elif elapsed >= float(a["lite_blocked_until"]):
        # One alternate check per movement tick. Turning direction alternates
        # to avoid full ray fans and expensive global replanning.
        var turn: float = 0.85 if int(a["lite_turn"]) % 2 == 0 else -0.85
        a["lite_turn"] = int(a["lite_turn"]) + 1
        var detour := from + direction.rotated(turn) * distance
        if _lite_safe_step(detour, direction, float(a["definition"].radius)):
            desired = detour
            moved = true
        else:
            a["lite_blocked_until"] = elapsed + 0.35
    if not moved:
        if a["visual"].visible:
            a["visual"].advance(dt)
        return
    a["position"] = desired
    a["heading"] = (desired - from).normalized()
    a["velocity"] = (desired - from) / maxf(0.001, dt)
    a["visual"].face(WorldProjection.to_screen(desired - from))
    _place_visual(a)
    if a["visual"].visible:
        a["visual"].advance(dt)


func _think() -> void:
    if agents.is_empty():
        return
    var started := Time.get_ticks_usec()
    var index: int = think_cursor % agents.size()
    if index == 0:
        _rebuild_spatial()
        noise = noise.filter(func(v: Dictionary) -> bool: return float(v["until"]) > elapsed)
        # Forage scans are always incremental. The previous MobBrain fallback
        # performed 28 complete obstacle/water probes in one decision frame.
    var a: Dictionary = agents[index]
    think_cursor += 1
    limbo_current_agent = a
    limbo_current_index = index
    if limbo_enabled:
        var player: Node = a.get("limbo_player", null)
        if player == null:
            push_warning("TAMU_LIMBOAI_BT_RUNTIME_MISSING: MobBrain fallback active")
            print("TAMU_MOB_NATIVE_FALLBACK reason=bt_runtime")
            limbo_enabled = false
        else:
            player.call("update", FIXED_STEP)
    if not limbo_enabled:
        _limbo_sense_step(FIXED_STEP)
        _limbo_decide_step(FIXED_STEP)
        _limbo_apply_step(FIXED_STEP)
    limbo_current_agent = {}
    limbo_current_index = -1
    last_think_usec = Time.get_ticks_usec() - started
    max_frame_ai_usec = maxi(max_frame_ai_usec, last_think_usec)

# Three real LimboAI BTCallMethod leaves in a C++ BTSequence.
# Deterministic MobBrain policy, event IDs and animation are unchanged.
func _limbo_sense_step(_delta: float) -> bool:
    var a: Dictionary = limbo_current_agent
    a["limbo_senses"] = _senses(a) if a["brain"].health > 0.0 else {"position": a["position"]}
    return true

func _limbo_decide_step(delta: float) -> bool:
    var a: Dictionary = limbo_current_agent
    a["intent"] = a["brain"].tick(delta, a["limbo_senses"])
    return true

func _limbo_apply_step(_delta: float) -> bool:
    var a: Dictionary = limbo_current_agent
    var index: int = limbo_current_index
    var intent: Dictionary = a["intent"]
    if intent["state"] != a["last_state"]:
        mob_event.emit(a["id"], intent["state"])
        a["last_state"] = intent["state"]
    if intent["state"] == "graze":
        _consume_grass(a["position"], FIXED_STEP)
    if intent["state"] in ["death", "dead"] and not a["death_reported"]:
        a["death_reported"] = true
        mob_died.emit(a["id"], a["definition"].id)
    var action := str(intent.get("action", ""))
    if action in ["attack", "defend"]:
        a["pending_attack"] = {"at": elapsed + 0.30, "target": str(intent["target_id"]),
            "command": "%s:%d" % [a["id"], int(intent["event_id"])]}
    elif action == "scavenge":
        var target_agent: Dictionary = by_id.get(str(intent["target_id"]), {})
        if not target_agent.is_empty() and target_agent["brain"].health <= 0.0 \
                and (a["position"] as Vector2).distance_to(target_agent["position"]) <= float(a["definition"].interaction_reach):
            target_agent["corpse_food"] = maxf(0.0, float(target_agent["corpse_food"]) - FIXED_STEP * 0.1)
    if intent["state"] == "chase" and a["definition"].policy.social:
        var prey_agent: Dictionary = by_id.get(str(intent["target_id"]), {})
        if not prey_agent.is_empty():
            var prey_pos: Vector2 = prey_agent["position"]
            if (a["position"] as Vector2).distance_to(prey_pos) > 65.0:
                var flank := prey_pos + Vector2.from_angle(float(index % 6) * TAU / 6.0) * 36.0
                if _stand(flank, float(a["definition"].radius)):
                    intent["goal"] = flank
    if not lite_enabled:
        _prepare_route(a)
    var requested_clip := str(intent["clip"])
    var mapped_clip := str(a["definition"].animation_map.get(requested_clip, requested_clip))
    a["visual"].play(mapped_clip)
    return true

func _prepare_route(a: Dictionary) -> void:
    var intent: Dictionary = a["intent"]
    var nav = a["navigator"]
    if float(intent.get("speed", 0.0)) <= 0.0:
        nav.cancel()
        a["route"].clear()
        a["route_ready"] = false
        return
    var target: Vector2 = intent["goal"]
    var changed: bool = target.distance_to(a["nav_goal"]) > 28.0
    if elapsed < float(a["repath_at"]) or (not changed and nav.state in ["searching", "ready"]):
        return
    a["repath_at"] = elapsed + (0.65 if intent["state"] in ["flee", "chase"] else 1.3)
    a["nav_goal"] = target
    a["route"].clear()
    a["route_ready"] = false
    nav.begin(a["position"], target, float(a["definition"].interaction_reach),
        float(a["definition"].radius), Callable(self, "_obstacles"), Callable(self, "_terrain"), host.get("world_bounds"))

func _advance_navigation(budget_us: int = NAV_BUDGET_US) -> void:
    if agents.is_empty():
        return
    var started := Time.get_ticks_usec()
    var visited := 0
    while visited < agents.size() and Time.get_ticks_usec() - started < budget_us:
        var a: Dictionary = agents[nav_cursor % agents.size()]
        nav_cursor += 1
        visited += 1
        var nav = a["navigator"]
        if nav.state == "searching":
            nav.advance(4, maxi(50, budget_us - (Time.get_ticks_usec() - started)))
        if nav.state == "ready" and not a["route_ready"]:
            a["route"] = nav.path.duplicate()
            a["route_ready"] = true

func _move_agent(a: Dictionary, dt: float) -> void:
    var route: Array = a["route"]
    var from: Vector2 = a["position"]
    var speed: float = float(a["intent"].get("speed", 0.0))
    while not route.is_empty() and from.distance_to(route[0]) < 3.0:
        route.pop_front()
    a["velocity"] = Vector2.ZERO
    if speed <= 0.0 or route.is_empty() or a["brain"].health <= 0.0:
        if a["visual"].visible:
            a["visual"].advance(dt)
        return
    var direction: Vector2 = (route[0] as Vector2) - from
    var delta := direction.limit_length(speed * dt)
    # Local body separation: never teleport or pass through another living actor.
    var separation := Vector2.ZERO
    for other in _neighbors(from, 35.0):
        if other["id"] == a["id"] or other["brain"].health <= 0.0:
            continue
        var diff: Vector2 = from - (other["position"] as Vector2)
        var minimum: float = float(a["definition"].radius) + float(other["definition"].radius) + 2.0
        if diff.length() < minimum and diff.length_squared() > 0.001:
            separation += diff.normalized() * (minimum - diff.length()) * 3.0 * dt
    delta += separation.limit_length(speed * dt * 0.3)
    var moved: Dictionary = Collision.move(from, delta, float(a["definition"].radius), Callable(self, "_obstacles"))
    var to: Vector2 = moved.get("position", from)
    # The last swept sample already validates the destination footprint.
    # Avoid re-running five terrain probes and the obstacle query at the same point.
    if not bool(moved.get("ok", false)):
        to = from
    else:
        var samples := maxi(1, ceili(from.distance_to(to) / 3.0))
        for step in range(1, samples + 1):
            if not _stand(from.lerp(to, float(step) / samples), float(a["definition"].radius)):
                to = from
                break
    for other in _neighbors(from, 40.0):
        if other["id"] == a["id"] or other["brain"].health <= 0.0:
            continue
        var minimum: float = float(a["definition"].radius) + float(other["definition"].radius)
        var other_at: Vector2 = other["position"]
        if to.distance_to(other_at) < minimum and to.distance_to(other_at) < from.distance_to(other_at):
            to = from
            break
    var travelled := from.distance_to(to)
    if travelled < 0.05:
        a["stuck"] = float(a["stuck"]) + dt
        if float(a["stuck"]) > 0.8:
            a["navigator"].cancel()
            a["route"].clear()
            a["escape_blocked"] = true
            a["nav_goal"] = Vector2(INF, INF)
    else:
        a["stuck"] = 0.0
        a["position"] = to
        a["velocity"] = (to - from) / maxf(dt, 0.001)
        a["heading"] = (to - from).normalized()
        a["visual"].face(WorldProjection.to_screen(to - from))
    _place_visual(a)
    # Match walk/run cycle speed to projected travel instead of sliding on the spot.
    var screen_speed: float = WorldProjection.to_screen(a["velocity"]).length()
    var reference_speed := 9.0 if a["intent"]["clip"] in ["walk", "limp"] else (26.0 if a["intent"]["clip"] == "trot" else 57.4)
    if a["visual"].visible:
        a["visual"].player.speed_scale = clampf(screen_speed / reference_speed, 0.25, 1.8)
        a["visual"].advance(dt)

func _resolve_attack(a: Dictionary) -> void:
    var pending: Dictionary = a["pending_attack"]
    if pending.is_empty() or elapsed < float(pending["at"]):
        return
    a["pending_attack"] = {}
    if a["brain"].health <= 0.0 or a["brain"].state == "hit":
        return
    var target_id := str(pending["target"])
    var at: Vector2 = host.get("actor_world") if target_id == "player" else by_id.get(target_id, {}).get("position", Vector2(INF, INF))
    if not at.is_finite() or (a["position"] as Vector2).distance_to(at) > float(a["definition"].attack_range) \
            or not _line_of_sight(a["position"], at):
        return
    var damage := float(a["definition"].attack_damage)
    if target_id == "player":
        # No fabricated player health/save field. Host combat must explicitly provide receiver.
        if player_damage_receiver.is_valid():
            player_damage_receiver.call(damage, a["position"], pending["command"])
            player_hit_requested.emit(damage, a["position"], pending["command"])
    elif by_id.has(target_id):
        by_id[target_id]["brain"].hurt(damage, a["id"], a["position"], str(pending["command"]))

func _feedback(text: String) -> void:
    var hud: Node = host.get("modular_hud")
    if hud != null:
        hud.call("_message", text)

func player_attack() -> void:
    if not bound or attack_cooldown > 0.0:
        return
    var p: Vector2 = host.get("actor_world")
    var target: Dictionary = by_id.get(selected_id, {})
    var best := 48.0
    if target.is_empty() or target["brain"].health <= 0.0:
        for candidate in _neighbors(p, 48.0):
            var d := p.distance_to(candidate["position"])
            if candidate["brain"].health > 0.0 and d < best:
                target = candidate
                best = d
    if target.is_empty() or p.distance_to(target["position"]) > 48.0:
        _feedback("HEDEF YOK / YAPRAKKULAK UZAKTA")
        return
    if not _line_of_sight(p, target["position"]):
        _feedback("HEDEFİN ÖNÜ KAPALI")
        return
    attack_cooldown = 0.7
    command_sequence += 1
    selected_id = target["id"]
    var result: Dictionary = target["brain"].hurt(9.0, "player", p, "player-mob:%d" % command_sequence)
    if result.get("ok", false):
        add_noise(p, 1.0)
        _feedback("YAPRAKKULAK  %d / %d" % [ceili(float(result["health"])), ceili(float(target["definition"].max_health))])

func _install_mob_diagnostics() -> void:
    diagnostic_layer = CanvasLayer.new()
    diagnostic_layer.name = "MobAndroidDiagnostics"
    diagnostic_layer.layer = 126
    host.add_child(diagnostic_layer)
    diagnostic_label = Label.new()
    diagnostic_label.name = "MobStatus"
    diagnostic_label.position = Vector2(12.0, 54.0)
    diagnostic_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
    diagnostic_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    diagnostic_label.add_theme_constant_override("shadow_offset_x", 1)
    diagnostic_label.add_theme_constant_override("shadow_offset_y", 1)
    diagnostic_layer.add_child(diagnostic_label)


func _update_mob_diagnostics(force: bool = false) -> void:
    if diagnostic_label == null:
        return
    var visible_count := 0
    var nearest_distance := INF
    var player_world: Vector2 = host.get("actor_world")
    for agent in agents:
        if agent["visual"].visible:
            visible_count += 1
        nearest_distance = minf(nearest_distance,
            (agent["position"] as Vector2).distance_to(player_world))
    var status := "LITE" if lite_enabled else ("ON" if limbo_enabled else ("FALLBACK" if limbo_requested else "OFF"))
    var nearest := "%.0f" % nearest_distance if is_finite(nearest_distance) else "-"
    diagnostic_label.text = "MOB %d/%d | LimboAI %s | nearest %s" % [
        visible_count, agents.size(), status, nearest]
    if force or diagnostic_elapsed >= 1.0:
        print("TAMU_MOB_ANDROID_STATUS total=", agents.size(),
            " visible=", visible_count, " limbo=", status,
            " nearest=", nearest, " region_loaded=", host.get("region_chunks").has(region))
        diagnostic_elapsed = 0.0
    if not mobile_visibility_checked and OS.get_environment("TAMU_VISUAL_CI") == "1" \
            and OS.get_environment("TAMU_VISUAL_CASE") in ["mobs", "combo"] \
            and VisualEnvironment.mobile_fast_mode() and Engine.get_process_frames() >= 30:
        mobile_visibility_checked = true
        if visible_count <= 0 or not limbo_enabled:
            push_error("TAMU_MOB_MOBILE_VISIBLE_FAILED total=%d visible=%d limbo=%s" %
                [agents.size(), visible_count, status])
        else:
            print("TAMU_MOB_MOBILE_VISIBLE_OK total=", agents.size(),
                " visible=", visible_count, " limbo=", status)


func _process(delta: float) -> void:
    if not bound:
        return
    diagnostic_elapsed += delta
    last_think_usec = 0
    last_scan_usec = 0
    last_navigation_usec = 0
    last_movement_usec = 0
    # A frozen creature stays rendered in mob_ai_off: isolate CPU only.
    if isolation_mode in ["mob_ai_off", "mob_all_off"]:
        _update_mob_diagnostics()
        last_process_usec = 0
        return
    var start_usec: int = Time.get_ticks_usec()
    var resident: bool = host.get("region_chunks").has(region)
    var mobile_fast := VisualEnvironment.mobile_fast_mode()
    var camera: Camera2D = host.get_node_or_null("Camera2D") as Camera2D
    var view := Rect2()
    if mobile_fast and camera != null:
        var half_size := camera.get_viewport_rect().size * 0.5 / camera.zoom
        view = Rect2(camera.get_screen_center_position() - half_size, half_size * 2.0).grow(160.0)
    for a in agents:
        var show: bool = resident and isolation_mode != "mob_visual_off"
        if mobile_fast and camera != null:
            show = show and view.has_point(WorldProjection.to_screen(a["position"]))
        if a["visual"].visible != show:
            a["visual"].visible = show
    if not resident:
        _update_mob_diagnostics()
        last_process_usec = Time.get_ticks_usec() - start_usec
        return
    _update_mob_diagnostics()
    var dt := minf(delta, 0.05)
    elapsed += dt
    attack_cooldown = maxf(0.0, attack_cooldown - dt)
    var pos: Vector2 = host.get("actor_world")
    player_velocity = (pos - player_last) / maxf(dt, 0.001)
    player_last = pos
    accumulator += dt
    var decision_interval := LITE_DECISION_INTERVAL if lite_enabled else FIXED_STEP / maxf(1.0, float(agents.size()))
    if accumulator >= decision_interval:
        accumulator = minf(accumulator - decision_interval, decision_interval)
        if lite_enabled:
            _lite_think()
        else:
            _think()
    # Build static locations once for every creature; no per-mob water survey.
    var scan_started := Time.get_ticks_usec()
    _build_resource_index_step()
    last_scan_usec = Time.get_ticks_usec() - scan_started
    var nav_started := Time.get_ticks_usec()
    if not lite_enabled:
        _advance_navigation(350 if mobile_fast else NAV_BUDGET_US)
    last_navigation_usec = Time.get_ticks_usec() - nav_started
    var movement_started := Time.get_ticks_usec()
    # Spread expensive swept collision and visual ticks across frames on mobile.
    # All agents accrue time; only two of six perform full collision per frame.
    for a in agents:
        a["motion_accum"] = minf(0.2, float(a["motion_accum"]) + dt)
    var move_count := agents.size() if not mobile_fast else mini(agents.size(), maxi(2, ceili(float(agents.size()) / 3.0)))
    for i in range(move_count):
        var a: Dictionary = agents[movement_cursor % agents.size()]
        movement_cursor += 1
        var distance: float = (a["position"] as Vector2).distance_to(pos)
        var near_hz := 12.0 if mobile_fast else 30.0
        var far_hz := 4.0 if mobile_fast else 10.0
        a["visual"].lod_seconds = 1.0 / (near_hz if distance < 650.0 else far_hz)
        var step := minf(0.1, float(a["motion_accum"]))
        a["motion_accum"] = maxf(0.0, float(a["motion_accum"]) - step)
        if step > 0.0:
            if lite_enabled:
                _lite_move_agent(a, step)
            else:
                _move_agent(a, step)
            _resolve_attack(a)
    last_movement_usec = Time.get_ticks_usec() - movement_started
    last_process_usec = Time.get_ticks_usec() - start_usec

func _exit_tree() -> void:
    for a in agents:
        if is_instance_valid(a["visual"]):
            a["visual"].queue_free()
