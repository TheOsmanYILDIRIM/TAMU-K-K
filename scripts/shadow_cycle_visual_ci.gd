extends SceneTree
# Actual Godot shader screenshot / pixel gate. No Python stand-in render.
# Upper row: authored alpha shadow only. Lower row: same shadow + MultiMesh2D AO.
const Solar = preload("res://scripts/solar_shadow.gd")
const CastShader = preload("res://scripts/object_shadow.gdshader")
const AOShader = preload("res://scripts/contact_ao.gdshader")
const PANEL_WIDTH := 320
const BG := Color(0.38, 0.48, 0.32)
const HOURS := [9.0, 12.0, 17.75, 21.0]

func _initialize() -> void:
    call_deferred("_capture")

func _tree_texture() -> Texture2D:
    var image := Image.create(120, 160, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    for y in range(160):
        for x in range(120):
            var crown := pow((float(x) - 60.0) / 53.0, 2.0) + pow((float(y) - 59.0) / 47.0, 2.0) <= 1.0
            var trunk := x >= 54 and x <= 66 and y >= 77 and y < 156
            if crown or trunk:
                image.set_pixel(x, y, Color.WHITE)
    return ImageTexture.create_from_image(image)

func _capture() -> void:
    var window := get_root()
    window.size = Vector2i(PANEL_WIDTH * 4, 700)
    window.content_scale_size = window.size
    var root_node := Node2D.new()
    window.add_child(root_node)
    var bg := ColorRect.new()
    bg.color = BG
    bg.size = Vector2(window.size)
    root_node.add_child(bg)
    var texture := _tree_texture()
    for i in range(HOURS.size()):
        var solar: Dictionary = Solar.sample(HOURS[i])
        for layer in range(2):
            var ground := Vector2(float(i * PANEL_WIDTH + PANEL_WIDTH / 2), 252.0 + 330.0 * float(layer))
            var cast := Sprite2D.new()
            cast.texture = texture
            cast.centered = true
            cast.position = ground
            cast.offset = Vector2(0.0, 160.0 * (0.5 - 124.0 / 128.0))
            var material := ShaderMaterial.new()
            material.shader = CastShader
            material.set_shader_parameter("solar_dir", solar["cast_direction"])
            material.set_shader_parameter("solar_length", solar["cast_length"])
            material.set_shader_parameter("canopy_depth", 0.41)
            material.set_shader_parameter("opacity", solar["cast_opacity"])
            cast.material = material
            root_node.add_child(cast)
            if layer == 1:
                var mesh := MultiMesh.new()
                mesh.transform_format = MultiMesh.TRANSFORM_2D
                mesh.use_colors = true
                var quad := QuadMesh.new()
                quad.size = Vector2.ONE
                mesh.mesh = quad
                mesh.instance_count = 1
                mesh.set_instance_transform_2d(0, Transform2D(0.0, Vector2(124.0, 67.0), 0.0, ground))
                mesh.set_instance_color(0, Color.WHITE)
                var ao := MultiMeshInstance2D.new()
                ao.multimesh = mesh
                ao.material = ShaderMaterial.new()
                ao.material.shader = AOShader
                ao.material.set_shader_parameter("moon_level", solar["moon_ao"])
                root_node.add_child(ao)
    for frame in range(6):
        await process_frame
    await RenderingServer.frame_post_draw
    var screenshot := window.get_texture().get_image()
    DirAccess.make_dir_recursive_absolute("res://screenshots")
    var err := screenshot.save_png("res://screenshots/fx-shadow-cycle.png")
    if err != OK:
        push_error("TAMU_SHADOW_CYCLE_SCREENSHOT_FAILED")
        quit(51)
        return
    var solar_counts: Array[int] = []
    var ao_counts: Array[int] = []
    for i in range(HOURS.size()):
        var cast_count := 0
        var ao_count := 0
        var minx := 100000
        var maxx := -1
        var miny := 100000
        var maxy := -1
        for y in range(40, 329):
            for x in range(i * PANEL_WIDTH + 30, (i + 1) * PANEL_WIDTH - 30):
                var c := screenshot.get_pixel(x, y)
                if c.r < BG.r - 0.045:
                    cast_count += 1
                    minx = mini(minx, x)
                    maxx = maxi(maxx, x)
                    miny = mini(miny, y)
                    maxy = maxi(maxy, y)
        for y in range(365, 688):
            for x in range(i * PANEL_WIDTH + 30, (i + 1) * PANEL_WIDTH - 30):
                if screenshot.get_pixel(x, y).r < BG.r - 0.055:
                    ao_count += 1
        solar_counts.append(cast_count)
        ao_counts.append(ao_count)
        if i == 1 and (maxx - minx < 24 or maxy - miny < 24):
            push_error("TAMU_NOON_SHADOW_THIN_FAILED span=" + str(Vector2(maxx-minx, maxy-miny)))
            quit(52)
            return
    if solar_counts[0] < 400 or solar_counts[1] < 400:
        push_error("TAMU_DAYTIME_CAST_MISSING " + str(solar_counts))
        quit(53)
        return
    if solar_counts[2] >= solar_counts[0] or solar_counts[3] > 0:
        push_error("TAMU_TWILIGHT_FADE_FAILED " + str(solar_counts))
        quit(54)
        return
    if ao_counts[3] < 250:
        push_error("TAMU_NIGHT_AO_NOT_VISIBLE " + str(ao_counts))
        quit(55)
        return
    print("TAMU_SHADOW_CYCLE_PIXEL_OK solar=", solar_counts, " contact_ao=", ao_counts)
    quit(0)
