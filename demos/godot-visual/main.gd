extends Node2D

const MAP_SIZE := 28
const CELL := 39.0
var atlas: Texture2D
var terrain: Array = []
var objects: Array = []
var water_mat := ShaderMaterial.new()
var river: Polygon2D
var camera_shift := Vector2.ZERO
var dragging := false
var last_pos := Vector2.ZERO
var scale_factor := 1.0

func _ready() -> void:
    var manifest_path := "res://assets/manifest.json"
    var atlas_path := "res://assets/atlas_00.png"
    assert(FileAccess.file_exists(manifest_path), "Manifest missing")
    assert(ResourceLoader.exists(atlas_path), "Atlas missing")
    var doc = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    assert(doc is Dictionary and doc.has("assets"))
    atlas = load(atlas_path)
    for entry in doc["assets"]:
        if entry["kind"] == "terrain":
            terrain.append(entry)
        elif entry["kind"] == "object":
            objects.append(entry)
    assert(not terrain.is_empty() and not objects.is_empty(), "Both terrain and objects required")
    water_mat.shader = load("res://water.gdshader")
    river = Polygon2D.new()
    river.material = water_mat
    river.z_index = 3
    add_child(river)
    var pts := PackedVector2Array()
    var uv := PackedVector2Array()
    for i in range(61):
        var t := float(i)/60.0
        var y := -280.0 + t*1850.0
        pts.append(Vector2(350.0+65.0*sin(t*9.0)-35.0,y))
        uv.append(Vector2(0,t))
    for i in range(60,-1,-1):
        var t := float(i)/60.0
        var y := -280.0 + t*1850.0
        pts.append(Vector2(350.0+65.0*sin(t*9.0)+35.0,y))
        uv.append(Vector2(1,t))
    river.polygon=pts
    river.uv=uv
    queue_redraw()

func _iso(x: float, y: float) -> Vector2:
    return Vector2(360.0+(x-y)*CELL*0.70, 150.0+(x+y)*CELL*0.35)

func _rect(entry: Dictionary) -> Rect2:
    var uv: Array=entry["uv_rect"]
    var size := atlas.get_size()
    return Rect2(uv[0]*size.x, uv[1]*size.y, uv[2]*size.x, uv[3]*size.y)

func _draw() -> void:
    draw_rect(Rect2(-1000,-1000,3000,4000),Color("#1d322b"))
    draw_set_transform(camera_shift,0.0,Vector2.ONE*scale_factor)
    for y in range(-MAP_SIZE,MAP_SIZE+1):
        for x in range(-MAP_SIZE,MAP_SIZE+1):
            var p := _iso(float(x),float(y))
            if p.x < -90 or p.x > 820 or p.y < -90 or p.y > 1400:
                continue
            var h := 8.0*sin(float(x)*0.4)+8.0*cos(float(y)*0.31)
            var asset: Dictionary=terrain[abs(x*13+y*7)%terrain.size()]
            var r := _rect(asset)
            var d := CELL*0.72
            var quad := PackedVector2Array([p+Vector2(0,-d*0.5-h),p+Vector2(d,0-h),p+Vector2(0,d*0.5-h),p+Vector2(-d,0-h)])
            var texuv := PackedVector2Array([r.position+Vector2(r.size.x*0.5,0),r.position+Vector2(r.size.x,r.size.y*0.5),r.position+Vector2(r.size.x*0.5,r.size.y),r.position+Vector2(0,r.size.y*0.5)])
            draw_polygon(quad,PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE]),texuv,atlas)
            if (x*23+y*11)%11==0:
                var obj: Dictionary=objects[abs(x*5+y*13)%objects.size()]
                var sr := _rect(obj)
                var scale_obj := 0.8
                draw_texture_rect_region(atlas,Rect2(p.x-sr.size.x*scale_obj*0.5,p.y-sr.size.y*scale_obj+6,sr.size.x*scale_obj,sr.size.y*scale_obj),sr)
    draw_set_transform()
    draw_string(ThemeDB.fallback_font,Vector2(22,55),"OSMAN  /  GODOT 2.5D",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(22,87),"Verified repository atlas | visual demo",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#d3ecdf"))

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        dragging=event.pressed
        last_pos=event.position
    elif event is InputEventScreenDrag and dragging:
        camera_shift+=event.position-last_pos
        last_pos=event.position
        queue_redraw()
    elif event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_LEFT:
            dragging=event.pressed
            last_pos=event.position
        elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:
            scale_factor=minf(scale_factor*1.1,2.0)
            queue_redraw()
        elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
            scale_factor=maxf(scale_factor/1.1,0.6)
            queue_redraw()
    elif event is InputEventMouseMotion and dragging:
        camera_shift+=event.position-last_pos
        last_pos=event.position
        queue_redraw()
