extends Control
# TAMU resource card: presentation only. forest_harvest_gui.gd and main.gd
# retain canonical selection, inventory, harvesting, marking and Stage6 state.
const ART_ROOT := "res://ui/selection/parts/"
const PART_NAMES := ["panel", "title_tree", "subtitle_tree", "resource_bar",
    "button_primary", "button_detail", "button_mark", "icon_wood",
    "icon_axe", "icon_info", "icon_pin"]
const FALLBACK_TOOL := "res://assets/gui/pick.png"
var is_initialized: bool = false
var textures: Dictionary = {}
var buttons: Dictionary = {}
var font_sizes: Dictionary = {}
var heading: Label
var subtitle: Label
var item_name: Label
var quantity: Label
var status: Label
var mark_caption: Label
var item_icon: TextureRect
var action_icon: TextureRect

func _place(node: Control, where: Vector2, span: Vector2) -> void:
    node.anchor_left = where.x
    node.anchor_top = where.y
    node.anchor_right = where.x + span.x
    node.anchor_bottom = where.y + span.y
    node.offset_left = 0.0
    node.offset_top = 0.0
    node.offset_right = 0.0
    node.offset_bottom = 0.0

func _sprite(name: String, where: Vector2, span: Vector2, is_icon: bool = false) -> TextureRect:
    var node := TextureRect.new()
    node.name = name
    node.texture = textures[name]
    node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    node.stretch_mode = (TextureRect.STRETCH_KEEP_ASPECT_CENTERED if is_icon
        else TextureRect.STRETCH_SCALE)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(node)
    _place(node, where, span)
    return node

func _caption(name: String, value: String, where: Vector2, span: Vector2,
        px: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var node := Label.new()
    node.name = name
    node.text = value
    node.horizontal_alignment = align
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    node.clip_text = true
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.add_theme_font_size_override("font_size", px)
    node.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78))
    node.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.015, 0.92))
    node.add_theme_constant_override("shadow_offset_x", 1)
    node.add_theme_constant_override("shadow_offset_y", 2)
    add_child(node)
    _place(node, where, span)
    font_sizes[name] = px
    return node

func _button(name: String, art: String, icon_name: String, value: String,
        where: Vector2, span: Vector2, callback: Callable) -> TextureButton:
    var node := TextureButton.new()
    node.name = name
    node.texture_normal = textures[art]
    node.ignore_texture_size = true
    node.stretch_mode = TextureButton.STRETCH_SCALE
    node.mouse_filter = Control.MOUSE_FILTER_STOP
    node.focus_mode = Control.FOCUS_NONE
    node.tooltip_text = value
    node.pressed.connect(callback)
    add_child(node)
    _place(node, where, span)
    var glyph := TextureRect.new()
    glyph.name = "Glyph"
    glyph.texture = textures[icon_name]
    glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.add_child(glyph)
    if name == "PrimaryHarvest":
        _place(glyph, Vector2(0.285, 0.16), Vector2(0.13, 0.69))
    else:
        _place(glyph, Vector2(0.18, 0.18), Vector2(0.19, 0.66))
    var label := Label.new()
    label.name = "Caption"
    label.text = value
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.clip_text = true
    label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.80))
    label.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.01, 0.95))
    label.add_theme_constant_override("shadow_offset_y", 2)
    var base_px := 26 if name == "PrimaryHarvest" else 15
    label.add_theme_font_size_override("font_size", base_px)
    node.add_child(label)
    if name == "PrimaryHarvest":
        _place(label, Vector2(0.43, 0.10), Vector2(0.46, 0.80))
    else:
        _place(label, Vector2(0.35, 0.10), Vector2(0.60, 0.80))
    buttons[name] = node
    font_sizes[name] = base_px
    return node

func _update_type() -> void:
    if not is_initialized or size.x <= 1.0 or size.y <= 1.0:
        return
    # The existing popup is responsive; scale captions with its actual dimensions.
    var factor := clampf(minf(size.x / 440.0, size.y / 330.0), 0.60, 1.30)
    for name in ["Heading", "Subtitle", "ResourceName", "Amount", "Status"]:
        var node := get_node_or_null(name) as Label
        if node != null:
            node.add_theme_font_size_override("font_size", maxi(10, roundi(int(font_sizes[name]) * factor)))
    for name in buttons:
        var lbl := (buttons[name] as TextureButton).get_node("Caption") as Label
        lbl.add_theme_font_size_override("font_size", maxi(10, roundi(int(font_sizes[name]) * factor)))

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _update_type()

func initialize(on_harvest: Callable, on_detail: Callable, on_mark: Callable) -> bool:
    if is_initialized:
        return true
    var result: Dictionary = {}
    for name in PART_NAMES:
        var path := ART_ROOT + name + ".png"
        if not ResourceLoader.exists(path):
            push_warning("TAMU_SELECTION_ART_MISSING: " + path)
            return false
        var tex: Texture2D = load(path)
        if tex == null:
            push_warning("TAMU_SELECTION_ART_INVALID: " + path)
            return false
        result[name] = tex
    textures = result
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_PASS
    _sprite("panel", Vector2.ZERO, Vector2.ONE)
    # 124100.png is solely the measured layout reference; its baked text is NOT used.
    heading = _caption("Heading", "AĞAÇ", Vector2(0.407, 0.115),
        Vector2(0.50, 0.15), 30)
    subtitle = _caption("Subtitle", "Toplanabilir Kaynak", Vector2(0.407, 0.240),
        Vector2(0.52, 0.097), 17)
    var divider := ColorRect.new()
    divider.name = "Divider"
    divider.color = Color(0.88, 0.74, 0.52, 0.38)
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(divider)
    _place(divider, Vector2(0.375, 0.353), Vector2(0.55, 0.003))
    _sprite("resource_bar", Vector2(0.177, 0.391), Vector2(0.758, 0.147))
    item_icon = _sprite("icon_wood", Vector2(0.219, 0.404), Vector2(0.12, 0.123), true)
    item_name = _caption("ResourceName", "Odun", Vector2(0.358, 0.404),
        Vector2(0.32, 0.121), 21)
    quantity = _caption("Amount", "× 4", Vector2(0.735, 0.404),
        Vector2(0.16, 0.121), 19, HORIZONTAL_ALIGNMENT_RIGHT)
    _button("PrimaryHarvest", "button_primary", "icon_axe", "TOPLA",
        Vector2(0.176, 0.555), Vector2(0.758, 0.192), on_harvest)
    action_icon = (buttons["PrimaryHarvest"] as TextureButton).get_node("Glyph") as TextureRect
    _button("DetailAction", "button_detail", "icon_info", "DETAY",
        Vector2(0.176, 0.765), Vector2(0.355, 0.142), on_detail)
    _button("MarkAction", "button_mark", "icon_pin", "İŞARETLE",
        Vector2(0.557, 0.765), Vector2(0.373, 0.142), on_mark)
    mark_caption = (buttons["MarkAction"] as TextureButton).get_node("Caption") as Label
    status = _caption("Status", "", Vector2(0.19, 0.91),
        Vector2(0.72, 0.057), 11, HORIZONTAL_ALIGNMENT_CENTER)
    status.visible = false
    is_initialized = true
    _update_type()
    return true

func _load_icon(paths: Array[String]) -> Texture2D:
    for path in paths:
        if ResourceLoader.exists(path):
            var tex: Texture2D = load(path)
            if tex != null:
                return tex
    return null

func set_icons(resource_tex: Texture2D, tool_tex: Texture2D) -> void:
    # Optional mod/gameplay adapter. Does NOT mutate canonical inventory or IDs.
    if is_initialized:
        item_icon.texture = resource_tex
        action_icon.texture = tool_tex

func set_resource(kind: String, item_title: String, count: int) -> void:
    if not is_initialized:
        return
    heading.text = "AĞAÇ" if kind == "tree" else ("KAYA" if kind == "rock" else kind.to_upper())
    subtitle.text = "Toplanabilir Kaynak"
    item_name.text = item_title
    quantity.text = "× " + str(maxi(0, count))
    if kind == "tree":
        set_icons(textures["icon_wood"], textures["icon_axe"])
    elif kind == "rock":
        # Rock is NOT represented as wood. Use actual engine assets if present.
        set_icons(_load_icon(["res://assets/gui/stone.png", FALLBACK_TOOL]),
            _load_icon([FALLBACK_TOOL]))
    else:
        set_icons(null, null)
    set_marked(false)
    set_status("")

func set_marked(value: bool) -> void:
    if is_initialized:
        mark_caption.text = "İŞARETLİ" if value else "İŞARETLE"

func set_status(value: String) -> void:
    if is_initialized:
        status.text = value
        status.visible = not value.is_empty()

func verify_contract() -> bool:
    return (is_initialized and textures.size() == PART_NAMES.size()
        and buttons.has("PrimaryHarvest") and buttons.has("DetailAction")
        and buttons.has("MarkAction"))
