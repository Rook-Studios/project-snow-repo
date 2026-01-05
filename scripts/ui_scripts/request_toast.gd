extends CanvasLayer

@onready var panel: Control = $Panel
@onready var label: Label = $Panel/MarginContainer/Label

@export var show_seconds: float = 1.6
@export var fade_seconds: float = 0.25

var _tween: Tween

func _ready() -> void:
	panel.visible = false
	panel.modulate.a = 0.0

	# Listen for completions
	Requests.request_completed.connect(_on_request_completed)

func _on_request_completed(id: StringName) -> void:
	var r: Dictionary = Requests.requests.get(id, {})
	var title := String(r.get("title", String(id)))

	show_toast("%s —  complete!" % title)

func show_toast(text: String) -> void:
	label.text = text

	if _tween and _tween.is_valid():
		_tween.kill()

	panel.visible = true
	panel.modulate.a = 0.0

	_tween = create_tween()
	_tween.tween_property(panel, "modulate:a", 1.0, 0.12)
	_tween.tween_interval(show_seconds)
	_tween.tween_property(panel, "modulate:a", 0.0, fade_seconds)
	_tween.finished.connect(func():
		panel.visible = false
	)
