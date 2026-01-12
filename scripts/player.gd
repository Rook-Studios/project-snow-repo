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
@export var jump_release_gravity_scale: float = 2.0  # extra gravity when jump is released while rising
@export var fall_gravity_scale: float = 1.4          # a bit more gravity on the way down (nice feel)
@export_range(0.0, 1.0, 0.05) var jump_cut_factor: float = 0.5  # one-time damping on release (0.5 = halve upward speed)


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

## --- Controller Look ---
@export_category("Controller Look")
@export var controller_look_enabled: bool = true
@export var controller_look_sensitivity: float = 2.2   # radians per second at full stick
@export var controller_look_deadzone: float = 0.15
@export var controller_invert_y: bool = false
@export var controller_look_accel: float = 18.0   # how quickly it ramps up to stick input
@export var controller_look_decel: float = 14.0   # how quickly it eases to a stop when released


## --- Camera Bob ---
@export_category("Camera Bob")
@export var camera_bob_enabled: bool = true
@export var camera_bob_amplitude: float = 0.05  # how high/low in meters
@export var camera_bob_frequency: float = 6.0   # how fast the bob cycles
@export var camera_bob_speed_threshold: float = 0.1  # min horizontal speed to start bobbing
@export var camera_bob_return_speed: float = 10.0    # how fast it returns to neutral when stopping
@export var camera_sway_enabled: bool = true
@export var camera_sway_amplitude: float = 0.03  # side-to-side in meters

@export var controls_enabled: bool = true

## --- Input Buffers ---
@export_category("Input Buffers")
@export var jump_lock_after_dialogue: float = 0.15  # seconds

## --- Optional external orientation (will auto-use Pivot if empty) ---
@export_category("Orientation")
@export var orientation_node: NodePath


var _yaw := 0.0
var _pitch := 0.0

@onready var _pivot: Node3D = $Pivot
@onready var _spring: SpringArm3D = $Pivot/SpringArm3D
@onready var _camera: Camera3D = $Pivot/SpringArm3D/Camera3D
var _orient_ref: Node3D
@onready var sprite = $Sprite3D
@onready var anim = $Sprite3D/AnimationPlayer
@onready var debug = $debug


var _target_arm_length: float = 0.0
var _bob_phase: float = 0.0
var _pivot_base_y: float
var _pivot_base_x: float
var _default_arm_length: float = 0.0   # NEW: remember default zoom

var _look_vel := Vector2.ZERO  # radians/sec (x = yaw speed, y = pitch speed)
var _using_controller: bool = false
var _jump_lock_timer: float = 0.0

var _was_on_floor: bool = true
var _landing: bool = false



func _ready() -> void:
	# Initial orbit angles
	_pitch = deg_to_rad(start_pitch_deg)
	_yaw = deg_to_rad(start_yaw_deg)
	_apply_pivot_rotation()

	# Apply camera settings
	_camera.fov = camera_fov
	_camera.near = camera_near
	_camera.far = camera_far
	_pivot_base_y = _pivot.position.y
	_pivot_base_x = _pivot.position.x

	# Apply spring arm starting length, clamped to min/max, and remember as default
	if arm_start_length <= 0.0:
		arm_start_length = _spring.spring_length

	_default_arm_length = clamp(arm_start_length, min_arm_length, max_arm_length)
	_target_arm_length = _default_arm_length
	_spring.spring_length = _target_arm_length


	# Use Pivot for camera-relative movement unless user set something else
	if orientation_node != NodePath():
		_orient_ref = get_node_or_null(orientation_node) as Node3D
	else:
		_orient_ref = _pivot
	
		# Find DialogueUI and connect to its signals (group added in its _ready()).
	var ui_nodes := get_tree().get_nodes_in_group("DialogueUI")
	if ui_nodes.size() > 0:
		var ui = ui_nodes[0]
		if not ui.opened.is_connected(_on_dialogue_opened):
			ui.opened.connect(_on_dialogue_opened)
		if not ui.closed.is_connected(_on_dialogue_closed):
			ui.closed.connect(_on_dialogue_closed)
	
		# Find JournalUI and connect to its signals (group it similarly or just search by node name/group)
	var journal_nodes := get_tree().get_nodes_in_group("JournalUI")
	if journal_nodes.size() > 0:
		var j = journal_nodes[0]
		if not j.opened.is_connected(_on_journal_opened):
			j.opened.connect(_on_journal_opened)
		if not j.closed.is_connected(_on_journal_closed):
			j.closed.connect(_on_journal_closed)

	_was_on_floor = is_on_floor()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_using_controller = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_using_controller = false
	
	if _using_controller == false:
		if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_yaw -= event.relative.x * mouse_sensitivity
			var dy = event.relative.y * mouse_sensitivity
			_pitch += (dy if invert_y else -dy)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return


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
	if not controls_enabled:
		# Keep the player grounded and still while frozen.
		if is_on_floor():
			velocity = Vector3(0, -0.1, 0)  # gentle stick-to-floor
		else:
			# If somehow in air, fall normally but ignore controls.
			var g: float = (ProjectSettings.get_setting("physics/3d/default_gravity") as float) * gravity_scale
			velocity.y = max(velocity.y - g * delta, -max_fall_speed)
			velocity.x = 0
			velocity.z = 0
		move_and_slide()
		return

	var g: float = (ProjectSettings.get_setting("physics/3d/default_gravity") as float) * gravity_scale
	
	if _jump_lock_timer > 0.0:
		_jump_lock_timer = max(_jump_lock_timer - delta, 0.0)
	
	# 1) Input direction (and analog strength), camera-relative if _orient_ref set
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_strength = clamp(input_vec.length(), 0.0, 1.0) # 0..1 (analog), ~1 for keyboard

	# Optional: prevent tiny stick drift (feel free to tune/remove)
	var move_deadzone := 0.15
	if input_strength < move_deadzone:
		input_vec = Vector2.ZERO
		input_strength = 0.0
	else:
		# Rescale so it still reaches 1.0 after deadzone
		input_strength = (input_strength - move_deadzone) / max(1.0 - move_deadzone, 0.001)

	var move_dir := Vector3.ZERO
	if _orient_ref:
		var f := _orient_ref.global_transform.basis.z
		var r := _orient_ref.global_transform.basis.x
		f.y = 0
		r.y = 0
		f = f.normalized()
		r = r.normalized()

		var dir3 := (f * input_vec.y + r * input_vec.x)
		move_dir = dir3.normalized() if dir3.length() > 0.001 else Vector3.ZERO
	else:
		var dir3 := Vector3(input_vec.x, 0.0, input_vec.y)
		move_dir = dir3.normalized() if dir3.length() > 0.001 else Vector3.ZERO

	# 2) Horizontal velocity lerp (scale speed by analog strength)
	var target_speed := walk_speed  # (you can swap to sprint_speed if you later add sprint on controller)
	var desired_vxz = move_dir * (target_speed * input_strength)

	var current_vxz := Vector2(velocity.x, velocity.z)
	var desired_vxz2 := Vector2(desired_vxz.x, desired_vxz.z)
	var accel := acceleration if is_on_floor() else air_acceleration
	current_vxz = current_vxz.lerp(desired_vxz2, clamp(accel * delta, 0.0, 1.0))
	velocity.x = current_vxz.x
	velocity.z = current_vxz.y


	# 3) Gravity + jump (variable height)
	if is_on_floor():
		velocity.y = min(velocity.y, 0.0)
		if _jump_lock_timer <= 0.0 and Input.is_action_just_pressed("jump"):
			velocity.y = _jump_velocity(g)

	else:
		if velocity.y > 0.0:
			# Rising
			if Input.is_action_pressed("jump"):
				# normal rise
				velocity.y -= g * gravity_scale * delta
			else:
				# jump released early: stronger gravity (decay)
				velocity.y -= g * gravity_scale * jump_release_gravity_scale * delta
				if Input.is_action_just_released("jump"):
					velocity.y *= jump_cut_factor  # one-time damping for a crisp short hop
		else:
			# Falling
			velocity.y = max(velocity.y - g * gravity_scale * fall_gravity_scale * delta, -max_fall_speed)


	# 4) Move
	move_and_slide()

	# 5) Smooth camera zoom toward target_arm_length
	var t = clamp(arm_lerp_speed * delta, 0.0, 1.0)
	_spring.spring_length = lerp(_spring.spring_length, _target_arm_length, t)

	# 6) Camera bobbing
	_apply_camera_bob(delta)
	
	# 7) Prints
	if Input.is_action_just_pressed("check"):
		#print(Requests.total_completed)
		print(WorldState._flags)
		
	# 8) Controller input searching
	_apply_controller_look(delta)
	
	# 9) Animations 
	var trying_to_move := input_vec.length() > 0.01
	var h_speed = Vector2(velocity.x, velocity.z).length()
	#debug.text = str(Engine.get_frames_per_second())
	

	var on_floor_now := is_on_floor()
	var just_landed := (not _was_on_floor) and on_floor_now
	_was_on_floor = on_floor_now

	if not controls_enabled:
		_landing = false
		anim.play("idle")

	elif not on_floor_now:
		_landing = false
		anim.play("jump")

	else:
		# If we just landed, play land once
		if just_landed:
			_landing = true
			anim.play("land")

		# While landing anim is playing, don't override it
		elif _landing:
			# When land finishes, go back to idle/walk
			if not anim.is_playing() or anim.current_animation != "land":
				_landing = false
			elif anim.current_animation_position >= anim.current_animation_length - 0.001:
				_landing = false

			# If still landing, do nothing (keep "land")
			if _landing:
				pass
			else:
				anim.play("walk" if h_speed >= 1.0 else "idle")

		else:
			anim.play("walk" if h_speed >= 1.0 else "idle")

	
	# 10) Sprite Flipping
	if controls_enabled:
		if Input.is_action_just_pressed("move_left"):
			sprite.flip_h = true
		if Input.is_action_just_pressed("move_right"):
			sprite.flip_h = false


func set_camera_zoom_target(target_length: float, speed: float = -1.0) -> void:
	# Optional per-area override of zoom speed
	if speed > 0.0:
		arm_lerp_speed = speed

	_target_arm_length = clamp(target_length, min_arm_length, max_arm_length)


func restore_default_zoom(speed: float = -1.0) -> void:
	# Called by zoom areas when you leave them
	if speed > 0.0:
		arm_lerp_speed = speed

	_target_arm_length = _default_arm_length

func _apply_camera_bob(delta: float) -> void:
	if not camera_bob_enabled:
		# Smoothly return pivot to base position if disabled at runtime
		_pivot.position.y = lerp(
			_pivot.position.y,
			_pivot_base_y,
			camera_bob_return_speed * delta
		)
		_pivot.position.x = lerp(
			_pivot.position.x,
			_pivot_base_x,
			camera_bob_return_speed * delta
		)
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var should_bob := horizontal_speed > camera_bob_speed_threshold and is_on_floor()

	if should_bob:
		# Advance phase based on frequency and how fast we're moving (normalized by walk_speed)
		var speed_factor = clamp(horizontal_speed / max(walk_speed, 0.01), 0.5, 1.5)
		_bob_phase += camera_bob_frequency * speed_factor * delta

		var y_offset := sin(_bob_phase) * camera_bob_amplitude

		var x_offset := 0.0
		if camera_sway_enabled:
			# Cosine gives a 90° phase offset from the vertical bob
			x_offset = cos(_bob_phase) * camera_sway_amplitude

		_pivot.position.y = _pivot_base_y + y_offset
		_pivot.position.x = _pivot_base_x + x_offset
	else:
		# Reset phase and gently move pivot back to its base position
		_bob_phase = 0.0
		_pivot.position.y = lerp(
			_pivot.position.y,
			_pivot_base_y,
			camera_bob_return_speed * delta
		)
		_pivot.position.x = lerp(
			_pivot.position.x,
			_pivot_base_x,
			camera_bob_return_speed * delta
		)

func _jump_velocity(gravity: float) -> float:
	return sqrt(2.0 * gravity * jump_height)


func _on_dialogue_opened() -> void:
	set_controls_enabled(false)
	anim.play("idle")
	if _using_controller:
		# keep cursor out of sight on controller
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		# mouse users can click choices
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_dialogue_closed() -> void:
	set_controls_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_jump_lock_timer = jump_lock_after_dialogue


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO   # kill momentum immediately

func _apply_controller_look(delta: float) -> void:
	if not controller_look_enabled:
		return

	# Right stick as a vector from actions
	var look_vec := Input.get_vector("look_left", "look_right", "look_up", "look_down")

	# Manual deadzone (extra safety; you can also rely on InputMap deadzone)
	var has_input := look_vec.length() >= controller_look_deadzone

	var desired_vel := Vector2.ZERO

	if has_input:
		# Optional: rescale after deadzone so it still reaches 1.0
		var t = (look_vec.length() - controller_look_deadzone) / max(1.0 - controller_look_deadzone, 0.001)
		look_vec = look_vec.normalized() * clamp(t, 0.0, 1.0)

		# Convert stick to desired angular velocity (radians/sec)
		desired_vel.x = -look_vec.x * controller_look_sensitivity
		var y := look_vec.y
		if controller_invert_y:
			y = -y
		desired_vel.y = -y * controller_look_sensitivity

		# Ease toward stick velocity
		var a = clamp(controller_look_accel * delta, 0.0, 1.0)
		_look_vel = _look_vel.lerp(desired_vel, a)
	else:
		# Ease toward stop (inertia)
		var d = clamp(controller_look_decel * delta, 0.0, 1.0)
		_look_vel = _look_vel.lerp(Vector2.ZERO, d)

	# Apply angular velocity (continue even after release, briefly)
	_yaw += _look_vel.x * delta
	_pitch += _look_vel.y * delta

	# Clamp pitch
	var min_p := deg_to_rad(min_pitch_deg)
	var max_p := deg_to_rad(max_pitch_deg)
	_pitch = clamp(_pitch, min_p, max_p)

	_apply_pivot_rotation()


func _on_journal_opened() -> void:
	set_controls_enabled(false)
	# Keep mouse visible for UI, or hide if you're fully controller-only
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_journal_closed() -> void:
	set_controls_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
