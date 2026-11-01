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

func _cubic(a: float, b: float, t: float) -> float:
    var v := 1.0 - t
    return 3.0 * v * v * t * a + 3.0 * v * t * t * b + t * t * t

func _derivative(a: float, b: float, t: float) -> float:
    var v := 1.0 - t
    return 3.0 * v * v * a + 6.0 * v * t * (b-a) + 3.0 * t * t * (1.0-b)

# Matches the original LÖVE Rigby runtime's Newton/bisection cubic inversion.
func _ease(curve: Variant, value: float, component: int = -1) -> float:
    var t := clampf(value, 0.0, 1.0)
    if curve is String and curve == "stepped":
        return 0.0
    var handles: Array = []
    if curve is Dictionary:
        if curve.has("bezier") and curve["bezier"] is Array:
            handles = curve["bezier"]
        elif curve.has("beziers") and curve["beziers"] is Array:
            var variants: Array = curve["beziers"]
            if not variants.is_empty():
                handles = variants[mini(maxi(component,0), variants.size()-1)]
    if handles.size() != 4:
        return t
    var x1 := clampf(float(handles[0]), 0.0, 1.0)
    var y1 := float(handles[1])
    var x2 := clampf(float(handles[2]), 0.0, 1.0)
    var y2 := float(handles[3])
    var u := t
    for i in range(8):
        var error := _cubic(x1,x2,u)-t
        if absf(error) < 0.00001:
            return _cubic(y1,y2,u)
        var dx := _derivative(x1,x2,u)
        if absf(dx) < 0.000001:
            break
        u = clampf(u-error/dx,0.0,1.0)
    var low := 0.0
    var high := 1.0
    u = t
    for i in range(30):
        var x := _cubic(x1,x2,u)
        if absf(x-t) < 0.00001:
            break
        if x<t:
            low=u
        else:
            high=u
        u=(low+high)*0.5
    return _cubic(y1,y2,u)

func _sample(keys: Array, time: float, component: int = -1) -> float:
    if keys.is_empty():
        return 0.0
    var at: Dictionary = keys[0]
    if time <= float(at["time"]):
        var first: Variant = at.get("value",0.0)
        return float(first[component] if component >= 0 and first is Array else first)
    var nxt: Dictionary = keys[keys.size()-1]
    for i in range(keys.size()):
        if float(keys[i]["time"]) <= time:
            at = keys[i]
            nxt = keys[mini(i+1,keys.size()-1)]
        else:
            break
    var start: Variant = at.get("value",0.0)
    var finish: Variant = nxt.get("value",0.0)
    var a := float(start[component] if component>=0 and start is Array else start)
    var b := float(finish[component] if component>=0 and finish is Array else finish)
    var dt := float(nxt["time"])-float(at["time"])
    if dt<=0.0:
        return a
    return lerpf(a,b,_ease(at.get("curve","linear"),(time-float(at["time"]))/dt,component))

func verify_curve_reference(path: String) -> bool:
    if not FileAccess.file_exists(path):
        push_error("TAMU_RIGBY_CURVE_REFERENCE_MISSING")
        return false
    var records := FileAccess.get_file_as_string(path).split("\n",false)
    var count := 0
    var max_error := 0.0
    for record in records:
        var parts := record.strip_edges().split(",")
        if parts.size()!=4:
            return false
        var kind := str(parts[0])
        var component := int(parts[1])
        var timestamp := float(parts[2])
        var expected := float(parts[3])
        var curve: Variant = "linear"
        match kind:
            "linear": curve = "linear"
            "stepped": curve = "stepped"
            "bezier": curve = {"bezier":[0.2,0.0,0.65,1.0]}
            "beziers": curve = {"beziers":[[0.3,0.1,0.5,0.9],[0.7,0.4,0.9,0.6]]}
            _: return false
        var v1: Variant = [10.0,10.0] if component>=0 else 10.0
        var v2: Variant = [30.0,30.0] if component>=0 else 30.0
        var keys: Array = [{"time":0.0,"value":v1,"curve":curve},{"time":1.0,"value":v2}]
        var actual := _sample(keys,timestamp,component)
        var difference := absf(actual-expected)
        max_error=maxf(max_error,difference)
        if not is_finite(actual) or difference>0.0005:
            push_error("TAMU_RIGBY_CURVE_MISMATCH "+kind+" error="+str(difference))
            return false
        count+=1
    if count!=70:
        return false
    print("TAMU_RIGBY_CURVE_PARITY_OK samples=",count,
        " max_abs_error=",snappedf(max_error,0.000001))
    return true

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
