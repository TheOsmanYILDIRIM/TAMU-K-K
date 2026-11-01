extends Skeleton2D
# TAMU: native Godot Bone2D FK sampler from the unchanged Rigby JSON.
# Region attachment skinning and mesh-weight parity are separate acceptance gates.
var bones: Array[Bone2D] = []
var setups: Array[Dictionary] = []
var animations: Dictionary = {}
var current := ""
var elapsed := 0.0

func configure(rig: Dictionary) -> void:
    for entry in rig.get("bones", []):
        var bone := Bone2D.new()
        bone.name = str(entry["name"])
        var parent_id := int(entry.get("parent", -1))
        if parent_id >= 0:
            bones[parent_id].add_child(bone)
        else:
            add_child(bone)
        bone.position = Vector2(float(entry.get("x", 0)), -float(entry.get("y", 0)))
        bone.rotation_degrees = -float(entry.get("rotation", 0))
        bone.scale = Vector2(float(entry.get("scale_x", 1)), float(entry.get("scale_y", 1)))
        bone.rest = bone.transform
        bones.append(bone)
        setups.append(entry)
    for clip in rig.get("animations", []):
        animations[str(clip["name"])] = clip
    assert(bones.size() >= 38 and animations.size() == 44)
    print("TAMU_NATIVE_BONE_FK_READY bones=", bones.size(), " clips=", animations.size())

func play_clip(name: String) -> void:
    if not animations.has(name):
        push_error("Unknown Rigby FK clip: " + name)
        return
    if current != name:
        elapsed = 0.0
        current = name

func _sample(keys: Array, time: float, component: int = -1) -> float:
    if keys.is_empty():
        return 0.0
    var at: Dictionary = keys[0]
    var nxt: Dictionary = keys[keys.size()-1]
    for i in range(keys.size()):
        if float(keys[i]["time"]) <= time:
            at = keys[i]
            nxt = keys[mini(i+1, keys.size()-1)]
        else:
            break
    var v = at.get("value", 0)
    var w = nxt.get("value", 0)
    var a := float(v[component] if component >= 0 and v is Array else v)
    var b := float(w[component] if component >= 0 and w is Array else w)
    var dt := float(nxt["time"]) - float(at["time"])
    if dt <= 0 or at.get("curve","linear") == "stepped":
        return a
    var f := clampf((time-float(at["time"]))/dt, 0.0, 1.0)
    # Exact cubic Bézier handles remain a parity task; linear fallback is explicit.
    return lerpf(a,b,f)

func advance(delta: float) -> void:
    if current.is_empty():
        return
    var clip: Dictionary = animations[current]
    elapsed = fposmod(elapsed + delta, maxf(float(clip["duration"]),0.001))
    for i in range(bones.size()):
        var entry: Dictionary = setups[i]
        var bone := bones[i]
        bone.position = Vector2(float(entry.get("x",0)), -float(entry.get("y",0)))
        bone.rotation_degrees = -float(entry.get("rotation",0))
        bone.scale = Vector2(float(entry.get("scale_x",1)), float(entry.get("scale_y",1)))
    for track in clip.get("bones", []):
        var index := int(track["bone"])
        var node := bones[index]
        if track.has("rotate"):
            node.rotation_degrees = -float(setups[index].get("rotation",0)) - _sample(track["rotate"], elapsed)
        if track.has("translate"):
            node.position += Vector2(_sample(track["translate"],elapsed,0),-_sample(track["translate"],elapsed,1))
        if track.has("scale"):
            node.scale *= Vector2(_sample(track["scale"],elapsed,0),_sample(track["scale"],elapsed,1))
