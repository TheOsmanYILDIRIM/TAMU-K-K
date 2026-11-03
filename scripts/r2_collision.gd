extends RefCounted
# Faithful swept AABB + sliding port of game/love/physics/collision.lua.
static func move(start: Vector2, delta: Vector2, radius: float, query: Callable) -> Dictionary:
    if not query.is_valid() or not is_finite(start.x) or not is_finite(start.y)             or not is_finite(delta.x) or not is_finite(delta.y) or radius < 0.0:
        return {"ok": false, "status": "invalid_input"}
    var p := start
    var v := delta
    var collided := false
    for pass_index in range(3):
        if absf(v.x)+absf(v.y) < 0.000001:
            break
        var lo := p.min(p+v)-Vector2.ONE*radius
        var hi := p.max(p+v)+Vector2.ONE*radius
        var items: Variant = query.call(lo.x,lo.y,hi.x,hi.y)
        if not items is Array:
            return {"ok": false, "status": "invalid_query"}
        var best := 1.000001
        var normal := Vector2.ZERO
        for item in items:
            if not item is Dictionary:
                return {"ok": false, "status": "invalid_obstacle"}
            var a := Vector2(float(item.get("x", NAN)),float(item.get("y",NAN)))
            var b := Vector2(float(item.get("w", NAN)),float(item.get("h",NAN)))
            if not is_finite(a.x) or not is_finite(a.y) or not is_finite(b.x) or not is_finite(b.y):
                return {"ok": false, "status": "invalid_obstacle"}
            var low := a-Vector2.ONE*radius
            var high := a+b+Vector2.ONE*radius
            var tx0 := -INF
            var tx1 := INF
            var ty0 := -INF
            var ty1 := INF
            if absf(v.x) < 0.00000001:
                if p.x <= low.x or p.x >= high.x:
                    continue
            else:
                tx0 = (low.x-p.x)/v.x
                tx1 = (high.x-p.x)/v.x
                if tx0 > tx1:
                    var save_x := tx0
                    tx0 = tx1
                    tx1 = save_x
            if absf(v.y) < 0.00000001:
                if p.y <= low.y or p.y >= high.y:
                    continue
            else:
                ty0 = (low.y-p.y)/v.y
                ty1 = (high.y-p.y)/v.y
                if ty0 > ty1:
                    var save_y := ty0
                    ty0 = ty1
                    ty1 = save_y
            var enter := maxf(tx0,ty0)
            var leave := minf(tx1,ty1)
            if enter > leave or leave < 0.0 or enter > 1.0 or enter < 0.0:
                continue
            var n := Vector2.ZERO
            if tx0 >= ty0:
                n.x = -1.0 if v.x > 0 else 1.0
            else:
                n.y = -1.0 if v.y > 0 else 1.0
            if enter < best-0.000001 or (absf(enter-best)<=0.000001 and n.x < normal.x):
                best = enter
                normal = n
        if best > 1.0:
            p += v
            break
        collided = true
        var travel := maxf(0.0,best-0.000001)
        p += v*travel
        v *= 1.0-travel
        var into := v.dot(normal)
        if into < 0.0:
            v -= normal*into
    return {"ok": true, "status": "moved", "position": p, "collided": collided}
