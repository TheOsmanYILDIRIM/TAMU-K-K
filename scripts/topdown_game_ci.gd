extends SceneTree
const LPC = preload("res://scripts/lpc_sprite_actor.gd")
const Topdown = preload("res://scripts/topdown_game.gd")
const LPCAnimal = preload("res://scripts/lpc_animal_actor.gd")
const WorldProjection = preload("res://scripts/topdown_projection.gd")
const Gameplay = preload("res://scripts/gameplay_session.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if not WorldProjection.verify_contract():
        push_error("TAMU_TOPDOWN_PROJECTION_TEST_FAILED")
        quit(101)
        return
    var tex_path := "res://assets/lpc/body/bodies/male/walk.png"
    if not ResourceLoader.exists(tex_path):
        push_error("TAMU_LPC_RUNTIME_BODY_MISSING")
        quit(102)
        return
    var image := load(tex_path) as Texture2D
    if image == null or image.get_width() != 576 or image.get_height() != 256:
        push_error("TAMU_LPC_9X4_FRAME_LAYOUT_FAILED")
        quit(103)
        return
    var head_path := "res://assets/lpc/head/heads/human/male/walk.png"
    if not ResourceLoader.exists(head_path):
        push_error("TAMU_LPC_RUNTIME_HEAD_MISSING")
        quit(102)
        return
    var actor := LPC.new()
    actor.sheet_paths = PackedStringArray([tex_path, head_path])
    root.add_child(actor)
    if actor.sprites.size() < 2:
        push_error("TAMU_LPC_PLAYER_HEAD_OR_BODY_NOT_LOADED")
        quit(104)
        return
    if not actor.verify_animation_contract():
        push_error("TAMU_LPC_PLAYER_ANIMATION_VISIBILITY_FAILED")
        quit(104)
        return
    actor.set_motion(Vector2.UP, 0.125)
    if actor._direction_offset() != 0:
        push_error("TAMU_LPC_UP_DIRECTION_FAILED")
        quit(105)
        return
    actor.set_motion(Vector2.RIGHT, 0.125)
    if actor._direction_offset() != 3:
        push_error("TAMU_LPC_RIGHT_DIRECTION_FAILED")
        quit(106)
        return
    actor.play_action("slash", 0.45)
    if actor.clip != "slash":
        push_error("TAMU_LPC_ACTION_FAILED")
        quit(107)
        return
    actor.set_motion(Vector2.ZERO, 0.6)
    if actor.clip != "idle":
        push_error("TAMU_LPC_IDLE_FAILED")
        quit(108)
        return
    var wolf_path := "res://assets/lpc/animals/wolf/walk.png"
    if not ResourceLoader.exists(wolf_path):
        push_error("TAMU_LPC_ANIMAL_SHEET_MISSING")
        quit(109)
        return
    var animal := LPCAnimal.new()
    if animal.frame_size != Vector2i(32, 64):
        push_error("TAMU_LPC_ANIMAL_FRAME_LAYOUT_FAILED")
        quit(110)
        return
    root.add_child(animal)
    animal.configure(Vector2(96, 96), 0)
    if not animal.loaded or not animal.verify_animation_contract():
        push_error("TAMU_LPC_ANIMAL_ANIMATION_VISIBILITY_FAILED")
        quit(110)
        return
    for direction in [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]:
        animal.facing = direction
        for step in range(32):
            animal.elapsed = float(step) / animal.fps
            animal._draw_frame()
            var used: Rect2i = animal.current_frame_visible_bounds()
            if not animal.sprite.visible or not used.has_area() or used.size.x < 24 \
                    or used.size.y < 18 or used.size.x * used.size.y < 600 \
                    or animal.current_frame_opaque_pixels() < 160:
                push_error("TAMU_LPC_ANIMAL_FRAME_FRAGMENT direction=" + str(direction)
                    + " step=" + str(step) + " used=" + str(used))
                quit(110)
                return
    animal.queue_free()
    var gameplay := Gameplay.new()
    if not gameplay.verify_contract():
        push_error("TAMU_TOPDOWN_CANONICAL_GAMEPLAY_FAILED")
        quit(109)
        return
    var scene := load("res://scenes/topdown.tscn") as PackedScene
    if scene == null:
        push_error("TAMU_TOPDOWN_SCENE_IMPORT_FAILED")
        quit(110)
        return
    actor.queue_free()
    print("TAMU_TOPDOWN_LPC_GAMEPLAY_CONTRACT_OK body_head_layers=true four_directions=true clips=idle/walk/slash/spellcast wolf_nonempty_frames=true canonical_harvest_craft=true")
    if OS.get_environment("TAMU_PCK_HUD_CHECK") == "1":
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        if not bool(game.get("world_ready")):
            push_error("TAMU_TOPDOWN_PCK_HUD_WORLD_NOT_READY")
            quit(111)
            return
        var hud = game.get("modular_hud")
        if hud == null or not bool(hud.call("verify_contract")):
            push_error("TAMU_TOPDOWN_PCK_HUD_CONTRACT_FAILED")
            quit(112)
            return
        print("TAMU_TOPDOWN_PCK_HUD_CONTRACT_OK")
        var objects = game.get("objects")
        if not (objects is Array) or objects.is_empty() or not bool(game.call("_select_harvest", objects[0])):
            push_error("TAMU_TOPDOWN_PCK_SELECTION_OPEN_FAILED")
            quit(113)
            return
        var forest = game.get("forest_gui")
        var panel = forest.get("panel") as Control if forest != null else null
        var premium = forest.get("premium_card") if forest != null else null
        if forest == null or panel == null or not panel.visible or premium == null \
                or not bool(premium.call("verify_contract")):
            push_error("TAMU_TOPDOWN_PCK_SELECTION_UI_FAILED")
            quit(114)
            return
        print("TAMU_TOPDOWN_PCK_SELECTION_UI_OK")
        game.queue_free()
    quit()
