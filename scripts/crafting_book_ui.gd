extends CanvasLayer
## IN-GAME portrait crafting book, reads canonical catalog and live inventory.
## Existing approved recipes call the canonical GameplaySession.begin_craft.
## The axe is a visual blueprint draft only until catalog/save support it.
const AxePreview = preload("res://scripts/crafting_axe_preview.gd")
const CATEGORIES := ["Tümü", "Araçlar", "Silahlar", "Yapılar", "Ekipman", "İşleme", "Diğer"]
const NAMES := {
    "core:wood_log": "Odun", "core:wood_plank": "Tahta", "core:stone": "Taş",
    "core:workbench": "Tezgâh", "core:planks_from_log": "Tahta Üretimi",
    "core:bench_from_planks": "Tezgâh Üretimi"}
const REGIONS := {"edge":"Kesici ağız", "head":"Baş gövdesi", "collar":"Bağlantı",
    "handle":"Sap", "grip":"Kavrama", "pommel":"Dip başlığı"}
const REGION_HINTS := {
    "edge":"Kesme işlevi: sertlik, tokluk ve aşınma direnci önemlidir.",
    "head":"Kütle, yoğunluk ve darbe dayanımı birlikte değerlendirilir.",
    "collar":"Baş ile sapın bağını taşıyacak dayanım gerektirir.",
    "handle":"Eğilme dayanımı, kütle ve darbe sönümleme etkiler.",
    "grip":"Tutuş, sürtünme ve rahatlık bu bölgede önemlidir.",
    "pommel":"Dengeye katkı sağlar; bütün şemalarda zorunlu değildir."}
const GOLD := Color("#d5ae6e")
const PAPER := Color("#f0dcba")
const BACK := Color("#111a20")
var gameplay: RefCounted
var on_craft: Callable
var open_button: Button
var overlay: Control
var stage: VBoxContainer
var active_category := "Tümü"
var search_query := ""
var active_page := "library"
var current_recipe := ""
var selected_role := "edge"
var selections: Dictionary = {}
var notice: Label

func setup(source: RefCounted, craft_callback: Callable) -> void:
    gameplay = source
    on_craft = craft_callback

func is_open() -> bool:
    return overlay != null and overlay.visible

func _style(bg: Color, border: Color = GOLD, radius: int = 17) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(2)
    s.set_corner_radius_all(radius)
    s.set_content_margin_all(12)
    return s

func _text(value: String, size: int = 20, tint: Color = PAPER) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_color_override("font_color", tint)
    label.add_theme_font_size_override("font_size", size)
    return label

func _button(text: String, callback: Callable, min_height: float = 60.0) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0,min_height)
    b.add_theme_font_size_override("font_size", 20)
    b.add_theme_color_override("font_color", PAPER)
    b.add_theme_stylebox_override("normal",_style(Color("#25313a"),Color("#826c4e")))
    b.add_theme_stylebox_override("hover",_style(Color("#35464d"),GOLD))
    b.add_theme_stylebox_override("pressed",_style(Color("#58644f"),GOLD))
    if callback.is_valid():
        b.pressed.connect(callback)
    return b

func _ready() -> void:
    layer = 145
    var shell := Control.new()
    shell.name = "CraftingBookRoot"
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shell)
    open_button = _button("ŞEMALAR",Callable(self,"open_book"),74)
    open_button.name = "OpenCraftingBook"
    open_button.anchor_left = 1.0
    open_button.anchor_right = 1.0
    open_button.anchor_top = 0.0
    open_button.anchor_bottom = 0.0
    open_button.offset_left = -200.0
    open_button.offset_right = -18.0
    open_button.offset_top = 26.0
    open_button.offset_bottom = 100.0
    shell.add_child(open_button)
    overlay = Control.new()
    overlay.name = "CraftingBookOverlay"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.visible = false
    shell.add_child(overlay)
    var shade := ColorRect.new()
    shade.color = Color(0.02,0.04,0.055,0.97)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(shade)
    var panel := PanelContainer.new()
    panel.name = "CraftingBookPanel"
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 12
    panel.offset_top = 12
    panel.offset_right = -12
    panel.offset_bottom = -12
    panel.add_theme_stylebox_override("panel",_style(Color("#172025"),Color("#96784e"),22))
    overlay.add_child(panel)
    stage = VBoxContainer.new()
    stage.name = "CraftingBookContent"
    stage.add_theme_constant_override("separation",12)
    panel.add_child(stage)
    notice = _text("",15,Color("#e0bd77"))

func open_book() -> void:
    if gameplay == null or gameplay.catalog == null:
        push_error("TAMU_CRAFTING_UI_GAMEPLAY_UNAVAILABLE")
        return
    overlay.visible = true
    open_button.visible = false
    active_page = "library"
    _render_library()

func close_book() -> void:
    overlay.visible = false
    open_button.visible = true
    active_page = "library"

func _clear() -> void:
    if stage == null:
        return
    for child in stage.get_children():
        stage.remove_child(child)
        child.queue_free()

func _topline(heading: String, back: Callable) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",8)
    stage.add_child(row)
    var back_btn := _button("‹",back,62)
    back_btn.custom_minimum_size.x = 72
    row.add_child(back_btn)
    var title := _text(heading,28,GOLD)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(title)
    var close_btn := _button("×",Callable(self,"close_book"),62)
    close_btn.custom_minimum_size.x = 72
    row.add_child(close_btn)

func _scroll_host() -> VBoxContainer:
    var sc := ScrollContainer.new()
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    stage.add_child(sc)
    var inner := VBoxContainer.new()
    inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inner.add_theme_constant_override("separation",14)
    sc.add_child(inner)
    return inner

func _friendly(id: String) -> String:
    if NAMES.has(id):
        return NAMES[id]
    var raw := id.get_slice(":",1).replace("_"," ")
    return raw.capitalize() if not raw.is_empty() else id

func _recipe_category(recipe: Dictionary) -> String:
    var explicit := str(recipe.get("category",""))
    if CATEGORIES.has(explicit) and explicit != "Tümü":
        return explicit
    var output: Array = recipe.get("outputs",[])
    if output.is_empty():
        return "Diğer"
    var def: Dictionary = gameplay.catalog.item(str(output[0].get("def_id","")))
    if str(def.get("kind","")) == "structure":
        return "Yapılar"
    if str(output[0].get("def_id","")) == "core:wood_plank":
        return "İşleme"
    return "Diğer"

func visible_schema_ids() -> Array:
    if gameplay == null or gameplay.catalog == null:
        return []
    var ids: Array = gameplay.catalog.recipes.keys()
    ids.sort()
    ids.push_front("_axe_draft")
    var result: Array = []
    for id in ids:
        var name := "Balta (taslak)" if id == "_axe_draft" else _friendly(str(id))
        var category := "Araçlar" if id == "_axe_draft" else _recipe_category(gameplay.catalog.recipe(str(id)))
        if active_category != "Tümü" and active_category != category:
            continue
        if not search_query.is_empty() and name.to_lower().find(search_query.to_lower()) < 0:
            continue
        result.append(id)
    return result

func _render_library() -> void:
    active_page = "library"
    _clear()
    _topline("ÖRÜ DEFTERİ", Callable(self,"close_book"))
    stage.add_child(_text("Keşfet · Şemayı incele · Üret",17,Color("#b8b5a8")))
    var input := LineEdit.new()
    input.placeholder_text = "Şema ara..."
    input.text = search_query
    input.custom_minimum_size.y = 62
    input.add_theme_font_size_override("font_size",20)
    input.text_changed.connect(_search_changed)
    stage.add_child(input)
    var category_strip := ScrollContainer.new()
    category_strip.custom_minimum_size.y = 66
    category_strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    stage.add_child(category_strip)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation",8)
    category_strip.add_child(tabs)
    for category in CATEGORIES:
        var b := _button(category,Callable(self,"_change_category").bind(category),56)
        b.custom_minimum_size.x = 122
        if category == active_category:
            b.add_theme_stylebox_override("normal",_style(Color("#695239"),GOLD))
        tabs.add_child(b)
    var inner := _scroll_host()
    var results := visible_schema_ids()
    if results.is_empty():
        inner.add_child(_text("Bu kategoride henüz öğrenilmiş şema bulunmuyor.",21))
        return
    var grid := GridContainer.new()
    grid.columns = 2 if get_viewport().get_visible_rect().size.x > 560 else 1
    grid.add_theme_constant_override("h_separation",10)
    grid.add_theme_constant_override("v_separation",10)
    inner.add_child(grid)
    for id in results:
        var draft := str(id) == "_axe_draft"
        var recipe: Dictionary = {} if draft else gameplay.catalog.recipe(str(id))
        var b := _button(("◈ BALTA\n" if draft else "◆ "+_friendly(str(id))+"\n") +
            ("Taslak • Deneysel, üretilemez" if draft else "Öğrenilmiş şema · "+_recipe_category(recipe)),
            Callable(self,"_open_schema").bind(str(id)),134)
        b.custom_minimum_size.x = 290 if grid.columns == 2 else 0
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if draft:
            b.add_theme_stylebox_override("normal",_style(Color("#293437"),Color("#819c98")))
        grid.add_child(b)
    inner.add_child(_text("Öğrenilen yeni şemalar katalog verisinden burada görünür.",16,Color("#a5aa9e")))

func _search_changed(value: String) -> void:
    search_query = value
    _render_library()

func _change_category(value: String) -> void:
    active_category = value
    _render_library()

func _open_schema(id: String) -> void:
    current_recipe = id
    if id == "_axe_draft":
        _render_axe()
    else:
        _render_recipe(id)

func _render_recipe(id: String) -> void:
    active_page = "recipe"
    var recipe: Dictionary = gameplay.catalog.recipe(id)
    _clear()
    _topline(_friendly(id).to_upper(),Callable(self,"_render_library"))
    var inner := _scroll_host()
    inner.add_child(_text("Öğrenilmiş şema  •  "+_recipe_category(recipe),19,GOLD))
    inner.add_child(_text("Gerekli malzemeler",25))
    var can_make := true
    for input in recipe.get("inputs",[]):
        var item := str(input.get("def_id",""))
        var need := int(input.get("count",0))
        var owned: int = gameplay.count_item(item)
        var label := "%s   %d / %d" % [_friendly(item), owned, need]
        var row := _text(label,23, Color("#a2dfb7") if owned >= need else Color("#f2ac8c"))
        inner.add_child(row)
        can_make = can_make and owned >= need
    inner.add_child(_text("Üretilecek",25))
    for output in recipe.get("outputs",[]):
        inner.add_child(_text("%s ×%d" % [_friendly(str(output["def_id"])),int(output["count"])],22))
    var station_tags: Array = recipe.get("station_tags",[])
    if not station_tags.is_empty():
        inner.add_child(_text("Bu şema uygun bir üretim istasyonu gerektirir.",18))
    var craft := _button("ÜRET",Callable(self,"_craft_real_recipe").bind(id),80)
    craft.disabled = not can_make or not station_tags.is_empty() or not gameplay.active_craft.is_empty()
    inner.add_child(craft)
    inner.add_child(_text("Üretim gerçek envanter ve oyun işlem sistemiyle yürütülür.",17,Color("#9db4ac")))
    notice = _text("",18,GOLD)
    inner.add_child(notice)

func _craft_real_recipe(id: String) -> void:
    if not on_craft.is_valid():
        return
    var result: Dictionary = on_craft.call(id)
    notice.text = "İşlem: "+str(result.get("status","unknown"))
    if bool(result.get("ok",false)):
        # Engine performs the real item debit/output when its timer finishes.
        notice.text += " · Tamamlanınca çantaya aktarılacak."
    print("TAMU_CRAFT_BOOK_ACTION recipe=",id," status=",result.get("status","unknown"))

func _render_axe() -> void:
    active_page = "axe"
    _clear()
    _topline("BALTA · TASARIM",Callable(self,"_render_library"))
    var inner := _scroll_host()
    inner.add_child(_text("Şema taslağı: parçaya dokun, çantandan malzeme seç.",19,GOLD))
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel",_style(Color("#0c151a"),Color("#54756c"),24))
    inner.add_child(frame)
    var area := Control.new()
    area.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.x * 0.70,260,500)
    frame.add_child(area)
    var axe := AxePreview.new()
    axe.name = "AxeMaskHitTarget"
    axe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    axe.region_selected.connect(_select_role)
    area.add_child(axe)
    axe.apply_materials(selections, gameplay.catalog)
    # Labels are anchored directly to the image, not displayed as a parts sidebar.
    for item in [
        {"role":"edge","text":"KESİCİ","x":0.82,"y":0.42},
        {"role":"head","text":"GÖVDE","x":0.66,"y":0.16},
        {"role":"collar","text":"BAĞ","x":0.55,"y":0.31},
        {"role":"handle","text":"SAP","x":0.42,"y":0.53},
        {"role":"grip","text":"SARIM","x":0.24,"y":0.77},
        {"role":"pommel","text":"DİP","x":0.16,"y":0.91}
    ]:
        var b := _button(str(item["text"]),Callable(self,"_select_role").bind(str(item["role"])),44)
        b.anchor_left = float(item["x"])
        b.anchor_right = float(item["x"])
        b.anchor_top = float(item["y"])
        b.anchor_bottom = float(item["y"])
        b.offset_left = -62
        b.offset_right = 62
        b.offset_top = -22
        b.offset_bottom = 22
        b.add_theme_font_size_override("font_size",15)
        if str(item["role"]) == selected_role:
            b.add_theme_stylebox_override("normal",_style(Color("#426b63"),GOLD,12))
        area.add_child(b)
    var label: String = str(REGIONS.get(selected_role,"Bölüm"))
    inner.add_child(_text("SEÇİLİ BÖLGE · "+str(label).to_upper(),23,GOLD))
    inner.add_child(_text(REGION_HINTS.get(selected_role,""),18,Color("#a8bdb4")))
    var available := _inventory_materials()
    if available.is_empty():
        inner.add_child(_text("Çantanda kullanılabilecek malzeme bulunmuyor. Kaynak topla.",19,Color("#f0b6a3")))
    else:
        inner.add_child(_text("Çantandaki olası malzemeler",21))
        for id in available:
            var name := _friendly(str(id))
            var b := _button(name+"  ×"+str(gameplay.count_item(str(id))),Callable(self,"_bind_material").bind(selected_role,str(id)),58)
            inner.add_child(b)
    var picked := str(selections.get(selected_role,""))
    inner.add_child(_text("Seçim: "+("Yapılmadı" if picked.is_empty() else _friendly(picked)),19))
    inner.add_child(_text("Malzeme fiziksel özellikleri katalogda tanımlanmadığından kesin stat hesaplanmıyor.",17,Color("#b8a48d")))
    var locked := _button("ÜRETİM KAPALI · KANONİK BALTA ŞEMASI YOK",Callable(),76)
    locked.disabled = true
    inner.add_child(locked)
    inner.add_child(_text("Bu ekran oyunun gerçek arayüzüne entegredir; balta henüz bir envanter eşyası olarak yaratılmaz.",16,Color("#9ea7aa")))

func _inventory_materials() -> Array:
    var found := {}
    for entry in gameplay.inventory.slots:
        if not entry is Dictionary:
            continue
        var id := str(entry.get("def_id",""))
        var definition: Dictionary = gameplay.catalog.item(id)
        if str(definition.get("kind","")) != "item":
            continue
        var tags: Array = definition.get("tags",[])
        var comp: Dictionary = definition.get("components",{})
        if tags.has("core:wood") or tags.has("core:stone") or comp.has("core:material"):
            found[id] = true
    var ids: Array = found.keys()
    ids.sort()
    return ids

func _select_role(role: String) -> void:
    if not REGIONS.has(role):
        return
    selected_role = role
    _render_axe()

func _bind_material(role: String, id: String) -> void:
    if not REGIONS.has(role) or not _inventory_materials().has(id):
        return
    selections[role] = id
    _render_axe()

func verify_contract() -> bool:
    if gameplay == null or gameplay.catalog == null:
        return false
    if not visible_schema_ids().has("_axe_draft"):
        return false
    if not visible_schema_ids().has("core:planks_from_log"):
        return false
    if not visible_schema_ids().has("core:bench_from_planks"):
        return false
    return true
