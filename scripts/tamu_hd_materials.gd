extends RefCounted
# Isolated HD material experiment. Does not alter canonical R2 sources or collision.
const TERRAIN_SHADER = preload("res://scripts/tamu_hd_terrain.gdshader")
const TREE_SHADER = preload("res://scripts/tamu_hd_tree.gdshader")
const ROOT := "res://assets/terrain/hd_fast_atlas/"
const TREE_ROOT := "res://assets/trees/"
const MOBILE_ROOT := "res://assets/trees/mobile_768/"
const SPECIES := [
    "fractureborn_oak", "skyward_forest_oak", "stormslope_beech",
    "marshkeeper_alder", "rootbound_hornbeam", "ironwind_pine",
    "ashskin_birch", "borderwatch_ash"]
const MATERIALS := ["forest_grass","forest_rocky","forest_sparse_litter",
    "forest_roots_litter","conifer_needle_litter","forest_moss_pebbles"]

static func enabled() -> bool:
    return OS.get_environment("TAMU_HD_MATERIALS") != "0"

static func terrain_bundle() -> Dictionary:
    if not enabled():
        return {}
    for suffix in ["albedo","normal"]:
        if not ResourceLoader.exists(ROOT + suffix + ".png"):
            push_warning("TAMU_HD_FAST_ATLAS_MISSING " + suffix)
            return {}
    var base: Texture2D = load(ROOT + "albedo.png")
    var nrm: Texture2D = load(ROOT + "normal.png")
    if base == null or nrm == null or base.get_size() != Vector2(1848,1584) or base.get_size() != nrm.get_size():
        push_warning("TAMU_HD_FAST_ATLAS_INVALID")
        return {}
    var material := ShaderMaterial.new()
    material.shader = TERRAIN_SHADER
    material.set_shader_parameter("hd_normal_atlas",nrm)
    print("TAMU_HD_FAST_TERRAIN_READY slots=168 land=137 wetland=31 samples=2 height=baked")
    return {"albedo":base,"material":material}

static func terrain_material() -> ShaderMaterial:
    return terrain_bundle().get("material") as ShaderMaterial

static func tree_asset(seed: int, family: String) -> Dictionary:
    if not enabled():
        return {}
    var candidates: Array[String] = []
    if family == "conifer":
        candidates = ["ironwind_pine"]
    else:
        candidates = ["fractureborn_oak","skyward_forest_oak","stormslope_beech",
            "marshkeeper_alder","rootbound_hornbeam","ashskin_birch","borderwatch_ash"]
    var name: String = candidates[posmod(seed,candidates.size())]
    var folder := MOBILE_ROOT + name + "/"
    if not ResourceLoader.exists(folder+"albedo.png") or not ResourceLoader.exists(folder+"normal.png"):
        push_warning("TAMU_HD_MOBILE_TREE_MISSING " + name)
        return {}
    var a: Texture2D = load(folder+"albedo.png")
    var n: Texture2D = load(folder+"normal.png")
    if a == null or n == null or a.get_size() != Vector2(768,768) or a.get_size() != n.get_size():
        push_warning("TAMU_HD_MOBILE_TREE_INVALID " + name)
        return {}
    var material := ShaderMaterial.new()
    material.shader = TREE_SHADER
    material.set_shader_parameter("tree_normal",n)
    return {"id":name,"albedo":a,"material":material}

static func verify_contract() -> bool:
    return MATERIALS.size() == 6 and SPECIES.size() == 8 and not ROOT.is_empty()
