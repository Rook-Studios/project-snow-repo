extends Resource
class_name Dialogue
@export var start_node: StringName = "start"
# nodes: { id: {"text": String, "require_day": int?, "choices": [ {...} ] } }
@export var nodes: Dictionary = {}
