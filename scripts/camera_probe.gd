extends Area3D

@export var camera_path: NodePath = ^"../Camera3D"
@onready var cam: Camera3D = get_node(camera_path) as Camera3D

func _process(_delta: float) -> void:
	if cam:
		global_position.x = cam.global_position.x
