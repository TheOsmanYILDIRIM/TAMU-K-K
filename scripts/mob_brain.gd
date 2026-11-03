extends RefCounted
# Deterministic 5 Hz decisions. World owns terrain, perception, movement and damage.
# Clocks are real seconds, never multiplied by the game's 30-second day cycle.
var definition: Resource
var rng := RandomNumberGenerator.new()
var state := "idle"
var state_time := 0.0
var health := 0.0
var hunger := 0.35
var thirst := 0.25
var energy := 1.0
var home := Vector2.ZERO
var goal := Vector2.ZERO
var threat_at := Vector2.ZERO
var threat_id := ""
var threat_memory := 0.0
var attack_timer := 0.0
var hit_timer := 0.0
var pursuit_time := 0.0
var calm_time := 0.0
var event_sequence := 0
var target_id := ""
var notice := ""
var initialized := false
var received_commands: Dictionary = {}
var command_order: Array[String] = []

func setup(config: Resource, seed_value: int, at: Vector2) -> bool:
    if config == null or not config.validate() or not at.is_finite():
        return false
    definition = config
    rng.seed = seed_value
    home = at
    goal = at
    health = float(config.max_health)
    hunger = rng.randf_range(0.28, 0.65)
    thirst = rng.randf_range(0.15, 0.48)
    initialized = true
    return true

func change(next: String) -> void:
    if state != next:
        state = next
        state_time = 0.0

func hurt(amount: float, attacker: String, at: Vector2, command: String) -> Dictionary:
    if not initialized or state in ["death", "dead"]:
        return {"ok": false, "status": "not_alive"}
    if command.is_empty() or attacker.is_empty() or not is_finite(amount) or amount <= 0.0 or not at.is_finite():
        return {"ok": false, "status": "invalid_damage"}
    if received_commands.has(command):
        return {"ok": false, "status": "duplicate"}
    received_commands[command] = true
    command_order.append(command)
    # A bounded session window, not a claim of persistent transaction idempotency.
    if command_order.size() > 128:
        received_commands.erase(command_order.pop_front())
    health = maxf(0.0, health - amount)
    threat_at = at
    threat_id = attacker
    threat_memory = float(definition.memory_seconds)
    calm_time = 0.0
    if health <= 0.0:
        change("death")
    else:
        hit_timer = 0.55
        change("hit")
    return {"ok": true, "status": "damaged", "health": health}

func _output(clip: String, speed: float = 0.0, action: String = "") -> Dictionary:
    var out := {"state": state, "clip": clip, "speed": speed, "goal": goal,
        "target_id": target_id, "action": action, "health": health, "notice": notice}
    if not action.is_empty():
        event_sequence += 1
        out["event_id"] = event_sequence
    return out

func _move(clip: String, speed: float) -> Dictionary:
    if health < float(definition.max_health) * 0.35 and clip != "run":
        return _output("limp", speed * 0.65)
    return _output(clip, speed)

func _arrived(s: Dictionary) -> bool:
    var position: Vector2 = s.get("position", home)
    return position.distance_to(goal) <= float(definition.interaction_reach)

func _set_target(s: Dictionary, name: String) -> bool:
    var item: Dictionary = s.get(name, {})
    if item.is_empty() or not item.get("position") is Vector2:
        return false
    goal = item["position"]
    target_id = str(item.get("id", ""))
    return goal.is_finite()

func tick(delta: float, senses: Dictionary) -> Dictionary:
    if not initialized or not is_finite(delta) or delta < 0.0 or delta > 0.5:
        return {"state": "invalid", "clip": "idle", "speed": 0.0, "goal": home, "action": ""}
    state_time += delta
    attack_timer = maxf(0.0, attack_timer - delta)
    hit_timer = maxf(0.0, hit_timer - delta)
    notice = ""
    if health <= 0.0:
        if state != "death" and state != "dead":
            change("death")
        if state == "death" and state_time >= 1.6:
            change("dead")
        return _output(state)
    hunger = clampf(hunger + float(definition.hunger_rate) * delta, 0.0, 1.0)
    thirst = clampf(thirst + float(definition.thirst_rate) * delta, 0.0, 1.0)
    var position: Vector2 = senses.get("position", home)
    var observed: Dictionary = senses.get("threat", {})
    var danger := false
    if not observed.is_empty():
        var seen_at: Vector2 = observed.get("position", position)
        if seen_at.is_finite():
            threat_at = seen_at
            threat_id = str(observed.get("id", "unknown"))
            threat_memory = float(definition.memory_seconds)
            danger = true
            calm_time = 0.0
    else:
        threat_memory = maxf(0.0, threat_memory - delta)
        calm_time += delta
    if hit_timer > 0.0:
        return _output("hit")
    if state == "hit":
        change("flee")
    var distance := position.distance_to(threat_at)
    var policy: Resource = definition.policy
    var low_health: bool = health / float(definition.max_health) < float(policy.retreat_health)
    var scared: bool = threat_memory > 0.0 and (distance < float(definition.panic_range) or state == "flee")
    var territorial: bool = policy.temperament == "territorial" and danger and distance < float(definition.alert_range)
    var cornered: bool = bool(senses.get("escape_blocked", false)) and threat_memory > 0.0
    if state in ["kick", "attack"]:
        if state_time >= 0.85:
            change("idle" if state == "attack" else ("flee" if low_health or policy.temperament == "timid" else "alert"))
        else:
            return _output("kick")
    if (cornered or territorial) and not low_health and distance <= float(definition.attack_range):
        if attack_timer <= 0.0 and bool(senses.get("can_attack_threat", false)):
            target_id = threat_id
            attack_timer = float(definition.attack_cooldown)
            change("kick")
            return _output("kick", 0.0, "defend")
    # Confident territorial animals warn, then drive an intruder out; they do not
    # pursue indefinitely outside home. Defensive grazers stand instead of hunting.
    if territorial and not low_health and float(policy.bravery) >= 0.5:
        if state not in ["territory_warn", "territory_chase"]:
            change("territory_warn")
        if state == "territory_warn" and state_time < 1.8:
            return _output("defend")
        if state_time < float(policy.pursuit_seconds) and position.distance_to(home) < float(definition.home_radius):
            change("territory_chase")
            goal = threat_at
            target_id = threat_id
            return _move("trot", float(definition.trot_speed))
        goal = home
        change("return_home")
        return _move("walk", float(definition.walk_speed))
    if danger and not low_health and policy.temperament == "defensive" and float(policy.bravery) >= 0.5:
        change("alert")
        return _output("defend")
    if scared or (danger and low_health):
        energy = maxf(0.0, energy - delta * 0.018)
        if state not in ["flee", "startle"]:
            change("startle")
        if state == "startle" and state_time < 0.65:
            return _output("startle")
        change("flee")
        if _set_target(senses, "escape"):
            return _move("run" if energy > 0.08 else "trot",
                float(definition.run_speed) if energy > 0.08 else float(definition.trot_speed))
        notice = "escape_unavailable"
        return _output("defend")
    if state == "flee":
        if distance < float(definition.safe_range) or calm_time < 2.5:
            if _set_target(senses, "escape"):
                return _move("run", float(definition.run_speed))
            return _output("alert_hold")
        change("stop_run")
    if state == "stop_run":
        if state_time < 0.8:
            return _output("stop_run")
        change("alert")
    if danger and distance < float(definition.alert_range) and policy.temperament in ["timid", "defensive", "territorial"]:
        change("alert")
        return _output("alert" if state_time < 1.8 else "alert_hold")
    if state == "alert" and (threat_memory > 0.0 or state_time < 1.8):
        return _output("alert_hold" if state_time >= 1.8 else "alert")
    # No searching through walls: candidates must be visible/heard by world perception.
    var prey: Dictionary = senses.get("prey", {})
    var prefers_carrion: bool = not senses.get("carrion", {}).is_empty() and float(policy.carrion_preference) >= 0.5
    var can_hunt: bool = policy.diet in ["carnivore", "omnivore"] and not low_health and not prefers_carrion
    if can_hunt and not prey.is_empty() and hunger >= float(policy.chase_hunger):
        pursuit_time += delta
        if pursuit_time <= float(policy.pursuit_seconds) and position.distance_to(home) < float(definition.home_radius):
            _set_target(senses, "prey")
            if position.distance_to(goal) <= float(definition.attack_range):
                if attack_timer <= 0.0:
                    attack_timer = float(definition.attack_cooldown)
                    change("attack")
                    return _output("kick", 0.0, "attack")
                return _output("defend")
            change("chase")
            return _move("run", float(definition.run_speed))
    elif state not in ["chase", "attack"]:
        pursuit_time = 0.0
    if state in ["chase", "attack", "territory_chase", "territory_warn"]:
        change("return_home")
    # Natural behavior has hysteresis and entry/exit clips, not rapid state flicker.
    match state:
        "graze_enter":
            if state_time >= 1.1:
                change("graze")
            return _output("graze_enter" if state == "graze_enter" else "graze")
        "graze":
            if not bool(senses.get("food_here", false)) or hunger <= 0.18 or state_time >= 10.0:
                change("graze_exit")
                return _output("graze_exit")
            hunger = maxf(0.0, hunger - delta * 0.10)
            energy = minf(1.0, energy + delta * 0.015)
            return _output("graze")
        "graze_exit":
            if state_time < 0.8:
                return _output("graze_exit")
            change("chew")
        "chew":
            if state_time < 2.0:
                return _output("chew")
            change("idle")
        "drink_enter":
            if not bool(senses.get("water_here", false)):
                change("idle")
            elif state_time >= 1.2:
                change("drink")
            else:
                return _output("drink_enter")
        "drink":
            if not bool(senses.get("water_here", false)) or thirst <= 0.12 or state_time >= 8.0:
                change("drink_exit")
                return _output("drink_exit")
            thirst = maxf(0.0, thirst - delta * 0.14)
            return _output("drink")
        "drink_exit":
            if state_time < 0.9:
                return _output("drink_exit")
            change("idle")
        "lie_down":
            if state_time < 1.5:
                return _output("lie_down")
            change("sleep" if bool(senses.get("night", false)) and definition.night_rest else "rest")
        "rest", "sleep":
            energy = minf(1.0, energy + delta * 0.045)
            if state_time >= 12.0 and (energy >= 0.95 or hunger > 0.8 or thirst > 0.8):
                change("wake_up" if state == "sleep" else "stand_up")
            return _output(state)
        "wake_up":
            if state_time < 1.6:
                return _output("wake_up")
            change("stand_up")
        "stand_up":
            if state_time < 1.3:
                return _output("stand_up")
            change("idle")
        "seek_food", "seek_water", "seek_carrion":
            if bool(senses.get("path_failed", false)) or state_time > 14.0:
                change("idle")
                notice = "resource_unreachable"
                return _output("sniff")
            if _arrived(senses):
                if state == "seek_water" and bool(senses.get("water_here", false)):
                    change("drink_enter")
                    return _output("drink_enter")
                var available_carrion: Dictionary = senses.get("carrion", {})
                if state == "seek_carrion" and str(available_carrion.get("id", "")) == target_id                         and not target_id.is_empty():
                    hunger = maxf(0.0, hunger - delta * 0.2)
                    if hunger < 0.18:
                        change("idle")
                    return _output("chew", 0.0, "scavenge")
                if state == "seek_food" and bool(senses.get("food_here", false)):
                    change("graze_enter")
                    return _output("graze_enter")
                change("idle")
                return _output("sniff")
            return _move("walk", float(definition.walk_speed))
        "return_home", "regroup", "wander":
            if _arrived(senses) or bool(senses.get("path_failed", false)) or state_time > 18.0:
                change("idle")
            else:
                return _move("trot" if state == "regroup" else "walk",
                    float(definition.trot_speed) if state == "regroup" else float(definition.walk_speed))
        "social_call", "groom", "shake", "ear_flick", "sniff", "idle_look":
            var durations := {"social_call": 1.6, "groom": 2.4, "shake": 1.0, "ear_flick": 1.2, "sniff": 1.8, "idle_look": 2.8}
            if state_time < float(durations[state]):
                return _output(state)
            change("idle")
    energy = minf(1.0, energy + delta * 0.008)
    if position.distance_to(home) > float(definition.home_radius):
        goal = home
        change("return_home")
        return _move("walk", float(definition.walk_speed))
    if thirst > 0.55 and _set_target(senses, "water"):
        change("seek_water")
        return _move("walk", float(definition.walk_speed))
    var carrion: Dictionary = senses.get("carrion", {})
    if policy.diet in ["scavenger", "carnivore", "omnivore"] and hunger > 0.4 and not carrion.is_empty():
        _set_target(senses, "carrion")
        change("seek_carrion")
        return _move("walk", float(definition.walk_speed))
    if policy.diet in ["herbivore", "omnivore"] and hunger > 0.45 and _set_target(senses, "food"):
        change("seek_food")
        return _move("walk", float(definition.walk_speed))
    if energy < 0.25 or (definition.night_rest and bool(senses.get("night", false)) and calm_time > 25.0 and energy < 0.85):
        change("lie_down")
        return _output("lie_down")
    var herd: Dictionary = senses.get("herd", {})
    if policy.social and not herd.is_empty() and position.distance_to(herd.get("position", position)) > float(definition.herd_distance):
        _set_target(senses, "herd")
        change("regroup")
        return _move("trot", float(definition.trot_speed))
    if state != "idle":
        change("idle")
    if state_time < 2.5:
        return _output("idle")
    var choice := rng.randi_range(0, 9)
    if choice < 4 and _set_target(senses, "wander"):
        change("wander")
        return _move("walk", float(definition.walk_speed))
    change(["idle_look", "sniff", "ear_flick", "groom", "shake", "social_call"][choice % 6])
    return _output(state)
