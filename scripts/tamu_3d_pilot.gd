extends Node3D
## Isolated 3D migration proof. No save writes, no authored world ID fabrication.
## Vendor packages are fetched by scripts/tamu_3d_vendor.py in GitHub Actions.
const CONTROLLER_SCENE := "res://addons/JehenoThirdPersonController/PlayerCharacter/player_character_scene.tscn"
const CAMERA_HOST := "res://addons/phantom_camera/scripts/phantom_camera_host/phantom_camera_host.gd"
const PHANTOM_3D := "res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd"
const GLOOT_INVENTORY := "res://addons/gloot/core/inventory.gd"
const MODELS := ["res://assets/tamu_3d/forest.glb", "res://assets/tamu_3d/nature.glb"]

var ready_verified := false
var system_status: Dictionary = {}


func _enter_tree() -> void:
    # Phantom Camera installs this autoload via its editor plugin. Our isolated
    # pilot must also work without changing the existing 2.5D project.godot.
    if Engine.has_singleton("PhantomCameraManager"):
        return
    var manager_script: Script = load("res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd")
    if manager_script == null:
        push_error("TAMU3D_PHANTOM_MANAGER_SCRIPT_MISSING")
        return
    var manager: Node = manager_script.new()
    manager.name = "PhantomCameraManager"
    get_tree().root.add_child(manager)


func _ready() -> void:
    if not ClassDB.class_exists("Terrain3D") or not ClassDB.class_exists("Terrain3DTextureAsset"):
        push_error("TAMU3D_TERRAIN3D_NATIVE_MISSING")
        return
    if not _setup_terrain():
        return
    _setup_navmesh()
    var player = _setup_player()
    if player == null:
        return
    if not _setup_camera(player):
        return
    if not _setup_assets():
        return
    var inv_script: Script = load(GLOOT_INVENTORY)
    if inv_script == null:
        push_error("TAMU3D_GLOOT_MISSING")
        return
    var inv: Node = inv_script.new()
    inv.name = "PilotInventory"
    add_child(inv)
    system_status["inventory"] = "gloot_instantiated_no_save_migration"
    ready_verified = true
    print("TAMU3D_STACK_READY terrain=Terrain3D camera=PhantomCamera player=Jeheno nav=GodotNavigation models=2 inventory=GLoot")


func _setup_terrain() -> bool:
    var terrain_obj: Object = ClassDB.instantiate("Terrain3D")
    if terrain_obj == null or not (terrain_obj is Node3D):
        push_error("TAMU3D_NATIVE_TERRAIN_CONSTRUCTION_FAILED")
        return false
    var terrain_node: Node3D = terrain_obj as Node3D
    terrain_node.name = "Terrain3D"
    terrain_obj.set("free_editor_textures", false)
    add_child(terrain_node)
    var terrain_assets: Object = terrain_obj.get("assets")
    var terrain_data: Object = terrain_obj.get("data")
    var terrain_material: Object = terrain_obj.get("material")
    if terrain_assets == null or terrain_data == null or terrain_material == null:
        push_error("TAMU3D_TERRAIN_API_FAILED")
        return false
    terrain_material.set("world_background", 0)
    terrain_material.set("auto_shader_enabled", true)

    var tex_img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    tex_img.fill(Color(0.27, 0.34, 0.22, 1.0))
    tex_img.generate_mipmaps()
    var asset: Object = ClassDB.instantiate("Terrain3DTextureAsset")
    if asset == null:
        push_error("TAMU3D_TERRAIN_TEXTURE_CLASS_FAILED")
        return false
    asset.set("name", "TAMU Ground Prototype")
    asset.set("albedo_texture", ImageTexture.create_from_image(tex_img))
    terrain_assets.call("set_texture_asset", 0, asset)

    # True 3D geometry, not a sprite height-map simulation; pilot uses flat data.
    # Authored TAMU R2 156/832 parity conversion is a *separate* acceptance gate.
    var height: Image = Image.create(1024, 1024, false, Image.FORMAT_RF)
    height.fill(Color(0, 0, 0, 1))
    terrain_obj.set("region_size", 1024)
    terrain_data.call("import_images", [height, null, null], Vector3(-512, 0, -512), 0.0, 2.0)
    system_status["terrain"] = "Terrain3D_native_1024"
    return true


func _setup_navmesh() -> void:
    var navigation: NavigationRegion3D = NavigationRegion3D.new()
    navigation.name = "NavigationRegion3D"
    var navmesh: NavigationMesh = NavigationMesh.new()
    navmesh.vertices = PackedVector3Array([
        Vector3(-12, 0, -12), Vector3(12, 0, -12),
        Vector3(12, 0, 12), Vector3(-12, 0, 12)])
    navmesh.add_polygon(PackedInt32Array([0, 1, 2]))
    navmesh.add_polygon(PackedInt32Array([0, 2, 3]))
    navigation.navigation_mesh = navmesh
    add_child(navigation)
    system_status["navigation"] = "NavigationServer3D_native"


func _setup_player() -> CharacterBody3D:
    var packed: PackedScene = load(CONTROLLER_SCENE)
    if packed == null:
        push_error("TAMU3D_JEHENO_CONTROLLER_NOT_IMPORTED")
        return null
    var actor: Node = packed.instantiate()
    if not (actor is CharacterBody3D):
        push_error("TAMU3D_CONTROLLER_WRONG_ROOT")
        actor.free()
        return null
    var player: CharacterBody3D = actor as CharacterBody3D
    player.name = "Player3D"
    player.position = Vector3(0, 1.5, 0)
    add_child(player)
    system_status["player"] = "Jeheno_player_character_scene"
    return player


func _setup_camera(player: Node3D) -> bool:
    var host_script: Script = load(CAMERA_HOST)
    var phantom_script: Script = load(PHANTOM_3D)
    if host_script == null or phantom_script == null:
        push_error("TAMU3D_PHANTOM_CAMERA_MISSING")
        return false
    var camera: Camera3D = Camera3D.new()
    camera.name = "IsometricCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 26.0
    camera.position = Vector3(17, 23, 17)
    add_child(camera)
    camera.look_at(Vector3(0, 0, 0), Vector3.UP)

    var host: Node = host_script.new()
    host.name = "PhantomCameraHost"
    camera.add_child(host)

    var pcam: Node3D = phantom_script.new()
    pcam.name = "FixedAnglePhantomCamera"
    pcam.position = camera.position
    pcam.rotation = camera.rotation
    pcam.set("follow_mode", 1) # GLUED
    pcam.set("follow_target", NodePath("../Player3D"))
    pcam.set("priority", 10)
    add_child(pcam)
    camera.make_current()
    system_status["camera"] = "PhantomCamera3D_fixed_angle"
    return true


func _setup_assets() -> bool:
    var positions: Array[Vector3] = [Vector3(-8, 0, -5), Vector3(8, 0, -5)]
    for i in MODELS.size():
        var pack: PackedScene = load(MODELS[i])
        if pack == null:
            push_error("TAMU3D_MODEL_NOT_IMPORTED: " + MODELS[i])
            return false
        var imported: Node = pack.instantiate()
        if not (imported is Node3D):
            imported.free()
            push_error("TAMU3D_MODEL_INVALID_SCENE: " + MODELS[i])
            return false
        var visual: Node3D = imported as Node3D
        visual.name = "CC0Forest" if i == 0 else "CC0Nature"
        visual.position = positions[i]
        add_child(visual)
    system_status["models"] = "Pinned_CC0_GLTF_2"
    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.name = "Sun"
    sun.light_energy = 0.8
    sun.rotation_degrees = Vector3(-48, -35, 0)
    add_child(sun)
    return true
