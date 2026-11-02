extends RefCounted
# Phase 2 bridge: preserve the authored weighted mesh vertices, UVs and triangles.
# Built against the native Skeleton2D pose; only numeric/hidden mesh gates here.
# Do not replace the production six-part sprites until visual parity is proven.
const REQUIRED_MESHES := 4
const REQUIRED_VERTICES := 1624
const REQUIRED_TRIANGLES := 2930
const REQUIRED_INFLUENCES := 2082

static func build(source: Dictionary, skeleton: Skeleton2D) -> Dictionary:
    var result := {"records": [], "vertices": 0, "triangles": 0, "influences": 0}
    var slots: Array = source.get("slots", [])
    var count := 0
    for slot_index in range(slots.size()):
        var slot: Dictionary = slots[slot_index]
        for asset in slot.get("attachments", []):
            if not asset is Dictionary or not asset.has("weights"):
                continue
            if str(asset.get("type", "")) != "mesh":
                push_error("TAMU_RIGBY_WEIGHTED_TYPE_INVALID")
                return {}
            var weights: Array = asset["weights"]
            var uvs: Array = asset.get("uvs", [])
            var triangles: Array = asset.get("triangles", [])
            if weights.is_empty() or uvs.size() != weights.size() * 2 or triangles.size() % 3 != 0:
                push_error("TAMU_RIGBY_WEIGHTED_TOPOLOGY_INVALID")
                return {}
            var image_name := str(asset.get("image", asset.get("name", "")))
            if image_name.is_empty() or image_name.contains("/") or image_name.contains("\\"):
                return {}
            var tex_path := "res://assets/osman_rig/images/%s.png" % image_name
            var tex: Texture2D = load(tex_path)
            if tex == null:
                push_error("TAMU_RIGBY_WEIGHTED_IMAGE_MISSING " + tex_path)
                return {}
            var uv_points := PackedVector2Array()
            var points := PackedVector2Array()
            uv_points.resize(weights.size())
            points.resize(weights.size())
            for i in range(weights.size()):
                var influences: Array = weights[i]
                var total := 0.0
                if influences.is_empty():
                    return {}
                for influence in influences:
                    var bone_index := int(influence.get("bone", -1))
                    var weight := float(influence.get("weight", -1.0))
                    if bone_index < 0 or bone_index >= 40 or not is_finite(weight) or weight < 0.0:
                        return {}
                    total += weight
                    result["influences"] += 1
                if absf(total - 1.0) > 0.00001:
                    push_error("TAMU_RIGBY_WEIGHTS_NOT_NORMALIZED")
                    return {}
                uv_points[i] = Vector2(float(uvs[i * 2]) * tex.get_width(),
                    float(uvs[i * 2 + 1]) * tex.get_height())
            var indices: Array[PackedInt32Array] = []
            for t in range(0, triangles.size(), 3):
                var tri := PackedInt32Array()
                for j in range(3):
                    var idx := int(triangles[t + j])
                    if idx < 0 or idx >= weights.size():
                        return {}
                    tri.append(idx)
                indices.append(tri)
            var polygon := Polygon2D.new()
            polygon.name = "WeightedSlot_%d" % slot_index
            polygon.texture = tex
            polygon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
            polygon.uv = uv_points
            polygon.polygon = points
            polygon.polygons = indices
            polygon.visible = false
            # This is an opt-in source proof, not yet the live character renderer.
            skeleton.add_child(polygon)
            result["records"].append({"polygon": polygon, "weights": weights,
                "source_slot": slot_index, "image": image_name})
            count += 1
            result["vertices"] += weights.size()
            result["triangles"] += indices.size()
    if count != REQUIRED_MESHES or result["vertices"] != REQUIRED_VERTICES or result["triangles"] != REQUIRED_TRIANGLES or result["influences"] != REQUIRED_INFLUENCES:
        push_error("TAMU_RIGBY_WEIGHTED_SOURCE_PARITY_FAILED")
        return {}
    return result

static func update_pose(state: Dictionary, skeleton: Skeleton2D, bone_nodes: Array[Bone2D]) -> bool:
    if state.is_empty() or not state.has("records") or bone_nodes.size() != 40:
        return false
    for entry in state["records"]:
        var polygon: Polygon2D = entry["polygon"]
        var weights: Array = entry["weights"]
        var positions := PackedVector2Array()
        positions.resize(weights.size())
        for i in range(weights.size()):
            var xy := Vector2.ZERO
            for influence in weights[i]:
                var index := int(influence["bone"])
                # Original Rigby is mathematical Y-up; Godot native bones Y-down.
                # Use Godot's actual FK hierarchy for the temporary mesh bridge.
                var local_point := Vector2(float(influence["x"]), -float(influence["y"]))
                var transformed := skeleton.to_local(bone_nodes[index].to_global(local_point))
                xy += transformed * float(influence["weight"])
            if not is_finite(xy.x) or not is_finite(xy.y):
                push_error("TAMU_RIGBY_SKIN_NONFINITE")
                return false
            positions[i] = xy
        polygon.polygon = positions
    return true

static func verify(state: Dictionary) -> bool:
    if state.is_empty() or state.get("vertices", 0) != REQUIRED_VERTICES or state.get("triangles", 0) != REQUIRED_TRIANGLES:
        return false
    var records: Array = state.get("records", [])
    if records.size() != REQUIRED_MESHES:
        return false
    for record in records:
        var poly: Polygon2D = record["polygon"]
        if poly.polygon.size() != record["weights"].size() or poly.uv.size() != poly.polygon.size():
            return false
        if poly.polygons.is_empty() or poly.texture == null:
            return false
    return true
