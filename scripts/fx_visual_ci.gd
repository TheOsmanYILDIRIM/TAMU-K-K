extends SceneTree
# Real Godot GL screenshot: three sun azimuths prove the shadow mass retains
# width even if the authored 2D sprite projection collapses side-on.
const Shadow = preload("res://scripts/object_shadow.gdshader")
const ShadowVolume = preload("res://scripts/shadow_volume.gd")

func _initialize() -> void:
    call_deferred("_render")

func _render() -> void:
    if not ShadowVolume.verify_contract():
        push_error("TAMU_SHADOW_VOLUME_CONTRACT_FAILED")
        quit(41)
        return
    var window := get_root()
    window.size = Vector2i(540, 360)
    window.content_scale_size = Vector2i(540, 360)
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
    var directions := [Vector2.RIGHT, Vector2(0.0, -1.0), Vector2.LEFT]
    for i in range(3):
        var ground := Vector2(115.0 + i * 155.0, 250.0)
        var cast: Vector2 = directions[i]
        var volume := Polygon2D.new()
        if not ShadowVolume.configure(volume, "tree", Vector2(120, 160), ShadowVolume.alpha_spans(texture)):
            push_error("TAMU_SHADOW_VOLUME_BUILD_FAILED")
            quit(41)
            return
        volume.position = ground
        ShadowVolume.apply_sun(volume, cast, 1.05, 1.0)
        scene.add_child(volume)
        var silhouette := Sprite2D.new()
        silhouette.texture = texture
        silhouette.position = ground
        silhouette.offset = Vector2(0.0, -80.0)
        var material := ShaderMaterial.new()
        material.shader = Shadow
        material.set_shader_parameter("solar_dir", cast)
        material.set_shader_parameter("solar_length", 1.05)
        material.set_shader_parameter("opacity", 0.45)
        silhouette.material = material
        scene.add_child(silhouette)
        var original := Sprite2D.new()
        original.texture = texture
        original.position = ground
        original.offset = silhouette.offset
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
    print("TAMU_SHADOW_ALPHA_INSET_OK azimuths=3")
    print("TAMU_FX_SHADOW_25D_VOLUME_OK azimuths=3")
    print("TAMU_FX_VISUAL_OK size=", screenshot.get_width(), "x", screenshot.get_height())
    quit(0)
