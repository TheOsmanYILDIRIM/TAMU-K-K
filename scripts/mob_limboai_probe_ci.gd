extends SceneTree
const Bridge = preload("res://scripts/mob_limboai_bridge.gd")
const Agent = preload("res://scripts/mob_limboai_probe_agent.gd")

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    if not Bridge.available():
        push_error("TAMU_LIMBOAI_EXTENSION_MISSING")
        quit(71)
        return
    var agent: Node = Agent.new()
    root.add_child(agent)
    var player: Node = Bridge.install(agent, "test")
    if player == null:
        push_error("TAMU_LIMBOAI_BT_CREATION_FAILED")
        quit(72)
        return
    if agent.sequence.size() != 0:
        push_error("TAMU_LIMBOAI_UNEXPECTED_AUTO_TICK")
        quit(73)
        return
    player.call("update", 0.2)
    if agent.sequence.size() != 3 \
            or not agent.sequence[0].begins_with("sense:") \
            or not agent.sequence[1].begins_with("decide:") \
            or not agent.sequence[2].begins_with("apply:"):
        push_error("TAMU_LIMBOAI_BT_ORDER_FAILED " + str(agent.sequence))
        quit(74)
        return
    print("TAMU_LIMBOAI_BT_CONTRACT_OK tasks=3 manual=true class=BTPlayer")
    quit()
