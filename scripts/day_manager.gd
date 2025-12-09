extends Node
class_name DayManager

signal day_changed(day: int)

var _current_day: int = 1

@export var current_day: int:
	get:
		return _current_day
	set(value):
		var clamped = clamp(value, 1, 5)
		if clamped == _current_day:
			return
		_current_day = clamped
		day_changed.emit(_current_day)
