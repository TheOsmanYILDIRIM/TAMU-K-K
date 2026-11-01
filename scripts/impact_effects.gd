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
