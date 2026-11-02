extends RefCounted
# One authored REGION chunk, compiled from its original small source cells.
# Additional game regions must be separate manifests and nodes; never fuse globally.
const SOURCE_RUN_ID := 41234831527

static func build(atlas: Texture2D) -> Dictionary:
    return build_region(atlas, "res://chunks/merged_terrain.json")

static func build_region(atlas: Texture2D, manifest_path: String, mixed_material: ShaderMaterial = null) -> Dictionary:
    var path := manifest_path
    if not FileAccess.file_exists(path):
        push_error("TAMU_MERGED_MANIFEST_MISSING")
        return {}
    var manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not manifest is Dictionary or int(manifest.get("source_run_id", -1)) != SOURCE_RUN_ID:
        return {}
    if str(manifest.get("schema", "")) != "tamu.region.terrain.v1":
        return {}
    var region_id: String = str(manifest.get("region_id", ""))
    var source_cells: int = int(manifest.get("source_chunks", 0))
    if region_id.is_empty() or source_cells <= 0 or not manifest.has("layers"):
        return {}
    var layers: Array = manifest["layers"]
    if layers.is_empty() or layers.size() > 2:
        return {}
    var seen_z := {}
    var total_decode_usec := 0
    var total_mesh_usec := 0
    var group := Node2D.new()
    group.name = "TAMURegion_" + region_id
    var total_vertices := 0
    for layer in layers:
        var z := int(layer["z"])
        var count := int(layer["count"])
        if z < 0 or z > 1 or seen_z.has(z) or count <= 0 or count % 3 != 0:
            return {}
        seen_z[z] = true
        var basename: String = str(layer.get("file", ""))
        if basename.is_empty() or basename.find("/") != -1 or basename.find("\\") != -1:
            return {}
        if not basename.ends_with("_%d.verts" % z):
            return {}
        var filename := manifest_path.get_base_dir().path_join(basename)
        if not FileAccess.file_exists(filename) or FileAccess.get_sha256(filename) != str(layer["sha256"]):
            push_error("TAMU_MERGED_LAYER_HASH_FAILED z=" + str(z))
            return {}
        var raw := FileAccess.get_file_as_bytes(filename)
        if raw.size() != count * 20:
            push_error("TAMU_MERGED_LAYER_SIZE_FAILED z=" + str(z))
            return {}
        var decode_started: int = Time.get_ticks_usec()
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
        total_decode_usec += Time.get_ticks_usec() - decode_started
        var mesh_started: int = Time.get_ticks_usec()
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
        if z == 1 and mixed_material != null:
            instance.material = mixed_material
        group.add_child(instance)
        total_mesh_usec += Time.get_ticks_usec() - mesh_started
        total_vertices += count
    if total_vertices != int(manifest.get("vertices", -1)):
        return {}
    return {"root": group, "region_id": region_id, "source_cells": source_cells,
        "vertices": total_vertices, "surfaces": group.get_child_count(),
        "decode_ms": float(total_decode_usec) / 1000.0,
        "mesh_ms": float(total_mesh_usec) / 1000.0}
