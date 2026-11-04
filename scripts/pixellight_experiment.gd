extends Node2D
# Genuine PixelLight 2D 1.0.2 isolated GL Compatibility experiment.
# No player, world, saved-state or authored texture mutations.
const PixelLightWorld = preload("res://scripts/pixellight_world.gd")
var sprites: Array[Sprite2D] = []
var test_frames := 0

func _ready() -> void:
    var addon_path := "res://addons/pixel_light_2d/pl_auto.gd"
    if not ResourceLoader.exists(addon_path):
        push_error("TAMU_PIXELLIGHT_ADDON_MISSING " + addon_path)
        get_tree().quit(81)
        return
    var auto_script: Script = load(addon_path)
    var ambient := CanvasModulate.new()
    ambient.color = Color(0.78, 0.82, 0.92)
    add_child(ambient)
    var sun := DirectionalLight2D.new()
    sun.energy = 0.85
    sun.rotation_degrees = -35.0
    add_child(sun)
    for i in range(3):
        var image := Image.create(96, 112, false, Image.FORMAT_RGBA8)
        image.fill(Color.TRANSPARENT)
        var center := Vector2(48, 55)
        for y in range(112):
            for x in range(96):
                var p := Vector2(x, y)
                if p.distance_to(center) < 32.0 or (absf(x - 48.0) < 7.0 and y > 50 and y < 108):
                    image.set_pixel(x, y, Color(0.23 + 0.17 * i, 0.58, 0.30, 1.0))
        var sprite := Sprite2D.new()
        sprite.texture = ImageTexture.create_from_image(image)
        sprite.position = Vector2(180.0 + i * 160.0, 420.0)
        add_child(sprite)
        sprites.append(sprite)
        if i > 0:
            var auto = auto_script.new()
            auto.lights = false
            auto.occluder = "base" if i == 2 else "none"
            sprite.add_child(auto)
    var label := Label.new()
    label.text = "PixelLight 2D | baseline / normals / normals + base occluder"
    label.position = Vector2(35, 70)
    add_child(label)

func _process(_delta: float) -> void:
    if OS.get_environment("TAMU_PIXELLIGHT_TEST") != "1":
        return
    test_frames += 1
    if test_frames != 18:
        return
    if sprites.size() != 3 or sprites[0].texture is CanvasTexture:
        push_error("TAMU_PIXELLIGHT_BASELINE_INVALID")
        get_tree().quit(82)
        return
    for i in [1, 2]:
        var material_texture: Texture2D = sprites[i].texture
        if not material_texture is CanvasTexture or (material_texture as CanvasTexture).normal_texture == null:
            push_error("TAMU_PIXELLIGHT_NORMAL_MISSING " + str(i))
            get_tree().quit(83)
            return
    var occluders := 0
    for child in sprites[2].get_children():
        if child is LightOccluder2D:
            occluders += 1
    if occluders == 0:
        push_error("TAMU_PIXELLIGHT_OCCLUDER_MISSING")
        get_tree().quit(84)
        return
    var snapshot := get_viewport().get_texture().get_image()
    if snapshot == null or snapshot.is_empty() or snapshot.save_png("/tmp/tamu-pixellight-preview.png") != OK:
        push_error("TAMU_PIXELLIGHT_SCREENSHOT_FAILED")
        get_tree().quit(85)
        return
    if not _verify_authored_atlas_bridge():
        push_error("TAMU_PIXELLIGHT_ATLAS_BRIDGE_FAILED")
        get_tree().quit(86)
        return
    print("TAMU_PIXELLIGHT_VISUAL_OK normal_maps=2 occluders=", occluders, " source=original_addon_1.0.2")
    get_tree().quit()

# A real AtlasTexture path (unlike the original synthetic Sprite2D-only demo).
# This mirrors TAMU's atlas-based authored tree/rock setup and verifies that
# source-alpha harvesting survives the normal-map CanvasTexture conversion.
func _verify_authored_atlas_bridge() -> bool:
    var atlas := AtlasTexture.new()
    atlas.atlas = sprites[0].texture
    atlas.region = Rect2(0.0, 0.0, 96.0, 112.0)
    var sprite := Sprite2D.new()
    sprite.name = "AuthoredAtlasTree"
    sprite.texture = atlas
    sprite.position = Vector2(-900, -900)
    add_child(sprite)
    var old_shadow := Sprite2D.new()
    old_shadow.texture = atlas
    old_shadow.position = sprite.position
    add_child(old_shadow)
    var item := {"kind": "tree", "position": Vector2.ZERO, "sprite": sprite, "silhouette": old_shadow}
    var items: Array[Dictionary] = [item]
    var result: Dictionary = PixelLightWorld.install(items, self, Vector2.ZERO)
    if int(result.get("count", 0)) != 1 or int(result.get("occluders", 0)) < 1:
        return false
    if old_shadow.visible or not bool(old_shadow.get_meta("tamu_pixellight_replaced_shadow", false)):
        return false
    if not sprite.texture is CanvasTexture or (sprite.texture as CanvasTexture).normal_texture == null:
        return false
    var alpha: Image = item.get("pixel_alpha_image")
    if alpha == null or alpha.get_size() != Vector2i(96, 112):
        return false
    var shadow_nodes := 0
    for node in sprite.get_children():
        if node is LightOccluder2D:
            shadow_nodes += 1
    if shadow_nodes < 1:
        return false
    print("TAMU_PIXELLIGHT_ATLAS_BRIDGE_OK objects=1 light=1 occluders=", shadow_nodes, " source_alpha=1")
    return true
