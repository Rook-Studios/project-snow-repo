extends Area3D
class_name QuestArea

@export var area_id: StringName = &""

func _ready() -> void:
	body_entered.connect(func(b):
		if area_id != StringName() and b is CharacterBody3D:
			EventBus.emit_entered_area(area_id)
	)
