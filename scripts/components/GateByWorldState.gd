extends Node
class_name GateByWorldState

enum Mode { Visible, EnableInteraction, EnableArea, EnableNode, RemoveNode } # NEW

@export var required_flag: StringName = &""
@export var required_counter: StringName = &""
@export var counter_at_least: int = 0

@export var mode: Mode = Mode.Visible
@export var target_path: NodePath

@export var visible_disables_collision: bool = true
@export var visible_disables_areas: bool = true # disables Area3D monitoring when hidden


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

			# Defer collision/area toggles to avoid physics refresh issues
			if visible_disables_collision:
				call_deferred("_set_collisions_enabled", _target, ok)
			if visible_disables_areas:
				call_deferred("_set_areas_enabled", _target, ok)



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

func _set_collisions_enabled(root: Node, enabled: bool) -> void:
	# Handle the root itself if it is a collision node
	if root is CollisionShape3D:
		(root as CollisionShape3D).set_deferred("disabled", not enabled)
	elif root is CollisionPolygon3D:
		(root as CollisionPolygon3D).set_deferred("disabled", not enabled)

	# Then recurse children
	for c in root.get_children():
		_set_collisions_enabled(c, enabled)


func _set_areas_enabled(root: Node, enabled: bool) -> void:
	# Handle the root itself if it is an Area3D
	if root is Area3D:
		var a := root as Area3D
		# Defer so physics updates cleanly
		a.set_deferred("monitoring", enabled)
		a.set_deferred("monitorable", enabled)

	# Then recurse children
	for c in root.get_children():
		_set_areas_enabled(c, enabled)
