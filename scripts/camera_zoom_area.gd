extends Area3D

@export var target_arm_length: float = 4.5
@export var zoom_lerp_speed: float = 4.0
@export var revert_on_exit: bool = true
@export var exit_zoom_lerp_speed: float = 4.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_camera_zoom_target"):
		body.set_camera_zoom_target(target_arm_length, zoom_lerp_speed)

func _on_body_exited(body: Node) -> void:
	if not revert_on_exit:
		return
	if body.has_method("restore_default_zoom"):
		body.restore_default_zoom(exit_zoom_lerp_speed)
