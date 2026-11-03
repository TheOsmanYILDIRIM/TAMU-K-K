extends SceneTree
# CI-only one-time bake of verified R2 surface; never run per gameplay frame.
const Surface = preload("res://scripts/r2_surface.gd")
const WorldProjection = preload("res://scripts/world_projection.gd")
const SIDE := 256
func _initialize() -> void:
    call_deferred("_bake")
func _bake() -> void:
    var source = Surface.new()
    if not source.initialize():
        push_error("TAMU_MINIMAP_SURFACE_MISSING")
        quit(81)
        return
    var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://chunks/index.json"))
    if not doc is Dictionary or not doc.get("available",null) is Array:
        quit(82)
        return
    var low := Vector2(INF,INF)
    var high := Vector2(-INF,-INF)
    for key in doc["available"]:
        var parts := str(key).split("_")
        if parts.size()!=3:
            continue
        var p := Vector2(float(parts[1]),float(parts[2]))*WorldProjection.CHUNK_SIZE
        low=low.min(p)
        high=high.max(p+Vector2.ONE*WorldProjection.CHUNK_SIZE)
    if not is_finite(low.x) or high.x<=low.x:
        quit(83)
        return
    var image := Image.create(SIDE,SIDE,false,Image.FORMAT_RGB8)
    var water := 0
    var land := 0
    for y in range(SIDE):
        for x in range(SIDE):
            var p := low + Vector2((float(x)+0.5)/SIDE,(float(y)+0.5)/SIDE)*(high-low)
            var s: Dictionary = source.sample(p.x,p.y)
            var h := clampf(float(s.get("height",0.0))/25.0,0.0,1.0)
            var c := Color(0.12+0.15*h,0.25+0.32*h,0.12+0.13*h)
            if bool(s.get("water_body",false)):
                c=Color(0.08,0.23+0.08*h,0.39+0.10*h)
                water+=1
            elif str(s.get("feature",""))=="path":
                c=Color(0.54,0.46,0.30)
                land+=1
            else:
                land+=1
            image.set_pixel(x,y,c)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/minimap"))
    var err := image.save_png("res://assets/ui/minimap/terrain.png")
    if err != OK or land==0:
        push_error("TAMU_MINIMAP_BAKE_FAILED")
        quit(84)
        return
    print("TAMU_STATIC_MINIMAP_BAKED_OK pixels=",SIDE*SIDE," land=",land," water=",water)
    quit(0)
