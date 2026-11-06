extends Control
## Touch-based, code-drawn workshop sandbox; no external image assets.
signal closed
const Engine = preload("res://scripts/production_engine.gd")
var model
var place_choice: OptionButton
var module_choice: OptionButton
var cells: Array[Button] = []
var report: Label
var selected := "furnace"
var mode := "place"
var elapsed := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    model = Engine.new()
    if not model.initialize():
        push_error("TAMU_PRODUCTION_UI_CATALOG_INVALID")
        return
    _build()
    _redraw()

func _action(label: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(100,48)
    b.pressed.connect(callback)
    return b

func _build() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.07,0.105,0.115,0.98)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_"+side,12)
    add_child(margin)
    var scrolling := ScrollContainer.new()
    scrolling.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scrolling.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_child(scrolling)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation",8)
    scrolling.add_child(column)
    var head := HBoxContainer.new()
    column.add_child(head)
    var title := Label.new()
    title.text = "TAMU | ÜRETİM & TARLA"
    title.add_theme_font_size_override("font_size",22)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(title)
    head.add_child(_action("KAPAT",func() -> void: closed.emit()))
    var note := Label.new()
    note.text = "OTURUMLUK DEMO • Gerçek envantere/kayıtlara dokunmaz."
    column.add_child(note)
    var selects := HBoxContainer.new()
    column.add_child(selects)
    place_choice = OptionButton.new()
    place_choice.custom_minimum_size.x = 230
    selects.add_child(place_choice)
    for id in model.definitions["sites"]:
        place_choice.add_item(str(model.definitions["sites"][id]["label"]))
        place_choice.set_item_metadata(place_choice.item_count-1,id)
    place_choice.item_selected.connect(_site_changed)
    module_choice = OptionButton.new()
    module_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    selects.add_child(module_choice)
    for id in model.definitions["modules"]:
        var entry: Dictionary = model.definitions["modules"][id]
        module_choice.add_item("T%d %s" % [int(entry["tier"]),str(entry["label"])])
        module_choice.set_item_metadata(module_choice.item_count-1,id)
    module_choice.item_selected.connect(_module_changed)
    var toolbar := HFlowContainer.new()
    column.add_child(toolbar)
    toolbar.add_child(_action("KUR",func() -> void: _set_mode("place")))
    toolbar.add_child(_action("SÖK",func() -> void: _set_mode("remove")))
    toolbar.add_child(_action("DÖNDÜR",func() -> void: _set_mode("rotate")))
    toolbar.add_child(_action("EK",func() -> void: _set_mode("plant")))
    toolbar.add_child(_action("SULA",func() -> void: _set_mode("water")))
    toolbar.add_child(_action("HASAT",func() -> void: _set_mode("harvest")))
    toolbar.add_child(_action("BAŞLAT",func() -> void: model.activate(true); _redraw()))
    toolbar.add_child(_action("DURDUR",func() -> void: model.activate(false); _redraw()))
    toolbar.add_child(_action("+10 sn",_ten_seconds))
    var board := GridContainer.new()
    board.columns = 5
    board.add_theme_constant_override("h_separation",4)
    board.add_theme_constant_override("v_separation",4)
    column.add_child(board)
    for y in range(5):
        for x in range(5):
            var b := Button.new()
            b.custom_minimum_size = Vector2(78,62)
            b.pressed.connect(_on_cell.bind(Vector2i(x,y)))
            board.add_child(b)
            cells.append(b)
    report = Label.new()
    report.add_theme_font_size_override("font_size",17)
    report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(report)
    var explanation := Label.new()
    explanation.text = "Örnek bağlantı: [Fırın] → [Pota] → [Kalıp] yatay diz. Parçalar yönlü soketlerle birleşir.\nFırın ahşap alanda ısı ve yangın riski; taş alanda farklı sonuç. Açık tarla: EK / SULA / BAŞLAT / HASAT."
    explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(explanation)
    for i in range(place_choice.item_count):
        if str(place_choice.get_item_metadata(i))==model.site_id:
            place_choice.select(i)
    for i in range(module_choice.item_count):
        if str(module_choice.get_item_metadata(i))==selected:
            module_choice.select(i)

func _site_changed(index: int) -> void:
    model.use_site(str(place_choice.get_item_metadata(index)))
    _redraw()

func _module_changed(index: int) -> void:
    selected = str(module_choice.get_item_metadata(index))

func _set_mode(action: String) -> void:
    mode = action
    model.message = "Eylem: "+action
    _redraw()

func _on_cell(p: Vector2i) -> void:
    match mode:
        "place": model.place(selected,p)
        "remove": model.remove(p)
        "rotate": model.rotate(p)
        "plant": model.plant(p)
        "water": model.water(p)
        "harvest": model.harvest(p)
    _redraw()

func _ten_seconds() -> void:
    model.activate(true)
    for i in range(10):
        model.step()
    _redraw()

func _process(delta: float) -> void:
    if model==null:
        return
    model.advance(delta)
    elapsed+=delta
    if elapsed>=0.65:
        elapsed=0.0
        if visible:
            _redraw()

func _redraw() -> void:
    if report==null or model==null:
        return
    report.text=model.summary()
    for i in range(cells.size()):
        var p := Vector2i(i%5,int(i/5))
        var b: Button = cells[i]
        b.disabled=not model.inside(p)
        if b.disabled:
            b.text=""
            continue
        var item: Dictionary = model.at(p)
        if not item.is_empty():
            var data: Dictionary = model.definitions["modules"][item["kind"]]
            b.text=str(data["glyph"])+"\n"+str(data["label"]).substr(0,10)
            b.modulate=Color(1,0.65,0.48) if model.fire>20 else Color(0.87,0.92,1)
        elif model.crops.has(model.key(p)):
            var crop: Dictionary = model.crops[model.key(p)]
            b.text="OLGUN" if crop["ripe"] else "EKİLİ\n%d%%" % int(100.0*crop["growth"]/model.definitions["crops"][crop["kind"]]["growth_seconds"])
            b.modulate=Color(0.64,1,0.68)
        else:
            b.text="+\n%d,%d" % [p.x,p.y]
            b.modulate=Color(0.81,0.9,0.88)
