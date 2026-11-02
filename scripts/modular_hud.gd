extends CanvasLayer
# TAMU reference HUD. Each piece is independently replaceable through
# ui/hud/layout.json and original transparent PNGs.
# If the binary HUD package is absent, legacy functional controls remain.
const ZIP_PATH := "res://ui/hud/packs/TAMU_HUD_Correct_Split.zip"
const LAYOUT_PATH := "res://ui/hud/layout.json"
var host: Node
var overlay: Control
var sprites: Dictionary = {}
var layout: Dictionary = {}
var initialized := false
var zip: ZIPReader
func setup(game: Node) -> bool:
    host = game
    var manifest_text := ""
    if FileAccess.file_exists(LAYOUT_PATH):
        manifest_text = FileAccess.get_file_as_string(LAYOUT_PATH)
    if ResourceLoader.exists("res://ui/hud/portrait.png"):
        pass
    elif FileAccess.file_exists(ZIP_PATH):
        zip = ZIPReader.new()
        if zip.open(ZIP_PATH) != OK:
            return false
    else:
        return false
    if manifest_text.is_empty() and zip != null:
        manifest_text = zip.read_file("layout.json").get_string_from_utf8()
    var parsed = JSON.parse_string(manifest_text)
    if not parsed is Dictionary:
        push_warning("TAMU_MODULAR_HUD_LAYOUT_INVALID")
        return false
    layout = parsed
    layer = 109
    overlay = Control.new()
    overlay.name = "ReferenceHUD"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay)
    for key in layout:
        var cfg: Dictionary = layout[key]
        if not bool(cfg.get("visible",true)):
            continue
        var filename := "%s.png" % str(key)
        var texture: Texture2D
        if ResourceLoader.exists("res://ui/hud/"+filename):
            texture = load("res://ui/hud/"+filename)
        elif zip != null and zip.get_files().has(filename):
            var image := Image.new()
            if image.load_png_from_buffer(zip.read_file(filename)) != OK:
                continue
            texture = ImageTexture.create_from_image(image)
        if texture == null:
            continue
        var visual := TextureRect.new()
        visual.name = str(key)
        visual.texture = texture
        visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        visual.stretch_mode = TextureRect.STRETCH_SCALE
        visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.add_child(visual)
        sprites[key] = visual
    if sprites.is_empty():
        queue_free()
        return false
    get_viewport().size_changed.connect(_position_sprites)
    _position_sprites()
    initialized = true
    return true
func _position_sprites() -> void:
    if overlay == null:
        return
    var v := get_viewport().get_visible_rect().size
    for key in sprites:
        var cfg: Dictionary = layout[key]
        var pos: Array = cfg["pos"]
        var size: Array = cfg["size"]
        var visual: TextureRect = sprites[key]
        visual.position = Vector2(float(pos[0])*v.x,float(pos[1])*v.y)
        visual.size = Vector2(float(size[0])*v.x,float(size[1])*v.y)
func verify_contract() -> bool:
    return initialized and sprites.has("portrait") and sprites.has("hotbar") and sprites.has("joystick")
