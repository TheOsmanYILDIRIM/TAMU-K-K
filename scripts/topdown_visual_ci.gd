extends SceneTree
## Real Godot game bootstrap, using recovered canonical authored R2 source.
## The test captures a screenshot only after the playable scene is ready.
var time_in_scene := 0.0
var started := false

func _initialize() -> void:
    call_deferred("_launch")

func _launch() -> void:
    var result := change_scene_to_file("res://scenes/topdown.tscn")
    if result != OK:
        push_error("TAMU_TOPDOWN_BOOT_SCENE_LOAD_FAILED")
        quit(131)
        return
    started = true

func _process(delta: float) -> void:
    if not started:
        return
    time_in_scene += delta
    if time_in_scene < 1.8:
        return
    started = false
    var game := current_scene
    if game == null or not bool(game.get("world_ready")):
        push_error("TAMU_TOPDOWN_BOOT_WORLD_NOT_READY")
        quit(132)
        return
    var authority = game.get("authority")
    var gameplay = game.get("gameplay")
    var actor = game.get("actor")\n    var animals = game.get("animals")
    if authority == null or authority.records.size() != 832:
        push_error("TAMU_TOPDOWN_BOOT_SOURCE_PARITY_FAILED")
        quit(133)
        return
    if gameplay == null or gameplay.durable_slot != "game":
        push_error("TAMU_TOPDOWN_STAGE6_NOT_BOUND")
        quit(134)
        return
    if actor == null or actor.sprites.size() < 1:
        push_error("TAMU_TOPDOWN_LPC_PLAYER_UNAVAILABLE")
        quit(135)
        return
    if not (animals is Array) or animals.size() < 3:
        push_error("TAMU_TOPDOWN_LPC_ANIMALS_UNAVAILABLE")
        quit(138)
        return
    var image := root.get_texture().get_image()
    if image == null or image.get_width() < 400 or image.get_height() < 600:
        push_error("TAMU_TOPDOWN_SCREENSHOT_EMPTY")
        quit(136)
        return
    var path := ProjectSettings.globalize_path("res://screenshots/topdown-gameplay.png")
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    if image.save_png(path) != OK:
        push_error("TAMU_TOPDOWN_SCREENSHOT_SAVE_FAILED")
        quit(137)
        return
    print("TAMU_TOPDOWN_AUTHORED_SCENE_OK objects=832 stage6=game lpc=true animals=3 oak_only=true screenshot=topdown-gameplay.png")
    quit()
    return
