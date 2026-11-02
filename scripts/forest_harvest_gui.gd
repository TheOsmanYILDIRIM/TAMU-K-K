extends CanvasLayer
# Forest resource card: art textures are baked ONCE by build_forest_gui.py.
# No gameplay authority, inventory edits, or per-frame texture generation.
const BLUR_SHADER = preload("res://scripts/forest_focus.gdshader")
var host: Node2D
var blur_layer: CanvasLayer
var blur_rect: ColorRect
var bokeh: TextureRect
var focus_layer: CanvasLayer
var focus: Sprite2D
var focus_outline: Sprite2D
var root: Control
var panel: NinePatchRect
var connector: Line2D
var target_ring: Line2D
var title_label: Label
var subtitle_label: Label
var item_label: Label
var quantity_label: Label
var status_label: Label
var mark_label: Label
var last_viewport := Vector2.ZERO
var target_position := Vector2.ZERO
var panel_open := false
var marked := false
var entrance: Tween
var art_root := "res://assets/gui/"
var main_buttons: Array[TextureButton] = []

func setup(game: Node2D) -> void:
    host = game
    layer = 115
    blur_layer = CanvasLayer.new()
    blur_layer.name = "ForestSelectionBackdrop"
    blur_layer.layer = 105
    host.add_child(blur_layer)
    blur_rect = ColorRect.new()
    blur_rect.name = "SelectiveWorldDefocus"
    blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var material := ShaderMaterial.new()
    material.shader = BLUR_SHADER
    blur_rect.material = material
    blur_layer.add_child(blur_rect)
    bokeh = TextureRect.new()
    bokeh.name = "ForestBokeh"
    bokeh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bokeh.texture = load(art_root + "bokeh.png")
    bokeh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bokeh.stretch_mode = TextureRect.STRETCH_SCALE
    bokeh.modulate.a = 0.24
    bokeh.mouse_filter = Control.MOUSE_FILTER_IGNORE
    blur_layer.add_child(bokeh)
    blur_layer.visible = false

    focus_layer = CanvasLayer.new()
    focus_layer.layer = 107
    focus_layer.name = "SelectedObjectFocus"
    host.add_child(focus_layer)
    focus = Sprite2D.new()
    focus.name = "FocusedSource"
    focus.visible = false
    focus.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    focus_layer.add_child(focus)
    focus_outline = Sprite2D.new()
    focus_outline.name = "FocusedGoldContour"
    focus.add_child(focus_outline)

    root = Control.new()
    root.name = "ForestInteractionOverlay"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    connector = Line2D.new()
    connector.name = "FineGoldTargetLink"
    connector.width = 1.8
    connector.default_color = Color(0.99,0.91,0.68,0.91)
    connector.antialiased = true
    connector.visible = false
    root.add_child(connector)
    target_ring = Line2D.new()
    target_ring.name = "GoldTargetRing"
    target_ring.width = 2.2
    target_ring.default_color = Color(1.0,0.83,0.34)
    target_ring.antialiased = true
    target_ring.visible = false
    root.add_child(target_ring)

    panel = NinePatchRect.new()
    panel.name = "HarvestWoodPanel"
    panel.texture = load(art_root + "panel.png")
    panel.patch_margin_left = 60
    panel.patch_margin_right = 60
    panel.patch_margin_top = 60
    panel.patch_margin_bottom = 60
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(panel)
    _panel_label("Heading",Vector2(0.27,0.075),Vector2(0.68,0.13),28,
        Color(1,0.93,0.77),true)
    title_label = panel.get_node("Heading")
    _panel_label("Subtitle",Vector2(0.27,0.204),Vector2(0.68,0.09),15,
        Color(0.81,0.73,0.60),false)
    subtitle_label = panel.get_node("Subtitle")
    _panel_label("Resource",Vector2(0.28,0.345),Vector2(0.44,0.095),18,
        Color(0.95,0.89,0.73),false)
    item_label = panel.get_node("Resource")
    _panel_label("Quantity",Vector2(0.72,0.345),Vector2(0.20,0.095),17,
        Color(1.0,0.92,0.79),false)
    quantity_label = panel.get_node("Quantity")
    quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _panel_label("Status",Vector2(0.12,0.87),Vector2(0.77,0.10),13,
        Color(0.94,0.77,0.45),false)
    status_label = panel.get_node("Status")
    var badge := TextureRect.new()
    badge.name = "LeafMedallion"
    badge.texture = load(art_root + "leaf.png")
    badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(badge)
    _percent_rect(badge,Vector2(0.09,0.09),Vector2(0.16,0.18))
    var resource_icon := TextureRect.new()
    resource_icon.name = "ResourceIcon"
    resource_icon.texture = load(art_root + "log.png")
    resource_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    resource_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    resource_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(resource_icon)
    _percent_rect(resource_icon,Vector2(0.12,0.335),Vector2(0.13,0.13))

    _card_button("PrimaryHarvest",art_root + "button_oak.png",
        Vector2(0.11,0.49),Vector2(0.79,0.18),"TOPLA","basket",
        Callable(host,"_try_harvest"))
    _card_button("DetailAction",art_root + "button_small.png",
        Vector2(0.11,0.695),Vector2(0.36,0.155),"DETAY","leaf",
        Callable(self,"_detail"))
    _card_button("MarkAction",art_root + "button_small.png",
        Vector2(0.52,0.695),Vector2(0.37,0.155),"İŞARETLE","pin",
        Callable(self,"_mark"))
    mark_label = panel.get_node("MarkAction/Caption")
    panel.visible = false
    for x in [
        ["BuildAction","KUR","pick","_place_workbench"],
        ["StationAction","TEZGAH","hammer","core:bench_from_planks"],
        ["PlankAction","TAHTA","log","core:planks_from_log"],
        ["HarvestAction","TOPLA","basket","_try_harvest"]
    ]:
        var callback: Callable = Callable(host,str(x[3])) if str(x[3]).begins_with("_") else Callable(host,"_begin_craft").bind(str(x[3]))
        var button := _make_textured_button(str(x[0]),art_root + "button_green.png",str(x[1]),str(x[2]),callback)
        root.add_child(button)
        main_buttons.append(button)
    _hide_legacy_buttons()
    set_process(true)
    _layout()

func _hide_legacy_buttons() -> void:
    var legacy := host.get_node_or_null("HarvestTestUI/HarvestOverlay")
    if legacy != null:
        for child in legacy.get_children():
            if child is Button or child is Label:
                child.visible = false

func _percent_rect(node: Control, pos: Vector2, span: Vector2) -> void:
    node.anchor_left = pos.x
    node.anchor_top = pos.y
    node.anchor_right = pos.x+span.x
    node.anchor_bottom = pos.y+span.y
    node.offset_left = 0
    node.offset_top = 0
    node.offset_right = 0
    node.offset_bottom = 0

func _panel_label(name: String, pos: Vector2, size_ratio: Vector2, font_size: int,
        color: Color, bold: bool) -> void:
    var label := Label.new()
    label.name = name
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_color_override("font_color",color)
    label.add_theme_color_override("font_shadow_color",Color(0.05,0.03,0.02,0.95))
    label.add_theme_constant_override("shadow_offset_x",1)
    label.add_theme_constant_override("shadow_offset_y",2)
    label.add_theme_font_size_override("font_size",font_size)
    label.clip_text = true
    panel.add_child(label)
    _percent_rect(label,pos,size_ratio)

func _make_textured_button(name: String, skin: String, caption: String,
        icon: String, action: Callable) -> TextureButton:
    var button := TextureButton.new()
    button.name = name
    button.texture_normal = load(skin)
    button.ignore_texture_size = true
    button.stretch_mode = TextureButton.STRETCH_SCALE
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.pressed.connect(action)
    var glyph := TextureRect.new()
    glyph.name = "Icon"
    glyph.texture = load(art_root + icon + ".png")
    glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(glyph)
    _percent_rect(glyph,Vector2(0.07,0.19),Vector2(0.24,0.63))
    var label := Label.new()
    label.name = "Caption"
    label.text = caption
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size",19)
    label.add_theme_color_override("font_color",Color(1.0,0.94,0.79))
    label.add_theme_color_override("font_shadow_color",Color(0.06,0.03,0.015,0.95))
    label.add_theme_constant_override("shadow_offset_y",2)
    button.add_child(label)
    _percent_rect(label,Vector2(0.30,0.06),Vector2(0.67,0.82))
    return button

func _card_button(name: String,skin: String,pos: Vector2,
        size_ratio: Vector2,caption: String,icon: String,action: Callable) -> void:
    var b := _make_textured_button(name,skin,caption,icon,action)
    panel.add_child(b)
    _percent_rect(b,pos,size_ratio)
    b.get_node("Caption").add_theme_font_size_override("font_size",20 if name=="PrimaryHarvest" else 14)

func _layout() -> void:
    if host == null or panel == null:
        return
    var view: Vector2 = get_viewport().get_visible_rect().size
    if view == last_viewport:
        return
    last_viewport = view
    target_position = Vector2(view.x - minf(view.x*0.50,360.0) - 10.0,
        clampf(view.y*0.19,70.0,view.y*0.35))
    panel.size = Vector2(minf(view.x*0.50,360.0),clampf(view.y*0.255,205.0,290.0))
    if panel.visible:
        panel.position = target_position
    var w := clampf(view.x*0.245,140.0,184.0)
    var bh := clampf(view.y*0.07,63.0,80.0)
    for i in range(main_buttons.size()):
        var b: TextureButton = main_buttons[i]
        b.size = Vector2(w,bh)
        b.position = Vector2(view.x-w-8.0,view.y*0.65 + i*(bh+8.0))
    blur_rect.size = view
    bokeh.size = view

func open_for(item: Dictionary) -> void:
    if item.is_empty():
        return
    marked = false
    mark_label.text = "İŞARETLE"
    title_label.text = "AĞAÇ" if str(item["kind"])=="tree" else "KAYA"
    subtitle_label.text = "Toplanabilir Kaynak"
    var drop: Dictionary = host.gameplay.harvest_drop(str(item["kind"]))
    var item_id := str(drop.get("def_id",""))
    item_label.text = "Odun" if item_id=="core:wood_log" else ("Taş" if item_id=="core:stone" else item_id)
    quantity_label.text = "× " + str(drop.get("count",0))
    var resource_icon: TextureRect = panel.get_node("ResourceIcon")
    resource_icon.texture = load(art_root + ("log.png" if str(item["kind"])=="tree" else "pick.png"))
    status_label.text = "KAYNAĞI TOPLAMAK İÇİN DOKUN"
    blur_layer.visible = true
    focus.visible = true
    connector.visible = true
    target_ring.visible = true
    _layout()
    if entrance != null and entrance.is_running():
        entrance.kill()
    panel.visible = true
    panel.position = Vector2(last_viewport.x+18.0,target_position.y)
    entrance = create_tween()
    entrance.set_trans(Tween.TRANS_CUBIC)
    entrance.set_ease(Tween.EASE_OUT)
    entrance.tween_property(panel,"position",target_position,0.32)
    panel_open = true
    _sync_focus(item)
    print("TAMU_FOREST_PANEL_OPEN id=",item["id"])

func close() -> void:
    panel_open = false
    blur_layer.visible = false
    focus.visible = false
    connector.visible = false
    target_ring.visible = false
    panel.visible = false

func set_status(message: String) -> void:
    if panel != null and panel.visible and status_label != null:
        status_label.text = message

func _detail() -> void:
    if host.selected_harvest.is_empty():
        return
    var item: Dictionary = host.selected_harvest
    var r := float(item.get("radius",0.0))
    set_status(("AĞAÇ" if str(item["kind"])=="tree" else "KAYA") + " · MENZİL " + str(snappedf(r,1.0)))
    print("TAMU_HARVEST_DETAIL id=",item["id"])

func _mark() -> void:
    if host.selected_harvest.is_empty():
        return
    marked = not marked
    mark_label.text = "İŞARETLİ" if marked else "İŞARETLE"
    set_status("KAYNAK İŞARETLENDİ" if marked else "İŞARET KALDIRILDI")
    print("TAMU_HARVEST_MARK id=",host.selected_harvest["id"]," active=",marked)

func _sync_focus(item: Dictionary) -> void:
    var sprite: Sprite2D = item["sprite"]
    var xf := sprite.get_global_transform_with_canvas()
    focus.texture = sprite.texture
    focus.centered = sprite.centered
    focus.offset = sprite.offset
    focus.flip_h = sprite.flip_h
    focus.position = xf*Vector2.ZERO
    focus.scale = sprite.scale * host.get_node("Camera2D").zoom
    if host.selected_harvest_outline != null:
        focus_outline.texture = host.selected_harvest_outline.texture
        focus_outline.centered = sprite.centered
        focus_outline.offset = sprite.offset
        focus_outline.flip_h = sprite.flip_h
        focus_outline.material = host.selected_harvest_outline.material
    var anchor := xf * sprite.get_rect().get_center()
    if panel.visible:
        var dest := panel.position + Vector2(panel.size.x*0.26,panel.size.y*0.92)
        connector.points = PackedVector2Array([anchor,Vector2(anchor.x+18.0,anchor.y-21.0),dest])
        var radius := 7.0
        var ring := PackedVector2Array()
        for i in range(25):
            var angle := TAU*float(i)/24.0
            ring.append(anchor+Vector2(cos(angle),sin(angle))*radius)
        target_ring.points = ring

func _process(_dt: float) -> void:
    _layout()
    if panel_open and host != null and not host.selected_harvest.is_empty():
        _sync_focus(host.selected_harvest)
