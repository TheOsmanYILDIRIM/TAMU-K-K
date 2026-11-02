extends CanvasLayer
# Optional replaceable HUD source sprites; no gameplay state stored here.
# User-supplied assets belong in res://assets/gui/hud/. The existing UI is
# retained as a fallback until images are actually installed.
var overlay: Control
var sprites: Dictionary = {}
var layout: Dictionary = {}
var layout_path := "res://assets/gui/hud/layout.json"
func setup(_host: Node) -> bool:
    if not ResourceLoader.exists("res://assets/gui/hud/portrait.png"):
        return false
    layer = 109
    overlay = Control.new()
    overlay.name = "HUDArt"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay)
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
    if not parsed is Dictionary:
        push_warning("TAMU_HUD_LAYOUT_INVALID")
        return false
    layout = parsed
    for name in layout:
        var path = "res://assets/gui/hud/%s.png" % str(name)
        if not ResourceLoader.exists(path):
            continue
        var node := TextureRect.new()
        node.name = str(name)
        node.texture = load(path)
        node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        node.stretch_mode = TextureRect.STRETCH_SCALE
        node.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.add_child(node)
        sprites[name] = node
    get_viewport().size_changed.connect(_position_sprites)
    _position_sprites()
    return true
func _position_sprites() -> void:
    if overlay == null:
        return
    var canvas = get_viewport().get_visible_rect().size
    for name in sprites:
        var config: Dictionary = layout[name]
        var at: Array = config["pos"]
        var dimensions: Array = config["size"]
        var node: TextureRect = sprites[name]
        node.position = Vector2(float(at[0])*canvas.x,float(at[1])*canvas.y)
        node.size = Vector2(float(dimensions[0])*canvas.x,float(dimensions[1])*canvas.y)
