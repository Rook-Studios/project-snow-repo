# res://scripts/npc/components/StartVisitAreaRequest.gd
extends Node
class_name StartVisitAreaRequest

@export_group("Request Triggers")
@export var start_visit_request_id: StringName = &""
@export var start_visit_request_title: String = ""
@export var start_visit_request_notes: String = ""
@export var start_visit_area_id: StringName = &""

@export_group("When")
@export var start_on: StartMoment = StartMoment.OnTalkFinished
@export var only_once: bool = true

enum StartMoment { OnTalkStarted, OnTalkFinished }

var _started := false

func _ready() -> void:
	var npc := get_parent()
	if npc == null:
		return

	# We expect parent to be NPCBase (or compatible) exposing talk_started/talk_finished.
	if start_on == StartMoment.OnTalkStarted:
		if npc.has_signal("talk_started"):
			npc.connect("talk_started", Callable(self, "_try_start"))
	else:
		if npc.has_signal("talk_finished"):
			npc.connect("talk_finished", Callable(self, "_try_start"))

func _try_start() -> void:
	if only_once and _started:
		return
	if start_visit_request_id == StringName():
		return
	if Requests == null:
		return

	#start request if it does not currently exist
	if not Requests.requests.has(start_visit_request_id):
		Requests.start_visit_area(
			start_visit_request_id,
			start_visit_request_title,
			start_visit_request_notes,
			start_visit_area_id
		)

	_started = true
