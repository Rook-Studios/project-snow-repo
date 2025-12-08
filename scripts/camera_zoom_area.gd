extends Area3D

@export var target_arm_length: float = 4.5
@export var zoom_lerp_speed: float = 5.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Only affect things that understand our API
	if body.has_method("set_camera_zoom_target"):
		body.set_camera_zoom_target(target_arm_length, zoom_lerp_speed)
