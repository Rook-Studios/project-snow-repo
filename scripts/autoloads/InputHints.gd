extends Node
class_name Input_Hints

signal scheme_changed(is_controller: bool)

var using_controller: bool = false

func _input(event: InputEvent) -> void:
	# Detect last meaningful device
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_set_controller(true)
	elif event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_set_controller(false)

func _set_controller(v: bool) -> void:
	if using_controller == v:
		return
	using_controller = v
	scheme_changed.emit(using_controller)

func hint_for_interact() -> String:
	# You can expand this later for other actions
	return "[A] Talk" if using_controller else "[E] Talk"

func hint_for_action(action_name: StringName, kb: String, pad: String) -> String:
	return pad if using_controller else kb
