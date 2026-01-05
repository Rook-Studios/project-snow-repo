# res://scripts/npc/components/StartTalkToNPCRequest.gd
extends Node
class_name StartTalkToNPCRequest

@export_group("Request")
@export var request_id: StringName = &""
@export var title: String = ""
@export var notes: String = ""

@export_group("Target NPC")
@export var target_npc_id: StringName = &""

@export_group("When")
@export var start_on: StartMoment = StartMoment.OnTalkFinished
@export var only_once: bool = true

enum StartMoment { OnTalkStarted, OnTalkFinished }

var _started := false

func _ready() -> void:
	var npc := get_parent()
	if npc == null:
		return

	if start_on == StartMoment.OnTalkStarted:
		if npc.has_signal("talk_started"):
			npc.connect("talk_started", Callable(self, "_try_start"))
	else:
		if npc.has_signal("talk_finished"):
			npc.connect("talk_finished", Callable(self, "_try_start"))

func _try_start() -> void:
	if only_once and _started:
		return
	if Requests == null:
		return
	if request_id == StringName():
		return
	if target_npc_id == StringName():
		return

	# Don't restart if it already exists (or is already done).
	if Requests.requests.has(request_id):
		_started = true
		return

	Requests.start_talk_to(request_id, title, notes, target_npc_id)
	_started = true
