# res://scripts/requests/components/StartDeliveryRequest.gd
extends Node
class_name StartDeliveryRequest

@export_group("Request")
@export var request_id: StringName = &""
@export var title: String = ""
@export var notes: String = ""

@export_group("Delivery")
@export var deliver_to_npc_id: StringName = &""
@export var item_id: StringName = &""

@export_group("Start timing")
@export var start_on_talk_finished: bool = true
@export var start_on_talk_started: bool = false

@export_group("Flow")
@export var prevent_same_talk_completion: bool = true

var _started := false

func _ready() -> void:
	var npc := get_parent()
	if npc == null:
		return

	if start_on_talk_started and npc.has_signal("talk_started"):
		if not npc.is_connected("talk_started", Callable(self, "_on_parent_talk_started")):
			npc.connect("talk_started", Callable(self, "_on_parent_talk_started"))

	if start_on_talk_finished and npc.has_signal("talk_finished"):
		if not npc.is_connected("talk_finished", Callable(self, "_on_parent_talk_finished")):
			npc.connect("talk_finished", Callable(self, "_on_parent_talk_finished"))

func _on_parent_talk_started() -> void:
	start_request()

func _on_parent_talk_finished() -> void:
	start_request()

func start_request() -> void:
	if _started:
		return
	if Requests == null:
		push_error("StartDeliveryRequest: Requests autoload missing")
		return
	if request_id == StringName():
		push_error("StartDeliveryRequest: request_id is empty")
		return
	if deliver_to_npc_id == StringName() or item_id == StringName():
		push_error("StartDeliveryRequest: deliver_to_npc_id and item_id must be set")
		return

	# Don't restart if already present (active or done)
	if Requests.requests.has(request_id):
		_started = true
		return

	Requests.start_delivery(request_id, title, notes, deliver_to_npc_id, item_id)
	_started = true
	
	if prevent_same_talk_completion and WorldState != null:
		# Mark this request as "started this conversation" so it can't be delivered immediately.
		WorldState.set_flag(StringName("delivery_started_this_talk_" + String(request_id)), true)
