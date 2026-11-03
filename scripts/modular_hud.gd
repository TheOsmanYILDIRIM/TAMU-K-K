extends CanvasLayer
# Functional portrait HUD. One art/control surface, never decorative buttons over old ones.
const ART := "res://assets/ui/hud/parts/"
const MINIMAP = preload("res://scripts/minimap.gd")
const PACK := "res://assets/ui/hud/packs/TAMU_HUD_Correct_Split.zip"
var host: Node
var root: Control
var sprites: Dictionary = {}
var controls: Dictionary = {}
var zip: ZIPReader
var initialized := false
var selected_index := 0
var joystick_origin := Vector2.ZERO
var joystick_span := 152.0
var alert: Label
var minimap: Control
func _tex(name: String) -> Texture2D:
    var path := ART + name + ".png"
    if ResourceLoader.exists(path):
        return load(path)
    if zip != null and zip.get_files().has(name + ".png"):
        var img := Image.new()
        if img.load_png_from_buffer(zip.read_file(name + ".png")) == OK:
            return ImageTexture.create_from_image(img)
    return null
func _art(name: String) -> TextureRect:
    var t := _tex(name)
    if t == null:
        return null
    var rect := TextureRect.new()
    rect.name = name
    rect.texture = t
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(rect)
    sprites[name] = rect
    return rect
func _button(name: String, art: String, action: Callable) -> TextureButton:
    var t := _tex(art)
    if t == null:
        return null
    var b := TextureButton.new()
    b.name = name
    b.texture_normal = t
    b.ignore_texture_size = true
    b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    b.mouse_filter = Control.MOUSE_FILTER_STOP
    b.pressed.connect(action)
    root.add_child(b)
    controls[name] = b
    return b
func _message(message: String) -> void:
    if alert != null:
        alert.text = message
func _zoom(amount: float) -> void:
    if minimap != null:
        minimap.call("change_zoom",amount)
func _action(key: String) -> void:
    match key:
        "interact":
            host.call("_try_harvest")
        "attack":
            _message("SALDIRI — henüz oynanışa bağlı değil")
        "crouch":
            _message("EĞİLME — henüz oynanışa bağlı değil")
        "sprint":
            _message("KOŞMA — henüz oynanışa bağlı değil")
        "bag","codex","forge","journal","growth","menu":
            _message(key.to_upper() + " — ekran henüz uygulanmadı")
        _:
            _message(key)
func _slot(slot: int) -> void:
    selected_index = slot
    _layout()
    _message("HIZLI ERİŞİM " + str(slot + 1))
func setup(game: Node) -> bool:
    host = game
    if not ResourceLoader.exists(ART + "portrait.png"):
        if not FileAccess.file_exists(PACK):
            return false
        zip = ZIPReader.new()
        if zip.open(PACK) != OK:
            return false
    layer = 119
    root = Control.new()
    root.name = "TouchHud"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    for n in ["portrait","health_water_energy","compass_and_zoom","joystick","joystick_thumb","blank_hotbar","selected_slot"]:
        _art(n)
    minimap = MINIMAP.new()
    minimap.name = "WorldMinimap"
    minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(minimap)
    for n in ["codex","forge","bag","menu","journal","growth","interact","crouch","sprint"]:
        _button(n,n,Callable(self,"_action").bind(n))
    _button("attack","blank_attack",Callable(self,"_action").bind("attack"))
    # Plus/minus artwork is already baked into the compass; hitboxes only.
    for key in ["zoom_plus","zoom_minus"]:
        var hit := Button.new()
        hit.name = key
        hit.flat = true
        hit.focus_mode = Control.FOCUS_NONE
        hit.mouse_filter = Control.MOUSE_FILTER_STOP
        hit.pressed.connect(Callable(self,"_zoom").bind(1.15 if key=="zoom_plus" else 1.0/1.15))
        root.add_child(hit)
        controls[key] = hit
    for index in range(8):
        var slot_art := _art("empty_slot")
        if slot_art != null:
            # The same transparent texture is independently positioned per slot.
            slot_art.name = "EmptySlot%d" % index
            sprites["empty_slot%d" % index] = slot_art
    sprites.erase("empty_slot")
    for index in range(8):
        var hit := Button.new()
        hit.name = "Hotbar%d" % index
        hit.flat = true
        hit.focus_mode = Control.FOCUS_NONE
        hit.mouse_filter = Control.MOUSE_FILTER_STOP
        hit.pressed.connect(Callable(self,"_slot").bind(index))
        root.add_child(hit)
        controls["hotbar%d" % index] = hit
    # Selected frame must render ABOVE every empty slot.
    if sprites.has("selected_slot"):
        root.move_child(sprites["selected_slot"],root.get_child_count()-1)
    alert = Label.new()
    alert.name = "ActionFeedback"
    alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
    alert.add_theme_color_override("font_color",Color(1.0,0.88,0.58))
    root.add_child(alert)
    # Remove visual duplicates: the gameplay authority is still host.
    var forest = host.get("forest_gui")
    if forest != null:
        for old in forest.get("main_buttons"):
            old.visible = false
            old.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if host.get("joystick_base") != null:
        (host.get("joystick_base") as Panel).modulate.a = 0.0
    get_viewport().size_changed.connect(_layout)
    set_process(true)
    _layout()
    initialized = sprites.has("portrait") and sprites.has("blank_hotbar") and sprites.has("joystick_thumb")
    return initialized
func _put(key: String, at: Vector2, dimension: Vector2) -> void:
    var node: Control = sprites.get(key,controls.get(key))
    if node != null:
        node.position = at
        node.size = dimension
func _layout() -> void:
    if root == null:
        return
    var v := get_viewport().get_visible_rect().size
    var margin := maxf(8.0,v.x*0.025)
    var top := maxf(12.0,v.y*0.022)
    var circle := clampf(v.x*0.135,50.0,76.0)
    var compact := clampf(v.x*0.113,44.0,65.0)
    var bar_height := clampf(v.x*0.155,70.0,105.0)
    var bottom := v.y - maxf(20.0,v.y*0.03) - bar_height
    _put("portrait",Vector2(margin,top),Vector2(circle*1.18,circle*1.28))
    _put("health_water_energy",Vector2(margin+circle*1.22,top+8.0),Vector2(v.x*0.46,circle*1.12))
    for i in range(4):
        _put(["codex","forge","bag","menu"][i],Vector2(v.x-(4-i)*(compact+3.0)-margin,top),Vector2(compact,compact))
    for i in range(2):
        _put(["journal","growth"][i],Vector2(margin,top+circle*1.7+i*(compact+12.0)),Vector2(compact,compact))
    var compass := clampf(v.x*0.38,150.0,224.0)
    var compass_pos := Vector2(v.x-compass-margin,top+circle+18.0)
    _put("compass_and_zoom",compass_pos,Vector2(compass,compass))
    minimap.position = compass_pos + Vector2.ONE * compass * 0.215
    minimap.size = Vector2.ONE * compass * 0.57
    # One zoom pair; the compass texture contains no extra separate buttons.
    _put("zoom_plus",compass_pos+Vector2(compass*0.79,compass*0.53),Vector2(compass*0.18,compass*0.18))
    _put("zoom_minus",compass_pos+Vector2(compass*0.79,compass*0.75),Vector2(compass*0.18,compass*0.18))
    _put("blank_hotbar",Vector2(margin,bottom),Vector2(v.x-2.0*margin,bar_height))
    var slot_w := (v.x-2.0*margin)*0.947/8.0
    var first_x := margin+(v.x-2.0*margin)*0.026
    for i in range(8):
        var x := first_x+slot_w*float(i)
        _put("empty_slot%d"%i,Vector2(x,bottom+bar_height*0.07),Vector2(slot_w,bar_height*0.86))
        _put("hotbar%d"%i,Vector2(x,bottom+bar_height*0.07),Vector2(slot_w,bar_height*0.86))
    _put("selected_slot",Vector2(first_x+slot_w*float(selected_index),bottom+bar_height*0.04),Vector2(slot_w,bar_height*0.93))
    var stick := clampf(v.x*0.30,134.0,190.0)
    joystick_origin = Vector2(margin,v.y-bar_height-stick-34.0)
    joystick_span = stick
    _put("joystick",joystick_origin,Vector2(stick,stick))
    _put("joystick_thumb",joystick_origin+Vector2.ONE*stick*0.33,Vector2.ONE*stick*0.34)
    var native: Panel = host.get("joystick_base")
    if native != null:
        native.set_anchors_preset(Control.PRESET_TOP_LEFT)
        native.position = joystick_origin
        native.size = Vector2(stick,stick)
    var right := v.x-margin
    _put("interact",Vector2(right-circle,v.y-bar_height-stick*1.5-66.0),Vector2(circle,circle))
    _put("attack",Vector2(right-circle*1.65,v.y-bar_height-stick*0.95-39.0),Vector2(circle*1.3,circle*1.3))
    _put("crouch",Vector2(right-circle*2.1,v.y-bar_height-circle-22.0),Vector2(circle,circle))
    _put("sprint",Vector2(right-circle,v.y-bar_height-circle-22.0),Vector2(circle,circle))
    alert.position = Vector2(margin,bottom-25.0)
    alert.size = Vector2(v.x-margin*2.0,24.0)
func _process(_dt: float) -> void:
    if host == null or not sprites.has("joystick_thumb"):
        return
    # A resource panel owns the upper-right focus region; do not overlap it.
    var forest = host.get("forest_gui")
    var panel_open := forest != null and bool(forest.get("panel_open"))
    for key in ["compass_and_zoom"]:
        if sprites.has(key):
            (sprites[key] as Control).visible = not panel_open
    for key in ["zoom_plus","zoom_minus"]:
        if controls.has(key):
            (controls[key] as Control).visible = not panel_open
    minimap.visible = not panel_open
    minimap.call("set_world",host.get("actor_world"),host.get("available_chunks"))
    var direction: Vector2 = host.get("joystick_vector")
    var thumb: TextureRect = sprites["joystick_thumb"]
    var dimension := joystick_span*0.34
    thumb.position = joystick_origin+Vector2.ONE*(joystick_span-dimension)*0.5+direction*joystick_span*0.28
func verify_contract() -> bool:
    return initialized and controls.has("interact") and controls.has("zoom_plus") and sprites.has("joystick_thumb") and minimap != null
