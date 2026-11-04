extends Node2D
# Short GPU impacts, bounded on Android; not a generic physics simulation.
const MAX_BURSTS := 16
var active: Array[GPUParticles2D] = []
var palette := {
    "tree": Color(0.32, 0.62, 0.32, 0.86),
    "rock": Color(0.62, 0.62, 0.58, 0.82),
    "craft": Color(0.95, 0.76, 0.35, 0.85),
    "hit": Color(0.95, 0.49, 0.27, 0.9)
}

func burst(position_world: Vector2, kind: String, count: int = 10) -> void:
    if active.size() >= MAX_BURSTS:
        return
    var particles := GPUParticles2D.new()
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.amount = clampi(count, 2, 20)
    particles.lifetime = 0.42
    particles.position = position_world
    particles.z_index = 10
    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
    process.direction = Vector3(0.0, -1.0, 0.0)
    process.spread = 55.0
    process.initial_velocity_min = 24.0
    process.initial_velocity_max = 65.0
    process.gravity = Vector3(0, 140, 0)
    process.scale_min = 0.45
    process.scale_max = 1.2
    process.color = palette.get(kind, palette["hit"])
    particles.process_material = process
    add_child(particles)
    active.append(particles)
    particles.finished.connect(func():
        active.erase(particles)
        particles.queue_free()
    )
    particles.emitting = true

# Texture-derived chips: one tiny region from the actual authored tree/rock
# atlas, no CPU pixels, texture baking or shader compilation during strikes.
# Burst count and lifetime are fixed, and the material is shared.
const MAX_TEXTURE_BURSTS := 6
var chip_material: ParticleProcessMaterial
var chip_pool: Array[GPUParticles2D] = []
var chip_busy: Dictionary = {}
var chip_sequence := 0

func chip_burst(world_screen: Vector2, source: Sprite2D) -> void:
    if source == null or source.texture == null:
        return
    if chip_material == null:
        chip_material = ParticleProcessMaterial.new()
        chip_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
        chip_material.direction = Vector3(0.0, -1.0, 0.0)
        chip_material.spread = 65.0
        chip_material.initial_velocity_min = 25.0
        chip_material.initial_velocity_max = 62.0
        chip_material.gravity = Vector3(0.0, 145.0, 0.0)
        chip_material.scale_min = 0.28
        chip_material.scale_max = 0.55
    var dimensions: Vector2 = source.texture.get_size()
    if dimensions.x < 12.0 or dimensions.y < 12.0:
        return
    # Shift the little crop each strike so fragments reflect different bark,
    # stone and mineral patches from the authentic source sprite.
    chip_sequence += 1
    var side := mini(18, floori(minf(dimensions.x, dimensions.y) * 0.18))
    var cx := clampi(floori(dimensions.x * (0.30 + float(chip_sequence % 4) * 0.13)), 0, floori(dimensions.x)-side)
    var cy := clampi(floori(dimensions.y * (0.28 + float(chip_sequence % 3) * 0.17)), 0, floori(dimensions.y)-side)
    var fragment := AtlasTexture.new()
    fragment.atlas = source.texture
    fragment.region = Rect2(cx, cy, side, side)
    var particles: GPUParticles2D
    for candidate in chip_pool:
        if not bool(chip_busy.get(candidate.get_instance_id(), false)):
            particles = candidate
            break
    if particles == null:
        if chip_pool.size() >= MAX_TEXTURE_BURSTS:
            return
        particles = GPUParticles2D.new()
        particles.process_material = chip_material
        particles.one_shot = true
        particles.explosiveness = 1.0
        particles.amount = 6
        particles.lifetime = 0.28
        particles.z_index = 10
        add_child(particles)
        chip_pool.append(particles)
        var emitter: GPUParticles2D = particles
        emitter.finished.connect(func():
            chip_busy[emitter.get_instance_id()] = false
        )
    particles.emitting = false
    particles.position = world_screen
    particles.texture = fragment
    chip_busy[particles.get_instance_id()] = true
    particles.restart()
    particles.emitting = true
