extends SceneTree
## Native CI gate; not a substitute for Android visual/performance acceptance.
const SOURCE_SCENE := "res://scenes/tamu_3d_pilot.tscn"
const MANDATORY = [
    "res://addons/terrain_3d/plugin.cfg",
    "res://addons/asset_placer/plugin.cfg",
    "res://addons/phantom_camera/plugin.cfg",
    "res://addons/gloot/plugin.cfg",
    "res://addons/JehenoThirdPersonController/PlayerCharacter/player_character_scene.tscn",
    "res://assets/tamu_3d/forest.glb",
    "res://assets/tamu_3d/nature.glb",
    "res://assets/tamu_3d/crew.glb",
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    for path in MANDATORY:
        if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
            push_error("TAMU3D_MISSING_DEPENDENCY " + path)
            quit(10)
            return
    if not ClassDB.class_exists("Terrain3D"):
        push_error("TAMU3D_NATIVE_GDEXTENSION_NOT_LOADED")
        quit(11)
        return
    # PhantomCamera3D and Inventory are GDScript global classes, not ClassDB natives.
    if load("res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd") == null:
        push_error("TAMU3D_PHANTOM_SCRIPT_MISSING")
        quit(12)
        return
    if load("res://addons/gloot/core/inventory.gd") == null:
        push_error("TAMU3D_GLOOT_SCRIPT_MISSING")
        quit(13)
        return

    var scene: PackedScene = load(SOURCE_SCENE)
    if scene == null:
        push_error("TAMU3D_SCENE_FAILED_TO_LOAD")
        quit(14)
        return
    var instance: Node = scene.instantiate()
    root.add_child(instance)
    for i in 8:
        await process_frame
    if not bool(instance.get("ready_verified")):
        push_error("TAMU3D_PILOT_NOT_READY")
        quit(15)
        return
    var status: Dictionary = instance.get("system_status")
    for required in ["terrain", "player", "camera", "navigation", "models", "inventory"]:
        if not status.has(required):
            push_error("TAMU3D_UNWIRED_SYSTEM " + required)
            quit(16)
            return
    print("TAMU3D_NATIVE_BOOT_OK " + str(status))
    quit(0)
