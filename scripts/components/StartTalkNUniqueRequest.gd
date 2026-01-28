# res://scripts/requests/components/StartTalkNUniqueRequest.gd
extends Node
class_name StartTalkNUniqueRequest

@export_group("Request")
@export var request_id: StringName = &""
@export var title: String = ""
@export var notes: String = ""
@export_range(1, 999, 1) var need_unique: int = 3

@export_group("Start timing")
@export var start_on_talk_finished: bool = true
@export var start_on_talk_started: bool = false

@export_group("Counting")
@export var count_giver_if_it_makes_sense: bool = false
# If false, the giver will be registered as "already seen" so talking to them later
# won't count toward the unique total.

var _started := false


func _ready() -> void:
	var npc := get_parent()
	if npc == null:
		return

	# Connect using signal names to avoid relying on typed signal properties.
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
		push_error("Requests autoload missing")
		return
	if request_id == StringName():
		push_error("StartTalkNUniqueRequest: request_id is empty")
		return

	# If it's already present (active or done), don't touch it.
	if Requests.requests.has(request_id):
		_started = true
		return

	Requests.start_talk_n_unique(request_id, title, notes, need_unique)
	_started = true

	# Always register the giver as "already seen" so they don't get counted later,
	# unless you explicitly want them to count.
	_register_giver_in_unique(count_giver_if_it_makes_sense)


func _register_giver_in_unique(should_increment: bool) -> void:
	var npc := get_parent()
	if npc == null:
		return

	# Read npc_id safely (works if parent script defines exported var npc_id)
	var giver_val = npc.get("npc_id")
	if giver_val == null:
		return

	var giver_id: StringName = StringName(giver_val)
	if giver_id == StringName():
		return

	var r: Dictionary = Requests.requests.get(request_id, {})
	if r.is_empty():
		return

	var u: Dictionary = r.get("unique", {})
	if u.has(giver_id):
		return

	# Mark giver as already-seen so future talks don't count.
	u[giver_id] = true
	r["unique"] = u

	# Only increment progress if you want the giver to count immediately.
	if should_increment:
		r["count"] = int(r.get("count", 0)) + 1

	Requests.requests[request_id] = r
	Requests.request_updated.emit(request_id)

	# Optional completion if giver counts and finishes it
	if should_increment and int(r["count"]) >= int(r.get("need", 1)):
		Requests._complete(request_id) # If you want, we can expose a public wrapper.
