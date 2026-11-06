extends Node2D
# GPU-weighted native rig; AI advances independently of visibility and animation LOD.
var skeleton: Skeleton2D
var player: AnimationPlayer
var artwork: Node2D
var contact_shadow: Polygon2D
var ground_screen_height := 0.0
var source: Resource
var bone_nodes: Array[Bone2D] = []
var current_clip := ""
var visual_scale := 0.13
var accumulator := 0.0
var lod_seconds := 1.0 / 30.0
var installed := false

func configure(data: Resource, scale_value: float) -> bool:
    if installed or data == null or not data.has_method("validate") or not data.validate():
        push_error("TAMU_MOB_RIG_INVALID")
        return false
    source = data
    visual_scale = scale_value
    var shadow := Polygon2D.new()
    shadow.name = "ContactShadow"
    var ring := PackedVector2Array()
    for i in range(24):
        ring.append(Vector2(cos(TAU * i / 24.0) * 24.0, sin(TAU * i / 24.0) * 6.0))
    shadow.polygon = ring
    shadow.color = Color(0.08, 0.10, 0.06, 0.23)
    add_child(shadow)
    contact_shadow = shadow
    var mirror := Node2D.new()
    mirror.name = "Facing"
    # Animation paths are rooted at Facing, keeping mirroring out of bone transforms.
    add_child(mirror)
    artwork = Node2D.new()
    artwork.name = "Artwork"
    artwork.position.y = -float(data.ground_y)
    mirror.scale = Vector2.ONE * visual_scale
    mirror.add_child(artwork)
    skeleton = Skeleton2D.new()
    skeleton.name = "Skeleton2D"
    artwork.add_child(skeleton)
    for item in data.bones:
        var bone := Bone2D.new()
        bone.name = str(item["name"])
        bone.position = item["position"]
        bone.rotation = float(item["angle"])
        bone.rest = bone.transform
        bone.set_autocalculate_length_and_angle(false)
        bone.set_length(maxf(0.1, float(item["length"])))
        var parent_index: int = int(item["parent"])
        if parent_index < 0:
            skeleton.add_child(bone)
        else:
            bone_nodes[parent_index].add_child(bone)
        bone_nodes.append(bone)
    for item in data.meshes:
        var polygon := Polygon2D.new()
        polygon.name = str(item["name"])
        polygon.texture = data.atlas
        polygon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        polygon.polygon = item["points"]
        polygon.uv = item["uv"]
        var triangles: PackedInt32Array = item["triangles"]
        var polygons: Array[PackedInt32Array] = []
        for i in range(0, triangles.size(), 3):
            polygons.append(PackedInt32Array([triangles[i], triangles[i + 1], triangles[i + 2]]))
        polygon.polygons = polygons
        artwork.add_child(polygon)
        polygon.skeleton = polygon.get_path_to(skeleton)
        for binding in item["bind"]:
            polygon.add_bone(skeleton.get_path_to(bone_nodes[int(binding["bone"])]), binding["weights"])
    player = AnimationPlayer.new()
    player.name = "AnimationPlayer"
    mirror.add_child(player)
    player.root_node = NodePath("..")
    player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    if player.add_animation_library("", data.animations) != OK:
        return false
    installed = true
    play("idle", 0.0)
    player.advance(0.0)
    return true

# Root remains at the unraised Cartesian ground projection for the same
# Y-sort contract as the player; only the artwork and footprint are lifted.
func set_ground_height(screen_height: float) -> void:
    if not installed or not is_finite(screen_height):
        return
    ground_screen_height = screen_height
    contact_shadow.position.y = -screen_height
    artwork.position.y = -float(source.ground_y) - screen_height / visual_scale

func play(clip: String, blend: float = 0.14, rate: float = 1.0) -> bool:
    if not installed or not player.has_animation(clip):
        push_error("TAMU_MOB_CLIP_MISSING " + clip)
        return false
    player.speed_scale = clampf(rate, 0.2, 2.0)
    if current_clip != clip:
        current_clip = clip
        player.play(clip, blend)
    return true

func face(screen_delta: Vector2) -> void:
    # One supplied lateral view only. Do not fabricate 8-view artwork.
    if absf(screen_delta.x) > 0.05:
        get_node("Facing").scale.x = visual_scale * (-1.0 if screen_delta.x < 0.0 else 1.0)

func advance(delta: float) -> void:
    if not installed:
        return
    accumulator += delta
    if accumulator >= lod_seconds:
        player.advance(accumulator)
        accumulator = 0.0
