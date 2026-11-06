extends SceneTree
# Run in actual Godot 4.6: godot --headless --path . --script res://scripts/mob_contract_ci.gd
# This gate is supplied, NOT claimed executed by the authoring container.
const Brain = preload("res://scripts/mob_brain.gd")
const Definition = preload("res://scripts/mob_definition.gd")
const Policy = preload("res://scripts/mob_policy.gd")
const Visual = preload("res://scripts/mob_visual.gd")
const Navigation = preload("res://scripts/mob_navigation.gd")
const SPECIES = preload("res://data/catalog/mob_yaprakkulak.tres")
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error("TAMU_MOB_TEST_FAILED " + label)

func new_brain(policy_name: String = "herd_herbivore"):
    var d = Definition.new()
    d.policy = load("res://data/catalog/mob_policy_%s.tres" % policy_name)
    var b = Brain.new()
    check(b.setup(d, 71, Vector2.ZERO), "brain setup " + policy_name)
    return b

func senses() -> Dictionary:
    return {"position": Vector2.ZERO, "food": {}, "water": {}, "wander": {}, "food_here": false,
        "water_here": false, "night": false, "prey": {}, "carrion": {}, "threat": {}, "herd": {},
        "escape": {"position": Vector2(-120, 0)}, "can_attack_threat": true}

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    check(SPECIES.validate(), "species resource")
    check(SPECIES.rig.validate(), "weights/topology")
    check(SPECIES.rig.bones.size() == 29, "29 bones")
    check(SPECIES.rig.meshes.size() == 7, "7 meshes")
    check(SPECIES.rig.animations.get_animation_list().size() == 39, "38 clips plus RESET")
    var a = new_brain()
    var s := senses()
    a.hunger = 0.9
    s["food"] = {"position": Vector2.ZERO}
    s["food_here"] = true
    check(a.tick(0.2, s)["state"] == "seek_food", "seek plant food")
    check(a.tick(0.2, s)["clip"] == "graze_enter", "grazing entry")
    for i in range(10):
        a.tick(0.2, s)
    check(a.state == "graze" and a.hunger < 0.9, "grazing reduces hunger")
    s["threat"] = {"id": "player", "position": Vector2(15, 0)}
    check(a.tick(0.2, s)["clip"] == "startle", "threat interrupts grazing")
    for i in range(5):
        a.tick(0.2, s)
    check(a.state == "flee", "herbivore flees")
    check(a.tick(0.2, s)["action"] != "attack", "no herbivore hunting")
    a = new_brain()
    s = senses()
    a.thirst = 0.9
    s["water"] = {"position": Vector2.ZERO}
    s["water_here"] = true
    a.tick(0.2, s)
    a.tick(0.2, s)
    for i in range(10):
        a.tick(0.2, s)
    check(a.state == "drink" and a.thirst < 0.9, "verified bank drinking")
    a = new_brain()
    check(a.hurt(9.0, "player", Vector2(10, 0), "cmd1")["ok"], "hit applied")
    check(not a.hurt(9.0, "player", Vector2(10, 0), "cmd1")["ok"], "duplicate hit rejected")
    check(not a.hurt(NAN, "player", Vector2.ZERO, "bad")["ok"], "NaN damage rejected")
    a.hurt(999.0, "player", Vector2.ZERO, "kill")
    for i in range(20):
        a.tick(0.2, senses())
    check(a.state == "dead", "terminal death")
    check(not a.hurt(1.0, "player", Vector2.ZERO, "again")["ok"], "dead cannot revive or take damage")
    a = new_brain("territorial_herbivore")
    s = senses()
    s["threat"] = {"id": "player", "position": Vector2(70, 0)}
    check(a.tick(0.2, s)["clip"] == "defend", "territorial warning")
    a = new_brain("defensive_herbivore")
    check(a.tick(0.2, s)["clip"] == "defend", "defensive stand ground")
    for name in ["solitary_predator", "pack_predator"]:
        a = new_brain(name)
        a.hunger = 0.9
        s = senses()
        s["prey"] = {"id": "prey1", "position": Vector2(80, 0)}
        check(a.tick(0.2, s)["state"] == "chase", name + " hunts")
    a = new_brain("scavenger")
    a.hunger = 0.9
    s = senses()
    s["prey"] = {"id": "living", "position": Vector2(10, 0)}
    s["carrion"] = {"id": "dead", "position": Vector2(80, 0)}
    check(a.tick(0.2, s)["state"] == "seek_carrion", "scavenger chooses corpse not living prey")
    a = new_brain("opportunist_omnivore")
    a.hunger = 0.9
    check(a.tick(0.2, s)["state"] == "seek_carrion", "omnivore carrion preference")
    var b1 = new_brain()
    var b2 = new_brain()
    s = senses()
    s["wander"] = {"position": Vector2(80, 40)}
    for i in range(400):
        check(b1.tick(0.2, s) == b2.tick(0.2, s), "deterministic tick %d" % i)
    var nav = Navigation.new()
    check(nav.begin(Vector2.ZERO, Vector2(120, 0), 22.0, 8.0,
        Callable(self, "boxes"), Callable(self, "terrain"), Rect2(-256, -256, 512, 512)), "navigation begin")
    for i in range(300):
        nav.advance(4, 1000)
        if nav.state != "searching":
            break
    check(nav.state == "ready", "navigation goes around obstacle")
    for p in nav.path:
        check(nav._can_stand(p), "all path points walkable")
    check(not nav._clear_edge(Vector2(-16, 80), Vector2(16, 80)), "water edge blocked")
    var visual = Visual.new()
    root.add_child(visual)
    check(visual.configure(SPECIES.rig, 0.13), "native rig build")
    if visual.installed:
        visual.set_ground_height(17.5)
        check(visual.position.is_equal_approx(Vector2.ZERO), "mob foot root unchanged for Y-sort")
        check(is_equal_approx(visual.contact_shadow.position.y, -17.5), "mob shadow terrain foot")
        check(is_equal_approx(visual.artwork.position.y, -float(SPECIES.rig.ground_y) - 17.5 / 0.13), "mob art terrain offset")
        visual.face(Vector2(-15, 0))
        check(visual.contact_shadow.scale.is_equal_approx(Vector2.ONE), "mob contact shadow never mirrored")
        check(visual.get_node("Facing").scale.x < 0.0, "mob profile left-facing")

    if visual.installed:
        for clip in SPECIES.rig.animations.get_animation_list():
            if clip == "RESET":
                continue
            check(visual.play(clip, 0.0), "clip plays " + clip)
            visual.player.advance(0.25)
            for bone in visual.bone_nodes:
                check(bone.global_position.is_finite() and is_finite(bone.global_rotation), "finite bone " + str(bone.name))
    visual.free()
    if failures.is_empty():
        print("TAMU_MOB_CONTRACT_OK checks=", checks)
        quit(0)
    else:
        print("TAMU_MOB_CONTRACT_FAILED count=", failures.size())
        quit(1)

func boxes(_x1: float, _y1: float, _x2: float, _y2: float) -> Array:
    return [{"x": 42.0, "y": -20.0, "w": 20.0, "h": 40.0}]

func terrain(x: float, y: float) -> Dictionary:
    return {"walkable": not (absf(x) < 4.0 and y > 60.0), "feature": "grass"}
