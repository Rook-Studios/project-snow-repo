# res://scripts/requests/components/DeliverItemOnTalkFinished.gd
extends Node
class_name DeliverItemOnTalkFinished

@export_group("Recipient")
@export var recipient_npc_id: StringName = &""  # usually same as parent NPCBase npc_id
@export var auto_read_parent_npc_id: bool = true

@export_group("Acceptable Items")
@export var acceptable_items: Array[StringName] = []  # if empty, accept ANY item flag found (not recommended)
@export var consume_item_on_delivery: bool = true

@export_group("WorldState Keys")
@export var item_flag_prefix: String = "item_"

func _ready() -> void:
	var npc := get_parent()
	if npc == null:
		return

	if auto_read_parent_npc_id and recipient_npc_id == StringName():
		var v = npc.get("npc_id")
		if v != null:
			recipient_npc_id = StringName(v)

	if recipient_npc_id == StringName():
		push_error("DeliverItemOnTalkFinished: recipient_npc_id not set (and could not read from parent)")
		return

	if npc.has_signal("talk_finished"):
		if not npc.is_connected("talk_finished", Callable(self, "_on_talk_finished")):
			npc.connect("talk_finished", Callable(self, "_on_talk_finished"))

func _item_flag(id: StringName) -> StringName:
	return StringName(item_flag_prefix + String(id))

func _find_matching_delivery_request_id(item_id: StringName) -> StringName:
	if Requests == null:
		return StringName()

	for k in Requests.active_ids():
		var r: Dictionary = Requests.requests.get(k, {})
		if r.is_empty():
			continue
		if int(r.get("type", -1)) != Requests.Type.DELIVERY:
			continue
		if StringName(r.get("target", StringName())) != recipient_npc_id:
			continue
		if StringName(r.get("item", StringName())) != item_id:
			continue

		# If this request was started this same conversation, block it for now.
		if WorldState != null and WorldState.has_flag(_started_this_talk_flag(StringName(k))):
			continue

		return StringName(k)

	return StringName()

func _try_deliver(item_id: StringName) -> void:
	if WorldState == null or EventBus == null:
		return

	var flag := _item_flag(item_id)
	if not WorldState.has_flag(flag):
		return

	var matching_req := _find_matching_delivery_request_id(item_id)
	if matching_req == StringName():
		return

	EventBus.emit_delivered(recipient_npc_id, item_id)

	if consume_item_on_delivery:
		WorldState.clear_flag(flag)

func _on_talk_finished() -> void:
	if recipient_npc_id == StringName():
		return

	# Try delivery as usual
	if acceptable_items.size() > 0:
		for item_id in acceptable_items:
			_try_deliver(item_id)

	# Clear "started this talk" markers for any active delivery requests.
	# (So next conversation can complete them.)
	if WorldState != null and Requests != null:
		for k in Requests.active_ids():
			var r: Dictionary = Requests.requests.get(k, {})
			if int(r.get("type", -1)) == Requests.Type.DELIVERY:
				WorldState.clear_flag(_started_this_talk_flag(StringName(k)))


func _started_this_talk_flag(req_id: StringName) -> StringName:
	return StringName("delivery_started_this_talk_" + String(req_id))
