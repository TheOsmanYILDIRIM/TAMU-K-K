extends Node2D
## OSMAN visual-only terrain study. World-space surfaces + shared parent camera.
const SEED := 20261018
const GRID := 64
const CELL_X := 30.0
const CELL_Y := 15.0
const BASE_Y := 310.0
const MAP_CENTER := Vector2(360.0, 480.0)
var atlas: Texture2D
var terrain: Array = []
var objects: Array = []
var groups := {}
var water_mat := ShaderMaterial.new()
var water: Polygon2D
var bank: Polygon2D
var drag := false
var previous := Vector2.ZERO
var zoom := 1.0
var world_noise := FastNoiseLite.new()
var height_noise := FastNoiseLite.new()
var decorations: Array = []

func _ready() -> void:
    var manifest_path := "res://assets/manifest.json"
    var atlas_path := "res://assets/atlas_00.png"
    assert(FileAccess.file_exists(manifest_path), "Atlas manifest missing")
    var doc = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    assert(doc is Dictionary and doc.has("assets"), "Invalid atlas manifest")
    atlas = load(atlas_path)
    assert(atlas != null, "Atlas failed loading")
    for entry in doc["assets"]:
        if entry["kind"] == "terrain":
            terrain.append(entry)
            var family: String = str(entry.get("family", "grass"))
            if not groups.has(family):
                groups[family] = []
            groups[family].append(entry)
        elif entry["kind"] == "object":
            objects.append(entry)
    assert(not terrain.is_empty() and not objects.is_empty(), "Missing terrain or object entries")
    world_noise.seed = SEED
    world_noise.frequency = 0.095
    height_noise.seed = SEED + 31
    height_noise.frequency = 0.041
    water_mat.shader = load("res://water.gdshader")
    bank = Polygon2D.new()
    bank.color = Color("#a3a18a")
    bank.z_index = 1
    add_child(bank)
    water = Polygon2D.new()
    water.material = water_mat
    water.z_index = 2
    add_child(water)
    _build_river()
    _build_decorations()
    var ui := CanvasLayer.new()
    add_child(ui)
    var heading := Label.new()
    heading.text = "OSMAN  /  GODOT 2.5D"
    heading.position = Vector2(20.0, 40.0)
    heading.add_theme_font_size_override("font_size", 26)
    ui.add_child(heading)
    var caption := Label.new()
    caption.text = "Authored atlas / terrain study"
    caption.position = Vector2(20.0, 78.0)
    caption.add_theme_font_size_override("font_size", 16)
    ui.add_child(caption)
    queue_redraw()

func _screen(x: float, y: float, h: float = 0.0) -> Vector2:
    return MAP_CENTER + Vector2((x-y)*CELL_X,(x+y)*CELL_Y-h)

func _river_center(y: float) -> float:
    return 355.0 + 87.0*sin((y-100.0)*0.0039) + 32.0*sin((y+190.0)*0.0105)

func _river_dist(p: Vector2) -> float:
    return absf(p.x - _river_center(p.y))

func _height(x: float, y: float) -> float:
    var flat_p := _screen(x, y)
    var distance := _river_dist(flat_p)
    var ridge := clampf((distance-62.0)/240.0, 0.0, 1.0)
    var detail := height_noise.get_noise_2d(x,y)*10.0
    return maxf(0.0, 52.0*ridge*ridge+detail*ridge)

func _rect(entry: Dictionary) -> Rect2:
    var uv: Array = entry["uv_rect"]
    var s := atlas.get_size()
    return Rect2(float(uv[0])*s.x,float(uv[1])*s.y,float(uv[2])*s.x,float(uv[3])*s.y)

func _make_strip(radius: float) -> PackedVector2Array:
    var left := PackedVector2Array()
    var right := PackedVector2Array()
    for i in range(101):
        var y := -650.0 + float(i)*28.0
        left.append(Vector2(_river_center(y)-radius,y))
        right.append(Vector2(_river_center(y)+radius,y))
    for i in range(100,-1,-1):
        left.append(right[i])
    return left

func _build_river() -> void:
    bank.polygon = _make_strip(67.0)
    water.polygon = _make_strip(49.0)
    var tex_uv := PackedVector2Array()
    for p in water.polygon:
        tex_uv.append(Vector2((p.x-_river_center(p.y))/98.0+0.5,(p.y+650.0)/2800.0))
    water.uv = tex_uv

func _pick(family: String, n: int) -> Dictionary:
    var subset: Array = groups.get(family, [])
    if subset.is_empty():
        subset = terrain
    return subset[posmod(n,subset.size())]

func _build_decorations() -> void:
    decorations.clear()
    for row in range(-GRID,GRID+1,2):
        for col in range(-GRID,GRID+1,2):
            var h := _height(float(col),float(row))
            var p := _screen(float(col),float(row),h)
            if p.x < -150 or p.x > 1000 or p.y < -220 or p.y > 1740:
                continue
            if _river_dist(p) < 83.0:
                continue
            var n := world_noise.get_noise_2d(col*0.8,row*0.8)
            var place := sin(float(col*73+row*129+SEED)*0.137)
            if place > 0.48 and n > -0.45:
                var variant := abs(col*13+row*7+SEED)%objects.size()
                decorations.append({"p":p,"asset":objects[variant],"s":0.52+0.11*absf(n)})
    decorations.sort_custom(func(a,b): return a["p"].y < b["p"].y)

func _draw() -> void:
    draw_rect(Rect2(-4000,-4000,8000,8000),Color("#263e32"))
    # Each quad shares all four projected vertices with adjacent quads.
    # All surfaces are drawn before objects and the z-indexed world-space river.
    for row in range(-GRID,GRID):
        for col in range(-GRID,GRID):
            var x := float(col)
            var y := float(row)
            var a := _screen(x,y,_height(x,y))
            var b := _screen(x+1.0,y,_height(x+1.0,y))
            var c := _screen(x+1.0,y+1.0,_height(x+1.0,y+1.0))
            var d := _screen(x,y+1.0,_height(x,y+1.0))
            if maxf(maxf(a.x,b.x),maxf(c.x,d.x)) < -100 or minf(minf(a.x,b.x),minf(c.x,d.x)) > 820:
                continue
            if maxf(maxf(a.y,b.y),maxf(c.y,d.y)) < -120 or minf(minf(a.y,b.y),minf(c.y,d.y)) > 1440:
                continue
            var sample := (a+b+c+d)*0.25
            var dist := _river_dist(sample)
            var moisture := world_noise.get_noise_2d(x*0.50,y*0.50)
            var family := "grass"
            if dist < 82.0:
                family = "wetland"
            elif moisture > 0.23:
                family = "forest"
            elif dist > 280.0 and moisture < -0.12:
                family = "rock"
            elif absf(moisture)<0.08 and dist>170.0:
                family = "dirt"
            var entry := _pick(family,abs(col*19+row*31))
            var src := _rect(entry)
            var quad := PackedVector2Array([a,b,c,d])
            var tuv := PackedVector2Array([
                src.position,
                src.position+Vector2(src.size.x,0),
                src.position+src.size,
                src.position+Vector2(0,src.size.y)
            ])
            var light := clampf(0.87+0.13*(b.y-a.y)/CELL_Y,0.72,1.0)
            var tint := Color(light,light,light,1.0)
            draw_polygon(quad,PackedColorArray([tint,tint,tint,tint]),tuv,atlas)
    # Sprites live in exactly the same world as the terrain, banks and river.
    for instance in decorations:
        var p: Vector2 = instance["p"]
        var src := _rect(instance["asset"])
        var factor: float = instance["s"]
        draw_texture_rect_region(atlas,Rect2(p.x-src.size.x*factor*0.5,p.y-src.size.y*factor,src.size.x*factor,src.size.y*factor),src)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        drag=event.pressed
        previous=event.position
    elif event is InputEventScreenDrag and drag:
        position += event.position-previous
        previous=event.position
    elif event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_LEFT:
            drag=event.pressed
            previous=event.position
        elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:
            zoom=clampf(zoom*1.10,0.65,1.7)
            scale=Vector2.ONE*zoom
        elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
            zoom=clampf(zoom/1.10,0.65,1.7)
            scale=Vector2.ONE*zoom
    elif event is InputEventMouseMotion and drag:
        position += event.position-previous
        previous=event.position
