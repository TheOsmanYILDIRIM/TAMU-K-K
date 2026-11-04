extends Node
# Isolated native BT callback proof; no authored game data or fake Limbo classes.
var sequence: Array[String] = []
func _limbo_sense_step(delta: float) -> bool:
    sequence.append("sense:%s" % str(delta))
    return true
func _limbo_decide_step(delta: float) -> bool:
    sequence.append("decide:%s" % str(delta))
    return true
func _limbo_apply_step(delta: float) -> bool:
    sequence.append("apply:%s" % str(delta))
    return true
