extends Node2D
# Godot 4.6: original six PNG layers + editor-authored 23-bone numeric pose curves.
# A mesh is deformed by joint matrices in code; NO AnimatedSprite2D or frame PNG atlases.
const ROOT := "res://assets/profile_character/"
const CLIP_ALIAS := {
    "walk": "smooth_walk", "run": "smooth_run", "idle": "idle",
    "slash": "slash", "stab": "stab", "die": "die", "sit": "sit",
}
const SOURCE_SCALE := 0.061
const SKIN_HZ := 30.0
var source: Dictionary = {}
var bones: Array = []
var bone_parents: Array[int] = []
var mesh_records: Array[Dictionary] = []
var clips: Dictionary = {}
var current_clip := "idle"
var elapsed := 0.0
var render_accumulator := 0.0
var ready := false
var draw_updates := 0

func setup() -> bool:
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
    if bones.size() != 23 or source.get("order", []).size() != 6 or source.get("clips", []).size() != 7:
        push_error("TAMU_PROFILE_RIG_TOPOLOGY_INVALID")
        return false
    bone_parents.clear()
    var names: Array[String] = []
    for b in bones:
        if not b is Dictionary or not b.has("bind_start") or not b.has("bind_end"):
            return false
        var parent_name := str(b.get("parent", ""))
        var index := names.find(parent_name) if not parent_name.is_empty() and parent_name != "<null>" else -1
        if b.get("parent") != null and index < 0:
            push_error("TAMU_PROFILE_RIG_PARENT_ORDER_INVALID")
            return false
        bone_parents.append(index)
        names.append(str(b["name"]))
    for clip in source["clips"]:
        if not clip is Dictionary or clip.get("frames", []).is_empty():
            return false
        var key := str(clip["id"])
        if clips.has(key):
            return false
        for frame in clip["frames"]:
            if frame.get("a", []).size() != 23 or frame.get("root", []).size() != 2:
                return false
        clips[key] = clip
    if clips.size() != 7:
        return false
    for name in source["order"]:
        var path_png := ROOT + str(name) + ".png"
        if not ResourceLoader.exists(path_png):
            push_error("TAMU_PROFILE_ORIGINAL_PART_MISSING " + path_png)
            return false
        var tex: Texture2D = load(path_png)
        if tex == null:
            return false
        var mesh_data: Dictionary = source["meshes"].get(name, {})
        var n: int = mesh_data.get("bind_vertices", []).size()
        if n == 0 or mesh_data.get("uv", []).size() != n \
                or mesh_data.get("rotation_centres", []).size() != n \
                or mesh_data.get("vertex_influences", []).size() != n:
            push_error("TAMU_PROFILE_SKIN_VERTICES_INVALID")
            return false
        var uvs := PackedVector2Array()
        var indices := PackedInt32Array()
        var texture_size := tex.get_size()
        for uv in mesh_data["uv"]:
            uvs.append(Vector2(float(uv[0]), float(uv[1])) / texture_size)
        for tri in mesh_data["triangles"]:
            if tri.size() != 3:
                return false
            for index in tri:
                if int(index) < 0 or int(index) >= n:
                    return false
                indices.append(int(index))
        var node := MeshInstance2D.new()
        node.name = "Original_" + str(name)
        node.texture = tex
        node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        add_child(node)
        mesh_records.append({"node": node, "data": mesh_data, "uvs": uvs, "indices": indices, "count": n})
    # Source 1178px-high character in ~72px Godot world profile; feet at Y~689.
    scale = Vector2.ONE * SOURCE_SCALE
    position = Vector2(0.0, -689.0 * SOURCE_SCALE)
    ready = true
    set_clip("idle")
    _render_pose(_sample(0.0))
    print("TAMU_PROFILE_NATIVE_RIG_READY bones=", bones.size(), " parts=", mesh_records.size(),
        " clips=", clips.size(), " frames=310 no_spritesheet=true")
    return true

func set_clip(action: String) -> void:
    var next: String = str(CLIP_ALIAS.get(action, "idle"))
    if clips.has(next) and next != current_clip:
        current_clip = next
        elapsed = 0.0
        render_accumulator = 0.0

func advance(delta: float) -> void:
    if not ready or not is_finite(delta) or delta < 0.0:
        return
    elapsed += minf(delta, 0.1)
    render_accumulator += delta
    if render_accumulator < 1.0 / SKIN_HZ:
        return
    render_accumulator = fmod(render_accumulator, 1.0 / SKIN_HZ)
    _render_pose(_sample(elapsed))

func _frame(clip: Dictionary, index: int) -> Dictionary:
    var frames: Array = clip["frames"]
    var n := frames.size()
    var j := posmod(index, n) if bool(clip["loop"]) else clampi(index, 0, n - 1)
    return frames[j]

func _wrap_angle(angle: float) -> float:
    return atan2(sin(angle), cos(angle))

func _cubic(a: float, b: float, c: float, d: float, t: float) -> float:
    return b + 0.5 * t * (c - a + t * (2.0 * a - 5.0 * b + 4.0 * c - d \
        + t * (3.0 * (b - c) + d - a)))

func _sample(t: float) -> Dictionary:
    var clip: Dictionary = clips[current_clip]
    var count: int = clip["frames"].size()
    var ms: float = float(clip["ms"])
    var position_frame := t * 1000.0 / ms
    position_frame = fposmod(position_frame, float(count)) if bool(clip["loop"]) \
        else clampf(position_frame, 0.0, float(count - 1))
    var k := floori(position_frame)
    var ratio := position_frame - float(k)
    var b := _frame(clip, k)
    if ratio < 0.0000001 or str(clip.get("interpolation", "")) == "hold":
        return b
    var a := _frame(clip, k - 1)
    var c := _frame(clip, k + 1)
    var d := _frame(clip, k + 2)
    var smooth := str(clip.get("interpolation", "")) == "smooth"
    var root := []
    var angles := []
    for i in range(2):
        root.append(_cubic(float(a["root"][i]), float(b["root"][i]),
            float(c["root"][i]), float(d["root"][i]), ratio) if smooth else \
            lerpf(float(b["root"][i]), float(c["root"][i]), ratio))
    for i in range(bones.size()):
        var bv := float(b["a"][i])
        var av := bv + _wrap_angle(float(a["a"][i]) - bv)
        var cv := bv + _wrap_angle(float(c["a"][i]) - bv)
        var dv := cv + _wrap_angle(float(d["a"][i]) - float(c["a"][i]))
        angles.append(_cubic(av, bv, cv, dv, ratio) if smooth else lerpf(bv, cv, ratio))
    return {"root": root, "a": angles}

func _solve(pose: Dictionary) -> Array[Transform2D]:
    var transforms: Array[Transform2D] = []
    var world_angles: Array[float] = []
    for i in range(bones.size()):
        var b: Dictionary = bones[i]
        var parent: int = bone_parents[i]
        var angle: float = float(pose["a"][i]) + (world_angles[parent] if parent >= 0 else 0.0)
        var bind: Array = b["bind_start"]
        var bind_at := Vector2(float(bind[0]), float(bind[1]))
        var joint := Vector2(float(pose["root"][0]), float(pose["root"][1]))
        if parent >= 0:
            joint = transforms[parent] * bind_at
        transforms.append(Transform2D(angle, joint - bind_at.rotated(angle)))
        world_angles.append(angle)
    return transforms

func _render_pose(pose: Dictionary) -> void:
    var matrices := _solve(pose)
    for record in mesh_records:
        var d: Dictionary = record["data"]
        var points := PackedVector2Array()
        var n: int = record["count"]
        points.resize(n)
        for i in range(n):
            var vertex: Array = d["bind_vertices"][i]
            var centre: Array = d["rotation_centres"][i]
            var influences: Array = d["vertex_influences"][i]
            var r0 := 0.0
            var r1 := 0.0
            var r2 := 0.0
            var r3 := 0.0
            var tx := 0.0
            var ty := 0.0
            for entry in influences:
                var bone_id := int(entry[0])
                var w := float(entry[1])
                var matrix: Transform2D = matrices[bone_id]
                r0 += matrix.x.x * w
                r1 += matrix.y.x * w
                r2 += matrix.x.y * w
                r3 += matrix.y.y * w
                tx += matrix.origin.x * w
                ty += matrix.origin.y * w
            var x := float(vertex[0])
            var y := float(vertex[1])
            var dx := x - float(centre[0])
            var dy := y - float(centre[1])
            var correction := 1.0 / maxf(0.00000001, sqrt(r0 * r0 + r2 * r2)) - 1.0
            points[i] = Vector2(r0 * x + r1 * y + tx + correction * (r0 * dx + r1 * dy),
                r2 * x + r3 * y + ty + correction * (r2 * dx + r3 * dy))
        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = points
        arrays[Mesh.ARRAY_TEX_UV] = record["uvs"]
        arrays[Mesh.ARRAY_INDEX] = record["indices"]
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        record["node"].mesh = mesh
    draw_updates += 1

func verify_contract() -> bool:
    if not ready or bones.size() != 23 or mesh_records.size() != 6 or clips.size() != 7:
        return false
    var count := 0
    for clip in clips.values():
        count += clip["frames"].size()
    if count != 310:
        return false
    for record in mesh_records:
        if record["node"].mesh == null or record["node"].mesh.get_surface_count() != 1:
            return false
        if record["node"].mesh.surface_get_array_len(0) != record["count"]:
            return false
    return draw_updates > 0
