extends Node3D

@export var display_name: String = "Villager"
@export_multiline var intro_line: String = "Morning! Lovely winter day, isn't it?"
@export var intro_lines: Array[String] = []

# Optional voice for this NPC
@export var voice_stream: AudioStream
@export var voice_pitch_min: float = 0.95
@export var voice_pitch_max: float = 1.05
@export var voice_blip_every: int = 2

# --- First question (Stage 0 -> 1 -> 2) ---
@export var choice_at_line_index: int = -1
@export var choice_labels: Array[String] = []
@export var followup_choice0: Array[String] = []
@export var followup_choice1: Array[String] = []
@export var followup_choice2: Array[String] = []
@export var shared_tail_lines: Array[String] = []   # plays after the first follow-up

# --- Second question (Stage 3 -> 4 -> 5) ---
@export var question2_lines: Array[String] = []                 # lines leading up to the second choice
@export var question2_choice_at_line_index: int = -1
@export var question2_choice_labels: Array[String] = []
@export var question2_followup_choice0: Array[String] = []
@export var question2_followup_choice1: Array[String] = []
@export var question2_followup_choice2: Array[String] = []
@export var final_tail_lines: Array[String] = []                # plays after second follow-up

@onready var _zone: Area3D = $InteractZone
@onready var _prompt: Label3D = $Prompt3D

var _player_in_range := false
var _talking := false
var _stage: int = 0
var _last_choice_idx: int = -1

func _ready() -> void:
	_prompt.visible = false
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		_player_in_range = true
		_update_prompt()

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody3D:
		_player_in_range = false
		_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact") and not _talking:
		_start_talk()

func _start_talk() -> void:
	var ui := _find_dialogue_ui()
	if ui == null:
		push_warning("DialogueUI not found in scene.")
		return

	_talking = true
	_stage = 0
	_last_choice_idx = -1
	_update_prompt()

	ui.set_speaker_name(display_name)
	ui.set_voice(voice_stream, voice_pitch_min, voice_pitch_max, voice_blip_every)

	var lines: Array[String] = []
	if intro_line.strip_edges() != "":
		lines.append(intro_line)
	for l in intro_lines:
		lines.append(l)

	if not ui.closed.is_connected(_on_ui_closed):
		ui.closed.connect(_on_ui_closed)

	# First question (optional)
	if choice_at_line_index >= 0 and choice_labels.size() > 0:
		if not ui.choice_selected.is_connected(_on_choice_selected_stage0):
			ui.choice_selected.connect(_on_choice_selected_stage0, CONNECT_ONE_SHOT)
		ui.show_lines_with_choice_at(lines, choice_at_line_index, choice_labels)
	else:
		ui.show_lines(lines)

	get_viewport().set_input_as_handled()

# === Choice handlers ===

func _on_choice_selected_stage0(line_idx: int, choice_idx: int) -> void:
	_last_choice_idx = choice_idx
	_stage = 1
	var ui := _find_dialogue_ui()
	if ui == null:
		_finish_conversation()
		return

	var follow: Array[String] = []
	match choice_idx:
		0: follow = followup_choice0
		1: follow = followup_choice1
		2: follow = followup_choice2
		_: follow = []

	if follow.size() > 0:
		ui.set_speaker_name(display_name)
		ui.show_lines(follow)
	else:
		# No unique follow-up; jump to shared tail
		_stage = 2
		_show_shared_tail_or_advance_to_question2()

func _on_choice_selected_stage2(line_idx: int, choice_idx: int) -> void:
	# (used for the second question)
	_last_choice_idx = choice_idx
	_stage = 4
	var ui := _find_dialogue_ui()
	if ui == null:
		_finish_conversation()
		return

	var follow: Array[String] = []
	match choice_idx:
		0: follow = question2_followup_choice0
		1: follow = question2_followup_choice1
		2: follow = question2_followup_choice2
		_: follow = []

	if follow.size() > 0:
		ui.set_speaker_name(display_name)
		ui.show_lines(follow)
	else:
		# No unique follow-up; jump to final tail
		_stage = 5
		_show_final_tail_or_finish()

# === Close handler: decide the next block ===

func _on_ui_closed() -> void:
	match _stage:
		0:
			# Opening finished (no first choice), end or go to question 2 if configured
			if question2_lines.size() > 0:
				_stage = 3
				_start_question2()
			else:
				_finish_conversation()
		1:
			# First unique follow-up finished -> shared tail
			_stage = 2
			_show_shared_tail_or_advance_to_question2()
		2:
			# Shared tail finished -> either question 2 or finish
			if question2_lines.size() > 0:
				_stage = 3
				_start_question2()
			else:
				_finish_conversation()
		3:
			# Question 2 opening finished (no choice there) -> finish
			_finish_conversation()
		4:
			# Second unique follow-up finished -> final tail
			_stage = 5
			_show_final_tail_or_finish()
		5:
			# Final tail finished -> end
			_finish_conversation()
		_:
			_finish_conversation()

# === Stage transitions ===

func _show_shared_tail_or_advance_to_question2() -> void:
	var ui := _find_dialogue_ui()
	if ui == null:
		_finish_conversation()
		return
	if shared_tail_lines.size() > 0:
		ui.set_speaker_name(display_name)
		ui.show_lines(shared_tail_lines)
	else:
		# No shared tail; go straight to question 2 or finish
		if question2_lines.size() > 0:
			_stage = 3
			_start_question2()
		else:
			_finish_conversation()

func _start_question2() -> void:
	var ui := _find_dialogue_ui()
	if ui == null:
		_finish_conversation()
		return

	ui.set_speaker_name(display_name)
	ui.set_voice(voice_stream, voice_pitch_min, voice_pitch_max, voice_blip_every)

	# Opening lines for second question
	if question2_lines.is_empty():
		_finish_conversation()
		return

	# Connect a fresh one-shot for the second choice if configured
	if question2_choice_at_line_index >= 0 and question2_choice_labels.size() > 0:
		if not ui.choice_selected.is_connected(_on_choice_selected_stage2):
			ui.choice_selected.connect(_on_choice_selected_stage2, CONNECT_ONE_SHOT)
		ui.show_lines_with_choice_at(question2_lines, question2_choice_at_line_index, question2_choice_labels)
	else:
		ui.show_lines(question2_lines)

func _show_final_tail_or_finish() -> void:
	var ui := _find_dialogue_ui()
	if ui == null:
		_finish_conversation()
		return
	if final_tail_lines.size() > 0:
		ui.set_speaker_name(display_name)
		ui.show_lines(final_tail_lines)
	else:
		_finish_conversation()

func _finish_conversation() -> void:
	_talking = false
	_update_prompt()
	# Tidy: disconnect the closed signal so next talk starts cleanly
	var ui := _find_dialogue_ui()
	if ui and ui.closed.is_connected(_on_ui_closed):
		ui.closed.disconnect(_on_ui_closed)

# === Helpers ===

func _find_dialogue_ui() -> Node:
	for n in get_tree().get_nodes_in_group("DialogueUI"):
		return n
	var root := get_tree().current_scene
	return root.get_node_or_null("DialogueUI") if root else null

func _update_prompt() -> void:
	_prompt.visible = _player_in_range and not _talking
