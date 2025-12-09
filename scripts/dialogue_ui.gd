extends CanvasLayer

signal opened
signal closed
signal choice_selected(line_index: int, choice_index: int)

@onready var _panel: Panel = $Panel
@onready var _line: Label = $Panel/MarginContainer/VBoxContainer/LineLabel
@onready var _name: Label = $Panel/NamePanel/HBoxContainer/NameLabel
@onready var _voice: AudioStreamPlayer = $VoicePlayer
@onready var _choices: HBoxContainer = $Panel/ChoicesPanel/ChoicesBox
@onready var choices_panel: Control = $Panel/ChoicesPanel

var _open := false
var _just_opened := false

# --- Typewriter settings ---
@export var chars_per_second: float = 40.0
@export var blip_every_n_chars: int = 2
@export var ignore_space_for_blip: bool = true

# --- UX: fast-forward ---
@export_category("UX")
@export var fast_mode_action: StringName = &"dialogue_fast"
@export var fast_mode_chars_per_second: float = 1000.0
@export var fast_mode_auto_advance: bool = true
var _fast_mode: bool = false

# --- runtime typing state ---
var _lines: Array[String] = []
var _idx: int = 0
var _typing: bool = false
var _full_text: String = ""
var _typed_text: String = ""
var _char_accum: float = 0.0
var _blip_counter: int = 0

# --- voice settings (per NPC) ---
var _voice_enabled := false
var _pitch_min := 0.95
var _pitch_max := 1.05
var _voice_blip_every := 2

# --- Choice state ---
var _pending_choices: Array[String] = []
var _choice_line_index: int = -1
var _choice_shown: bool = false

func _ready() -> void:
	_panel.visible = false
	_choices.visible = false
	choices_panel.visible = false
	add_to_group("DialogueUI")

# Public API
func set_speaker_name(name_text: String) -> void:
	_name.text = name_text

func set_voice(stream: AudioStream, pitch_min: float = 0.95, pitch_max: float = 1.05, blip_every: int = 2) -> void:
	_voice.stream = stream
	_voice_enabled = stream != null
	_pitch_min = pitch_min
	_pitch_max = max(pitch_min, pitch_max)
	_voice_blip_every = max(1, blip_every)

func show_line(text: String) -> void:
	show_lines([text])

func show_lines(lines: Array[String]) -> void:
	_clear_choices_ui()
	_pending_choices.clear()
	_choice_line_index = -1
	_choice_shown = false

	_lines = lines.duplicate()
	_idx = 0
	if _lines.is_empty():
		return
	_panel.visible = true
	_open = true
	_just_opened = true
	_start_typing(_lines[_idx])
	emit_signal("opened")

# schedule choices after a specific line index (0-based)
func show_lines_with_choice_at(lines: Array[String], after_line_index: int, choices: Array[String]) -> void:
	show_lines(lines) # reset/open first
	_pending_choices = choices.duplicate()
	_choice_line_index = after_line_index
	_choice_shown = false

func hide_dialogue() -> void:
	_panel.visible = false
	_open = false
	_lines.clear()
	_typing = false
	_clear_choices_ui()
	emit_signal("closed")

func is_open() -> bool:
	return _open

# --- Typewriter core ---
func _start_typing(text: String) -> void:
	_full_text = text
	_typed_text = ""
	_line.text = ""
	_char_accum = 0.0
	_blip_counter = 0
	_typing = true

func _process(delta: float) -> void:
	if not _open:
		return

	# fast mode while key held
	_fast_mode = Input.is_action_pressed(fast_mode_action)

	# auto-advance through finished lines while fast mode is held (unless choices are visible)
	if not _typing and _fast_mode and fast_mode_auto_advance and not choices_panel.visible and not _choices.visible:
		_advance_or_close()
		return

	if not _typing:
		return

	var cps := fast_mode_chars_per_second if _fast_mode else chars_per_second

	_char_accum += cps * delta
	var chars_to_add := int(_char_accum)
	if chars_to_add <= 0:
		return
	_char_accum -= float(chars_to_add)

	var start_idx := _typed_text.length()
	var end_idx = min(start_idx + chars_to_add, _full_text.length())
	_typed_text = _full_text.substr(0, end_idx)
	_line.text = _typed_text

	# blips for new characters
	for i in range(start_idx, end_idx):
		var c := _full_text[i]
		if ignore_space_for_blip and (c == " " or c == "\n" or c == "." or c == "," or c == "!" or c == "?"):
			continue
		_blip_counter += 1
		if _voice_enabled and (_blip_counter % _voice_blip_every == 0):
			_voice.pitch_scale = randf_range(_pitch_min, _pitch_max)
			_voice.play()

	if _typed_text == _full_text:
		_typing = false
		# if we just finished a line in fast mode, auto-advance right away (choices will still interrupt correctly)
		if _fast_mode and fast_mode_auto_advance and not choices_panel.visible and not _choices.visible:
			_advance_or_close()

# --- Advance / choices ---
func _advance_or_close() -> void:
	if not _open:
		return

	if _typing:
		_typed_text = _full_text
		_line.text = _full_text
		_typing = false
		return

	# show scheduled choices for this line (before advancing)
	if _pending_choices.size() > 0 and _choice_line_index == _idx and not _choice_shown:
		_show_choices_for_current_line()
		return

	# next line or close
	_idx += 1
	if _idx >= _lines.size():
		hide_dialogue()
	else:
		_start_typing(_lines[_idx])

func _show_choices_for_current_line() -> void:
	_choice_shown = true
	choices_panel.visible = true
	_choices.visible = true

	# rebuild buttons
	for c in _choices.get_children():
		c.queue_free()

	for i in range(_pending_choices.size()):
		var b := Button.new()
		b.text = _pending_choices[i]
		var idx := i
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func():
			_choices.visible = false
			choices_panel.visible = false
			emit_signal("choice_selected", _idx, idx)
			# reset choice state
			_pending_choices.clear()
			_choice_line_index = -1
			_choice_shown = false
			# do not close here; NPC will immediately call show_lines(follow)
		)
		_choices.add_child(b)

	await get_tree().process_frame
	if _choices.get_child_count() > 0 and _choices.get_child(0) is Control:
		(_choices.get_child(0) as Control).grab_focus()

func _clear_choices_ui() -> void:
	_choices.visible = false
	choices_panel.visible = false
	for c in _choices.get_children():
		c.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	# while choices are visible, ignore E so the player chooses with buttons
	if choices_panel.visible or _choices.visible:
		return
	if _just_opened:
		_just_opened = false
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		_advance_or_close()
