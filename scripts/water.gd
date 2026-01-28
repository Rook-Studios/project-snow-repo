extends Area3D
class_name WaterVolume

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(a: Area3D) -> void:
	if a.is_in_group("PlayerCamera"):
		var player := get_tree().get_first_node_in_group("Player")
		if player and player.has_method("set_camera_in_water"):
			player.call("set_camera_in_water", true)

func _on_area_exited(a: Area3D) -> void:
	if a.is_in_group("PlayerCamera"):
		var player := get_tree().get_first_node_in_group("Player")
		if player and player.has_method("set_camera_in_water"):
			player.call("set_camera_in_water", false)
