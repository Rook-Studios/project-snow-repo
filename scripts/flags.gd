extends Node

signal flag_changed(name: StringName, value)

var _flags: Dictionary = {}

func set_true(name: StringName) -> void:
	if name == StringName(): return
	_flags[name] = true
	flag_changed.emit(name, true)

func set_false(name: StringName) -> void:
	if name == StringName(): return
	_flags[name] = false
	flag_changed.emit(name, false)

func is_true(name: StringName) -> bool:
	return bool(_flags.get(name, false))

func set_flag(name: StringName, value) -> void:
	if name == StringName(): return
	_flags[name] = value
	flag_changed.emit(name, value)

func get_value(name: StringName, default_value = null):
	return _flags.get(name, default_value)

func inc(name: StringName, by: int = 1) -> int:
	var v: int = int(_flags.get(name, 0))
	v += by
	_flags[name] = v
	flag_changed.emit(name, v)
	return v
