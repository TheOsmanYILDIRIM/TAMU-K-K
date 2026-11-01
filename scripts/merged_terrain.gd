extends RefCounted
# Exact build-time union of 156 authored terrain chunks; two z-layer draw nodes.
const SOURCE_RUN_ID := 41234831527

static func build(atlas: Texture2D) -> Dictionary:
    var path := "res://chunks/merged_terrain.json"
    if not FileAccess.file_exists(path):
        push_error("TAMU_MERGED_MANIFEST_MISSING")
        return {}
    var manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not manifest is Dictionary or int(manifest.get("source_run_id", -1)) != SOURCE_RUN_ID:
        return {}
    if int(manifest.get("source_chunks", -1)) != 156 or not manifest.has("layers"):
        return {}
    var layers: Array = manifest["layers"]
    if layers.size() != 2:
        return {}
    var group := Node2D.new()
    group.name = "TAMUCompleteAuthoredTerrain"
    var total_vertices := 0
    for layer in layers:
        var z := int(layer["z"])
        var count := int(layer["count"])
        if z < 0 or z > 1 or count <= 0 or count % 3 != 0:
            return {}
        var filename := "res://chunks/merged_layer_%d.verts" % z
        if not FileAccess.file_exists(filename) or FileAccess.get_sha256(filename) != str(layer["sha256"]):
            push_error("TAMU_MERGED_LAYER_HASH_FAILED z=" + str(z))
            return {}
        var raw := FileAccess.get_file_as_bytes(filename)
        if raw.size() != count * 20:
            push_error("TAMU_MERGED_LAYER_SIZE_FAILED z=" + str(z))
            return {}
        var buffer := StreamPeerBuffer.new()
        buffer.big_endian = false
        buffer.data_array = raw
        var points := PackedVector2Array()
        var uvs := PackedVector2Array()
        var colors := PackedColorArray()
        points.resize(count)
        uvs.resize(count)
        colors.resize(count)
        for i in range(count):
            points[i] = Vector2(buffer.get_float(), buffer.get_float())
            uvs[i] = Vector2(buffer.get_float(), buffer.get_float())
            var rgba := buffer.get_u32()
            colors[i] = Color8(rgba & 255, (rgba >> 8) & 255,
                (rgba >> 16) & 255, (rgba >> 24) & 255)
        if buffer.get_position() != raw.size():
            return {}
        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = points
        arrays[Mesh.ARRAY_TEX_UV] = uvs
        arrays[Mesh.ARRAY_COLOR] = colors
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        var instance := MeshInstance2D.new()
        instance.name = "MergedTerrainLayer%d" % z
        instance.mesh = mesh
        instance.texture = atlas
        instance.z_index = z
        group.add_child(instance)
        total_vertices += count
    if total_vertices != int(manifest.get("vertices", -1)):
        return {}
    return {"root": group, "vertices": total_vertices, "surfaces": group.get_child_count()}
