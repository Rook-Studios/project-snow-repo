extends Node
class_name GateByWorldState

enum Mode { Visible, EnableInteraction, EnableArea, EnableNode, RemoveNode } # NEW

@export var required_flag: StringName = &""
@export var required_counter: StringName = &""
@export var counter_at_least: int = 0

@export var mode: Mode = Mode.Visible
@export var target_path: NodePath

var _did_remove := false
@onready var _target: Node = get_node(target_path) if target_path != NodePath() else get_parent()

func _ready() -> void:
	if WorldState == null:
		push_error("WorldState autoload missing")
		return

	_apply()
	WorldState.changed.connect(_on_world_changed)

func _on_world_changed(key: StringName, _value) -> void:
	if key == required_flag or key == required_counter or key == &"__all__":
		_apply()

func _passes() -> bool:
	if required_flag != StringName() and not WorldState.has_flag(required_flag):
		return false
	if required_counter != StringName() and WorldState.get_counter(required_counter) < counter_at_least:
		return false
	return true

func _apply() -> void:
	var ok := _passes()

	match mode:
		Mode.Visible:
			if _target is CanvasItem:
				(_target as CanvasItem).visible = ok
			elif _target is Node3D:
				(_target as Node3D).visible = ok

		Mode.EnableNode:
			_target.process_mode = Node.PROCESS_MODE_INHERIT if ok else Node.PROCESS_MODE_DISABLED

		Mode.EnableInteraction:
			_target.set_process_unhandled_input(ok)

		Mode.EnableArea:
			if _target is Area3D:
				(_target as Area3D).monitoring = ok
				(_target as Area3D).monitorable = ok

		Mode.RemoveNode:
			if ok and not _did_remove:
				_did_remove = true
				var to_remove: Node = get_parent()
				if is_instance_valid(to_remove):
					to_remove.queue_free()
				# Usually also remove this component immediately (optional safety):
				if is_instance_valid(self):
					queue_free()
