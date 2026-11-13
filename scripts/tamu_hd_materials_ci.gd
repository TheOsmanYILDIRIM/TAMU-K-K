extends SceneTree
# Isolated native Godot 4.6 acceptance gate; does not modify save/region IDs.
const HD = preload("res://scripts/tamu_hd_materials.gd")
const Solar = preload("res://scripts/solar_shadow.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _failed(message: String) -> void:
    push_error("TAMU_HD_NATIVE_FAIL " + message)
    quit(31)

func _verify() -> void:
    if not HD.verify_contract() or not Solar.verify_contract():
        _failed("contract")
        return
    var terrain = HD.terrain_material()
    if terrain == null or terrain.shader == null:
        _failed("terrain shader/material")
        return
    var names := HD.SPECIES
    for name in names:
        var path: String = "res://assets/trees/" + str(name) + "/"
        for channel in ["albedo", "normal"]:
            if not ResourceLoader.exists(path + channel + ".png"):
                _failed("tree missing " + name + " " + channel)
                return
            var tex: Texture2D = load(path + channel + ".png")
            if tex.get_size() != Vector2(1254.0, 1254.0):
                _failed("tree dimensions " + name)
                return
    for name in HD.MATERIALS:
        for channel in ["albedo", "height", "normal"]:
            var path: String = "res://assets/terrain/" + name + "/" + channel + ".png"
            if not ResourceLoader.exists(path):
                _failed("terrain missing " + path)
                return
            # A .png filename is insufficient: previous source files held JPEG data.
            var raw: FileAccess = FileAccess.open(path, FileAccess.READ)
            if raw == null or raw.get_buffer(8) != PackedByteArray([137,80,78,71,13,10,26,10]):
                _failed("terrain file not actual PNG " + path)
                return
    for name in names:
        for channel in ["albedo","normal"]:
            var mobile_path: String = "res://assets/trees/mobile_768/" + str(name) + "/" + channel + ".png"
            if not ResourceLoader.exists(mobile_path) or (load(mobile_path) as Texture2D).get_size() != Vector2(768,768):
                _failed("mobile tree missing or invalid " + mobile_path)
                return
    var oak: Dictionary = HD.tree_asset(0, "oak")
    var pine: Dictionary = HD.tree_asset(0, "conifer")
    if oak.is_empty() or pine.is_empty():
        _failed("tree material creation")
        return
    # Draw real mesh UVs rather than constructing illustrative colored squares.
    var parent := Node2D.new()
    parent.name = "MaterialScene"
    get_root().add_child(parent)
    var hd_atlas: Texture2D = load("res://assets/terrain/hd_fast_atlas/albedo.png")
    if hd_atlas == null or hd_atlas.get_size() != Vector2(1848,1584):
        _failed("packed HD atlas")
        return
    var hd_normal: Texture2D = load("res://assets/terrain/hd_fast_atlas/normal.png")
    if hd_normal == null or hd_normal.get_size() != hd_atlas.get_size():
        _failed("packed normal atlas")
        return
    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/terrain25d/manifest.json"))
    if not manifest is Dictionary:
        _failed("catalog manifest")
        return
    var uv_cell := Rect2()
    var found := false
    for entry in manifest.get("assets", []):
        if str(entry.get("kind", "")) == "terrain" and str(entry.get("family","")) == "grass":
            var a: Array = entry.get("uv_rect", [])
            if a.size() == 4:
                uv_cell = Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
                found = true
                break
    if not found:
        _failed("grass material uv")
        return
    # Verify ACTUAL mapped material pixels and preserved wetland, not file presence.
    # Canonical manifest is 14x12 132px slots. Build proof without touching game data.
    var old_image := Image.load_from_file("res://assets/terrain25d/atlas_00.png")
    var new_image := Image.load_from_file("res://assets/terrain/hd_fast_atlas/albedo.png")
    var normal_image := Image.load_from_file("res://assets/terrain/hd_fast_atlas/normal.png")
    if old_image == null or new_image == null or normal_image == null:
        _failed("atlas pixel evidence unavailable")
        return
    var changed := 0
    var kept_water := 0
    var mapped := 0
    for entry in manifest.get("assets", []):
        if str(entry.get("kind","")) != "terrain" or str(entry.get("atlas_page","")) != "atlas_00.png":
            continue
        var uv: Array = entry.get("uv_rect",[])
        var px := clampi(floori(float(uv[0])*14.0),0,13)*132 + 66
        var py := clampi(floori(float(uv[1])*12.0),0,11)*132 + 66
        var pixel: Color = new_image.get_pixel(px,py)
        var old_pixel: Color = old_image.get_pixel(px,py)
        var normal_pixel: Color = normal_image.get_pixel(px,py)
        if str(entry.get("family","")) == "wetland":
            if normal_pixel.a > 0.02 or (absf(pixel.r-old_pixel.r) + absf(pixel.g-old_pixel.g) + absf(pixel.b-old_pixel.b)) > 0.015:
                _failed("wetland altered")
                return
            kept_water += 1
        else:
            if normal_pixel.a < 0.98:
                _failed("land normal missing")
                return
            if (absf(pixel.r-old_pixel.r) + absf(pixel.g-old_pixel.g) + absf(pixel.b-old_pixel.b)) > 0.1:
                changed += 1
            mapped += 1
    if mapped != 137 or kept_water != 31 or changed < 60:
        _failed("HD atlas no visible land replacement mapped=%d changed=%d wetland=%d" % [mapped,changed,kept_water])
        return
    print("TAMU_HD_PIXEL_PROOF_OK land=137 wetland=31 changed=",changed)

    var vertices := PackedVector2Array([
        Vector2(15, 18), Vector2(345, 18), Vector2(345, 330),
        Vector2(15, 18), Vector2(345, 330), Vector2(15, 330)])
    var uvs := PackedVector2Array([
        uv_cell.position, uv_cell.position + Vector2(uv_cell.size.x, 0), uv_cell.end,
        uv_cell.position, uv_cell.end, uv_cell.position + Vector2(0, uv_cell.size.y)])
    var colors := PackedColorArray()
    for i in range(6):
        colors.append(Color.WHITE)
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = colors
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var terrain_node := MeshInstance2D.new()
    terrain_node.mesh = mesh
    terrain_node.texture = hd_atlas
    terrain_node.material = terrain
    parent.add_child(terrain_node)
    var tree := Sprite2D.new()
    tree.texture = oak["albedo"]
    tree.material = oak["material"]
    tree.position = Vector2(505, 310)
    tree.scale = Vector2.ONE * 0.23
    parent.add_child(tree)
    var noon = Solar.sample(12.0)
    var cast: Vector2 = noon["cast_direction"]
    var elev: float = deg_to_rad(float(noon["altitude_deg"]))
    var sun := Vector3(-cast.x*cos(elev),-cast.y*cos(elev),maxf(sin(elev),0.03)).normalized()
    terrain.set_shader_parameter("sun_vector",sun)
    terrain.set_shader_parameter("sun_light",noon["light"])
    tree.material.set_shader_parameter("sun_vector",sun)
    tree.material.set_shader_parameter("sun_light",noon["light"])
    for i in range(8):
        await process_frame
    var image: Image = get_root().get_texture().get_image()
    if image == null or image.is_empty():
        _failed("framebuffer capture")
        return
    var difference := 0.0
    for point in [Vector2i(65, 65), Vector2i(130, 110), Vector2i(240, 220)]:
        var p: Color = image.get_pixel(point.x,point.y)
        difference += absf(p.r - p.g) + absf(p.g - p.b)
    if difference < 0.04:
        _failed("terrain render not visibly textured")
        return
    var file_path := "user://tamu_hd_native_noon.png"
    var err := image.save_png(file_path)
    if err != OK:
        _failed("screenshot export")
        return
    # Regression: both textured trees and land must get darker when sun_light reaches zero.
    terrain.set_shader_parameter("sun_light", 0.0)
    tree.material.set_shader_parameter("sun_light", 0.0)
    for i in range(8):
        await process_frame
    var midnight_image: Image = get_root().get_texture().get_image()
    if midnight_image == null or midnight_image.is_empty():
        _failed("midnight framebuffer")
        return
    var original_tree: Image = (oak["albedo"] as Texture2D).get_image()
    var tree_day := 0.0
    var tree_night := 0.0
    var samples := 0
    for y in range(225, 392, 7):
        for x in range(425, 587, 7):
            var source_uv := (Vector2(x, y) - tree.position) / tree.scale + Vector2(384.0, 384.0)
            if source_uv.x < 0.0 or source_uv.y < 0.0 or source_uv.x >= 768.0 or source_uv.y >= 768.0:
                continue
            if original_tree.get_pixel(int(source_uv.x), int(source_uv.y)).a < 0.5:
                continue
            var midday_pixel: Color = image.get_pixel(x,y)
            var midnight_pixel: Color = midnight_image.get_pixel(x,y)
            tree_day += midday_pixel.r + midday_pixel.g + midday_pixel.b
            tree_night += midnight_pixel.r + midnight_pixel.g + midnight_pixel.b
            samples += 1
    if samples < 20 or tree_day <= 0.01 or tree_night >= tree_day * 0.62:
        _failed("HD tree does not darken at midnight samples=%d day=%.3f night=%.3f" % [samples, tree_day, tree_night])
        return
    var ground_day := 0.0
    var ground_night := 0.0
    for point in [Vector2i(65,65),Vector2i(130,110),Vector2i(240,220)]:
        var d: Color = image.get_pixel(point.x,point.y)
        var n: Color = midnight_image.get_pixel(point.x,point.y)
        ground_day += d.r+d.g+d.b
        ground_night += n.r+n.g+n.b
    if ground_day <= 0.01 or ground_night >= ground_day * 0.62:
        _failed("HD land does not darken at midnight day=%.3f night=%.3f" % [ground_day, ground_night])
        return
    var night_path := "user://tamu_hd_native_midnight.png"
    if midnight_image.save_png(night_path) != OK:
        _failed("midnight screenshot export")
        return
    print("TAMU_HD_LIGHT_CYCLE_OK tree_samples=", samples, " tree_night_ratio=", snappedf(tree_night / tree_day, 0.001),
        " ground_night_ratio=", snappedf(ground_night / ground_day, 0.001))
    print("TAMU_HD_NATIVE_RENDER_OK terrain6 tree8 shader2 optimized=2samples tree768 screenshot=",ProjectSettings.globalize_path(file_path))
    quit()
