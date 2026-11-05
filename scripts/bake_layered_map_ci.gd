extends SceneTree
## One-shot, offscreen, source-quality (128px textures) TAMU map bake.
## No gameplay runtime, no save access, no HUD, no fabricated world geometry.
## Outputs are pixel-aligned to the same global screen-space origin.
const WorldProjection = preload("res://scripts/world_projection.gd")
const MergedTerrain = preload("res://scripts/merged_terrain.gd")
const PAD := 160.0
const MAX_DIMENSION := 8192
const SOURCE_RUN_ID := 41234831527

func _initialize() -> void:
    call_deferred("_bake")

func _fail(message: String, code: int = 82) -> void:
    push_error(message)
    quit(code)

func _bake() -> void:
    var terrain_atlas: Texture2D = load("res://assets/terrain25d/atlas_00_mix.png")
    if terrain_atlas == null:
        terrain_atlas = load("res://assets/terrain25d/atlas_00.png")
    var object_atlas: Texture2D = load("res://assets/terrain25d/atlas_01.png")
    if terrain_atlas == null or object_atlas == null:
        _fail("TAMU_BAKE_SOURCE_ATLAS_UNAVAILABLE")
        return
    var combined: Dictionary = MergedTerrain.build_region(
        terrain_atlas, "res://chunks/merged_terrain.json")
    if combined.is_empty() or int(combined.get("source_cells",0)) != 156:
        _fail("TAMU_BAKE_SOURCE_MESH_UNAVAILABLE")
        return
    var source: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://chunks/r2_objects.json"))
    var manifest: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://assets/terrain25d/manifest.json"))
    if not source is Dictionary or not manifest is Dictionary:
        _fail("TAMU_BAKE_SOURCE_METADATA_UNAVAILABLE")
        return
    if source.get("objects", []).size() != 832:
        _fail("TAMU_BAKE_AUTHORED_OBJECT_COUNT_FAILED")
        return

    var viewport := SubViewport.new()
    viewport.disable_3d = true
    viewport.transparent_bg = true
    viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.size = Vector2i(16,16)
    get_root().add_child(viewport)
    var map_root := Node2D.new()
    map_root.name = "SourceAlignedLayerOrigin"
    viewport.add_child(map_root)
    var terrain_root: Node2D = combined["root"]
    map_root.add_child(terrain_root)

    var bounds := Rect2()
    var initialized := false
    for layer in terrain_root.get_children():
        if not layer is MeshInstance2D:
            continue
        var arrays: Array = layer.mesh.surface_get_arrays(0)
        var verts: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
        for pt in verts:
            if not initialized:
                bounds = Rect2(pt, Vector2.ZERO)
                initialized = true
            else:
                bounds = bounds.expand(pt)
    if not initialized or not bounds.has_area():
        _fail("TAMU_BAKE_TERRAIN_BOUNDS_EMPTY")
        return

    var families := {}
    for a in manifest["assets"]:
        if str(a.get("kind","")) == "object" and str(a.get("atlas_page","")) == "atlas_01.png":
            var family := str(a.get("family",""))
            if not families.has(family):
                families[family] = []
            families[family].append(a)
    for family in families:
        families[family].sort_custom(func(a,b): return str(a["id"]) < str(b["id"]))
    var object_layer := Node2D.new()
    object_layer.name = "Authored128ObjectLayer"
    object_layer.y_sort_enabled = true
    object_layer.visible = false
    map_root.add_child(object_layer)
    var objects_out: Array = []
    var atlas_size := object_atlas.get_size()
    for o in source["objects"]:
        var identifier := str(o["id"])
        var kind := str(o["kind"])
        var hash_value: int = 19
        for c in identifier.to_utf8_buffer():
            hash_value = posmod(hash_value*33 + int(c), 2147483647)
        var variant := hash_value % 12
        var family := "shrub"
        if kind == "tree":
            family = "broadleaf" if variant == 0 else ("conifer" if variant <= 2 else "oak")
        elif kind == "rock":
            family = "rock_spire" if variant == 0 else ("rock_cluster" if variant == 1 else "boulder")
        elif families.has(kind):
            family = kind
        if not families.has(family):
            family = "shrub"
        var choices: Array = families[family]
        if choices.is_empty():
            _fail("TAMU_BAKE_OBJECT_FAMILY_UNAVAILABLE " + family)
            return
        var asset: Dictionary = choices[hash_value % choices.size()]
        var uv: Array = asset["uv_rect"]
        var rectangle := Rect2(
            round(float(uv[0])*atlas_size.x),round(float(uv[1])*atlas_size.y),
            round(float(uv[2])*atlas_size.x),round(float(uv[3])*atlas_size.y))
        var texture := AtlasTexture.new()
        texture.atlas = object_atlas
        texture.region = rectangle
        var sprite := Sprite2D.new()
        sprite.texture = texture
        sprite.centered = true
        sprite.position = Vector2(float(o["sx"]),float(o["sy"]))
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        var scales := {"oak":1.18,"broadleaf":1.28,"conifer":1.34,"dead_tree":1.06,
            "boulder":0.44,"rock_cluster":0.50,"rock_spire":0.53,
            "shrub":0.30,"reeds":0.28,"stump":0.26,"fallen_log":0.41,"water_rocks":0.38}
        var jitter := 0.96 + float(hash_value % 9)*0.01
        var scale_value: float = float(scales.get(family,0.5))*jitter
        sprite.scale = Vector2.ONE * scale_value
        # Preserve the exact production foot pivot. These sprites remain
        # 128px assets; high-resolution atlas variants are never fetched.
        sprite.offset = Vector2(0.0,rectangle.size.y*(0.5-0.82))
        object_layer.add_child(sprite)
        var pt := sprite.position
        var top_left: Vector2 = pt + (-rectangle.size/2.0 + sprite.offset)*scale_value
        bounds = bounds.expand(top_left)
        bounds = bounds.expand(top_left + rectangle.size*scale_value)
        objects_out.append({"id":identifier,"kind":kind,"family":family,
            "x":float(o["x"]),"y":float(o["y"]),"radius":float(o["radius"]),
            "sx":pt.x,"sy":pt.y,"scale":scale_value})

    var min_pixel := Vector2(floor(bounds.position.x-PAD),floor(bounds.position.y-PAD))
    var final_size := Vector2i(
        ceili(bounds.end.x+PAD-min_pixel.x),
        ceili(bounds.end.y+PAD-min_pixel.y))
    if final_size.x < 512 or final_size.y < 512 or final_size.x > MAX_DIMENSION or final_size.y > MAX_DIMENSION:
        _fail("TAMU_BAKE_CANVAS_OUT_OF_RANGE " + str(final_size))
        return
    viewport.size = final_size
    map_root.position = -min_pixel
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://baked")) != OK:
        _fail("TAMU_BAKE_OUTPUT_DIR_FAILED")
        return

    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var terrain_image := viewport.get_texture().get_image()
    if terrain_image == null or not terrain_image.get_used_rect().has_area():
        _fail("TAMU_BAKE_TERRAIN_EMPTY")
        return
    if terrain_image.save_png("res://baked/terrain.png") != OK:
        _fail("TAMU_BAKE_TERRAIN_WRITE_FAILED")
        return

    terrain_root.visible = false
    object_layer.visible = true
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var object_image := viewport.get_texture().get_image()
    if object_image == null or not object_image.get_used_rect().has_area():
        _fail("TAMU_BAKE_OBJECTS_EMPTY")
        return
    if object_image.get_size() != terrain_image.get_size():
        _fail("TAMU_BAKE_MISALIGNED_CANVAS")
        return
    if object_image.save_png("res://baked/objects.png") != OK:
        _fail("TAMU_BAKE_OBJECTS_WRITE_FAILED")
        return
    # Sidecar enables future HTML placement on a fixed Cartesian 32-unit
    # grid. It does NOT grant save, collision or construction authority.
    var alignment := {"schema":"tamu.layered-map-preview.v1",
        "region_id":str(combined["region_id"]),"source_cells":156,
        "source_run_id":SOURCE_RUN_ID,
        "width":final_size.x,"height":final_size.y,
        "pixel_origin_world_screen":[min_pixel.x,min_pixel.y],
        "world_unit":32,
        "iso_x":WorldProjection.ISO_X,"iso_y":WorldProjection.ISO_Y,
        "objects":objects_out,
        "notes":"Terrain and objects are full-resolution 128-source atlas renders in exactly the same pixel-space; shadows/HUD/player not included; no un-authored region synthesized."}
    var file := FileAccess.open("res://baked/alignment.json", FileAccess.WRITE)
    if file == null:
        _fail("TAMU_BAKE_METADATA_WRITE_FAILED")
        return
    file.store_string(JSON.stringify(alignment))
    file.close()
    print("TAMU_128_LAYERED_BAKE_OK width=",final_size.x," height=",final_size.y,
        " cells=156 objects=",objects_out.size())
    quit(0)
