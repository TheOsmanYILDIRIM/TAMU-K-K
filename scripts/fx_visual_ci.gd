extends SceneTree
# Small deterministic real-GL shader render, independent of game assets.
const Shadow = preload("res://scripts/object_shadow.gdshader")

func _initialize() -> void:
    call_deferred("_render")

func _render() -> void:
    var window := get_root()
    window.size = Vector2i(540, 360)
    var scene := Node2D.new()
    window.add_child(scene)
    var bg := ColorRect.new()
    bg.color = Color(0.26, 0.34, 0.22)
    bg.size = Vector2(540, 360)
    scene.add_child(bg)
    var source := Image.create(120, 160, false, Image.FORMAT_RGBA8)
    source.fill(Color(0.0, 0.0, 0.0, 0.0))
    for y in range(160):
        for x in range(120):
            var crown := pow((float(x) - 60.0) / 57.0, 2.0) + pow((float(y) - 59.0) / 52.0, 2.0) <= 1.0
            var trunk := x >= 54 and x <= 66 and y >= 76 and y < 155
            if crown or trunk:
                source.set_pixel(x, y, Color(0.25, 0.56, 0.19) if crown else Color(0.43, 0.24, 0.11))
    var texture := ImageTexture.create_from_image(source)
    var shadow := Sprite2D.new()
    shadow.texture = texture
    shadow.position = Vector2(260, 252)
    shadow.offset = Vector2(0, -15)
    var material := ShaderMaterial.new()
    material.shader = Shadow
    material.set_shader_parameter("solar_dir", Vector2(0.75, 0.2))
    material.set_shader_parameter("solar_length", 1.7)
    material.set_shader_parameter("opacity", 0.65)
    shadow.material = material
    scene.add_child(shadow)
    var original := Sprite2D.new()
    original.texture = texture
    original.position = Vector2(260, 252)
    original.offset = Vector2(0, -15)
    scene.add_child(original)
    for frame in range(4):
        await process_frame
    await RenderingServer.frame_post_draw
    var screenshot := window.get_texture().get_image()
    DirAccess.make_dir_recursive_absolute("res://screenshots")
    var err := screenshot.save_png("res://screenshots/fx-shadow-preview.png")
    if err != OK or screenshot.get_width() < 540 or screenshot.get_height() < 360:
        push_error("TAMU_FX_VISUAL_FAILED " + str(err))
        quit(41)
        return
    print("TAMU_FX_VISUAL_OK size=", screenshot.get_width(), "x", screenshot.get_height())
    quit(0)
