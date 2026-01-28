extends CanvasLayer

signal opened
signal closed
signal choice_selected(line_index: int, choice_index: int)

@onready var _panel: Panel = $Panel
@onready var _line: RichTextLabel = $Panel/MarginContainer/VBoxContainer/LineLabel
@onready var _name: RichTextLabel = $Panel/NamePanel/HBoxContainer/NameLabel
@onready var _voice: AudioStreamPlayer = $VoicePlayer
@onready var _choices: HBoxContainer = $Panel/ChoicesPanel/ChoicesBox
@onready var choices_panel: Control = $Panel/ChoicesPanel
@onready var _name_panel: Control = $Panel/NamePanel

var _default_side: String = "left"
var _current_side: String = "left"


var _open := false
var _just_opened := false
var _default_speaker: String = ""
var _current_speaker: String = ""


# --- Typewriter settings ---
@export var chars_per_second: float = 40.0
@export var blip_every_n_chars: int = 2
@export var ignore_space_for_blip: bool = true  # (note: with BBCode we just do cadence; see comment below)

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
var _full_text_bbcode: String = ""
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
	choices_panel.visible = false
	_choices.visible = false
	# Ensure RichTextLabel is set up for formatting/word wrap
	_line.bbcode_enabled = true
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	_line.scroll_active = false
	
	_apply_name_side(_default_side)

	add_to_group("DialogueUI")

func set_speaker_name(name_text: String) -> void:
	_name.text = name_text
	_current_speaker = name_text
	_default_speaker = name_text

	# default side for NPC lines unless overridden by tags
	_current_side = _default_side
	_apply_name_side(_current_side)



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

# --- Typewriter core (RichTextLabel + visible_characters) ---
func _start_typing(text_bbcode: String) -> void:
	var parsed := _extract_line_tags(text_bbcode)

	# speaker
	if parsed.speaker != "":
		_current_speaker = parsed.speaker
		_name.text = _current_speaker

	# side
	if parsed.side != "":
		_current_side = parsed.side
		_apply_name_side(_current_side)

	text_bbcode = parsed.text

	_full_text_bbcode = _prewrap_bbcode(text_bbcode)

	_line.visible_characters = 0
	_line.clear()
	_line.append_text(_full_text_bbcode)

	_char_accum = 0.0
	_blip_counter = 0
	_typing = true


func _prewrap_bbcode(bbcode: String) -> String:
	# If the label has no width yet, don't attempt wrapping.
	var max_width := _line.size.x
	if max_width <= 1.0:
		return bbcode

	var font := _line.get_theme_font(&"normal_font")
	var font_size := _line.get_theme_font_size(&"normal_font_size")
	if font == null or font_size <= 0:
		return bbcode

	# Use parsed (plain) text for measuring, but insert breaks back into BBCode.
	var plain := _strip_bbcode(bbcode)

	# Compute where line breaks should go in "visible character indices".
	var break_indices := _compute_wrap_breaks(plain, max_width, font, font_size)
	if break_indices.is_empty():
		return bbcode

	# Insert '\n' into the BBCode string at those visible-character indices,
	# counting only "visible" characters (ignore tags like [b], [/color], etc).
	return _insert_breaks_into_bbcode(bbcode, break_indices)


func _strip_bbcode(s: String) -> String:
	# Minimal BBCode stripper good enough for measurement.
	# Removes [tags] but leaves the displayed text.
	var out := ""
	var in_tag := false
	for i in s.length():
		var ch := s[i]
		if ch == "[":
			in_tag = true
			continue
		if ch == "]" and in_tag:
			in_tag = false
			continue
		if not in_tag:
			out += ch
	return out


func _compute_wrap_breaks(text: String, max_width: float, font: Font, font_size: int) -> Array[int]:
	# Returns an array of visible character indices where we should insert '\n'
	# (indices are in terms of the plain text, not BBCode source).
	var breaks: Array[int] = []

	# Preserve explicit newlines if you already authored them.
	var paragraphs := text.split("\n", false)

	var global_index := 0
	for p in paragraphs:
		var words := p.split(" ", false)

		var line := ""
		var line_start_index := global_index

		for w_i in range(words.size()):
			var word := words[w_i]
			var candidate := (word if line == "" else (line + " " + word))

			if _text_width(candidate, font, font_size) <= max_width:
				line = candidate
			else:
				# If the word itself doesn't fit on an empty line, we can't fix that without hyphenation.
				# In that case, just start a new line and accept the overflow.
				if line != "":
					# Insert a break before this word (i.e. at current global index position).
					var break_at := line_start_index + line.length()
					breaks.append(break_at)

					# New line starts after the space we would have added.
					line_start_index = break_at + 1
					line = word
				else:
					# Word too long even for empty line: keep it.
					line = word

		# Move global index forward for this paragraph + newline
		global_index += p.length()
		# Account for the '\n' we split on (except after last paragraph)
		if paragraphs.size() > 1:
			global_index += 1

	return breaks


func _text_width(s: String, font: Font, font_size: int) -> float:
	var tl := TextLine.new()
	tl.add_string(s, font, font_size)
	return tl.get_line_width()


func _insert_breaks_into_bbcode(bbcode: String, break_indices: Array[int]) -> String:
	# break_indices are sorted insertion points in the *plain text character stream*
	break_indices.sort()

	var out := ""
	var visible_idx := 0
	var break_ptr := 0
	var in_tag := false

	for i in bbcode.length():
		var ch := bbcode[i]

		if ch == "[":
			in_tag = true
			out += ch
			continue

		if in_tag:
			out += ch
			if ch == "]":
				in_tag = false
			continue

		# Before adding this visible char, insert any pending breaks at this index
		while break_ptr < break_indices.size() and visible_idx == break_indices[break_ptr]:
			out += "\n"
			break_ptr += 1

		out += ch
		visible_idx += 1

	# If a break is at the end, apply it
	while break_ptr < break_indices.size() and visible_idx == break_indices[break_ptr]:
		out += "\n"
		break_ptr += 1

	return out


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

	# pick cps based on fast mode
	var cps := fast_mode_chars_per_second if _fast_mode else chars_per_second

	_char_accum += cps * delta
	var chars_to_add := int(_char_accum)
	if chars_to_add <= 0:
		return
	_char_accum -= float(chars_to_add)

	var prev_visible := _line.visible_characters
	var total := _line.get_total_character_count()  # excludes BBCode tags
	var new_visible = min(prev_visible + chars_to_add, total)
	_line.visible_characters = new_visible

	# Voice blips cadence based on added visible chars
	# Note: Ignoring spaces with BBCode is non-trivial; we use cadence here.
	var added = new_visible - prev_visible
	if added > 0 and _voice_enabled:
		for i in range(added):
			_blip_counter += 1
			if (_blip_counter % _voice_blip_every) == 0:
				_voice.pitch_scale = randf_range(_pitch_min, _pitch_max)
				_voice.play()

	# Finished this line?
	if new_visible >= total:
		_typing = false
		# auto-advance if fast mode is still held (choices will pause progression)
		if _fast_mode and fast_mode_auto_advance and not choices_panel.visible and not _choices.visible:
			_advance_or_close()

# --- Advance / choices ---
func _advance_or_close() -> void:
	if not _open:
		return

	if _typing:
		# snap to end of current line
		_line.visible_characters = _line.get_total_character_count()
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
		b.focus_mode = Control.FOCUS_ALL
		var idx := i
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

func _extract_speaker_tag(line: String) -> Dictionary:
	# Format: {speaker=Name} rest of line...
	# Safe with BBCode because we use curly braces.
	var s := line.strip_edges()
	if not s.begins_with("{speaker="):
		return {"text": line}

	var end := s.find("}")
	if end == -1:
		return {"text": line} # malformed, ignore

	var header := s.substr(0, end + 1) # "{speaker=Name}"
	var name := header.replace("{speaker=", "").replace("}", "").strip_edges()
	var rest := s.substr(end + 1, s.length() - (end + 1)).strip_edges()

	return {"speaker": name, "text": rest}

func _extract_line_tags(line: String) -> Dictionary:
	# Supports prefixes like:
	# {speaker=Name}{side=left} Hello
	# {side=right}{speaker=Player} Hi
	var s := line.strip_edges()

	var speaker := ""
	var side := ""
	var changed := true

	while changed and s.begins_with("{"):
		changed = false
		var end := s.find("}")
		if end == -1:
			break

		var header := s.substr(0, end + 1) # "{...}"
		var body := header.substr(1, header.length() - 2) # "speaker=Name"
		var eq := body.find("=")
		if eq == -1:
			break

		var key := body.substr(0, eq).strip_edges()
		var val := body.substr(eq + 1).strip_edges()

		if key == "speaker":
			speaker = val
			changed = true
		elif key == "side":
			# normalize
			val = val.to_lower()
			if val == "left" or val == "right":
				side = val
				changed = true

		if changed:
			s = s.substr(end + 1, s.length() - (end + 1)).strip_edges()

	return {
		"speaker": speaker,
		"side": side,
		"text": s
	}

func _apply_name_side(side: String) -> void:
	if _name_panel == null:
		return

	# Use editor-defined width (Custom Minimum Size X) as the source of truth.
	var w := _name_panel.custom_minimum_size.x
	if w <= 0.0:
		w = 1.0 # fallback if you didn't set a min size

	if side == "right":
		_name_panel.anchor_left = 1.0
		_name_panel.anchor_right = 1.0
		_name_panel.offset_left = -w
		_name_panel.offset_right = 0.0
	else:
		_name_panel.anchor_left = 0.0
		_name_panel.anchor_right = 0.0
		_name_panel.offset_left = 0.0
		_name_panel.offset_right = w

	# Optional: force a layout refresh next frame (helps if it "pops" late)
	_name_panel.call_deferred("queue_redraw")
