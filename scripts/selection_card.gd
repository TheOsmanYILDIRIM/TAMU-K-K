extends Control
# Selection card art layer only. Gameplay authority remains in main.gd.
# Transparent images from the user's 124069 reference, not UI screenshots.
const ART_ROOT := "res://ui/selection/parts/"
var ready := false
var buttons: Dictionary = {}
var kind_heading: Label
var tree_heading: TextureRect
var item_name: Label
var quantity: Label
var status: Label
var mark_caption: Label
var item_icon: TextureRect
var textures: Dictionary = {}

func _texture(name: String) -> Texture2D:
    if not ResourceLoader.exists(ART_ROOT + name + ".png"):
        return null
    return load(ART_ROOT + name + ".png")

func _place(node: Control, pos: Vector2, span: Vector2) -> void:
    node.anchor_left = pos.x
    node.anchor_top = pos.y
    node.anchor_right = pos.x + span.x
    node.anchor_bottom = pos.y + span.y
    node.offset_left = 0
    node.offset_top = 0
    node.offset_right = 0
    node.offset_bottom = 0

func _image(name: String, pos: Vector2, span: Vector2) -> TextureRect:
    var image := TextureRect.new()
    image.name = name
    image.texture = textures[name]
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_SCALE
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(image)
    _place(image,pos,span)
    return image

func _label(name: String, value: String, pos: Vector2, span: Vector2,
        font_size: int, centered: bool = false) -> Label:
    var label := Label.new()
    label.name = name
    label.text = value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",Color(0.98,0.91,0.74))
    label.add_theme_color_override("font_shadow_color",Color(0.06,0.03,0.01,0.98))
    label.add_theme_constant_override("shadow_offset_x",1)
    label.add_theme_constant_override("shadow_offset_y",2)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.clip_text = true
    add_child(label)
    _place(label,pos,span)
    return label

func _button(name: String, skin: String, icon_name: String,
        caption: String, pos: Vector2, span: Vector2, action: Callable) -> TextureButton:
    var button := TextureButton.new()
    button.name = name
    button.texture_normal = textures[skin]
    button.ignore_texture_size = true
    button.stretch_mode = TextureButton.STRETCH_SCALE
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(action)
    add_child(button)
    _place(button,pos,span)
    var glyph := TextureRect.new()
    glyph.name = "Glyph"
    glyph.texture = textures[icon_name]
    glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    button.add_child(glyph)
    _place(glyph,Vector2(0.11,0.14),Vector2(0.20,0.73))
    var label := Label.new()
    label.name = "Caption"
    label.text = caption
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_color_override("font_color",Color(1.0,0.94,0.77))
    label.add_theme_color_override("font_shadow_color",Color(0.08,0.04,0.015,0.95))
    label.add_theme_constant_override("shadow_offset_y",2)
    label.add_theme_font_size_override("font_size",22 if name=="PrimaryHarvest" else 15)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    button.add_child(label)
    _place(label,Vector2(0.32,0.10),Vector2(0.61,0.80))
    buttons[name] = button
    return button

func initialize(on_harvest: Callable, on_detail: Callable, on_mark: Callable) -> bool:
    var needed := ["panel","title_tree","subtitle_tree","resource_bar",
        "button_primary","button_detail","button_mark",
        "icon_wood","icon_axe","icon_info","icon_pin"]
    for name in needed:
        var image := _texture(name)
        if image == null:
            return false
        textures[name] = image
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_PASS
    _image("panel",Vector2.ZERO,Vector2.ONE)
    tree_heading = _image("title_tree",Vector2(0.28,0.115),Vector2(0.53,0.13))
    kind_heading = _label("OtherHeading","KAYA",Vector2(0.29,0.10),Vector2(0.54,0.15),26)
    kind_heading.visible = false
    _image("subtitle_tree",Vector2(0.27,0.259),Vector2(0.64,0.077))
    _image("resource_bar",Vector2(0.105,0.386),Vector2(0.81,0.145))
    item_icon = _image("icon_wood",Vector2(0.14,0.402),Vector2(0.14,0.105))
    item_name = _label("ResourceName","Odun",Vector2(0.32,0.394),Vector2(0.36,0.13),18)
    quantity = _label("Amount","× 4–8",Vector2(0.73,0.394),Vector2(0.17,0.13),18,true)
    _button("PrimaryHarvest","button_primary","icon_axe","TOPLA",
        Vector2(0.10,0.55),Vector2(0.82,0.175),on_harvest)
    _button("DetailAction","button_detail","icon_info","DETAY",
        Vector2(0.10,0.745),Vector2(0.395,0.139),on_detail)
    _button("MarkAction","button_mark","icon_pin","İŞARETLE",
        Vector2(0.515,0.745),Vector2(0.395,0.139),on_mark)
    mark_caption = buttons["MarkAction"].get_node("Caption")
    status = _label("Status","",Vector2(0.16,0.89),Vector2(0.73,0.075),13,true)
    ready = true
    return true

func set_resource(kind: String, item_title: String, count: int) -> void:
    if not ready:
        return
    tree_heading.visible = kind=="tree"
    kind_heading.visible = kind!="tree"
    kind_heading.text = "KAYA" if kind=="rock" else kind.to_upper()
    item_name.text = item_title
    quantity.text = "× " + str(count)
    item_icon.texture = textures["icon_wood"] if kind=="tree" else load("res://assets/gui/pick.png")
    set_marked(false)
    set_status("")

func set_marked(value: bool) -> void:
    if ready:
        mark_caption.text = "İŞARETLİ" if value else "İŞARETLE"

func set_status(value: String) -> void:
    if ready:
        status.text = value

func verify_contract() -> bool:
    return ready and buttons.has("PrimaryHarvest") and buttons.has("DetailAction") and buttons.has("MarkAction")
