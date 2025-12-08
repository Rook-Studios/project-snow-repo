extends CharacterBody3D

## --- Tunables (Inspector) ---
@export_category("Movement")
@export var walk_speed: float = 3.6
@export var sprint_speed: float = 5.2       # not used yet, but handy to have
@export var acceleration: float = 10.0      # ground accel
@export var air_acceleration: float = 4.0   # air control

@export_category("Jumping & Gravity")
@export var jump_height: float = 1.1        # in meters
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 22.0

@export_category("Orientation")
## If you assign a Node3D (e.g., a camera pivot), movement will be camera-relative.
@export var orientation_node: NodePath

## --- Internals ---
var _up: Vector3 = Vector3.UP
var _orient_ref: Node3D

func _ready() -> void:
	if orientation_node != NodePath():
		_orient_ref = get_node_or_null(orientation_node) as Node3D

func _physics_process(delta: float) -> void:
	var g: float = (ProjectSettings.get_setting("physics/3d/default_gravity") as float) * gravity_scale

	# 1) Read input
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Godot: forward is -Z; Input.get_vector returns (x,y) where y is forward/back
	var move_dir := Vector3.ZERO
	if _orient_ref:
		var f := -_orient_ref.global_transform.basis.z
		var r :=  _orient_ref.global_transform.basis.x
		f.y = 0; r.y = 0
		f = f.normalized(); r = r.normalized()
		move_dir = (f * input_vec.y + r * input_vec.x).normalized()
	else:
		move_dir = Vector3(input_vec.x, 0, input_vec.y).normalized()

	# 2) Target horizontal velocity
	var target_speed := walk_speed
	var desired_vxz := move_dir * target_speed
	var current_vxz := Vector2(velocity.x, velocity.z)
	var desired_vxz2 := Vector2(desired_vxz.x, desired_vxz.z)
	var accel := acceleration if is_on_floor() else air_acceleration
	current_vxz = current_vxz.lerp(desired_vxz2, clamp(accel * delta, 0.0, 1.0))
	velocity.x = current_vxz.x
	velocity.z = current_vxz.y

	# 3) Gravity + jump
	if is_on_floor():
		# stick to ground slightly for stable steps
		velocity.y = min(velocity.y, 0.0)
		if Input.is_action_just_pressed("jump"):
			velocity.y = _jump_velocity(g)
	else:
		velocity.y = max(velocity.y - g * delta, -max_fall_speed)

	# 4) Move
	move_and_slide()
	# Optional: rotate the body toward movement direction
	if move_dir.length() > 0.001:
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 12.0 * delta)

func _jump_velocity(gravity: float) -> float:
	# v = sqrt(2gh) produces a jump that peaks around 'jump_height'
	return sqrt(2.0 * gravity * jump_height)
