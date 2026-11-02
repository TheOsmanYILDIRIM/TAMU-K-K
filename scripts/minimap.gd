extends Control
# TAMU fixed-orientation schematic minimap: Cartesian world -> canonical 2.5D projection.
# Direction is NEVER read from actor facing or camera rotation. Triangle never rotates.
# Available chunk keys are authoritative; missing cells are not invented terrain.
const WorldProjection = preload("res://scripts/world_projection.gd")
const CHUNK := WorldProjection.CHUNK_SIZE
var world_position := Vector2.ZERO
var available: Dictionary = {}
var zoom := 0.085
var _last_world := Vector2(INF,INF)
func set_world(position: Vector2, chunks: Dictionary) -> void:
    if position.distance_squared_to(_last_world) < 9.0 and available.size() == chunks.size():
        return
    world_position = position
    _last_world = position
    available = chunks
    queue_redraw()
func change_zoom(factor: float) -> void:
    zoom = clampf(zoom*factor,0.025,0.26)
    queue_redraw()
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)
func _draw() -> void:
    var center := size*0.5
    var radius := minf(size.x,size.y)*0.48
    draw_circle(center,radius,Color(0.13,0.18,0.12,0.9))
    # Compact deterministic sampling, clipped to circular aperture.
    # Each cell queries the real streamed-world chunk index.
    var step := 4.0
    var scale := zoom*minf(size.x,size.y)/25.0
    var actor_screen := WorldProjection.to_screen(world_position)
    for yy in range(-24,25):
        for xx in range(-24,25):
            var pixel := Vector2(float(xx),float(yy))*step
            if pixel.length_squared() > (radius-2.0)*(radius-2.0):
                continue
            var source_screen := actor_screen+pixel/maxf(scale,0.001)
            var source := WorldProjection.to_world(source_screen)
            var cx := floori(source.x/CHUNK)
            var cy := floori(source.y/CHUNK)
            var key := "c_%d_%d" % [cx,cy]
            if not available.has(key):
                continue
            var tone := 0.13 if posmod(cx*13+cy*7,5)==0 else 0.0
            draw_rect(Rect2(center+pixel-Vector2.ONE*step*0.5,Vector2.ONE*step),Color(0.24+tone,0.34+tone*0.6,0.19,0.94))
    draw_arc(center,radius,0.0,TAU,64,Color(0.68,0.54,0.30,0.72),1.5,true)
    # A static north-facing triangular player marker, always precisely centered.
    var arrow := PackedVector2Array([center+Vector2(0,-9),center+Vector2(-6,7),center+Vector2(0,4),center+Vector2(6,7)])
    draw_colored_polygon(arrow,Color(1.0,0.76,0.17))
    draw_polyline(PackedVector2Array([arrow[0],arrow[1],arrow[2],arrow[3],arrow[0]]),Color(0.26,0.15,0.03),1.3,true)
func verify_contract() -> bool:
    var p := Vector2(64,128)
    return WorldProjection.to_world(WorldProjection.to_screen(p)).distance_to(p) < 0.001 and zoom >= 0.025
