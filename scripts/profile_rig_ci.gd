extends SceneTree
# Rev2D source integration contract: 41 bones, six original PNG parts,
# idle/walk animation and distance-controlled stride. No fabricated back view.
const ProfileRig = preload("res://scripts/profile_rig.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("TAMU_REV2D_CHARACTER_FAILED " + reason)
    quit(72)

func _run() -> void:
    var character := ProfileRig.new()
    root.add_child(character)
    if not character.setup() or not character.verify_contract():
        _fail("setup")
        return
    if character.bones.size() != 41 or character.mesh_records.size() != 6:
        _fail("source_topology")
        return
    if character.clips.size() != 2 or not character.clips.has("idle") or not character.clips.has("walk"):
        _fail("source_clips")
        return
    if character.get_node_or_null("Skeleton2D") != null:
        _fail("unexpected_skeleton")
        return
    var ids: Array[int] = []
    for record in character.mesh_records:
        var polygon: Polygon2D = record["node"]
        if polygon.texture == null or polygon.get_bone_count() != 0 or polygon.polygon.size() != int(record["count"]):
            _fail("mesh")
            return
        ids.append(polygon.get_instance_id())
    character.set_clip("walk")
    if character.current_clip != "walk":
        _fail("walk_selection")
        return
    var duration := float(character.clips["walk"]["duration"])
    character.advance(1.0 / 30.0, ProfileRig.WALK_CYCLE_SCREEN_PIXELS * 0.25)
    if absf(character.elapsed - duration * 0.25) > 0.0001:
        _fail("distance_phase")
        return
    var held := character.elapsed
    character.advance(1.0 / 30.0, 0.0)
    if absf(character.elapsed - held) > 0.0001:
        _fail("blocked_stride")
        return
    character.set_clip("run")
    if character.current_clip != "walk":
        _fail("temporary_run_fallback")
        return
    character.set_clip("idle")
    if character.current_clip != "idle":
        _fail("idle_selection")
        return
    for i in range(64):
        var motion := 3.0 if i % 2 == 0 else 0.0
        character.set_clip("walk")
        character.advance(1.0 / 30.0, motion)
        if not character.verify_contract():
            _fail("pose")
            return
        for j in range(character.mesh_records.size()):
            var record: Dictionary = character.mesh_records[j]
            var layer: Polygon2D = record["node"]
            if layer.get_instance_id() != ids[j] or layer.polygon.size() != int(record["count"]):
                _fail("layer_replaced")
                return
            for pos in layer.polygon:
                if not pos.is_finite():
                    _fail("nonfinite_vertex")
                    return
    print("TAMU_REV2D_CHARACTER_OK bones=41 parts=6 clips=2 extracted=true")
    quit(0)
