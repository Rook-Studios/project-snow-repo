extends Node
class_name _Requests

signal request_started(id: StringName)
signal request_updated(id: StringName)
signal request_completed(id: StringName)

signal total_completed_changed(total: int)

enum Type { DELIVERY, TALK_TO, TALK_N_UNIQUE, VISIT_AREA, INTERACT_OBJECT }

# request dict structure (simple on purpose)
# requests[id] = {
#   "id": StringName,
#   "title": String,
#   "type": int,
#   "state": "active"/"done",
#   "target": StringName,        # npc/area/object id (optional)
#   "item": StringName,          # for deliveries (optional)
#   "need": int,                 # for counts
#   "count": int,                # progress counter
#   "unique": Dictionary         # used for TALK_N_UNIQUE
# }
var requests: Dictionary = {}

var total_completed: int = 0

func _ready() -> void:
	# Listen to world events
	EventBus.talked_to.connect(_on_talked_to)
	EventBus.entered_area.connect(_on_entered_area)
	EventBus.interacted.connect(_on_interacted)
	EventBus.delivered.connect(_on_delivered)
	


func start_delivery(id: StringName, title: String, to_npc_id: StringName, item_id: StringName) -> void:
	_start({
		"id": id,
		"title": title,
		"type": Type.DELIVERY,
		"state": "active",
		"target": to_npc_id,
		"item": item_id,
		"need": 1,
		"count": 0,
	})

func start_talk_to(id: StringName, title: String, npc_id: StringName) -> void:
	_start({
		"id": id,
		"title": title,
		"type": Type.TALK_TO,
		"state": "active",
		"target": npc_id,
		"need": 1,
		"count": 0,
	})

func start_talk_n_unique(id: StringName, title: String, n: int) -> void:
	_start({
		"id": id,
		"title": title,
		"type": Type.TALK_N_UNIQUE,
		"state": "active",
		"need": max(1, n),
		"count": 0,
		"unique": {},
	})

func start_visit_area(id: StringName, title: String, area_id: StringName) -> void:
	_start({
		"id": id,
		"title": title,
		"type": Type.VISIT_AREA,
		"state": "active",
		"target": area_id,
		"need": 1,
		"count": 0,
	})

func start_interact_object(id: StringName, title: String, object_id: StringName) -> void:
	_start({
		"id": id,
		"title": title,
		"type": Type.INTERACT_OBJECT,
		"state": "active",
		"target": object_id,
		"need": 1,
		"count": 0,
	})

func _start(d: Dictionary) -> void:
	var id: StringName = d.get("id", StringName())
	if id == StringName():
		return
	# don't restart if already done
	if requests.has(id) and requests[id].get("state") == "done":
		return
	requests[id] = d
	request_started.emit(id)
	request_updated.emit(id)

func is_done(id: StringName) -> bool:
	return requests.has(id) and requests[id].get("state") == "done"

func active_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in requests.keys():
		if requests[k].get("state") == "active":
			out.append(k)
	return out

# --- Event handlers ---
func _on_talked_to(npc_id: StringName) -> void:
	for k in active_ids():
		var r = requests[k]
		match int(r.type):
			Type.TALK_TO:
				if r.target == npc_id:
					_complete(k)
			Type.TALK_N_UNIQUE:
				var u: Dictionary = r.get("unique", {})
				if not u.has(npc_id):
					u[npc_id] = true
					r.unique = u
					r.count = int(r.get("count", 0)) + 1
					requests[k] = r
					request_updated.emit(k)
					if int(r.count) >= int(r.need):
						_complete(k)
			_:
				pass

func _on_entered_area(area_id: StringName) -> void:
	for k in active_ids():
		var r = requests[k]
		if int(r.type) == Type.VISIT_AREA and r.target == area_id:
			_complete(k)

func _on_interacted(object_id: StringName) -> void:
	for k in active_ids():
		var r = requests[k]
		if int(r.type) == Type.INTERACT_OBJECT and r.target == object_id:
			_complete(k)

func _on_delivered(to_id: StringName, item_id: StringName) -> void:
	for k in active_ids():
		var r = requests[k]
		if int(r.type) == Type.DELIVERY and r.target == to_id and r.item == item_id:
			_complete(k)

func _complete(id: StringName) -> void:
	if not requests.has(id):
		return
	var r = requests[id]
	if r.get("state") == "done":
		return

	r.state = "done"
	requests[id] = r

	total_completed += 1
	total_completed_changed.emit(total_completed)

	#  Update state first
	if WorldState != null:
		WorldState.set_flag(id)
		WorldState.inc_counter(&"requests_completed")

	#  Then notify listeners
	request_updated.emit(id)
	request_completed.emit(id)


	
func completed_total() -> int:
	return total_completed
