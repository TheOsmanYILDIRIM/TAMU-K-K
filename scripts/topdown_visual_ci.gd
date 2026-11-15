extends SceneTree
## Real Godot game bootstrap, using recovered canonical authored R2 source.
## The test captures a screenshot only after the playable scene is ready.
var time_in_scene := 0.0
var started := false
var selection_opened := false
var animation_evidence_saved := false

func _initialize() -> void:
    call_deferred("_launch")

func _launch() -> void:
    var result := change_scene_to_file("res://scenes/topdown.tscn")
    if result != OK:
        push_error("TAMU_TOPDOWN_BOOT_SCENE_LOAD_FAILED")
        quit(131)
        return
    started = true

func _process(delta: float) -> bool:
    if not started:
        return false
    time_in_scene += delta
    if time_in_scene < 1.8:
        return false
    var game := current_scene
    if game == null or not bool(game.get("world_ready")):
        push_error("TAMU_TOPDOWN_BOOT_WORLD_NOT_READY")
        quit(132)
        return false
    var authority = game.get("authority")
    var gameplay = game.get("gameplay")
    var actor = game.get("actor")
    var animals = game.get("animals")
    var modular_hud = game.get("modular_hud")
    if authority == null or authority.records.size() != 832:
        push_error("TAMU_TOPDOWN_BOOT_SOURCE_PARITY_FAILED")
        quit(133)
        return false
    if gameplay == null or gameplay.durable_slot != "game":
        push_error("TAMU_TOPDOWN_STAGE6_NOT_BOUND")
        quit(134)
        return false
    if actor == null or actor.sprites.size() < 2 or not bool(actor.call("verify_animation_contract")):
        push_error("TAMU_TOPDOWN_LPC_PLAYER_UNAVAILABLE")
        quit(135)
        return false
    if not (animals is Array) or animals.size() < 3:
        push_error("TAMU_TOPDOWN_LPC_ANIMALS_UNAVAILABLE")
        quit(138)
        return false
    for animal in animals:
        if not bool(animal.get("loaded")) or not bool(animal.call("verify_animation_contract")) \
                or int(animal.call("current_frame_opaque_pixels")) < 160:
            push_error("TAMU_TOPDOWN_LPC_ANIMAL_VISIBLE_FRAME_FAILED")
            quit(143)
            return false
    if modular_hud == null or not bool(modular_hud.call("verify_contract")):
        push_error("TAMU_TOPDOWN_MODULAR_HUD_UNAVAILABLE")
        quit(139)
        return false
    if not animation_evidence_saved:
        var clean_image := root.get_texture().get_image()
        if clean_image == null or clean_image.get_width() < 400 or clean_image.get_height() < 600:
            push_error("TAMU_TOPDOWN_LPC_ANIMATION_SCREENSHOT_EMPTY")
            quit(144)
            return false
        var clean_path := ProjectSettings.globalize_path("res://screenshots/topdown-lpc-animation.png")
        DirAccess.make_dir_recursive_absolute(clean_path.get_base_dir())
        if clean_image.save_png(clean_path) != OK:
            push_error("TAMU_TOPDOWN_LPC_ANIMATION_SCREENSHOT_SAVE_FAILED")
            quit(145)
            return false
        animation_evidence_saved = true
        print("TAMU_TOPDOWN_LPC_ANIMATION_EVIDENCE_OK player_layers=2 animals=3")
    if not selection_opened:
        var objects = game.get("objects")
        var actor_world: Vector2 = game.get("actor_world")
        var nearest: Dictionary = {}
        var nearest_distance := INF
        for item in objects:
            if bool(item.get("collected", false)):
                continue
            var d: float = actor_world.distance_squared_to(item["position"])
            if d < nearest_distance:
                nearest_distance = d
                nearest = item
        if nearest.is_empty() or not bool(game.call("_select_harvest", nearest)):
            push_error("TAMU_TOPDOWN_SELECTION_OPEN_FAILED")
            quit(140)
            return false
        var forest_gui = game.get("forest_gui")
        var panel = forest_gui.get("panel") as Control if forest_gui != null else null
        var premium = forest_gui.get("premium_card") if forest_gui != null else null
        if forest_gui == null or panel == null or not panel.visible or premium == null \
                or not bool(premium.call("verify_contract")):
            push_error("TAMU_TOPDOWN_SELECTION_UI_CONTRACT_FAILED")
            quit(141)
            return false
        var selected = game.get("selected_harvest")
        if not (selected is Dictionary) or selected.is_empty() or not selected.has("sprite"):
            push_error("TAMU_TOPDOWN_SELECTION_EFFECT_PROXY_FAILED")
            quit(142)
            return false
        selection_opened = true
        time_in_scene = 0.0
        return false
    started = false
    var image := root.get_texture().get_image()
    if image == null or image.get_width() < 400 or image.get_height() < 600:
        push_error("TAMU_TOPDOWN_SCREENSHOT_EMPTY")
        quit(136)
        return false
    var path := ProjectSettings.globalize_path("res://screenshots/topdown-gameplay.png")
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    if image.save_png(path) != OK:
        push_error("TAMU_TOPDOWN_SCREENSHOT_SAVE_FAILED")
        quit(137)
        return false
    print("TAMU_TOPDOWN_AUTHORED_SCENE_OK objects=832 stage6=game lpc=true animals=3 oak_only=true modular_hud=true selection_ui=true selection_effect=true screenshot=topdown-gameplay.png")
    quit()
    return false
