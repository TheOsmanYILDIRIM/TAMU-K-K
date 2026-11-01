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
            passed = passed and not a.surface(float(first["x"]),float(first["y"])).get("walkable",true)
            if phase == "reopen":
                passed = passed and before.get("status") == "existing"
            if passed:
                print("TAMU_R2_AUTHORITY_OK phase=",phase," objects=",a.records.size()," obstacles=",a.boxes.size()," uuid=",before["id"])
    if not passed:
        push_error("TAMU_R2_AUTHORITY_FAILED phase=" + phase)
    quit(0 if passed else 68)
