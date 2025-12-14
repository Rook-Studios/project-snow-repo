extends Node3D

signal talk_started
signal choice_made(line_index: int, choice_index: int)
signal talk_finished

@export var display_name: String = "Villager"
@export_multiline var intro_line: String = "Morning! Lovely winter day, isn't it?"
@export var intro_lines: Array[String] = []

# Extra openings for repeat talks
@export var second_visit_intro_lines: Array[String] = []
@export var third_visit_intro_lines: Array[String] = []
@export var exhausted_lines: Array[String] = []

# Optional voice for this NPC
@export var voice_stream: AudioStream
@export var voice_pitch_min: float = 0.95
@export var voice_pitch_max: float = 1.05
@export var voice_blip_every: int = 2

# --- First question (Stage 0 -> 1 -> 2) ---
@export var first_choice_first_visit_only: bool = true
@export var choice_at_line_index: int = -1
@export var choice_labels: Array[String] = []
@export var followup_choice0: Array[String] = []
@export var followup_choice1: Array[String] = []
@export var followup_choice2: Array[String] = []
@export var shared_tail_lines: Array[String] = []

# --- NEW: First question prereqs / UX ---
@export var first_choice_require_flags_true: Array[StringName] = []
@export var first_choice_require_completed: Array[StringName] = []
@export var first_choice_locked_lines: Array[String] = []  # shown if prereqs NOT met
@export var first_choice_persistent_until_started: bool = false
@export var first_choice_quest_name: StringName = StringName()  # which quest counts as “started”

# --- Second question (Stage 3 -> 4 -> 5) ---
@export var question2_lines: Array[String] = []
@export var second_choice_first_visit_only: bool = true
@export var question2_choice_at_line_index: int = -1
@export var question2_choice_labels: Array[String] = []
@export var question2_followup_choice0: Array[String] = []
@export var question2_followup_choice1: Array[String] = []
@export var question2_followup_choice2: Array[String] = []
@export var final_tail_lines: Array[String] = []

@onready var _zone: Area3D = $InteractZone
@onready var _prompt: Label3D = $Prompt3D

var _player_in_range := false
var _talking := false
var _stage: int = 0
var _last_choice_idx: int = -1
var _times_spoken: int = 0

# Per-talk gate for the second question block
var _allow_question2: bool = false

# remember/restore mouse mode across the conversation
var _prev_mouse_mode := Input.get_mouse_mode()

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


# --- helpers ---
func _build_first_visit_lines() -> Array[String]:
	var lines: Array[String] = []
	if intro_line.strip_edges() != "":
		lines.append(intro_line)
	for l in intro_lines:
		lines.append(l)
	return lines

func _quest_started_or_done(qname: StringName) -> bool:
	if qname == StringName():
		return false
	return QuestManager.is_active(qname) or QuestManager.is_completed(qname)

func _meets_first_prereqs() -> bool:
	# Optional: you may have exported arrays like first_choice_require_flags_true/completed.
	# If you aren't using them yet, simply return true here.
	# If you DO have them, uncomment these lines and add the two export arrays at the top.
	# for f in first_choice_require_flags_true:
	# 	if not Flags.is_true(f): return false
	# for q in first_choice_require_completed:
	# 	if not QuestManager.is_completed(q): return false
	return true


# --- start (replace your _start_talk with this) ---
func _start_talk() -> void:
	var ui := _find_dialogue_ui()
	if ui == null:
		push_warning("DialogueUI not found in scene.")
		return

	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_talking = true
	talk_started.emit()
	_stage = 0
	_last_choice_idx = -1
	_update_prompt()

	ui.set_speaker_name(display_name)
	ui.set_voice(voice_stream, voice_pitch_min, voice_pitch_max, voice_blip_every)

	# Always connect close handler BEFORE showing any lines
	if not ui.closed.is_connected(_on_ui_closed):
		ui.closed.connect(_on_ui_closed)

	# --- decide opening lines & whether we can offer the first choice ---
	var prereqs_ok := _meets_first_prereqs()
	var quest_not_started := false
	# If you’re using first_choice_quest_name + persistence, compute this:
	# quest_not_started = (first_choice_quest_name != StringName()) and (not _quest_started_or_done(first_choice_quest_name))

	# If you keep “locked” lines, choose them when prereqs aren’t met; otherwise use normal openings.
	var opening_lines := _pick_opening_lines()
	# Optionally, if you have locked lines exposed:
	# if not prereqs_ok and first_choice_locked_lines.size() > 0:
	# 	opening_lines = first_choice_locked_lines.duplicate()

	if opening_lines.is_empty():
		_finish_conversation()
		return

	# Compute if we’re allowed to show the FIRST choice this talk.
	# NOTE: If you use “first visit only” and want persistence, add that here.
	var first_choice_allowed_by_visit := (not first_choice_first_visit_only) or (_times_spoken == 0)
	var have_choice_data := (choice_at_line_index >= 0 and choice_labels.size() > 0)
	var can_offer_choice := prereqs_ok and have_choice_data and first_choice_allowed_by_visit
	# If you want persistence (ask again even after first visit), loosen to:
	# var persistent_override := first_choice_persistent_until_started and quest_not_started
	# var can_offer_choice := prereqs_ok and have_choice_data and (first_choice_allowed_by_visit or persistent_override)

	# Per-talk allowance for Q2 (unchanged)
	var exhausted_visit := _is_exhausted_visit()
	_allow_question2 = (not exhausted_visit) and ((not second_choice_first_visit_only) or (_times_spoken == 0))

	# Show lines (with or without scheduling a choice). NO early returns afterward.
	if not exhausted_visit and can_offer_choice:
		if not ui.choice_selected.is_connected(_on_choice_selected_stage0):
			ui.choice_selected.connect(_on_choice_selected_stage0, CONNECT_ONE_SHOT)
		ui.show_lines_with_choice_at(opening_lines, choice_at_line_index, choice_labels)
	else:
		ui.show_lines(opening_lines)

	get_viewport().set_input_as_handled()


# Visit-based opening selection
func _pick_opening_lines() -> Array[String]:
	if _times_spoken == 0:
		var lines: Array[String] = []
		if intro_line.strip_edges() != "":
			lines.append(intro_line)
		for l in intro_lines:
			lines.append(l)
		if not lines.is_empty():
			return lines
	if _times_spoken == 1 and not second_visit_intro_lines.is_empty():
		return second_visit_intro_lines.duplicate()
	if _times_spoken == 2 and not third_visit_intro_lines.is_empty():
		return third_visit_intro_lines.duplicate()
	if not exhausted_lines.is_empty():
		return exhausted_lines.duplicate()
	return ["See you around."]

func _is_exhausted_visit() -> bool:
	if _times_spoken >= 3 and not exhausted_lines.is_empty():
		return true
	if (_times_spoken == 1 and second_visit_intro_lines.is_empty()) \
	or (_times_spoken == 2 and third_visit_intro_lines.is_empty()):
		return not exhausted_lines.is_empty()
	return false

# Choice handlers
func _on_choice_selected_stage0(line_idx: int, choice_idx: int) -> void:
	choice_made.emit(line_idx, choice_idx)

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
		_stage = 2
		_show_shared_tail_or_advance_to_question2()

func _on_choice_selected_stage2(line_idx: int, choice_idx: int) -> void:
	choice_made.emit(line_idx, choice_idx)

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
		_stage = 5
		_show_final_tail_or_finish()

# Close handler: decide next block
func _on_ui_closed() -> void:
	match _stage:
		0:
			if _allow_question2 and question2_lines.size() > 0:
				_stage = 3
				_start_question2()
			else:
				_finish_conversation()
		1:
			_stage = 2
			_show_shared_tail_or_advance_to_question2()
		2:
			if _allow_question2 and question2_lines.size() > 0:
				_stage = 3
				_start_question2()
			else:
				_finish_conversation()
		3:
			_finish_conversation()
		4:
			_stage = 5
			_show_final_tail_or_finish()
		5:
			_finish_conversation()
		_:
			_finish_conversation()

# Stage transitions
func _show_shared_tail_or_advance_to_question2() -> void:
	var ui := _find_dialogue_ui()
	if ui == null:
		_finish_conversation()
		return
	if shared_tail_lines.size() > 0:
		ui.set_speaker_name(display_name)
		ui.show_lines(shared_tail_lines)
	else:
		if _allow_question2 and question2_lines.size() > 0:
			_stage = 3
			_start_question2()
		else:
			_finish_conversation()

func _start_question2() -> void:
	var ui := _find_dialogue_ui()
	if ui == null:
		_finish_conversation()
		return
	if question2_lines.is_empty():
		_finish_conversation()
		return

	# NOTE: you can mirror the same prereq/persistence pattern for question2 if you want.
	ui.set_speaker_name(display_name)
	ui.set_voice(voice_stream, voice_pitch_min, voice_pitch_max, voice_blip_every)

	var q2_choice_allowed := (not second_choice_first_visit_only) or (_times_spoken == 0)

	if q2_choice_allowed and question2_choice_at_line_index >= 0 and question2_choice_labels.size() > 0:
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
	_times_spoken += 1
	Input.set_mouse_mode(_prev_mouse_mode)

	var ui := _find_dialogue_ui()
	if ui and ui.closed.is_connected(_on_ui_closed):
		ui.closed.disconnect(_on_ui_closed)

	talk_finished.emit()

# Helpers
func _find_dialogue_ui() -> Node:
	for n in get_tree().get_nodes_in_group("DialogueUI"):
		return n
	var root := get_tree().current_scene
	return root.get_node_or_null("DialogueUI") if root else null

func _update_prompt() -> void:
	_prompt.visible = _player_in_range and not _talking
