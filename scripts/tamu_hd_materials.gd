extends RefCounted
# HD experiment only. No canonical R2 mesh, save, collision or terrain-ID edits.
const TERRAIN_SHADER = preload("res://scripts/tamu_hd_terrain.gdshader")
const TREE_SHADER = preload("res://scripts/tamu_hd_tree.gdshader")
const ROOT := "res://assets/terrain/material_atlas/"
const TREE_ROOT := "res://assets/trees/"
const SPECIES := [
    "fractureborn_oak", "skyward_forest_oak", "stormslope_beech",
    "marshkeeper_alder", "rootbound_hornbeam", "ironwind_pine",
    "ashskin_birch", "borderwatch_ash"]
const MATERIALS := ["forest_grass","forest_rocky","forest_sparse_litter",
    "forest_roots_litter","conifer_needle_litter","forest_moss_pebbles"]

static func enabled() -> bool:
    return OS.get_environment("TAMU_HD_MATERIALS") != "0"

static func _material_index(family: String, slot: Vector2i) -> int:
    match family:
        "grass": return 0
        "rock": return 1
        "dirt": return 2
        "forest":
            return 3 if posmod(slot.x + slot.y * 3, 3) == 0 else (4 if posmod(slot.x + slot.y * 3, 3) == 1 else 5)
        "wetland": return 5
    return -1

static func terrain_material() -> ShaderMaterial:
    if not enabled():
        return null
    for suffix in ["albedo","height","normal"]:
        if not ResourceLoader.exists(ROOT + suffix + ".png"):
            push_warning("TAMU_HD_TERRAIN_MISSING " + ROOT + suffix + ".png")
            return null
    var lookup := Image.create(14, 12, false, Image.FORMAT_RGBA8)
    lookup.fill(Color.TRANSPARENT)
    var catalog_path := "res://assets/terrain25d/manifest.json"
    if not FileAccess.file_exists(catalog_path):
        push_warning("TAMU_HD_TERRAIN_CATALOG_MISSING")
        return null
    var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
    if not catalog is Dictionary:
        return null
    var used := 0
    for entry in catalog.get("assets", []):
        if str(entry.get("kind","")) != "terrain" or str(entry.get("atlas_page","")) != "atlas_00.png":
            continue
        var uv: Array = entry.get("uv_rect",[])
        if uv.size() != 4:
            continue
        var slot := Vector2i(clampi(floori(float(uv[0]) * 14.0),0,13),
            clampi(floori(float(uv[1]) * 12.0),0,11))
        var index := _material_index(str(entry.get("family","")),slot)
        if index >= 0:
            lookup.set_pixel(slot.x,slot.y,Color8(index,0,0,255))
            used += 1
    if used != 168:
        push_warning("TAMU_HD_TERRAIN_SLOTS_INVALID " + str(used))
        return null
    var material := ShaderMaterial.new()
    material.shader = TERRAIN_SHADER
    material.set_shader_parameter("tamu_albedo",load(ROOT + "albedo.png"))
    material.set_shader_parameter("tamu_normal",load(ROOT + "normal.png"))
    material.set_shader_parameter("tamu_height",load(ROOT + "height.png"))
    material.set_shader_parameter("family_lookup",ImageTexture.create_from_image(lookup))
    print("TAMU_HD_TERRAIN_READY materials=6 atlas=1536x1024 slots=",used)
    return material

static func tree_asset(seed: int, family: String) -> Dictionary:
    if not enabled():
        return {}
    var candidates: Array[String] = []
    if family == "conifer":
        candidates = ["ironwind_pine"]
    else:
        candidates = ["fractureborn_oak","skyward_forest_oak","stormslope_beech",
            "marshkeeper_alder","rootbound_hornbeam","ashskin_birch","borderwatch_ash"]
    var name: String = candidates[posmod(seed, candidates.size())]
    var base := TREE_ROOT + name + "/"
    if not ResourceLoader.exists(base + "albedo.png") or not ResourceLoader.exists(base + "normal.png"):
        push_warning("TAMU_HD_TREE_MISSING " + name)
        return {}
    var albedo: Texture2D = load(base + "albedo.png")
    var normal: Texture2D = load(base + "normal.png")
    if albedo == null or normal == null or albedo.get_size() != normal.get_size():
        push_warning("TAMU_HD_TREE_SIZE_MISMATCH " + name)
        return {}
    var mat := ShaderMaterial.new()
    mat.shader = TREE_SHADER
    mat.set_shader_parameter("tree_normal",normal)
    return {"id":name, "albedo":albedo, "material":mat}

static func verify_contract() -> bool:
    return MATERIALS.size() == 6 and SPECIES.size() == 8 and _material_index("wetland",Vector2i.ZERO) == 5
