extends Node3D

func _ready() -> void:
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(9.0, 10.0, 9.0)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.current = true
