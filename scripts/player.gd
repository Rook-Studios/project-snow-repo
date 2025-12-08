extends CharacterBody3D

## --- Movement ---
@export_category("Movement")
@export var walk_speed: float = 3.6
@export var sprint_speed: float = 5.2
@export var acceleration: float = 10.0
@export var air_acceleration: float = 4.0

## --- Jump/Gravity ---
@export_category("Jumping & Gravity")
@export var jump_height: float = 1.1
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 22.0

## --- Camera Orbit ---
@export_category("Camera Orbit")
@export var mouse_sensitivity: float = 0.008      # radians per pixel
@export var invert_y: bool = false
@export var min_pitch_deg: float = -35.0
@export var max_pitch_deg: float = 55.0
@export var start_pitch_deg: float = 10.0
@export var start_yaw_deg: float = 0.0

## --- Camera View (Camera3D child) ---
@export_category("Camera View")
@export_range(20.0, 120.0, 1.0) var camera_fov: float = 70.0
@export var camera_near: float = 0.05
@export var camera_far: float = 400.0

## --- Zoom (SpringArm3D child, auto) ---
@export_category("Camera Zoom")
@export var arm_start_length: float = 3.5
@export var min_arm_length: float = 1.0
@export var max_arm_length: float = 100.0
@export var arm_lerp_speed: float = 5.0   # how fast the camera moves to the target

## --- Optional external orientation (will auto-use Pivot if empty) ---
@export_category("Orientation")
@export var orientation_node: NodePath

var _yaw := 0.0
var _pitch := 0.0

@onready var _pivot: Node3D = $Pivot
@onready var _spring: SpringArm3D = $Pivot/SpringArm3D
@onready var _camera: Camera3D = $Pivot/SpringArm3D/Camera3D
var _orient_ref: Node3D

var _target_arm_length: float = 0.0   # <-- NEW: what we lerp toward


func _ready() -> void:
	# Initial orbit angles
	_pitch = deg_to_rad(start_pitch_deg)
	_yaw = deg_to_rad(start_yaw_deg)
	_apply_pivot_rotation()

	# Apply camera settings
	_camera.fov = camera_fov
	_camera.near = camera_near
	_camera.far = camera_far

	# Apply spring arm starting length, clamped to min/max
	if arm_start_length <= 0.0:
		arm_start_length = _spring.spring_length
	_target_arm_length = clamp(arm_start_length, min_arm_length, max_arm_length)
	_spring.spring_length = _target_arm_length

	# Use Pivot for camera-relative movement unless user set something else
	if orientation_node != NodePath():
		_orient_ref = get_node_or_null(orientation_node) as Node3D
	else:
		_orient_ref = _pivot

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		var dy = event.relative.y * mouse_sensitivity
		_pitch += (dy if invert_y else -dy)

		var min_p := deg_to_rad(min_pitch_deg)
		var max_p := deg_to_rad(max_pitch_deg)
		_pitch = clamp(_pitch, min_p, max_p)
		_apply_pivot_rotation()


	# Toggle capture with Esc
	if event.is_action_pressed("ui_cancel"):
		var mode := Input.get_mouse_mode()
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

func _apply_pivot_rotation() -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)

func _physics_process(delta: float) -> void:
	var g: float = (ProjectSettings.get_setting("physics/3d/default_gravity") as float) * gravity_scale

	# 1) Input direction, camera-relative if _orient_ref set
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := Vector3.ZERO
	if _orient_ref:
		var f := _orient_ref.global_transform.basis.z
		var r := _orient_ref.global_transform.basis.x
		f.y = 0
		r.y = 0
		f = f.normalized()
		r = r.normalized()
		move_dir = (f * input_vec.y + r * input_vec.x).normalized()
	else:
		move_dir = Vector3(input_vec.x, 0, input_vec.y).normalized()

	# 2) Horizontal velocity lerp
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
		velocity.y = min(velocity.y, 0.0)
		if Input.is_action_just_pressed("jump"):
			velocity.y = _jump_velocity(g)
	else:
		velocity.y = max(velocity.y - g * delta, -max_fall_speed)

	# 4) Move
	move_and_slide()

	# 5) Smooth camera zoom toward target_arm_length
	var t = clamp(arm_lerp_speed * delta, 0.0, 1.0)
	_spring.spring_length = lerp(_spring.spring_length, _target_arm_length, t)

func set_camera_zoom_target(target_length: float, speed: float = -1.0) -> void:
	# Optional per-area override of zoom speed
	if speed > 0.0:
		arm_lerp_speed = speed

	_target_arm_length = clamp(target_length, min_arm_length, max_arm_length)


func _jump_velocity(gravity: float) -> float:
	return sqrt(2.0 * gravity * jump_height)
