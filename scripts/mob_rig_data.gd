extends Resource
# Trusted first-party resource. Never load external .tres/.res scripts as player mods.
@export var atlas: Texture2D
@export var animations: AnimationLibrary
@export var ground_y: float = 174.0
@export var bones: Array[Dictionary] = []
@export var meshes: Array[Dictionary] = []

func validate() -> bool:
    if atlas == null or animations == null or bones.is_empty() or meshes.is_empty():
        return false
    for i in range(bones.size()):
        var b: Dictionary = bones[i]
        if int(b.get("parent", -1)) >= i or not b.get("position") is Vector2:
            return false
    for mesh in meshes:
        var pts: PackedVector2Array = mesh.get("points", PackedVector2Array())
        var uv: PackedVector2Array = mesh.get("uv", PackedVector2Array())
        var indices: PackedInt32Array = mesh.get("triangles", PackedInt32Array())
        if pts.is_empty() or pts.size() != uv.size() or indices.size() % 3 != 0:
            return false
        for index in indices:
            if index < 0 or index >= pts.size():
                return false
        var totals := PackedFloat32Array()
        totals.resize(pts.size())
        for binding in mesh.get("bind", []):
            var bi: int = int(binding.get("bone", -1))
            var weights: PackedFloat32Array = binding.get("weights", PackedFloat32Array())
            if bi < 0 or bi >= bones.size() or weights.size() != pts.size():
                return false
            for v in range(weights.size()):
                if not is_finite(weights[v]) or weights[v] < 0.0:
                    return false
                totals[v] += weights[v]
        for total in totals:
            if absf(total - 1.0) > 0.0001:
                return false
    return true
