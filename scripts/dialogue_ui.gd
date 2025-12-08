extends CanvasLayer

signal opened
signal closed

@onready var _panel: Panel = $Panel
@onready var _line: Label = $Panel/MarginContainer/LineLabel

var _open := false
var _just_opened := false

func _ready() -> void:
	_panel.visible = false



func show_line(text: String) -> void:
	_line.text = text
	_panel.visible = true
	_open = true
	_just_opened = true      # <-- block closing for this event/frame
	emit_signal("opened")

func hide_dialogue() -> void:
	_panel.visible = false
	_open = false
	emit_signal("closed")

func is_open() -> bool:
	return _open

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if _just_opened:
		# Clear the guard after this event so the next press can close
		_just_opened = false
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		hide_dialogue()
