extends Resource
const Policy = preload("res://scripts/mob_policy.gd")
@export var id: String = "core:yaprakkulak"
@export var label: String = "Yaprakkulak"
@export var policy: Resource
@export var rig: Resource
@export var tags: PackedStringArray = PackedStringArray(["herbivore", "small", "prey"])
# Canonical behavior clip -> species-specific authored clip. Future predators may
# map "kick" to "bite" without changing AI. Empty map uses the Yaprakkulak contract.
@export var animation_map: Dictionary = {}
@export var max_health: float = 45.0
@export var walk_speed: float = 22.0
@export var trot_speed: float = 52.0
@export var run_speed: float = 110.0
@export var radius: float = 8.0
@export var art_scale: float = 0.13
@export var vision_range: float = 210.0
@export var vision_degrees: float = 240.0
@export var hearing_range: float = 260.0
@export var alert_range: float = 130.0
@export var panic_range: float = 65.0
@export var safe_range: float = 230.0
@export var memory_seconds: float = 7.0
@export var home_radius: float = 550.0
@export var herd_distance: float = 110.0
@export var interaction_reach: float = 22.0
@export var attack_range: float = 28.0
@export var attack_damage: float = 7.0
@export var attack_cooldown: float = 1.8
@export var hunger_rate: float = 0.0015
@export var thirst_rate: float = 0.0022
@export var night_rest: bool = true
@export var spawn_count: int = 6

func validate() -> bool:
    if not id.contains(":") or policy == null or not policy is Policy or not policy.validate():
        return false
    for key in animation_map:
        if not key is String or not animation_map[key] is String or str(animation_map[key]).contains("/"):
            return false
    for field in [max_health, walk_speed, trot_speed, run_speed, radius, art_scale,
        vision_range, hearing_range, alert_range, panic_range, safe_range, memory_seconds,
        home_radius, herd_distance, interaction_reach, attack_range, attack_damage,
        attack_cooldown, hunger_rate, thirst_rate]:
        if not is_finite(field) or field <= 0.0:
            return false
    return radius <= 32.0 and walk_speed <= trot_speed and trot_speed <= run_speed \
        and run_speed <= 300.0 and panic_range < alert_range and alert_range < safe_range \
        and art_scale <= 1.0 and spawn_count >= 0 and spawn_count <= 32 \
        and vision_degrees > 0.0 and vision_degrees <= 360.0
