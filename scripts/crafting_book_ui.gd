extends CanvasLayer
## TAMU main-branch crafting book. Owns UI only; authority belongs to GameplaySession.
## Open through existing ModularHUD codex/bag, no extra world HUD buttons.
const AxePreview = preload("res://scripts/crafting_axe_preview.gd")
const CATEGORIES := ["Tümü", "Araçlar", "Silahlar", "Yapılar", "Ekipman", "İşleme", "Diğer"]
const INK := Color("#f2e4c7")
const GOLD := Color("#d6b176")
const MIST := Color("#95b5ad")
const GLASS := Color("#17262a")
const LABELS := {"edge":"KESİCİ", "head":"GÖVDE", "collar":"BAĞLANTI",
    "handle":"SAP", "grip":"SARIM", "pommel":"DİP"}
const HINTS := {
    "edge":"Kesme ve ağız dayanımı: sertlik, tokluk, aşınma.",
    "head":"Darbe ve kütle dağılımı: yoğunluk, dayanım, tokluk.",
    "collar":"Parçaları bir arada tutar: bağlantı ve yorulma dayanımı.",
    "handle":"Kontrol: eğilme dayanımı, kütle, esneklik.",
    "grip":"Tutuş: sürtünme, aşınma ve darbe sönümleme.",
    "pommel":"Denge ve bağlantı güvenilirliği."
}
const KNOWN_NAMES := {
    "core:wood_log":"Odun", "core:wood_plank":"Tahta",
    "core:workbench":"Tezgâh", "core:stone":"Taş",
    "core:planks_from_log":"Tahta Üretimi",
    "core:bench_from_planks":"Tezgâh Üretimi"
}
var gameplay: RefCounted
var craft_callback: Callable
var root_panel: Control
var parchment: Panel
var close_button: Button
var back_button: Button
var heading: Label
var scroll: ScrollContainer
var page_body: VBoxContainer
var material_drawer: Panel
var selected_category := "Tümü"
var search_text := ""
var current_page := "library"
var active_recipe := ""
var current_role := "edge"
var role_materials: Dictionary = {}
var axe_visual: TextureRect
var axe_labels: Dictionary = {}
var grid: GridContainer
var search_box: LineEdit
var feedback: Label
var last_view := Vector2.ZERO

func setup(source: RefCounted, callback: Callable) -> void:
    gameplay = source
    craft_callback = callback

func is_open() -> bool:
    return root_panel != null and root_panel.visible

func _style(bg: Color, edge: Color = GOLD, radius: int = 15) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = edge
    s.set_border_width_all(2)
    s.set_corner_radius_all(radius)
    s.set_content_margin_all(12.0)
    s.shadow_color = Color(0.0,0.0,0.0,0.22)
    s.shadow_size = 3
    return s

func _label(message: String, px: int = 21, color: Color = INK) -> Label:
    var l := Label.new()
    l.text = message
    l.add_theme_font_size_override("font_size",px)
    l.add_theme_color_override("font_color",color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _button(message: String, callback: Callable, height: float = 58.0) -> Button:
    var b := Button.new()
    b.text = message
    b.custom_minimum_size.y = height
    b.focus_mode = Control.FOCUS_NONE
    b.mouse_filter = Control.MOUSE_FILTER_STOP
    b.add_theme_font_size_override("font_size",19)
    b.add_theme_color_override("font_color",INK)
    b.add_theme_color_override("font_disabled_color",Color("#9b9a93"))
    b.add_theme_stylebox_override("normal",_style(GLASS,Color("#6c6353")))
    b.add_theme_stylebox_override("hover",_style(Color("#30423f"),GOLD))
    b.add_theme_stylebox_override("pressed",_style(Color("#48594a"),GOLD))
    b.add_theme_stylebox_override("disabled",_style(Color("#242b2b"),Color("#444743")))
    if callback.is_valid():
        b.pressed.connect(callback)
    return b

func _ready() -> void:
    layer = 145 # Above the current modular HUD, minimap and forest resource card.
    root_panel = Control.new()
    root_panel.name = "TamuBookModal"
    root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    root_panel.visible = false
    add_child(root_panel)
    var dim := ColorRect.new()
    dim.color = Color(0.025,0.047,0.055,0.975)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_panel.add_child(dim)
    parchment = Panel.new()
    parchment.name = "BookFrame"
    parchment.mouse_filter = Control.MOUSE_FILTER_STOP
    parchment.add_theme_stylebox_override("panel",_style(Color("#192426"),Color("#8c754e"),20))
    root_panel.add_child(parchment)
    heading = _label("ÖRÜ DEFTERİ",28,GOLD)
    heading.name = "BookHeading"
    root_panel.add_child(heading)
    back_button = _button("‹",Callable(self,"go_back"),72)
    back_button.name = "Back"
    back_button.add_theme_font_size_override("font_size",32)
    root_panel.add_child(back_button)
    # Independent of the scroll content and always above the material drawer.
    close_button = _button("×",Callable(self,"close_book"),76)
    close_button.name = "Close"
    close_button.add_theme_font_size_override("font_size",38)
    close_button.add_theme_stylebox_override("normal",_style(Color("#614035"),Color("#e5b78a"),18))
    close_button.z_index = 30
    root_panel.add_child(close_button)
    scroll = ScrollContainer.new()
    scroll.name = "PageScroll"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    root_panel.add_child(scroll)
    page_body = VBoxContainer.new()
    page_body.name = "PageBody"
    page_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    page_body.add_theme_constant_override("separation",12)
    scroll.add_child(page_body)
    material_drawer = Panel.new()
    material_drawer.name = "MaterialDrawer"
    material_drawer.visible = false
    material_drawer.z_index = 12
    material_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
    material_drawer.add_theme_stylebox_override("panel",_style(Color("#25352f"),GOLD,21))
    root_panel.add_child(material_drawer)
    get_viewport().size_changed.connect(_layout_modal)
    _layout_modal()

func _safe_top() -> float:
    var v := get_viewport().get_visible_rect().size
    # Visual safety margin accommodates common portrait status-bar insets.
    return maxf(24.0,minf(54.0,v.y * 0.045))

func _layout_modal() -> void:
    if root_panel == null:
        return
    var v := get_viewport().get_visible_rect().size
    last_view = v
    var safe := _safe_top()
    parchment.position = Vector2(12,safe)
    parchment.size = Vector2(maxf(1.0,v.x-24.0),maxf(1.0,v.y-safe-18.0))
    back_button.position = Vector2(24,safe+13.0)
    back_button.size = Vector2(74,76)
    close_button.position = Vector2(maxf(0.0,v.x-100.0),safe+13.0)
    close_button.size = Vector2(76,76)
    heading.position = Vector2(110,safe+25.0)
    heading.size = Vector2(maxf(60.0,v.x-218.0),52.0)
    scroll.position = Vector2(30,safe+102.0)
    scroll.size = Vector2(maxf(1.0,v.x-60.0),maxf(1.0,v.y-safe-139.0))
    if material_drawer.visible:
        _layout_drawer()
    if axe_visual != null and is_instance_valid(axe_visual):
        _place_labels()

func open_library() -> void:
    if gameplay == null or gameplay.catalog == null:
        push_error("TAMU_CRAFT_UI_MISSING_GAMEPLAY")
        return
    root_panel.visible = true
    current_page = "library"
    _close_drawer()
    _render_library()

func open_inventory() -> void:
    if gameplay == null or gameplay.inventory == null:
        push_error("TAMU_BAG_UI_MISSING_GAMEPLAY")
        return
    root_panel.visible = true
    current_page = "inventory"
    _close_drawer()
    _render_inventory()

func close_book() -> void:
    _close_drawer()
    root_panel.visible = false
    current_page = "library"

func go_back() -> void:
    if material_drawer.visible:
        _close_drawer()
    elif current_page == "recipe" or current_page == "axe":
        _render_library()
    else:
        close_book()

func _input(event: InputEvent) -> void:
    if not is_open():
        return
    if event is InputEventKey and event.pressed and not event.echo \
            and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
        go_back()
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open():
        go_back()

func _clear_page() -> void:
    _close_drawer()
    axe_visual = null
    axe_labels.clear()
    grid = null
    search_box = null
    feedback = null
    for c in page_body.get_children():
        page_body.remove_child(c)
        c.queue_free()
    scroll.scroll_vertical = 0

func _named(id: String) -> String:
    if KNOWN_NAMES.has(id):
        return str(KNOWN_NAMES[id])
    return id.get_slice(":",1).replace("_"," ").capitalize()

func _recipe_category(recipe: Dictionary) -> String:
    var explicit := str(recipe.get("category",""))
    if CATEGORIES.has(explicit) and explicit != "Tümü":
        return explicit
    var outputs: Array = recipe.get("outputs",[])
    if outputs.is_empty():
        return "Diğer"
    var first: String = str(outputs[0].get("def_id",""))
    if first == "core:workbench":
        return "Yapılar"
    if first == "core:wood_plank":
        return "İşleme"
    return "Diğer"

func schema_ids() -> Array:
    if gameplay == null or gameplay.catalog == null:
        return []
    var ids: Array = gameplay.catalog.recipes.keys()
    ids.sort()
    ids.push_front("_axe_prototype")
    var matches: Array = []
    for id in ids:
        var draft: bool = id == "_axe_prototype"
        var name := "Balta" if draft else _named(str(id))
        var category := "Araçlar" if draft else _recipe_category(gameplay.catalog.recipe(str(id)))
        if selected_category != "Tümü" and category != selected_category:
            continue
        if not search_text.is_empty() and name.to_lower().find(search_text.to_lower()) == -1:
            continue
        matches.append(id)
    return matches

func _page_title(title: String, subtitle: String) -> void:
    heading.text = title
    page_body.add_child(_label(subtitle,18,MIST))

func _render_library() -> void:
    current_page = "library"
    _clear_page()
    _page_title("ŞEMA KÜTÜPHANESİ","Keşfettiklerini bul, şema seç, malzemeleri incele.")
    search_box = LineEdit.new()
    search_box.name = "SchemaSearch"
    search_box.placeholder_text = "Şema ara..."
    search_box.text = search_text
    search_box.custom_minimum_size.y = 64
    search_box.add_theme_font_size_override("font_size",20)
    search_box.text_changed.connect(_on_search)
    page_body.add_child(search_box)
    var strip := ScrollContainer.new()
    strip.custom_minimum_size.y = 68
    strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    page_body.add_child(strip)
    var tabrow := HBoxContainer.new()
    tabrow.add_theme_constant_override("separation",8)
    strip.add_child(tabrow)
    for category in CATEGORIES:
        var b := _button(category,Callable(self,"_set_category").bind(category),58)
        b.custom_minimum_size.x = 124
        if category == selected_category:
            b.add_theme_stylebox_override("normal",_style(Color("#5b4c35"),GOLD))
        tabrow.add_child(b)
    page_body.add_child(_label("ŞEMALAR  /  BİLİNEN VE KEŞFEDİLEN",16,GOLD))
    grid = GridContainer.new()
    grid.columns = 2 if last_view.x >= 560 else 1
    grid.add_theme_constant_override("h_separation",10)
    grid.add_theme_constant_override("v_separation",10)
    page_body.add_child(grid)
    _fill_schema_grid()
    page_body.add_child(_label("Bilinmeyen şemalar keşif ilerledikçe görünür. " +
        "Şu an gerçek katalogda iki üretim tarifi vardır.",16,Color("#9caaa7")))

func _fill_schema_grid() -> void:
    if grid == null:
        return
    for c in grid.get_children():
        grid.remove_child(c)
        c.queue_free()
    var ids := schema_ids()
    if ids.is_empty():
        grid.add_child(_label("Bu kategoride açılmış şema bulunmuyor.",20,MIST))
    for id in ids:
        var draft: bool = id == "_axe_prototype"
        var r: Dictionary = {} if draft else gameplay.catalog.recipe(str(id))
        var panel := PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.custom_minimum_size = Vector2(260,160)
        panel.add_theme_stylebox_override("panel",_style(Color("#233336") if draft else GLASS,Color("#759b8e") if draft else Color("#827054")))
        grid.add_child(panel)
        var content := VBoxContainer.new()
        content.add_theme_constant_override("separation",9)
        panel.add_child(content)
        content.add_child(_label("◈  TASLAK  •  ARAÇLAR" if draft else
            "◆  ÖĞRENİLMİŞ  •  "+_recipe_category(r).to_upper(),15,MIST if draft else GOLD))
        content.add_child(_label("BALTA" if draft else _named(str(id)).to_upper(),23))
        content.add_child(_label("Şekil sabit · malzemeler serbest" if draft else
            "Envanterden üretim",16,MIST))
        content.add_child(_button("ŞEMAYI AÇ",Callable(self,"_open_schema").bind(str(id)),49))

func _on_search(value: String) -> void:
    # Never rebuild the search LineEdit while typing: preserve keyboard focus.
    search_text = value
    _fill_schema_grid()

func _set_category(value: String) -> void:
    selected_category = value
    _render_library()

func _open_schema(id: String) -> void:
    if id == "_axe_prototype":
        _render_axe()
    elif gameplay.catalog.recipes.has(id):
        _render_recipe(id)

func _render_inventory() -> void:
    current_page = "inventory"
    _clear_page()
    _page_title("ÇANTA","Gerçek oyun envanteri · 12 temel yuva")
    var holder := GridContainer.new()
    holder.columns = 4 if last_view.x >= 480 else 3
    holder.add_theme_constant_override("h_separation",8)
    holder.add_theme_constant_override("v_separation",8)
    page_body.add_child(holder)
    var slots: Array = gameplay.inventory.slots
    for i in range(slots.size()):
        var slot: Variant = slots[i]
        var p := PanelContainer.new()
        p.custom_minimum_size = Vector2(105,105)
        p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        p.add_theme_stylebox_override("panel",_style(GLASS,Color("#655a49")))
        holder.add_child(p)
        var content := VBoxContainer.new()
        p.add_child(content)
        content.add_child(_label(str(i+1).pad_zeros(2),13,MIST))
        if slot is Dictionary:
            content.add_child(_label(_named(str(slot.get("def_id",""))),16))
            content.add_child(_label("×"+str(slot.get("count",0)),19,GOLD))
        else:
            content.add_child(_label("—",24,MIST))
    page_body.add_child(_label("Buradaki miktarlar doğrudan oyun oturumundan okunur.",16,MIST))
    page_body.add_child(_button("ŞEMA KÜTÜPHANESİ",Callable(self,"open_library"),70))

func _render_recipe(id: String) -> void:
    current_page = "recipe"
    active_recipe = id
    _clear_page()
    var recipe: Dictionary = gameplay.catalog.recipe(id)
    _page_title("ÜRETİM · "+_named(id).to_upper(),"Bu şema oyun kataloğunda tanımlı.")
    page_body.add_child(_label("GEREKLİ MALZEMELER",20,GOLD))
    var can_make := true
    for entry in recipe.get("inputs",[]):
        var item: String = str(entry.get("def_id",""))
        var need: int = int(entry.get("count",0))
        var owned: int = gameplay.count_item(item)
        var row := PanelContainer.new()
        row.add_theme_stylebox_override("panel",_style(GLASS,Color("#456a5c") if owned >= need else Color("#906652")))
        page_body.add_child(row)
        row.add_child(_label("%s   %d / %d" % [_named(item),owned,need],22))
        can_make = can_make and owned >= need
    page_body.add_child(_label("SONUÇ",20,GOLD))
    for result in recipe.get("outputs",[]):
        page_body.add_child(_label("%s   ×%d" % [_named(str(result["def_id"])),int(result["count"])],23))
    var stations: Array = recipe.get("station_tags",[])
    if not stations.is_empty():
        page_body.add_child(_label("Bu tarif için uygun istasyon gerekir.",17,MIST))
    var action := _button("ÜRETİMİ BAŞLAT",Callable(self,"_craft_recipe").bind(id),84)
    action.disabled = not can_make or not stations.is_empty() or not gameplay.active_craft.is_empty()
    page_body.add_child(action)
    feedback = _label("Üretim yalnız gerçek envanterdeki kaynakları kullanır.",18,MIST)
    page_body.add_child(feedback)

func _craft_recipe(id: String) -> void:
    if not craft_callback.is_valid():
        feedback.text = "Üretim bağlantısı yok."
        return
    var result: Dictionary = craft_callback.call(id)
    feedback.text = "Üretim: "+str(result.get("status","unavailable"))
    print("TAMU_BOOK_CRAFT recipe=",id," status=",result.get("status","unavailable"))

func _render_axe() -> void:
    current_page = "axe"
    _clear_page()
    _page_title("BALTA · ŞEMA TASLAĞI","Şekil değişmez. Parçaya dokunarak malzeme seç.")
    var outline := PanelContainer.new()
    outline.add_theme_stylebox_override("panel",_style(Color("#101d23"),Color("#568079"),21))
    page_body.add_child(outline)
    var region := Control.new()
    region.name = "AxeRegionSurface"
    region.custom_minimum_size.y = clampf(last_view.x*0.78,280.0,560.0)
    outline.add_child(region)
    axe_visual = AxePreview.new()
    axe_visual.name = "AxePixelMask"
    axe_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    axe_visual.region_selected.connect(_open_drawer)
    region.add_child(axe_visual)
    axe_visual.apply_materials(role_materials,gameplay.catalog)
    for item in [
        {"role":"edge","x":0.79,"y":0.43},
        {"role":"head","x":0.69,"y":0.22},
        {"role":"collar","x":0.54,"y":0.38},
        {"role":"handle","x":0.41,"y":0.54},
        {"role":"grip","x":0.28,"y":0.73},
        {"role":"pommel","x":0.16,"y":0.87}
    ]:
        var role: String = str(item["role"])
        var b := _button(str(LABELS[role]),Callable(self,"_open_drawer").bind(role),41)
        b.name = "MaskLabel_"+role
        b.add_theme_font_size_override("font_size",14)
        b.add_theme_stylebox_override("normal",_style(Color("#1a3836d9"),Color("#91c6b2"),10))
        axe_visual.add_child(b)
        axe_labels[role] = {"node":b,"pos":Vector2(float(item["x"]),float(item["y"]))}
    axe_visual.resized.connect(_place_labels)
    _place_labels()
    page_body.add_child(_label("MALZEME SEÇİMLERİ",18,GOLD))
    for role in ["edge","head","collar","handle","grip","pommel"]:
        if role_materials.has(role):
            page_body.add_child(_label("%s  ·  %s" % [str(LABELS[role]),_named(str(role_materials[role]))],17))
    page_body.add_child(_label("Bu balta oyun kataloğunda henüz üretilebilir değil. " +
        "Gerçek malzeme özellikleri tanımlanana kadar sayısal stat gösterilmiyor.",17,MIST))
    var disabled := _button("ÜRETİM KİLİTLİ  ·  ŞEMA TASLAĞI",Callable(),74)
    disabled.disabled = true
    page_body.add_child(disabled)

func _place_labels() -> void:
    if axe_visual == null or not is_instance_valid(axe_visual):
        return
    var v: Vector2 = axe_visual.size
    var side := minf(v.x,v.y)
    var start := (v-Vector2.ONE*side)*0.5
    for role in axe_labels:
        var entry: Dictionary = axe_labels[role]
        var b: Button = entry["node"]
        var uv: Vector2 = entry["pos"]
        b.size = Vector2(103,44)
        b.position = start+uv*side-b.size*0.5

func _inventory_material_ids() -> Array:
    var result := {}
    for slot in gameplay.inventory.slots:
        if not slot is Dictionary:
            continue
        var id: String = str(slot.get("def_id",""))
        var definition: Dictionary = gameplay.catalog.item(id)
        var tags: Array = definition.get("tags",[])
        if tags.has("core:wood") or tags.has("core:stone") or tags.has("core:material") or tags.has("core:metal"):
            result[id] = true
    var ids: Array = result.keys()
    ids.sort()
    return ids

func _open_drawer(role: String) -> void:
    if not LABELS.has(role):
        return
    current_role = role
    _show_drawer()

func _layout_drawer() -> void:
    if material_drawer == null:
        return
    var v := get_viewport().get_visible_rect().size
    var height := maxf(255.0,minf(v.y*0.47,470.0))
    material_drawer.position = Vector2(16,v.y-height-16)
    material_drawer.size = Vector2(v.x-32,height)

func _show_drawer() -> void:
    material_drawer.visible = true
    _layout_drawer()
    for c in material_drawer.get_children():
        material_drawer.remove_child(c)
        c.queue_free()
    var box := VBoxContainer.new()
    box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    box.offset_left = 15
    box.offset_top = 13
    box.offset_right = -15
    box.offset_bottom = -14
    box.add_theme_constant_override("separation",8)
    material_drawer.add_child(box)
    var top := HBoxContainer.new()
    box.add_child(top)
    var title := _label("MALZEME · "+str(LABELS[current_role]),22,GOLD)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(title)
    var dismiss := _button("KAPAT",Callable(self,"_close_drawer"),52)
    top.add_child(dismiss)
    box.add_child(_label(str(HINTS.get(current_role,"")),16,MIST))
    var candidates := _inventory_material_ids()
    if candidates.is_empty():
        box.add_child(_label("Çantada malzeme yok. Önce dünyadan kaynak topla.",18,INK))
    else:
        var options := ScrollContainer.new()
        options.size_flags_vertical = Control.SIZE_EXPAND_FILL
        box.add_child(options)
        var stack := VBoxContainer.new()
        stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        options.add_child(stack)
        for id in candidates:
            var selected := str(role_materials.get(current_role,"")) == str(id)
            var caption := "%s  ×%d%s" % [_named(str(id)),gameplay.count_item(str(id)),
                "   ✓" if selected else ""]
            stack.add_child(_button(caption,Callable(self,"_select_material").bind(current_role,str(id)),62))
    box.add_child(_label("Uygunluk, sabit tarifle değil malzeme özellikleriyle hesaplanacak.",15,MIST))

func _select_material(role: String, id: String) -> void:
    if not LABELS.has(role) or not _inventory_material_ids().has(id):
        return
    role_materials[role] = id
    if axe_visual != null and is_instance_valid(axe_visual):
        axe_visual.apply_materials(role_materials,gameplay.catalog)
    _close_drawer()
    _render_axe()

func _close_drawer() -> void:
    if material_drawer != null:
        material_drawer.visible = false

func verify_contract() -> bool:
    return close_button != null and close_button.custom_minimum_size.y >= 72.0 \
        and gameplay != null and gameplay.catalog != null \
        and gameplay.catalog.recipes.has("core:planks_from_log") \
        and gameplay.catalog.recipes.has("core:bench_from_planks") \
        and schema_ids().has("_axe_prototype")
