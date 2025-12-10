extends Node
class_name QuestMgr

# Simple lifecycle
enum State { NOT_STARTED, ACTIVE, COMPLETED, FAILED }

# quests[name] = {
#   "state": int,
#   "title": String,
#   "steps": Array[String],   # optional journal entries per step
#   "step": int,              # -1=none, otherwise index into steps
#   "log": Array[String]      # all journal text appended in order
# }
var quests: Dictionary = {}

signal quest_started(name: StringName)
signal quest_advanced(name: StringName, step: int)
signal quest_completed(name: StringName)
signal quest_failed(name: StringName)
signal journal_entry(name: StringName, text: String)

# --- Core helpers ---

func ensure(name: StringName, title: String = "", steps: Array[String] = []) -> void:
	if name == StringName():
		return
	if not quests.has(name):
		quests[name] = {
			"state": State.NOT_STARTED,
			"title": (title if title != "" else String(name)),
			"steps": steps.duplicate(),
			"step": -1,
			"log": []
		}

func start(name: StringName, title: String = "", steps: Array[String] = []) -> void:
	if name == StringName():
		return
	ensure(name, title, steps)
	var q = quests[name]
	if q.state == State.NOT_STARTED:
		q.state = State.ACTIVE
		q.step = (0 if q.steps.size() > 0 else -1)
		quests[name] = q
		quest_started.emit(name)
		# first journal line if steps exist
		if q.step >= 0:
			var text = q.steps[q.step]
			q.log.append(text)
			quests[name] = q
			journal_entry.emit(name, text)

func advance(name: StringName) -> void:
	if not quests.has(name):
		return
	var q = quests[name]
	if q.state != State.ACTIVE:
		return
	if q.steps.size() == 0:
		complete(name)
		return
	q.step += 1
	if q.step >= q.steps.size():
		complete(name)
	else:
		quests[name] = q
		quest_advanced.emit(name, q.step)
		var text = q.steps[q.step]
		q.log.append(text)
		quests[name] = q
		journal_entry.emit(name, text)

func complete(name: StringName) -> void:
	if not quests.has(name):
		return
	var q = quests[name]
	q.state = State.COMPLETED
	quests[name] = q
	quest_completed.emit(name)

func fail(name: StringName) -> void:
	if not quests.has(name):
		return
	var q = quests[name]
	q.state = State.FAILED
	quests[name] = q
	quest_failed.emit(name)

# --- Queries (handy from NPCs/UI) ---

func state(name: StringName) -> int:
	return quests.get(name, {}).get("state", -1)

func is_active(name: StringName) -> bool:
	return state(name) == State.ACTIVE

func is_completed(name: StringName) -> bool:
	return state(name) == State.COMPLETED

func has(name: StringName) -> bool:
	return quests.has(name)

func title(name: StringName) -> String:
	return String(quests.get(name, {}).get("title", String(name)))

func step_index(name: StringName) -> int:
	return int(quests.get(name, {}).get("step", -1))

func step_text(name: StringName) -> String:
	var q = quests.get(name, null)
	if q == null:
		return ""
	var i: int = q.step
	return (q.steps[i] if i >= 0 and i < q.steps.size() else "")

func log(name: StringName) -> Array[String]:
	return (quests.get(name, {}).get("log", []) as Array[String]).duplicate()

# --- Optional: free-form journal note any time ---
func add_note(name: StringName, text: String) -> void:
	if not quests.has(name):
		return
	var q = quests[name]
	q.log.append(text)
	quests[name] = q
	journal_entry.emit(name, text)
