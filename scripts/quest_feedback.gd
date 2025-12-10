extends CanvasLayer

@onready var _sfx: AudioStreamPlayer = $Sfx
@onready var _toast: Label = $Toast

@export var fade_in_time: float = 0.25
@export var hold_time: float = 1.2
@export var fade_out_time: float = 0.4
@export var use_pop_scale: bool = false    # small scale pop on show
@export var use_slide: bool = false        # slide up a few pixels on show
@export var slide_pixels: float = 12.0

var _tween: Tween
var _toast_base_pos: Vector2
var _toast_base_scale: Vector2

func _ready() -> void:
	QuestManager.quest_completed.connect(_on_quest_completed)
	_toast.visible = false
	_toast_base_pos = _toast.position
	_toast_base_scale = _toast.scale

func _on_quest_completed(name: StringName) -> void:
	# Sound
	if _sfx.stream:
		_sfx.play()

	# If a previous animation is running, kill it cleanly.
	if _tween and _tween.is_valid():
		_tween.kill()

	# Prepare toast
	_toast.text = "%s completed!" % QuestManager.title(name)
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.scale = _toast_base_scale
	_toast.position = _toast_base_pos

	if use_pop_scale:
		_toast.scale = _toast_base_scale * 0.96
	if use_slide:
		_toast.position = _toast_base_pos + Vector2(0, slide_pixels)

	# Animate: fade-in -> hold -> fade-out
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Fade in
	_tween.tween_property(_toast, "modulate:a", 1.0, fade_in_time)
	if use_pop_scale:
		_tween.parallel().tween_property(_toast, "scale", _toast_base_scale, fade_in_time)
	if use_slide:
		_tween.parallel().tween_property(_toast, "position", _toast_base_pos, fade_in_time)

	# Hold
	_tween.tween_interval(hold_time)

	# Fade out
	_tween.tween_property(_toast, "modulate:a", 0.0, fade_out_time).set_ease(Tween.EASE_IN)

	# Cleanup
	_tween.finished.connect(func():
		_toast.visible = false
		_toast.modulate.a = 1.0
		_toast.scale = _toast_base_scale
		_toast.position = _toast_base_pos)
