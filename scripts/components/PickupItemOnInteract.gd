# res://scripts/world/components/PickupItemOnInteract.gd
extends Node
class_name PickupItemOnInteract

@export_group("Pickup Source")
@export var object_id: StringName = &""   # must match InteractableEmitter.object_id

@export_group("Item")
@export var item_id: StringName = &""
@export var pick_up_once: bool = true
@export var remove_node_on_pickup: bool = false

@export_group("WorldState Keys")
@export var item_flag_prefix: String = "item_"  # results in flags like "item_bucket"

func _ready() -> void:
	if EventBus == null:
		push_error("PickupItemOnInteract: EventBus autoload missing")
		return
	EventBus.interacted.connect(_on_interacted)

func _item_flag(id: StringName) -> StringName:
	return StringName(item_flag_prefix + String(id))

func _on_interacted(id: StringName) -> void:
	if object_id == StringName() or item_id == StringName():
		return
	if id != object_id:
		return
	if WorldState == null:
		return

	var flag := _item_flag(item_id)

	if pick_up_once and WorldState.has_flag(flag):
		return

	WorldState.set_flag(flag, true)

	# Optional: remove the pickup object from the world after pickup
	if remove_node_on_pickup:
		var to_remove := get_parent()
		if is_instance_valid(to_remove):
			to_remove.queue_free()
