extends Node2D
# Native Godot 4.6 weighted 2D rig: same Skeleton2D/Bone2D/Polygon2D/
# AnimationPlayer architecture used by Yaprakkulak. Six original PNGs.
# Geometry and bone weights are allocated once; no per-frame ArrayMesh rebuild.
const ROOT := "res://assets/profile_character/"
# Original source spans about 1,060 px from head to the lowest planted toe.
# 0.067 produces ~71 px at game zoom, matching the authored 72 px player.
const SOURCE_SCALE := 0.067
const SOURCE_GROUND_Y := 665.0
const SKIN_HZ := 30.0
const FOOT_GROUND_TOLERANCE := 12.0
const MAX_GROUND_CORRECTION := 50.0
# One planted foot is constrained in world space by two-joint CCD while
# its other leg swings. The torso/root never inherits a foot's lateral shift.
const CONTACT_BAND := 12.0
const IK_MAX_TURN := 0.42
const IK_REACH_LIMIT := 78.0
const MOBILE_SKIN_HZ := 30.0
const CLIP_ALIAS := {
    "walk": "smooth_walk", "run": "smooth_run", "idle": "idle",
    "slash": "slash", "stab": "stab", "die": "die", "sit": "sit",
}
var source: Dictionary = {}
var bones: Array = []
var clips: Dictionary = {}
var bone_nodes: Array[Bone2D] = []
var mesh_records: Array[Dictionary] = []
var skeleton: Skeleton2D
var player: AnimationPlayer
var current_clip := "idle"
var configured := false
var render_accumulator := 0.0
var draw_updates := 0
var ground_correction := 0.0
var locomotion_rate := 1.0
var last_contact_y := SOURCE_GROUND_Y
var foot_contact_count := 0
var planted_foot := -1
var planted_at := Vector2.ZERO
var traveled_screen := Vector2.ZERO
var grounding_error := 0.0

func setup() -> bool:
    if configured:
        return false
    var path := ROOT + "motion.json"
    if not FileAccess.file_exists(path):
        push_error("TAMU_PROFILE_MOTION_MISSING")
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary or parsed.get("format") != "tamu-editor-assets/1":
        push_error("TAMU_PROFILE_MOTION_INVALID")
        return false
    source = parsed
    bones = source.get("bones", [])
    var order: Array = source.get("order", [])
    var definitions: Array = source.get("clips", [])
    if bones.size() != 23 or order.size() != 6 or definitions.size() != 7:
        push_error("TAMU_PROFILE_RIG_TOPOLOGY_INVALID")
        return false
    skeleton = Skeleton2D.new()
    skeleton.name = "Skeleton2D"
    add_child(skeleton)
    var known := {}
    var bind_origins: Array[Vector2] = []
    for i in range(bones.size()):
        var b: Dictionary = bones[i]
        if not b.has("bind_start") or not b.has("bind_end"):
            return false
        var parent_name: Variant = b.get("parent")
        var parent_index := -1
        if parent_name != null:
            parent_index = int(known.get(str(parent_name), -1))
            if parent_index < 0:
                push_error("TAMU_PROFILE_RIG_PARENT_ORDER_INVALID")
                return false
        var start: Array = b["bind_start"]
        var finish: Array = b["bind_end"]
        var origin := Vector2(float(start[0]), float(start[1]))
        var target := Vector2(float(finish[0]), float(finish[1]))
        var bone := Bone2D.new()
        # Source names contain '/', which Godot node names cannot contain.
        bone.name = "Joint_%02d" % i
        bone.position = origin - (bind_origins[parent_index] if parent_index >= 0 else Vector2.ZERO)
        bone.rest = bone.transform
        bone.set_autocalculate_length_and_angle(false)
        bone.set_length(maxf(0.1, origin.distance_to(target)))
        if parent_index >= 0:
            bone_nodes[parent_index].add_child(bone)
        else:
            skeleton.add_child(bone)
        bind_origins.append(origin)
        bone_nodes.append(bone)
        known[str(b["name"])] = i
    for name in order:
        var filename := ROOT + str(name) + ".png"
        if not ResourceLoader.exists(filename):
            push_error("TAMU_PROFILE_ORIGINAL_PART_MISSING " + filename)
            return false
        var texture: Texture2D = load(filename)
        var data: Dictionary = source.get("meshes", {}).get(name, {})
        var raw_points: Array = data.get("bind_vertices", [])
        var raw_uv: Array = data.get("uv", [])
        var influences: Array = data.get("vertex_influences", [])
        var triangles: Array = data.get("triangles", [])
        var n := raw_points.size()
        if texture == null or n == 0 or raw_uv.size() != n or influences.size() != n:
            push_error("TAMU_PROFILE_SKIN_VERTICES_INVALID")
            return false
        var polygon := Polygon2D.new()
        polygon.name = "Original_" + str(name)
        polygon.texture = texture
        polygon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        var points := PackedVector2Array()
        var uvs := PackedVector2Array()
        for i in range(n):
            points.append(Vector2(float(raw_points[i][0]), float(raw_points[i][1])))
            uvs.append(Vector2(float(raw_uv[i][0]), float(raw_uv[i][1])))
        polygon.polygon = points
        polygon.uv = uvs
        var triangle_list: Array[PackedInt32Array] = []
        for tri in triangles:
            if tri.size() != 3:
                return false
            var indices := PackedInt32Array()
            for v in tri:
                var index := int(v)
                if index < 0 or index >= n:
                    push_error("TAMU_PROFILE_TRIANGLE_OUT_OF_RANGE")
                    return false
                indices.append(index)
            triangle_list.append(indices)
        polygon.polygons = triangle_list
        add_child(polygon)
        polygon.skeleton = polygon.get_path_to(skeleton)
        var per_bone: Array[PackedFloat32Array] = []
        var totals := PackedFloat32Array()
        totals.resize(n)
        for _j in range(bones.size()):
            var weights := PackedFloat32Array()
            weights.resize(n)
            per_bone.append(weights)
        for v in range(n):
            for entry in influences[v]:
                var bi := int(entry[0])
                var weight := float(entry[1])
                if bi < 0 or bi >= bones.size() or not is_finite(weight) or weight < 0.0:
                    push_error("TAMU_PROFILE_SKIN_WEIGHT_INVALID")
                    return false
                per_bone[bi][v] += weight
                totals[v] += weight
            if absf(totals[v] - 1.0) > 0.001:
                push_error("TAMU_PROFILE_SKIN_WEIGHT_SUM_INVALID")
                return false
        for j in range(bones.size()):
            var used := false
            for weight in per_bone[j]:
                if weight > 0.0:
                    used = true
                    break
            if used:
                polygon.add_bone(skeleton.get_path_to(bone_nodes[j]), per_bone[j])
        mesh_records.append({"node": polygon, "count": n, "texture": texture})
    var library := AnimationLibrary.new()
    for clip in definitions:
        if not clip is Dictionary or clip.get("frames", []).is_empty():
            return false
        var key := str(clip["id"])
        var frames: Array = clip["frames"]
        if clips.has(key):
            return false
        var frame_interval := float(clip["ms"]) / 1000.0
        if frame_interval <= 0.0:
            return false
        var animation := Animation.new()
        animation.length = maxf(0.001, float(frames.size()) * frame_interval)
        animation.loop_mode = Animation.LOOP_LINEAR if bool(clip["loop"]) else Animation.LOOP_NONE
        var root_track := animation.add_track(Animation.TYPE_VALUE)
        animation.track_set_path(root_track, NodePath("Skeleton2D:position"))
        var rotation_tracks: Array[int] = []
        for bone in bone_nodes:
            var track := animation.add_track(Animation.TYPE_VALUE)
            animation.track_set_path(track, NodePath(str(get_path_to(bone)) + ":rotation"))
            # The source already contains dense sampled motion (26-42 ms/pose).
            # Cubic bone interpolation invents intermediate rotations and can
            # overshoot at knee, hip and loop seams; honor the authored samples.
            animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
            rotation_tracks.append(track)
        var last_angles := PackedFloat32Array()
        last_angles.resize(bones.size())
        for i in range(frames.size()):
            var frame: Dictionary = frames[i]
            var angles: Array = frame.get("a", [])
            var root_values: Array = frame.get("root", [])
            if angles.size() != bones.size() or root_values.size() != 2:
                return false
            var time := float(i) * frame_interval
            animation.track_insert_key(root_track, time, Vector2(float(root_values[0]), float(root_values[1])) - bind_origins[0])
            for j in range(angles.size()):
                var angle := float(angles[j])
                if i > 0:
                    angle = last_angles[j] + wrapf(angle - last_angles[j], -PI, PI)
                last_angles[j] = angle
                animation.track_insert_key(rotation_tracks[j], time, angle)
        if library.add_animation(key, animation) != OK:
            push_error("TAMU_PROFILE_ANIMATION_INVALID " + key)
            return false
        clips[key] = clip
    player = AnimationPlayer.new()
    player.name = "AnimationPlayer"
    add_child(player)
    player.root_node = NodePath("..")
    player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    if player.add_animation_library("", library) != OK:
        return false
    scale = Vector2.ONE * SOURCE_SCALE
    position = Vector2(0.0, -SOURCE_GROUND_Y * SOURCE_SCALE)
    configured = true
    player.play("idle", 0.0)
    player.advance(0.0)
    _correct_foot_grounding()
    draw_updates = 1
    print("TAMU_PROFILE_NATIVE_SKELETON_OK bones=23 parts=6 clips=7 frames=310 mesh_rebuilds=0")
    return true

func set_clip(action: String) -> void:
    var next: String = str(CLIP_ALIAS.get(action, "idle"))
    if configured and next != current_clip and player.has_animation(next):
        current_clip = next
        render_accumulator = 0.0
        ground_correction = 0.0
        planted_foot = -1
        traveled_screen = Vector2.ZERO
        player.play(next, 0.0)

# The animation source already has planted toes near y=665, but its
# 1.632-second walk loop was independent of actual on-screen movement (~70 px/s).
# Drive stride rate from projected travel rather than letting boots skate.
func set_ground_speed(screen_pixels_per_second: float) -> void:
    if not is_finite(screen_pixels_per_second):
        return
    locomotion_rate = clampf(screen_pixels_per_second / 29.0, 0.65, 2.6)


func _toe_position(index: int) -> Vector2:
    var bone_data: Dictionary = bones[index]
    var tip: Array = bone_data["bind_end"]
    var start: Array = bone_data["bind_start"]
    var local_tip := Vector2(float(tip[0]) - float(start[0]), float(tip[1]) - float(start[1]))
    return to_local(bone_nodes[index].to_global(local_tip))


# The caller supplies *actual* projected travel, not joystick input. A
# blocked player contributes zero, so the planted foot stays in world space.
func apply_world_step(screen_motion: Vector2) -> void:
    if not screen_motion.is_finite():
        return
    traveled_screen += screen_motion


func _solve_planted_foot(index: int, target: Vector2) -> void:
    # Indices are stable source identities: left hip/knee/toe = 7/8/10,
    # right hip/knee/toe = 11/12/14. No new skeleton or mesh is allocated.
    var thigh_index: int = 7 if index == 10 else 11
    var shin_index: int = 8 if index == 10 else 12
    for iteration in range(4):
        for joint_index in [shin_index, thigh_index]:
            var joint: Bone2D = bone_nodes[joint_index]
            var pivot := to_local(joint.global_position)
            var from := _toe_position(index) - pivot
            var desired := target - pivot
            if from.length_squared() < 0.0001 or desired.length_squared() < 0.0001:
                continue
            var angle := wrapf(desired.angle() - from.angle(), -PI, PI)
            joint.rotation += clampf(angle, -IK_MAX_TURN, IK_MAX_TURN)


func _correct_foot_grounding() -> void:
    # Keep Skeleton2D root exactly as authored, never shift the entire body
    # sideways or make the neck swing to chase a foot. Only pose the leg
    # attached to the planted toe; mobile uses the already-existing 23 bones.
    if current_clip not in ["idle", "smooth_walk", "smooth_run"]:
        planted_foot = -1
        traveled_screen = Vector2.ZERO
        return
    var left := _toe_position(10)
    var right := _toe_position(14)
    if not left.is_finite() or not right.is_finite():
        return
    last_contact_y = maxf(left.y, right.y)
    if current_clip == "idle":
        planted_foot = -1
        traveled_screen = Vector2.ZERO
        grounding_error = absf(last_contact_y - SOURCE_GROUND_Y)
        foot_contact_count += 1
        return
    # A walk source has an alternating planted toe near y=665.
    # In a run both feet may be airborne: do not force a false foot plant.
    var next_foot := -1
    if absf(left.y - SOURCE_GROUND_Y) <= CONTACT_BAND:
        next_foot = 10
    if absf(right.y - SOURCE_GROUND_Y) <= CONTACT_BAND and (next_foot < 0 or right.y > left.y):
        next_foot = 14
    # Hysteresis: keep the current planted leg through shared-contact
    # frames instead of bouncing left/right on tiny float differences.
    if planted_foot == 10 and absf(left.y - SOURCE_GROUND_Y) <= CONTACT_BAND + 3.0:
        next_foot = 10
    elif planted_foot == 14 and absf(right.y - SOURCE_GROUND_Y) <= CONTACT_BAND + 3.0:
        next_foot = 14
    if next_foot != planted_foot:
        planted_foot = next_foot
        if planted_foot >= 0:
            planted_at = left if planted_foot == 10 else right
        traveled_screen = Vector2.ZERO
    if planted_foot < 0:
        grounding_error = 0.0
        return
    # World-space stance target moves opposite to the player anchor, after
    # accounting for avatar mirroring. Screen movement is converted once
    # into the original editor's unscaled source coordinate system.
    var parent_2d := get_parent() as Node2D
    var facing: float = -1.0 if parent_2d != null and parent_2d.scale.x < 0.0 else 1.0
    planted_at.x -= traveled_screen.x / maxf(SOURCE_SCALE, 0.001) * facing
    planted_at.y -= traveled_screen.y / maxf(SOURCE_SCALE, 0.001)
    traveled_screen = Vector2.ZERO
    var current: Vector2 = _toe_position(planted_foot)
    if current.distance_to(planted_at) > IK_REACH_LIMIT:
        # Stance ends before unnatural hyperextension / torso snap.
        planted_foot = -1
        grounding_error = 0.0
        return
    var upper_index: int = 7 if planted_foot == 10 else 11
    var lower_index: int = 8 if planted_foot == 10 else 12
    var saved_upper: float = bone_nodes[upper_index].rotation
    var saved_lower: float = bone_nodes[lower_index].rotation
    _solve_planted_foot(planted_foot, planted_at)
    grounding_error = _toe_position(planted_foot).distance_to(planted_at)
    if grounding_error > 14.0:
        # Preserve an authored pose if the target cannot be reached; never
        # drag the torso or hyperextend a leg to fake contact.
        bone_nodes[upper_index].rotation = saved_upper
        bone_nodes[lower_index].rotation = saved_lower
        planted_foot = -1
        grounding_error = 0.0
        return
    foot_contact_count += 1


func advance(delta: float) -> void:
    if not configured or not is_finite(delta) or delta < 0.0:
        return
    render_accumulator += minf(delta, 0.1)
    var hz := MOBILE_SKIN_HZ if OS.has_feature("mobile") else SKIN_HZ
    if render_accumulator >= 1.0 / hz:
        player.speed_scale = locomotion_rate if current_clip in ["smooth_walk", "smooth_run"] else 1.0
        player.advance(render_accumulator)
        render_accumulator = 0.0
        _correct_foot_grounding()
        draw_updates += 1

func verify_contract() -> bool:
    if not configured or skeleton == null or player == null or bones.size() != 23 or mesh_records.size() != 6 or clips.size() != 7:
        return false
    var frames := 0
    for clip in clips.values():
        frames += clip["frames"].size()
    if frames != 310 or bone_nodes.size() != 23:
        return false
    for record in mesh_records:
        var polygon: Polygon2D = record["node"]
        if polygon.polygon.size() != record["count"] or polygon.get_bone_count() == 0 or polygon.texture == null:
            return false
    return player.has_animation("idle") and player.has_animation("smooth_walk") and draw_updates > 0
