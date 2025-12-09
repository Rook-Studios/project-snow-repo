extends Node
class_name DialogueManager

signal started(npc_id: StringName)
signal node_changed(text: String, choices: Array[Dictionary]) # each: {"text": String, "index": int}
signal finished(npc_id: StringName)

var _active: bool = false
var _npc_id: StringName = StringName()
var _dialogue: Dialogue
var _node_id: StringName = StringName()

# Per-NPC variables (untyped Dictionary to satisfy GDScript typing rules)
var _vars_by_npc: Dictionary = {}  # e.g. { "mrs_blythe": {"mood":"cozy"} }

func begin(npc_id: StringName, dialogue: Dialogue, start: StringName = &"start") -> void:
	if dialogue == null:
		return
	_active = true
	_npc_id = npc_id
	_dialogue = dialogue
	_node_id = start
	started.emit(npc_id)
	_emit_node()

func choose(index: int) -> void:
	if not _active:
		return

	var node: Dictionary = _get_node(_node_id)
	var raw_choices: Array = node.get("choices", []) as Array
	var filtered: Array[Dictionary] = _filter_choices(raw_choices)

	if index < 0 or index >= filtered.size():
		return

	var ch: Dictionary = filtered[index]

	# Side effects
	if ch.has("set_var"):
		var var_name: StringName = ch["set_var"]
		var var_val: Variant = ch.get("set_value", true)
		if not _vars_by_npc.has(_npc_id):
			_vars_by_npc[_npc_id] = {}
		var npc_vars: Dictionary = _vars_by_npc[_npc_id]
		npc_vars[var_name] = var_val

	var next_id: StringName = StringName(ch.get("next", "END"))
	if String(next_id) == "END":
		_finish()
	else:
		_node_id = next_id
		_emit_node()

func is_active() -> bool:
	return _active

func _finish() -> void:
	var finished_id := _npc_id
	_active = false
	_npc_id = StringName()
	_dialogue = null
	_node_id = StringName()
	finished.emit(finished_id)

func _emit_node() -> void:
	var node: Dictionary = _get_node(_node_id)

	# Optional day gating on node: node["require_day"] = 1..5
	if node.has("require_day"):
		var req_day: int = int(node["require_day"])
		if req_day > 0 and DayMgr.current_day != req_day:  # <-- use autoload name 'DayMgr'
			_finish()
			return

	var text: String = String(node.get("text", ""))
	var filtered: Array[Dictionary] = _filter_choices(node.get("choices", []) as Array)

	var ui_choices: Array[Dictionary] = []
	for i in range(filtered.size()):
		ui_choices.append({
			"text": String(filtered[i].get("text", "")),
			"index": i
		})

	node_changed.emit(text, ui_choices)

func _get_node(id: StringName) -> Dictionary:
	if _dialogue == null:
		return {}
	return _dialogue.nodes.get(id, {}) as Dictionary

func _filter_choices(choices_any: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var npc_vars: Dictionary = _vars_by_npc.get(_npc_id, {}) as Dictionary

	for item in choices_any:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var ch: Dictionary = item as Dictionary
		var ok := true

		if ch.has("require_var"):
			var key: StringName = ch["require_var"]
			ok = npc_vars.has(key)
			if ok and ch.has("require_equals"):
				ok = npc_vars[key] == ch["require_equals"]

		if ok and ch.has("require_day"):
			ok = (int(ch["require_day"]) == DayMgr.current_day)  # <-- use 'Day'

		if ok:
			out.append(ch)

	return out

func advance() -> void:
	if not _active:
		return
	var node: Dictionary = _get_node(_node_id)
	var raw_choices: Array = node.get("choices", []) as Array
	var filtered: Array[Dictionary] = _filter_choices(raw_choices)
	if filtered.is_empty():
		_finish()
	else:
		choose(0)  # default path until we add UI buttons
