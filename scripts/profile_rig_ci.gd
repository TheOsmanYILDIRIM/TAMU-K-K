extends SceneTree
const ProfileRig = preload("res://scripts/profile_rig.gd")
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var character := ProfileRig.new()
    root.add_child(character)
    if not character.setup():
        push_error("TAMU_PROFILE_SOURCE_SETUP_FAILED")
        quit(71)
        return
    for action in ["idle", "walk", "run", "slash", "stab", "sit", "die"]:
        character.set_clip(action)
        for i in range(6):
            character.advance(1.0 / 30.0)
        if not character.verify_contract():
            push_error("TAMU_PROFILE_POSE_OR_MESH_FAILED " + action)
            quit(72)
            return
    print("TAMU_PROFILE_NUMERIC_SKIN_OK bones=23 parts=6 clips=7 frames=310")
    quit()
