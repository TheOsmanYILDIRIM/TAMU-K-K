extends TextureRect
# Immutable baked authored R2 terrain texture; only shader uniforms move.
# No per-frame CPU pixel loops, chunk scans or redraw requests.
const WorldProjection = preload("res://scripts/world_projection.gd")
const MAP_PATH := "res://assets/ui/minimap/terrain.png"
const SHADER = preload("res://scripts/minimap_static.gdshader")
var zoom := 1.0
var _last_world := Vector2(INF,INF)
var _bounds := Rect2(Vector2.ZERO,Vector2.ONE)
var _material: ShaderMaterial

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stretch_mode = TextureRect.STRETCH_SCALE
    if not ResourceLoader.exists(MAP_PATH):
        push_error("TAMU_MINIMAP_BAKED_TEXTURE_MISSING")
        return
    texture = load(MAP_PATH)
    var index: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://chunks/index.json"))
    if not index is Dictionary or not index.get("available",null) is Array:
        return
    var low := Vector2(INF,INF)
    var high := Vector2(-INF,-INF)
    for stem in index["available"]:
        var parts := str(stem).split("_")
        if parts.size()!=3:
            continue
        var p := Vector2(float(parts[1]),float(parts[2]))*WorldProjection.CHUNK_SIZE
        low = low.min(p)
        high = high.max(p+Vector2.ONE*WorldProjection.CHUNK_SIZE)
    if not is_finite(low.x) or high.x <= low.x:
        return
    _bounds = Rect2(low,high-low)
    _material = ShaderMaterial.new()
    _material.shader = SHADER
    _material.set_shader_parameter("map_bounds",Vector4(low.x,low.y,_bounds.size.x,_bounds.size.y))
    material = _material
    set_world(Vector2(64,128),{})

func set_world(position: Vector2, _chunks: Dictionary) -> void:
    if _material == null or position.distance_squared_to(_last_world) < 16.0:
        return
    _last_world = position
    _material.set_shader_parameter("player_world",position)

func change_zoom(factor: float) -> void:
    zoom = clampf(zoom*factor,0.5,4.0)
    if _material != null:
        _material.set_shader_parameter("view_span",1800.0/zoom)

func verify_contract() -> bool:
    return texture != null and _material != null and _bounds.size.x > 0.0
