extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        push_error("VISUAL_CAPTURE_FAILED: main scene missing")
        quit(2)
        return
    var instance := scene.instantiate()
    root.add_child(instance)
    current_scene = instance
    for i in range(20):
        await process_frame
    await RenderingServer.frame_post_draw
    var img := root.get_viewport().get_texture().get_image()
    if img == null or img.is_empty():
        push_error("VISUAL_CAPTURE_FAILED: no framebuffer")
        quit(3)
        return
    var result := img.save_png("res://build/osman-visual-render.png")
    if result != OK:
        push_error("VISUAL_CAPTURE_FAILED: could not save PNG %s" % result)
        quit(4)
        return
    print("OSMAN_VISUAL_CAPTURE_OK %dx%d" % [img.get_width(),img.get_height()])
    quit(0)
