extends Node
class_name StartInteractObjectRequest

@export_group("Request")
@export var request_id: StringName = &""
@export var title: String = ""
@export var notes: String = ""
@export var target_object_id: StringName = &""

@export_group("When")
enum StartMoment { OnTalkStarted, OnTalkFinished }
@export var start_on: StartMoment = StartMoment.OnTalkFinished
@export var only_once: bool = true

var _started := false

func _ready() -> void:
	var npc := get_parent()
	if npc == null:
		return

	var sig := "talk_finished"
	if start_on == StartMoment.OnTalkStarted:
		sig = "talk_started"

	if npc.has_signal(sig):
		npc.connect(sig, Callable(self, "_try_start"))

func _try_start() -> void:
	if only_once and _started:
		return
	if Requests == null:
		return
	if request_id == StringName() or target_object_id == StringName():
		return

	# Don't restart if it already exists (or is already done)
	if Requests.requests.has(request_id):
		_started = true
		return

	Requests.start_interact_object(request_id, title, notes, target_object_id)
	_started = true
