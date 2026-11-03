extends Resource
# Data-only behavior tuning. No player mod code is evaluated.
@export var id: String = "core:herd_herbivore"
@export_enum("herbivore", "carnivore", "omnivore", "scavenger") var diet: String = "herbivore"
@export_enum("timid", "defensive", "territorial", "hunter", "opportunist") var temperament: String = "timid"
@export var social: bool = true
@export var attack_player: bool = false
@export var prey_tags: PackedStringArray = PackedStringArray()
@export_range(0.0, 1.0) var bravery: float = 0.18
@export_range(0.0, 1.0) var chase_hunger: float = 0.45
@export_range(0.0, 1.0) var retreat_health: float = 0.35
@export_range(0.0, 60.0) var pursuit_seconds: float = 8.0
@export_range(0.0, 1.0) var carrion_preference: float = 0.0

func validate() -> bool:
    return id.contains(":") and diet in ["herbivore", "carnivore", "omnivore", "scavenger"] \
        and temperament in ["timid", "defensive", "territorial", "hunter", "opportunist"] \
        and is_finite(bravery) and bravery >= 0.0 and bravery <= 1.0 \
        and is_finite(retreat_health) and retreat_health > 0.0 and retreat_health < 1.0 \
        and is_finite(pursuit_seconds) and pursuit_seconds >= 0.0 and pursuit_seconds <= 60.0
