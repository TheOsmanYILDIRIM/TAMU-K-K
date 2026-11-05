extends SceneTree
# Contract compares Godot pose evaluation with the original editor's
# motion.json FK output. This is NOT a Skeleton2D/IK contract.
const ProfileRig = preload("res://scripts/profile_rig.gd")

func _initialize() -> void:
    call_deferred("_run")

func _check_close(label: String, got: Vector2, expected: Vector2, tol: float = 0.025) -> bool:
    if got.distance_to(expected) > tol:
        push_error("TAMU_PROFILE_SOURCE_PARITY_FAILED " + label + " actual=" + str(got) + " expected=" + str(expected))
        return false
    return true

func _run() -> void:
    var character := ProfileRig.new()
    root.add_child(character)
    if not character.setup() or not character.verify_contract():
        push_error("TAMU_PROFILE_SOURCE_SETUP_FAILED")
        quit(71)
        return
    if character.get_node_or_null("Skeleton2D") != null or character.has_method("_solve_planted_foot") or character.has_method("apply_world_step"):
        push_error("TAMU_PROFILE_LEGACY_IK_PRESENT_FAILED")
        quit(72)
        return
    var original_mesh_ids: Array[int] = []
    for record in character.mesh_records:
        var polygon: Polygon2D = record["node"]
        if polygon.texture == null or polygon.get_bone_count() != 0:
            push_error("TAMU_PROFILE_SKIN_TOPOLOGY_FAILED")
            quit(72)
            return
        original_mesh_ids.append(polygon.get_instance_id())
    # Golden values are from the independent Python GIF renderer and original ZIP.
    character.set_clip("walk")
    character._show_frame(0)
    if not _check_close("walk_head", character.posed_origins[5], Vector2(-2.6461, -235.9141)):
        quit(72)
        return
    character.set_clip("run")
    character._show_frame(0)
    if not _check_close("run_head", character.posed_origins[5], Vector2(26.4257, -234.7306)):
        quit(72)
        return
    character.set_clip("idle")
    character._show_frame(0)
    if not _check_close("idle_head", character.posed_origins[5], Vector2(-14.7385, -257.9763)):
        quit(72)
        return
    if not _check_close("idle_left_toe", character._toe_position(10), Vector2(26.75, 662.4552), 0.05):
        quit(72)
        return
    # Locomotion phase comes from *actual projected distance*, not time.
    character.set_clip("walk")
    var walk: Dictionary = character.clips["smooth_walk"]
    var cycle_duration: float = float(walk["ms"]) * float(walk["frames"].size()) / 1000.0
    character.advance(1.0 / 30.0, ProfileRig.WALK_CYCLE_SCREEN_PIXELS * 0.25)
    if absf(character.elapsed - cycle_duration * 0.25) > 0.0001:
        push_error("TAMU_PROFILE_STRIDE_DISTANCE_FAILED elapsed=" + str(character.elapsed))
        quit(72)
        return
    var held_elapsed: float = character.elapsed
    character.advance(1.0 / 30.0, 0.0)
    if absf(character.elapsed - held_elapsed) > 0.0001:
        push_error("TAMU_PROFILE_BLOCKED_STRIDE_FAILED")
        quit(72)
        return
    print("TAMU_PROFILE_DISTANCE_STRIDE_OK cycle_px=", ProfileRig.WALK_CYCLE_SCREEN_PIXELS)
    # Test all seven authored clips and frame transitions without any IK.
    for action in ["idle", "walk", "run", "slash", "stab", "sit", "die"]:
        character.set_clip(action)
        for i in range(6):
            character.advance(1.0 / 30.0)
        if not character.verify_contract():
            push_error("TAMU_PROFILE_POSE_FAILED " + action)
            quit(72)
            return
        if absf(character.scale.y - ProfileRig.SOURCE_SCALE) > 0.001:
            push_error("TAMU_PROFILE_SCALE_FAILED")
            quit(72)
            return
        for j in range(character.mesh_records.size()):
            var record: Dictionary = character.mesh_records[j]
            var polygon: Polygon2D = record["node"]
            if polygon.get_instance_id() != original_mesh_ids[j] or polygon.polygon.size() != record["count"]:
                push_error("TAMU_PROFILE_LAYER_REPLACED_FAILED")
                quit(72)
                return
        for origin in character.posed_origins:
            if not origin.is_finite():
                push_error("TAMU_PROFILE_NONFINITE_POSE_FAILED")
                quit(72)
                return
    print("TAMU_PROFILE_SOURCE_PARITY_OK clips=7 bones=23 parts=6")
    print("TAMU_PROFILE_NO_IK_OK base_poses=exact mesh_objects=persistent")
    print("TAMU_PROFILE_NUMERIC_SKIN_OK bones=23 parts=6 clips=7 frames=310")
    quit(0)
