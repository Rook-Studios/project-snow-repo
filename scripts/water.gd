# res://scripts/world/WaterVolume.gd
extends Area3D
class_name WaterVolume

@export var water_id: StringName = &"river" # optional, if you later want multiple water types

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(b: Node) -> void:
	if b is CharacterBody3D and b.is_in_group("Player"):
		# call a method on the player if it exists
		if b.has_method("set_in_water"):
			b.call("set_in_water", true, water_id)
		print("area entered")

func _on_body_exited(b: Node) -> void:
	if b is CharacterBody3D and b.is_in_group("Player"):
		if b.has_method("set_in_water"):
			b.call("set_in_water", false, water_id)
