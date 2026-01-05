extends Area3D
class_name QuestArea

@export var area_id: StringName = &""
@export var fire_once: bool = true

var _fired := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(b: Node) -> void:
	if fire_once and _fired:
		return
	if area_id == StringName():
		return
	if b.is_in_group("Player"):
		_fired = true
		EventBus.emit_entered_area(area_id)
