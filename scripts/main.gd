extends Node3D

func _ready() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = Vector3(12.0, 0.5, 12.0)
	ground.mesh = shape
	add_child(ground)
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(9.0, 11.0, 9.0)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.current = true
