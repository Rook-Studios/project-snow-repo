# res://scripts/autoload/WorldState.gd
extends Node

## Emits whenever anything changes (useful for debug UI, journal refresh, etc.)
signal changed(key: StringName, value)

## Internal storage
var _flags: Dictionary = {}     # StringName -> bool
var _counters: Dictionary = {}  # StringName -> int
var _values: Dictionary = {}    # StringName -> Variant


# -----------------
# Flags (true/false)
# -----------------

func set_flag(id: StringName, value: bool = true) -> void:
	if id == StringName():
		return
	_flags[id] = value
	changed.emit(id, value)

func clear_flag(id: StringName) -> void:
	if id == StringName():
		return
	if _flags.erase(id):
		changed.emit(id, false)

func has_flag(id: StringName) -> bool:
	if id == StringName():
		return false
	return bool(_flags.get(id, false))


# -----------------
# Counters (integers)
# -----------------

func set_counter(id: StringName, value: int) -> void:
	if id == StringName():
		return
	_counters[id] = value
	changed.emit(id, value)

func get_counter(id: StringName) -> int:
	if id == StringName():
		return 0
	return int(_counters.get(id, 0))

func inc_counter(id: StringName, by: int = 1) -> int:
	if id == StringName():
		return 0
	var v := int(_counters.get(id, 0)) + by
	_counters[id] = v
	changed.emit(id, v)
	return v


# -----------------
# Values (any Variant)
# -----------------

func set_value(id: StringName, value) -> void:
	if id == StringName():
		return
	_values[id] = value
	changed.emit(id, value)

func get_value(id: StringName, default_value = null):
	if id == StringName():
		return default_value
	return _values.get(id, default_value)

func erase_value(id: StringName) -> void:
	if id == StringName():
		return
	if _values.erase(id):
		changed.emit(id, null)


# -----------------
# Debug / Save helpers
# -----------------

func dump() -> Dictionary:
	# Returns a copy so outside code can’t mutate internal dictionaries accidentally.
	return {
		"flags": _flags.duplicate(true),
		"counters": _counters.duplicate(true),
		"values": _values.duplicate(true),
	}

func apply_dump(data: Dictionary) -> void:
	# For future save/load (optional).
	_flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	_counters = (data.get("counters", {}) as Dictionary).duplicate(true)
	_values = (data.get("values", {}) as Dictionary).duplicate(true)
	changed.emit(&"__all__", null)

func reset_all() -> void:
	_flags.clear()
	_counters.clear()
	_values.clear()
	changed.emit(&"__all__", null)
