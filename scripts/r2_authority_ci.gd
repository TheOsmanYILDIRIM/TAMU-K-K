extends SceneTree
const Authority = preload("res://scripts/r2_authority.gd")
const Identity = preload("res://scripts/world_identity.gd")
func _initialize() -> void:
    var phase := OS.get_environment("TAMU_WORLD_PHASE")
    var passed := false
    if phase == "create" or phase == "reopen":
        var a = Authority.new()
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
    if passed and phase == "reopen" and not a.boxes.is_empty():
        var box: Dictionary = a.boxes[0]
        var before_hits := a.obstacles(float(box["x"]),float(box["y"]),
            float(box["x"])+float(box["w"]),float(box["y"])+float(box["h"]))
        a.depleted_ids[str(box["id"])] = true
        var after_hits := a.obstacles(float(box["x"]),float(box["y"]),
            float(box["x"])+float(box["w"]),float(box["y"])+float(box["h"]))
        passed = before_hits.size() > after_hits.size()
    if not passed:
        push_error("TAMU_R2_AUTHORITY_FAILED phase=" + phase)
    quit(0 if passed else 68)
