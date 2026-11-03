extends SceneTree
const Game = preload("res://scripts/gameplay_session.gd")

func _initialize() -> void:
    var session = Game.new()
    if not session.verify_contract():
        push_error("TAMU_NATIVE_GAMEPLAY_CONTRACT_FAILED")
        quit(45)
        return
    print("TAMU_NATIVE_GAMEPLAY_CONTRACT_OK")
    quit(0)
