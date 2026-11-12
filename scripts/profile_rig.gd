extends Node2D
# TAMU Rev2D character adapter (Godot 4.x). Existing gameplay interface retained.
# Source: user-provided TAMU_Walk.zip. No invented back-facing or action artwork.
const ROOT := "res://assets/profile_character/rev2d/"
const SOURCE_SCALE := 0.058
const SOURCE_GROUND_Y := 1300.0
const WALK_CYCLE_SCREEN_PIXELS := 96.0
const SKIN_HZ := 24.0

var source: Dictionary = {}
var clips: Dictionary = {}
var bones: Array = []
var mesh_records: Array = []
var rest_matrices: Array[Transform2D] = []
var posed_matrices: Array[Transform2D] = []
var name_to_index: Dictionary = {}
var current_clip := "idle"
var configured := false
var draw_updates := 0
var elapsed := 0.0
var skin_clock := 0.0
var last_frame := -1
var _source_time := 0.0
var _rest_inverse: Array[Transform2D] = []

func _vec(x: float, y: float) -> Vector2:
    return Vector2(x, y)

func _make_local(b: Dictionary, props: Dictionary = {}) -> Transform2D:
    var angle := deg_to_rad(float(props.get("rotation", b.get("rotation", 0.0))))
    var sc := Vector2(float(props.get("scaleX", b.get("scaleX", 1.0))), float(props.get("scaleY", b.get("scaleY", 1.0))))
    var t := Transform2D(angle, _vec(float(props.get("x", b.get("x", 0.0))), float(props.get("y", b.get("y", 0.0)))))
    return t.scaled_local(sc)

func _pose_matrices(overrides: Dictionary, out: Array[Transform2D]) -> void:
    for i in range(bones.size()):
        var b: Dictionary = bones[i]
        var local := _make_local(b, overrides.get(str(b["id"]), {}))
        var parent_name: Variant = b.get("parent")
        out[i] = out[int(name_to_index[str(parent_name)])] * local if parent_name != null else local

func _interpolate(keys: Array, time_value: float, at_mode: bool = false) -> float:
    if keys.is_empty():
        return 0.0
    var axis := "at" if at_mode else "t"
    var first: Dictionary = keys[0]
    var first_time := float(first[axis][0]) if at_mode else float(first[axis])
    if time_value <= first_time:
        return float(first.get("value", 0.0) if at_mode else first.get("v", 0.0))
    for index in range(1, keys.size()):
        var prev: Dictionary = keys[index - 1]
        var nxt: Dictionary = keys[index]
        var left := float(prev[axis][0]) if at_mode else float(prev[axis])
        var right := float(nxt[axis][0]) if at_mode else float(nxt[axis])
        if time_value <= right:
            var alpha := clampf((time_value - left) / maxf(right - left, 0.000001), 0.0, 1.0)
            var v0 := float(prev.get("value", 0.0) if at_mode else prev.get("v", 0.0))
            var v1 := float(nxt.get("value", 0.0) if at_mode else nxt.get("v", 0.0))
            return lerpf(v0, v1, alpha)
    var last: Dictionary = keys.back()
    return float(last.get("value", 0.0) if at_mode else last.get("v", 0.0))

func setup() -> bool:
    if configured:
        return false
    var path := ROOT + "TAMU_walk.r2d.json"
    if not FileAccess.file_exists(path):
        push_error("TAMU_REV2D_SOURCE_MISSING")
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary or parsed.get("format") != "rev2d":
        push_error("TAMU_REV2D_SOURCE_INVALID")
        return false
    source = parsed
    source["order"] = ["02_uzak_bacak", "01_yakin_bacak", "05_uzak_kol", "03_govde", "04_yakin_kol", "06_bas"]
    bones = source.get("bones", [])
    if bones.size() < 6 or source.get("parts", []).size() != 6:
        return false
    for i in range(bones.size()):
        var b: Dictionary = bones[i]
        if name_to_index.has(str(b["id"])):
            return false
        if b.get("parent") != null and not name_to_index.has(str(b["parent"])):
            return false
        name_to_index[str(b["id"])] = i
    rest_matrices.resize(bones.size())
    posed_matrices.resize(bones.size())
    _pose_matrices({}, rest_matrices)
    for mat in rest_matrices:
        if absf(mat.determinant()) < 0.000001:
            return false
        _rest_inverse.append(mat.affine_inverse())
    var texture_paths: Dictionary = {}
    for tex in source.get("textures", []):
        texture_paths[str(tex["id"])] = tex
    var sorted_parts: Array = source.get("parts", []).duplicate()
    sorted_parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("z", 0)) < int(b.get("z", 0)))
    for part in sorted_parts:
        var shape: Dictionary = part.get("shape", {})
        var skin: Dictionary = part.get("skin", {})
        var tex_info: Dictionary = texture_paths.get(str(shape.get("texture", "")), {})
        var file_path := ROOT + str(tex_info.get("path", ""))
        if not ResourceLoader.exists(file_path):
            push_error("TAMU_REV2D_TEXTURE_MISSING " + file_path)
            return false
        var texture: Texture2D = load(file_path)
        if texture == null:
            return false
        var raw_vertices: Array = shape.get("vertices", [])
        var raw_uvs: Array = shape.get("uvs", [])
        var raw_triangles: Array = shape.get("triangles", [])
        var raw_weights: Array = skin.get("weights", [])
        var joint_names: Array = skin.get("bones", [])
        var count := int(raw_vertices.size() / 2)
        if count < 3 or raw_uvs.size() != raw_vertices.size() or raw_weights.size() != count or raw_triangles.size() % 3 != 0:
            return false
        var coords := PackedVector2Array()
        var uvs := PackedVector2Array()
        var weights: Array = []
        for v in range(count):
            coords.append(_vec(float(raw_vertices[2*v]), float(raw_vertices[2*v+1])))
            uvs.append(_vec(float(raw_uvs[2*v]) * texture.get_width(), float(raw_uvs[2*v+1]) * texture.get_height()))
            var influences: Array = []
            var weight_sum := 0.0
            for j in range(joint_names.size()):
                var w := float(raw_weights[v][j])
                if w > 0.0:
                    if not name_to_index.has(str(joint_names[j])):
                        return false
                    influences.append(Vector2(int(name_to_index[str(joint_names[j])]), w))
                    weight_sum += w
            if absf(weight_sum - 1.0) > 0.02:
                return false
            weights.append(influences)
        var polygons: Array[PackedInt32Array] = []
        for ix in range(0, raw_triangles.size(), 3):
            var tri := PackedInt32Array()
            for offset in range(3):
                var vertex := int(raw_triangles[ix+offset])
                if vertex < 0 or vertex >= count:
                    return false
                tri.append(vertex)
            polygons.append(tri)
        var layer := Polygon2D.new()
        layer.name = str(part.get("id", "piece"))
        layer.texture = texture
        layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        layer.polygon = coords
        layer.uv = uvs
        layer.polygons = polygons
        add_child(layer)
        mesh_records.append({"node": layer, "bind": coords, "weights": weights, "count": count})
    for definition in source.get("animations", []):
        clips[str(definition.get("id", ""))] = definition
    if not clips.has("idle") or not clips.has("walk"):
        return false
    scale = Vector2.ONE * SOURCE_SCALE
    position = Vector2(-345.0 * SOURCE_SCALE, -SOURCE_GROUND_Y * SOURCE_SCALE)
    configured = true
    _show_time(0.0)
    return true

func set_clip(action: String) -> void:
    var wanted := "walk" if action in ["walk", "run"] else "idle"
    if not configured:
        return
    if wanted != current_clip:
        current_clip = wanted
        elapsed = 0.0
        skin_clock = 0.0
        last_frame = -1
        _show_time(0.0)

func _show_time(seconds: float) -> void:
    var clip: Dictionary = clips[current_clip]
    var duration := float(clip.get("duration", 1.0))
    var t := fposmod(seconds, duration) if bool(clip.get("loop", false)) else minf(seconds, duration)
    var params: Dictionary = {}
    for entry in source.get("parameters", []):
        params[str(entry["id"])] = float(entry.get("default", 0.0))
    for track in clip.get("tracks", []):
        var target := str(track.get("target", ""))
        if target.begins_with("param:"):
            var key := target.substr(6)
            params[key] = _interpolate(track.get("keys", []), t) + float(track.get("offset", 0.0))
    var overrides: Dictionary = {}
    for binding in source.get("bindings", []):
        var target := str(binding.get("target", ""))
        if not target.begins_with("bone:"):
            continue
        var parts_of_target := target.substr(5).split(".")
        if parts_of_target.size() != 2:
            continue
        var pname: Array = binding.get("params", [])
        if pname.size() != 1:
            continue
        var value := _interpolate(binding.get("keys", []), float(params.get(str(pname[0]), 0.0)), true)
        var bone_name := parts_of_target[0]
        var prop := parts_of_target[1]
        if not overrides.has(bone_name):
            overrides[bone_name] = {}
        overrides[bone_name][prop] = value
    _pose_matrices(overrides, posed_matrices)
    for record in mesh_records:
        var bind: PackedVector2Array = record["bind"]
        var points := PackedVector2Array()
        points.resize(bind.size())
        var weights: Array = record["weights"]
        for i in range(bind.size()):
            var result := Vector2.ZERO
            for influence in weights[i]:
                var bi := int(influence.x)
                result += (posed_matrices[bi] * (_rest_inverse[bi] * bind[i])) * influence.y
            points[i] = result
        var layer: Polygon2D = record["node"]
        layer.polygon = points
    # Ground-contact correction in rig local space, without moving world anchor.
    var boot_bottom := -INF
    for record in mesh_records:
        var layer: Polygon2D = record["node"]
        if layer.name.begins_with("part_01_yakin_bacak") or layer.name.begins_with("part_02_uzak_bacak"):
            for point in layer.polygon:
                boot_bottom = maxf(boot_bottom, point.y)
    if is_finite(boot_bottom):
        var shift := SOURCE_GROUND_Y - boot_bottom
        for record in mesh_records:
            var layer: Polygon2D = record["node"]
            layer.position.y = shift
    draw_updates += 1
    last_frame = int(floor(t * SKIN_HZ))

func advance(delta: float, projected_travel_pixels: float = 0.0) -> void:
    if not configured or not is_finite(delta) or delta <= 0.0:
        return
    if current_clip == "walk":
        var travel := maxf(0.0, projected_travel_pixels) if is_finite(projected_travel_pixels) else 0.0
        elapsed += travel / WALK_CYCLE_SCREEN_PIXELS * float(clips["walk"].get("duration", 2.20833))
    else:
        elapsed += minf(delta, 0.1)
    skin_clock += minf(delta, 0.1)
    if skin_clock >= 1.0 / SKIN_HZ:
        skin_clock = 0.0
        _show_time(elapsed)

func verify_contract() -> bool:
    if not configured or bones.size() != 41 or mesh_records.size() != 6 or not clips.has("walk"):
        return false
    for record in mesh_records:
        var node: Polygon2D = record["node"]
        if node.texture == null or node.polygon.size() != int(record["count"]):
            return false
    return draw_updates > 0
