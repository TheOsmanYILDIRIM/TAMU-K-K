extends RefCounted
# Render-only 2.5D visual enrichment over the pinned authored R2 world.
# No changes to world objects, collisions, region geometry, or save identities.
# Stage gates: base -> mix -> variation -> detail. Production defaults detail.
const ATLAS_SIZE := Vector2(1848.0, 1584.0)
const CELL_SIZE := 132.0
const TILE_SIZE := 128.0
const OBJECT_ATLAS_SIZE := Vector2(1056.0, 1056.0)
const HIRES_OBJECT_ATLAS := "res://assets/terrain25d/atlas_objects_hires.png"
const MAX_DETAIL_QUADS := 1400
const MIX_SHADER = preload("res://scripts/terrain_mix.gdshader")
const WorldProjection = preload("res://scripts/world_projection.gd")

# The 60 high-resolution object slots follow sorted original_filename order.
# UVs are changed only in the transient parsed manifest, not the canonical source.
# Width/height remain logical 128px so world detail quads retain their size.
# Emergency mobile rendering tier: keep authored source/IDs untouched.
# Force this path in desktop CI with TAMU_MOBILE_PERF=1; TAMU_MOBILE_HD=1
# restores full quality for testing a known-fast phone.
static func mobile_fast_mode() -> bool:
    # Standalone full-resolution APK opts out of the mobile low-quality path.
    # Legacy/mobile benchmarks remain unchanged unless this setting is enabled.
    if bool(ProjectSettings.get_setting("tamu/mobile/full_quality", false)):
        return false
    return (OS.has_feature("mobile") or OS.get_environment("TAMU_MOBILE_PERF") == "1") \
        and OS.get_environment("TAMU_MOBILE_HD") != "1"

static func apply_highres_object_uvs(manifest: Dictionary) -> bool:
    if mobile_fast_mode() or OS.get_environment("TAMU_HIRES_OBJECTS") == "0":
        return false
    if not ResourceLoader.exists(HIRES_OBJECT_ATLAS):
        return false
    var objects: Array = []
    for item in manifest.get("assets", []):
        if item.get("kind") == "object" and item.get("atlas_page") == "atlas_01.png":
            objects.append(item)
    if objects.size() != 60:
        push_error("TAMU_HIRES_OBJECT_MANIFEST_COUNT_INVALID")
        return false
    objects.sort_custom(func(a, b): return str(a.get("original_filename", "")) < str(b.get("original_filename", "")))
    for i in range(objects.size()):
        var entry: Dictionary = objects[i]
        var x: int = i % 8
        var y: int = int(i / 8)
        entry["uv_rect"] = [float(x) / 8.0, float(y) / 8.0, 0.125, 0.125]
    return true

static func level() -> int:
    match OS.get_environment("TAMU_VISUAL_STAGE"):
        "base": return 0
        "mix": return 1
        "variation": return 2
        "detail", "": return 3
    return 3

static func variation(seed: int, kind: String) -> float:
    var n := float(posmod(seed / 7, 1009)) / 1008.0
    if kind == "tree":
        return lerpf(0.89, 1.22, n)
    if kind == "rock":
        return lerpf(0.79, 1.20, n)
    return lerpf(0.76, 1.24, n)

static func tint(seed: int) -> Color:
    var brightness := 0.91 + 0.18 * float(posmod(seed / 13, 101)) / 100.0
    var warmth := float(posmod(seed / 31, 101)) / 100.0
    return Color(brightness * (0.97 + 0.06 * warmth), brightness,
        brightness * (1.02 - 0.04 * warmth), 1.0)

static func _slot(asset: Dictionary) -> Vector2i:
    var uv: Array = asset["uv_rect"]
    return Vector2i(clampi(floori(float(uv[0]) * ATLAS_SIZE.x / CELL_SIZE),0,13),
        clampi(floori(float(uv[1]) * ATLAS_SIZE.y / CELL_SIZE),0,11))

static func _noise_texture() -> Texture2D:
    var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(64):
            # All samples match at tile boundaries through wraparound; no RNG
            # or user-state dependence. Low-frequency blend field on the GPU.
            var h: int = posmod((x * 137 + y * 397 + 11) * (x * 73 + y * 193 + 17), 65521)
            var h2: int = posmod((posmod(x + 1,64) * 137 + y * 397 + 11) *
                (posmod(x + 1,64) * 73 + y * 193 + 17), 65521)
            var v := int(round((float(h) / 65521.0 * 0.72 + float(h2) / 65521.0 * 0.28) * 255.0))
            image.set_pixel(x,y,Color8(v,v,v,255))
    return ImageTexture.create_from_image(image)

static func terrain_material(manifest: Dictionary) -> ShaderMaterial:
    var by_family := {}
    var materials: Array = []
    for item in manifest.get("assets",[]):
        if item.get("kind") != "terrain" or item.get("atlas_page") != "atlas_00.png":
            continue
        materials.append(item)
        var family := str(item.get("family",""))
        if not by_family.has(family):
            by_family[family] = []
        by_family[family].append(item)
    if materials.size() != 168:
        push_error("TAMU_TERRAIN_MIX_CATALOG_MISMATCH")
        return null
    var lut := Image.create(14,12,false,Image.FORMAT_RGBA8)
    lut.fill(Color(0,0,0,0))
    var partners := {"grass":"dirt","dirt":"grass","forest":"dirt","rock":"forest"}
    for item in materials:
        var family := str(item.get("family",""))
        if not partners.has(family):
            continue # wetland and water-adjacent materials stay unchanged
        var options: Array = by_family[str(partners[family])]
        if options.is_empty():
            continue
        var from: Vector2i = _slot(item)
        var selection: int = posmod(from.x * 19 + from.y * 23, options.size())
        var to: Vector2i = _slot(options[selection])
        var strength := 66 if family == "grass" else (54 if family == "forest" else 46)
        lut.set_pixel(from.x,from.y,Color8(to.x,to.y,strength,255))
    var material := ShaderMaterial.new()
    material.shader = MIX_SHADER
    material.set_shader_parameter("transition_lookup",ImageTexture.create_from_image(lut))
    material.set_shader_parameter("noise_field",_noise_texture())
    return material

# One immutable atlas mesh for small shrubs/pebbles. The world-space points
# are deterministic decorations, not harvestable instances and not obstacles.
static func detail_mesh(manifest: Dictionary, atlas: Texture2D,
        authored_objects: Array[Dictionary], authority: RefCounted) -> Dictionary:
    var family_assets := {}
    for item in manifest.get("assets",[]):
        if item.get("kind") == "object" and item.get("atlas_page") == "atlas_01.png":
            var family := str(item["family"])
            if not family_assets.has(family):
                family_assets[family] = []
            family_assets[family].append(item)
    for family in family_assets:
        family_assets[family].sort_custom(func(a,b): return a["id"] < b["id"])
    var vertices := PackedVector2Array()
    var uvs := PackedVector2Array()
    var colors := PackedColorArray()
    var count := 0
    for item in authored_objects:
        if count >= MAX_DETAIL_QUADS:
            break
        var seed := 19
        for ch in str(item["id"]).to_utf8_buffer():
            seed = posmod(seed * 33 + int(ch), 2147483647)
        for n in range(2):
            if count >= MAX_DETAIL_QUADS:
                break
            var h := posmod(seed + n * 87643, 2147483647)
            var theta := TAU * float(posmod(h, 360)) / 360.0
            var distance := 24.0 + float(posmod(h / 31, 40))
            var point: Vector2 = item["position"] + Vector2(cos(theta),sin(theta)) * distance
            var sample: Dictionary = authority.surface(point.x, point.y)
            if not bool(sample.get("walkable", false)) or str(sample.get("feature","")) != "grass":
                continue
            var family := "boulder" if posmod(h / 17, 5) == 0 else "shrub"
            if not family_assets.has(family):
                continue
            var options: Array = family_assets[family]
            var asset: Dictionary = options[posmod(h / 37, options.size())]
            var uv: Array = asset["uv_rect"]
            var size := Vector2(float(uv[2]),float(uv[3]))
            var ul := Vector2(float(uv[0]),float(uv[1]))
            var scale := (0.07 + float(posmod(h / 61, 15)) * 0.006) if family == "boulder" else (0.11 + float(posmod(h / 61, 17)) * 0.008)
            var w := float(asset.get("width",128)) * scale
            var hh := float(asset.get("height",128)) * scale
            var foot := WorldProjection.to_screen(point) - Vector2(0.0, float(sample["height"]) * 0.35)
            var a := foot + Vector2(-w * 0.5, -hh * 124.0 / 128.0)
            var b := a + Vector2(w,hh)
            var quad := [Vector2(a.x,a.y),Vector2(b.x,a.y),Vector2(b.x,b.y),
                Vector2(a.x,a.y),Vector2(b.x,b.y),Vector2(a.x,b.y)]
            var quad_uv := [ul,ul + Vector2(size.x,0),ul + size,ul,ul + size,ul + Vector2(0,size.y)]
            var col := tint(h)
            for k in range(6):
                vertices.append(quad[k])
                uvs.append(quad_uv[k])
                colors.append(col)
            count += 1
    if count == 0:
        return {"count":0,"node":null,"vertices":0}
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = colors
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    var layer := MeshInstance2D.new()
    layer.name = "TAMUEnvironmentalDetail"
    layer.mesh = mesh
    layer.texture = atlas
    layer.z_index = 2
    return {"count":count,"node":layer,"vertices":vertices.size()}

static func verify_contract() -> bool:
    return level() >= 0 and variation(55,"tree") > 0.8 and variation(55,"rock") < 1.3 and MAX_DETAIL_QUADS == 1400
