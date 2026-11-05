extends Node2D
# TAMU profile character — clean source-faithful numeric skinning.
# Reconstructed independently from the editor's motion.json FK and six PNGs.
# No Skeleton2D, Bone2D, AnimationPlayer, procedural sway, IK or foot shifting.
# Each authored frame is evaluated exactly; mesh topology and textures persist.
const ROOT := "res://assets/profile_character/"
const SOURCE_SCALE := 0.067
const SOURCE_GROUND_Y := 665.0
const SKIN_HZ := 30.0
# Source walk is 48 frames x 34ms. Its full left/right step cycle covers
# ~32 projected pixels at the authored 0.067 game scale. Advance from actual
# movement distance instead of wall-clock to remove apparent foot skating.
const WALK_CYCLE_SCREEN_PIXELS := 32.0
const CLIP_ALIAS := {
    "walk": "smooth_walk", "run": "smooth_run", "idle": "idle",
    "slash": "slash", "stab": "stab", "die": "die", "sit": "sit"
}
var source: Dictionary = {}
var bones: Array = []
var clips: Dictionary = {}
var mesh_records: Array[Dictionary] = []
var bind_origins: Array[Vector2] = []
var parents: PackedInt32Array = PackedInt32Array()
var posed_origins: Array[Vector2] = []
var posed_angles: PackedFloat32Array = PackedFloat32Array()
var current_clip := "idle"
var configured := false
var draw_updates := 0
var elapsed := 0.0
var accumulator := 0.0
var last_frame := -1

func _point(values: Array) -> Vector2:
    return Vector2(float(values[0]), float(values[1]))

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
        push_error("TAMU_PROFILE_SOURCE_TOPOLOGY_FAILED")
        return false
    var by_name: Dictionary = {}
    for i in range(bones.size()):
        var bone: Dictionary = bones[i]
        if not bone.has("bind_start") or not bone.has("bind_end"):
            return false
        var parent_name: Variant = bone.get("parent")
        var parent_index := -1
        if parent_name != null:
            parent_index = int(by_name.get(str(parent_name), -1))
            if parent_index < 0:
                push_error("TAMU_PROFILE_PARENT_ORDER_FAILED")
                return false
        parents.append(parent_index)
        bind_origins.append(_point(bone["bind_start"]))
        posed_origins.append(Vector2.ZERO)
        by_name[str(bone["name"])] = i
    posed_angles.resize(bones.size())
    var meshes: Dictionary = source.get("meshes", {})
    for name_value in order:
        var name: String = str(name_value)
        var filename := ROOT + name + ".png"
        if not ResourceLoader.exists(filename) or not meshes.has(name):
            push_error("TAMU_PROFILE_PART_MISSING " + filename)
            return false
        var texture: Texture2D = load(filename)
        var mesh: Dictionary = meshes[name]
        var points: Array = mesh.get("bind_vertices", [])
        var uv: Array = mesh.get("uv", [])
        var influence: Array = mesh.get("vertex_influences", [])
        var triangles: Array = mesh.get("triangles", [])
        if texture == null or points.is_empty() or points.size() != uv.size() or points.size() != influence.size():
            push_error("TAMU_PROFILE_MESH_INVALID " + name)
            return false
        var original := PackedVector2Array()
        var texcoords := PackedVector2Array()
        var weights: Array = []
        for v in range(points.size()):
            original.append(_point(points[v]))
            texcoords.append(_point(uv[v]))
            var vertex_weights: Array = []
            var total := 0.0
            for element in influence[v]:
                var index := int(element[0])
                var weight := float(element[1])
                if index < 0 or index >= bones.size() or not is_finite(weight) or weight < 0.0:
                    push_error("TAMU_PROFILE_WEIGHT_INVALID")
                    return false
                vertex_weights.append(Vector2(index, weight))
                total += weight
            if absf(total - 1.0) > 0.001:
                push_error("TAMU_PROFILE_WEIGHT_SUM_FAILED")
                return false
            weights.append(vertex_weights)
        var polygons: Array[PackedInt32Array] = []
        for tri in triangles:
            if tri.size() != 3:
                return false
            var indices := PackedInt32Array()
            for value in tri:
                var index := int(value)
                if index < 0 or index >= points.size():
                    return false
                indices.append(index)
            polygons.append(indices)
        var layer := Polygon2D.new()
        layer.name = "Source_" + name
        layer.texture = texture
        layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        layer.polygon = original
        layer.uv = texcoords
        layer.polygons = polygons
        add_child(layer)
        mesh_records.append({"node": layer, "bind": original, "weights": weights, "count": original.size()})
    for clip_value in definitions:
        var clip: Dictionary = clip_value
        var frames: Array = clip.get("frames", [])
        var key: String = str(clip.get("id", ""))
        if key.is_empty() or frames.is_empty() or clips.has(key) or float(clip.get("ms", 0)) <= 0.0:
            return false
        for frame_value in frames:
            var frame: Dictionary = frame_value
            if frame.get("a", []).size() != bones.size() or frame.get("root", []).size() != 2:
                return false
        clips[key] = clip
    scale = Vector2.ONE * SOURCE_SCALE
    position = Vector2(0.0, -SOURCE_GROUND_Y * SOURCE_SCALE)
    configured = true
    _show_frame(0)
    print("TAMU_PROFILE_SOURCE_FK_ACTIVE bones=23 parts=6 clips=7 no_ik=true")
    return true

func set_clip(action: String) -> void:
    var next: String = str(CLIP_ALIAS.get(action, "idle"))
    if configured and current_clip != next and clips.has(next):
        current_clip = next
        elapsed = 0.0
        accumulator = 0.0
        last_frame = -1
        _show_frame(0)

func _evaluate_frame(frame: Dictionary) -> void:
    # Same parent-relative FK as the verified motion.json GIF renderer.
    var angles: Array = frame["a"]
    var root_value: Vector2 = _point(frame["root"])
    for i in range(bones.size()):
        var parent_index: int = parents[i]
        var local_angle: float = float(angles[i])
        if parent_index < 0:
            posed_origins[i] = root_value
            posed_angles[i] = local_angle
        else:
            var offset: Vector2 = bind_origins[i] - bind_origins[parent_index]
            posed_origins[i] = posed_origins[parent_index] + offset.rotated(posed_angles[parent_index])
            posed_angles[i] = posed_angles[parent_index] + local_angle

func _show_frame(index: int) -> void:
    var clip: Dictionary = clips[current_clip]
    var frames: Array = clip["frames"]
    if index < 0 or index >= frames.size():
        return
    _evaluate_frame(frames[index])
    for record in mesh_records:
        var original: PackedVector2Array = record["bind"]
        var vertex_weights: Array = record["weights"]
        var output := PackedVector2Array()
        output.resize(original.size())
        for v in range(original.size()):
            var total := Vector2.ZERO
            for pair in vertex_weights[v]:
                var bi: int = int(pair.x)
                var weight: float = pair.y
                var displaced := posed_origins[bi] + (original[v] - bind_origins[bi]).rotated(posed_angles[bi])
                total += displaced * weight
            output[v] = total
        var layer: Polygon2D = record["node"]
        layer.polygon = output
    last_frame = index
    draw_updates += 1

func advance(delta: float, projected_travel_pixels: float = 0.0) -> void:
    if not configured or not is_finite(delta) or delta <= 0.0:
        return
    var clip: Dictionary = clips[current_clip]
    var frames: Array = clip["frames"]
    var duration: float = float(clip["ms"]) / 1000.0
    if current_clip == "smooth_walk" or current_clip == "smooth_run":
        # Travel is measured after collision/clamping; blocked steps add zero.
        var travel: float = maxf(0.0, projected_travel_pixels) if is_finite(projected_travel_pixels) else 0.0
        elapsed += (travel / WALK_CYCLE_SCREEN_PIXELS) * duration * float(frames.size())
    else:
        elapsed += minf(delta, 0.1)
    accumulator += minf(delta, 0.1)
    var index: int = floori(elapsed / duration)
    if bool(clip["loop"]):
        index = posmod(index, frames.size())
    else:
        index = mini(index, frames.size() - 1)
    if index != last_frame and accumulator >= 1.0 / SKIN_HZ:
        _show_frame(index)
        accumulator = 0.0

func _toe_position(index: int) -> Vector2:
    var bone: Dictionary = bones[index]
    var local_tip: Vector2 = _point(bone["bind_end"]) - bind_origins[index]
    return posed_origins[index] + local_tip.rotated(posed_angles[index])

func verify_contract() -> bool:
    if not configured or bones.size() != 23 or mesh_records.size() != 6 or clips.size() != 7 or draw_updates < 1:
        return false
    var frames_total := 0
    for clip in clips.values():
        frames_total += clip["frames"].size()
    if frames_total != 310:
        return false
    for record in mesh_records:
        var layer: Polygon2D = record["node"]
        if layer.texture == null or layer.polygon.size() != record["count"] or layer.get_bone_count() != 0:
            return false
    return true
