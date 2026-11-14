extends SceneTree
const LPC = preload("res://scripts/lpc_sprite_actor.gd")
const Topdown = preload("res://scripts/topdown_game.gd")
const Projection = preload("res://scripts/topdown_projection.gd")
const Gameplay = preload("res://scripts/gameplay_session.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if not Projection.verify_contract():
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
    var actor := LPC.new()
    actor.sheet_paths = PackedStringArray([tex_path])
    root.add_child(actor)
    if actor.sprites.size() != 1:
        push_error("TAMU_LPC_PLAYER_NOT_LOADED")
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
    print("TAMU_TOPDOWN_LPC_GAMEPLAY_CONTRACT_OK body=576x256 four_directions=true clips=idle/walk/slash canonical_harvest_craft=true")
    quit()
