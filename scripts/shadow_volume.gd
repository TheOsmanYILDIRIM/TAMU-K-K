extends RefCounted
# 2.5D mass proxy: one tapered swept footprint using the existing shadow polygon.
# Authored atlas silhouette remains a separate overlay; no extra draw nodes.
# In local coordinates -Y follows the ground-plane solar cast, with a
# broad canopy/rock cross-section at the far end and a narrow contact root.
static func alpha_spans(texture: Texture2D) -> Array[Vector2]:
    var result: Array[Vector2] = []
    if texture == null:
        return result
    var image: Image = texture.get_image()
    if image == null or image.is_empty():
        return result
    var w := image.get_width()
    var h := image.get_height()
    if w < 8 or h < 8:
        return result
    for i in range(12):
        var row := clampi(roundi(float(h-1)*(0.91-float(i)*0.069)),0,h-1)
        var left := w
        var right := -1
        for yy in range(maxi(0,row-2),mini(h,row+3)):
            for xx in range(w):
                if image.get_pixel(xx,yy).a > 0.14:
                    left=mini(left,xx)
                    right=maxi(right,xx)
        if right < 0:
            result.append(Vector2(-0.10,0.10))
        else:
            result.append(Vector2(float(left)/float(w)-0.5,
                float(right+1)/float(w)-0.5))
    return result

static func profile(kind: String, rendered_size: Vector2, spans: Array[Vector2] = []) -> Dictionary:
    if kind != "tree" and kind != "rock":
        return {}
    if not is_finite(rendered_size.x) or not is_finite(rendered_size.y) or rendered_size.x <= 0.0 or rendered_size.y <= 0.0:
        return {}
    var tree := kind == "tree"
    var radius := clampf(rendered_size.x * (0.23 if tree else 0.29), 10.0 if tree else 5.0, 44.0 if tree else 26.0)
    var travel := clampf(rendered_size.y * (0.45 if tree else 0.23), 12.0 if tree else 4.0, 92.0 if tree else 32.0)
    var base := radius * (0.32 if tree else 0.65)
    var shape := PackedVector2Array()
    var root := clampf(rendered_size.y*(0.16 if tree else 0.11),5.0,28.0)
    if spans.size() >= 8:
        var right_side := PackedVector2Array()
        for i in range(spans.size()):
            var t := float(i)/float(spans.size()-1)
            var y := -root - travel*t
            var half := radius*(0.34+0.58*t)
            shape.append(Vector2(minf(-half*0.55,spans[i].x*rendered_size.x*0.80),y))
            right_side.append(Vector2(maxf(half*0.55,spans[i].y*rendered_size.x*0.80),y))
        shape.append(Vector2(0,-root-travel-radius*0.26))
        for i in range(right_side.size()-1,-1,-1):
            shape.append(right_side[i])
        shape.append(Vector2(0,-root*0.65))
        return {"points":shape,"radius":radius,"travel":travel,
            "root_inset":root,"sampled_alpha":true}
    # Far hemisphere = canopy/rock mass; near hemisphere = contact footprint.
    for i in range(13):
        var angle := PI * float(i) / 12.0
        shape.append(Vector2(cos(angle) * radius, -travel - sin(angle) * radius * 0.62))
    for i in range(13):
        var angle := PI + PI * float(i) / 12.0
        shape.append(Vector2(cos(angle) * base, -sin(angle) * base * 0.62))
    return {"points":shape,"radius":radius,"travel":travel,
        "root_inset":root,"sampled_alpha":false}

static func configure(node: Polygon2D, kind: String, rendered_size: Vector2,
        spans: Array[Vector2] = []) -> bool:
    var mass := profile(kind, rendered_size, spans)
    if mass.is_empty():
        return false
    node.polygon = mass["points"]
    node.antialiased = true
    node.set_meta("root_inset",mass["root_inset"])
    var pigment := Color(0.025,0.045,0.04,0.24 if kind=="tree" else 0.18)
    if bool(mass["sampled_alpha"]):
        var fades := PackedColorArray()
        for i in range(node.polygon.size()):
            var alpha := 0.0 if i == 0 or i >= node.polygon.size()-2 else 1.0
            fades.append(Color(pigment.r,pigment.g,pigment.b,pigment.a*alpha))
        node.vertex_colors = fades
        node.color = Color.WHITE
    else:
        node.color = pigment
    return true

static func apply_sun(node: Polygon2D, cast_direction: Vector2, cast_length: float, sun_level: float) -> void:
    if cast_direction.length_squared() < 0.000001:
        return
    # Rotated local -Y follows the cast in BOTH screen axes.
    node.rotation = atan2(cast_direction.x, -cast_direction.y)
    # Extending the cast does not squash the lateral cross-section.
    node.scale = Vector2(1.0, clampf(cast_length, 0.28, 2.65))
    node.modulate.a = (0.42 + 0.58 * sun_level) * sun_level

static func verify_contract() -> bool:
    for kind in ["tree", "rock"]:
        var mass := profile(kind, Vector2(90.0, 135.0))
        if mass.is_empty():
            return false
        var points: PackedVector2Array = mass["points"]
        if points.size() != 26 or float(mass["travel"]) <= 0.0:
            return false
        # Side-on casts must keep full lateral area instead of a zero-depth line.
        for cast in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1.0, 1.0).normalized()]:
            var angle := atan2(cast.x, -cast.y)
            var lateral := Vector2(-cast.y, cast.x)
            var left := INF
            var right := -INF
            var area := 0.0
            for i in range(points.size()):
                var p: Vector2 = points[i].rotated(angle)
                var q: Vector2 = points[(i + 1) % points.size()].rotated(angle)
                var x := p.dot(lateral)
                left = minf(left, x)
                right = maxf(right, x)
                area += p.x * q.y - q.x * p.y
            if right - left < 1.9 * float(mass["radius"]) or absf(area) < 100.0:
                return false
    return true
