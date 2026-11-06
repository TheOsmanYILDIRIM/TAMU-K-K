extends RefCounted
# True LimboAI C++ BTPlayer / BTSequence / BTCallMethod adapter.
# No replacement/fake classes. The pinned native extension must be installed.
# Native binaries are NOT expected to be loadable from an external Android PCK.
const METHODS := [
    &"_limbo_sense_step",
    &"_limbo_decide_step",
    &"_limbo_apply_step"
]

static func available() -> bool:
    for name in ["BTPlayer", "BehaviorTree", "BTSequence", "BTCallMethod", "BBNode"]:
        if not ClassDB.class_exists(name):
            return false
    return true

static func install(receiver: Node, identifier: String) -> Node:
    if receiver == null or not available():
        return null
    var tree: Resource = ClassDB.instantiate("BehaviorTree")
    var sequence: Resource = ClassDB.instantiate("BTSequence")
    if tree == null or sequence == null:
        return null
    for method_name in METHODS:
        var task: Resource = ClassDB.instantiate("BTCallMethod")
        var target: Resource = ClassDB.instantiate("BBNode")
        if task == null or target == null:
            return null
        # The receiver is also the explicit LimboAI scene root.
        target.set("saved_value", NodePath("."))
        task.call("set_node_param", target)
        task.call("set_method", method_name)
        task.call("set_include_delta", true)
        sequence.call("add_child", task)
    tree.call("set_root_task", sequence)
    var player: Node = ClassDB.instantiate("BTPlayer")
    if player == null:
        return null
    player.name = "LimboAI_" + identifier.replace(":", "_")
    player.set("behavior_tree", tree)
    player.set("update_mode", 2) # BTPlayer.UpdateMode.MANUAL
    player.set("monitor_performance", false)
    player.call("set_scene_root_hint", receiver)
    receiver.add_child(player)
    if player.call("get_bt_instance") == null:
        player.queue_free()
        return null
    return player
