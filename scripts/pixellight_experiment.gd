extends Node2D
# Genuine PixelLight 2D 1.0.2 isolated GL Compatibility experiment.
# No player, world, saved-state or authored texture mutations.
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
    print("TAMU_PIXELLIGHT_VISUAL_OK normal_maps=2 occluders=", occluders, " source=original_addon_1.0.2")
    get_tree().quit()
