extends Node
class_name LowResInputForwarder

@export var lowres_viewport_path: NodePath

@onready var lowres_vp: SubViewport = get_node(lowres_viewport_path) as SubViewport

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event: InputEvent) -> void:
	if lowres_vp == null:
		return

	# Forward ALL input events to the SubViewport world
	lowres_vp.push_input(event)
