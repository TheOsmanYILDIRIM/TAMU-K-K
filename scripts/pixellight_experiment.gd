extends Node2D
# Isolated PixelLight visual test; does not change gameplay or the TAMU solar clock.
func _ready() -> void:
    var addon_path := "res://addons/pixel_light_2d/pl_auto.gd"
    if not ResourceLoader.exists(addon_path):
        push_error("PixelLight 2D addon not installed: " + addon_path)
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
        if i > 0:
            var auto = auto_script.new()
            auto.lights = false
            auto.occluder = "base" if i == 2 else "none"
            sprite.add_child(auto)
    var label := Label.new()
    label.text = "PixelLight 2D | left: baseline  middle: normals  right: normals + base occluder"
    label.position = Vector2(35, 70)
    add_child(label)
