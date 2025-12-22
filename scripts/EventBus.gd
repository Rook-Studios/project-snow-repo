extends Node
class_name Event_Bus

# Generic events
signal talked_to(id: StringName)
signal entered_area(id: StringName)
signal interacted(id: StringName)
signal delivered(to_id: StringName, item_id: StringName)

# Optional: useful for debugging
signal event_debug(name: String, payload: Dictionary)

func emit_talked_to(id: StringName) -> void:
	talked_to.emit(id)
	event_debug.emit("talked_to", {"id": id})

func emit_entered_area(id: StringName) -> void:
	entered_area.emit(id)
	event_debug.emit("entered_area", {"id": id})

func emit_interacted(id: StringName) -> void:
	interacted.emit(id)
	event_debug.emit("interacted", {"id": id})

func emit_delivered(to_id: StringName, item_id: StringName) -> void:
	delivered.emit(to_id, item_id)
	event_debug.emit("delivered", {"to_id": to_id, "item_id": item_id})
