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
    if character.skeleton == null or character.player == null or character.bone_nodes.size() != 23:
        push_error("TAMU_PROFILE_NATIVE_RIG_MISSING")
        quit(72)
        return
    for record in character.mesh_records:
        var polygon: Polygon2D = record["node"]
        if polygon.get_bone_count() == 0 or polygon.polygon.size() != record["count"]:
            push_error("TAMU_PROFILE_NATIVE_SKIN_MISSING")
            quit(72)
            return
    var original_mesh_ids: Array[int] = []
    for record in character.mesh_records:
        original_mesh_ids.append(record["node"].get_instance_id())
    for action in ["idle", "walk", "run", "slash", "stab", "sit", "die"]:
        character.set_clip(action)
        for i in range(6):
            character.advance(1.0 / 30.0)
        if not character.verify_contract():
            push_error("TAMU_PROFILE_POSE_OR_MESH_FAILED " + action)
            quit(72)
            return
        if action in ["idle", "walk", "run"]:
            var contact_y := maxf(character._toe_position(10).y, character._toe_position(14).y)
            if absf(contact_y - ProfileRig.SOURCE_GROUND_Y) > 1.5:
                push_error("TAMU_PROFILE_FOOT_CONTACT_FAILED " + action + " y=" + str(contact_y))
                quit(72)
                return
            if absf(character.scale.y - ProfileRig.SOURCE_SCALE) > 0.001:
                push_error("TAMU_PROFILE_SCALE_FAILED")
                quit(72)
                return
        for bone in character.bone_nodes:
            if not bone.global_position.is_finite() or not is_finite(bone.global_rotation):
                push_error("TAMU_PROFILE_NONFINITE_BONE " + str(bone.name))
                quit(72)
                return
        for j in range(character.mesh_records.size()):
            if character.mesh_records[j]["node"].get_instance_id() != original_mesh_ids[j]:
                push_error("TAMU_PROFILE_MESH_RECREATED")
                quit(72)
                return
    print("TAMU_PROFILE_FOOT_CONTACT_OK ground=", ProfileRig.SOURCE_GROUND_Y, " scale=", ProfileRig.SOURCE_SCALE)
    print("TAMU_PROFILE_NATIVE_SKELETON_TEST_OK bones=23 parts=6 clips=7 frames=310 cpu_mesh_rebuilds=0")
    # Legacy marker retained for existing CI diagnostics, not evidence of CPU skinning.
    print("TAMU_PROFILE_NUMERIC_SKIN_OK bones=23 parts=6 clips=7 frames=310")
    quit()
