extends SceneTree
const Authority = preload("res://scripts/r2_authority.gd")
const Identity = preload("res://scripts/world_identity.gd")
func _initialize() -> void:
    var phase := OS.get_environment("TAMU_WORLD_PHASE")
    var passed := false
    var a = Authority.new()
    if phase == "create" or phase == "reopen":
        if a.initialize():
            var first: Variant = a.records.values()[0]
            var item := {"id": first["id"], "kind": first["kind"], "radius": first["radius"],
                "position": Vector2(first["x"], first["y"])}
            var before: Dictionary = Identity.load_or_create()
            var tampered: Dictionary = item.duplicate(true)
            tampered["position"] = item["position"] + Vector2(1,0)
            passed = before.get("ok", false) and a.matches_object(item) and not a.matches_object(tampered)
            var spawn := a.surface(64.0,128.0)
            var river := a.surface(704.0,128.0)
            passed = passed and spawn.has("height") and not bool(river.get("walkable", true))
            passed = passed and str(river.get("feature", "")) == "water"
            passed = passed and absf(float(spawn.get("height", -1.0)) - 12.830245) < 0.015
            if phase == "reopen":
                passed = passed and before.get("status") == "existing"
            if passed:
                print("TAMU_R2_AUTHORITY_OK phase=",phase," objects=",a.records.size()," obstacles=",a.boxes.size()," uuid=",before["id"])
    # Compare broadphase queries against the original 832-box exhaustive search,
    # including cross-cell rectangles and source-order parity.
    if passed and phase == "reopen":
        for iteration in range(160):
            var item: Dictionary = a.boxes[(iteration * 37) % a.boxes.size()]
            var x1 := float(item["x"]) - float(iteration % 6) * 79.0
            var y1 := float(item["y"]) - float(iteration % 4) * 65.0
            var x2 := float(item["x"]) + float(item["w"]) + float(iteration % 3) * 110.0
            var y2 := float(item["y"]) + float(item["h"]) + float(iteration % 7) * 45.0
            var expected: Array = []
            for shape in a.boxes:
                if float(shape["x"]) < x2 and float(shape["x"]) + float(shape["w"]) > x1 \
                        and float(shape["y"]) < y2 and float(shape["y"]) + float(shape["h"]) > y1:
                    expected.append(shape)
            if a.obstacles(x1, y1, x2, y2) != expected:
                passed = false
                break
        if passed:
            print("TAMU_R2_OBSTACLE_INDEX_PARITY_OK queries=160 objects=", a.boxes.size())
    if passed and phase == "reopen" and not a.boxes.is_empty():
        var box: Dictionary = a.boxes[0]
        var before_hits: Array = a.obstacles(float(box["x"]),float(box["y"]),
            float(box["x"])+float(box["w"]),float(box["y"])+float(box["h"]))
        a.depleted_ids[str(box["id"])] = true
        var after_hits: Array = a.obstacles(float(box["x"]),float(box["y"]),
            float(box["x"])+float(box["w"]),float(box["y"])+float(box["h"]))
        passed = before_hits.size() > after_hits.size()
    if not passed:
        push_error("TAMU_R2_AUTHORITY_FAILED phase=" + phase)
    quit(0 if passed else 68)
