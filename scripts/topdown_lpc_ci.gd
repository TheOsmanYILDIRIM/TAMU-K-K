extends SceneTree

func _initialize() -> void:
    const P = preload("res://scripts/topdown_projection.gd")
    if not P.verify_contract():
        push_error("TAMU_TOPDOWN_PROJECTION_FAILED")
        quit(1)
        return
    const A = preload("res://scripts/lpc_sprite_actor.gd")
    var actor := A.new()
    actor.set_motion(Vector2.UP, 0.125)
    if actor.facing != Vector2.UP or actor._direction_offset() != 0:
        push_error("TAMU_LPC_DIRECTION_FAILED")
        actor.free()
        quit(2)
        return
    actor.set_motion(Vector2.LEFT, 0.125)
    if actor._direction_offset() != 1:
        push_error("TAMU_LPC_LEFT_FAILED")
        actor.free()
        quit(3)
        return
    actor.set_motion(Vector2.ZERO, 0.125)
    if actor.phase != 0.0:
        push_error("TAMU_LPC_IDLE_FAILED")
        actor.free()
        quit(4)
        return
    actor.free()
    print("TAMU_TOPDOWN_LPC_CONTRACT_OK")
    quit()
