# res://scripts/npc/NPCNoRequest.gd
extends Node3D
class_name NPCNoRequest

signal talk_started
signal talk_finished

@export_group("Identity")
@export var display_name: String = "Villager"
@export var npc_id: StringName = &""

@export_group("Visit Intros")
@export_multiline var first_visit_intro: Array[String] = []
@export_multiline var repeat_intro: Array[String] = []

@export_group("Dialogue Blocks")
@export var blocks: Array[DialogueBlock] = []
@export var repeat_blocks_override: Array[DialogueBlock] = []

@export_group("Voice Blips")
@export var voice_stream: AudioStream
@export var voice_pitch_min: float = 0.95
@export var voice_pitch_max: float = 1.05
@export var voice_blip_every: int = 2

@export_group("Interaction")
@export var prompt_verb: String = "Talk"  # builds "Press E to Talk" / "Press A to Talk" automatically

@export_group("Request Dialogue Gating")
@export var request_id_for_this_npc: StringName = &""   # any request to react to (optional)
@export_multiline var after_request_done_intro: Array[String] = []
@export var after_request_done_blocks: Array[DialogueBlock] = []

@onready var _zone: Area3D = $InteractZone
@onready var _prompt: Label3D = $Prompt3D

var _player_in := false
var _player_body: CharacterBody3D = null
var _talking := false
var _times_spoken := 0

# runtime state
var _block_idx := -1
var _choice_picked := -1

# per-conversation list after filtering
var _talk_blocks: Array[DialogueBlock] = []

# memory for play_once blocks this session
var _played_once: Dictionary = {}  # key:StringName -> true


func _ready() -> void:
	_prompt.visible = false
	_update_prompt_text()

	# Update prompt automatically when input scheme changes
	if InputHints != null:
		if not InputHints.scheme_changed.is_connected(_on_scheme_changed):
			InputHints.scheme_changed.connect(_on_scheme_changed)

	if _zone:
		_zone.body_entered.connect(func(b):
			if b is CharacterBody3D:
				_player_body = b
				_player_in = true
				_update_prompt()
		)
		_zone.body_exited.connect(func(b):
			if b == _player_body:
				_player_body = null
			if b is CharacterBody3D:
				_player_in = false
				_update_prompt()
		)

func _process(_delta: float) -> void:
	# Ensure prompt updates when player lands/jumps while inside range
	if _player_in and not _talking:
		_update_prompt()

func _unhandled_input(e: InputEvent) -> void:
	if _player_in and not _talking and e.is_action_pressed("interact"):
		# Only allow talking while grounded
		if _player_body != null and _player_body.is_on_floor():
			_start_conversation()

func _on_scheme_changed(_is_controller: bool) -> void:
	_update_prompt_text()

func _update_prompt_text() -> void:
	var using_controller := false
	if InputHints != null:
		using_controller = InputHints.using_controller
	_prompt.text = ("Press A to %s" % prompt_verb) if using_controller else ("Press E to %s" % prompt_verb)

func _start_conversation() -> void:
	var ui := _ui()
	if ui == null:
		return

	_talking = true
	choice_reset()
	_update_prompt()

	var req_done := false
	if request_id_for_this_npc != StringName() and Requests != null:
		req_done = Requests.is_done(request_id_for_this_npc)

	ui.set_speaker_name(display_name)
	ui.set_voice(voice_stream, voice_pitch_min, voice_pitch_max, voice_blip_every)

	# Choose blocks based on request completion (optional)
	if req_done and not after_request_done_blocks.is_empty():
		_talk_blocks = after_request_done_blocks
	else:
		_talk_blocks = _get_blocks_for_this_talk()

	# Choose intro based on request completion (optional), otherwise visit-based
	var intro: Array[String] = []
	if req_done and not after_request_done_intro.is_empty():
		intro = after_request_done_intro
	else:
		if _times_spoken == 0 and not first_visit_intro.is_empty():
			intro = first_visit_intro
		elif _times_spoken > 0 and not repeat_intro.is_empty():
			intro = repeat_intro

	if not intro.is_empty():
		_connect_closed_once(_on_intro_closed)
		ui.show_lines(intro)
	else:
		_next_block_or_finish()

func _on_intro_closed() -> void:
	_next_block_or_finish()

func _next_block_or_finish() -> void:
	_block_idx += 1
	_choice_picked = -1

	if _block_idx >= _talk_blocks.size():
		_end_conversation()
		return

	var ui := _ui()
	if ui == null:
		return

	ui.set_speaker_name(display_name)

	var blk := _talk_blocks[_block_idx]
	if blk.choice_line_index >= 0 and blk.choice_labels.size() > 0:
		_connect_choice_once(_on_choice_selected_block)
		_connect_closed_once(_on_block_pre_closed)
		ui.show_lines_with_choice_at(blk.lines, blk.choice_line_index, blk.choice_labels)
	else:
		_connect_closed_once(_on_block_lines_closed_no_choice)
		ui.show_lines(blk.lines)

func _on_block_pre_closed() -> void:
	if _choice_picked == -1:
		_on_block_lines_closed_no_choice()

func _on_block_lines_closed_no_choice() -> void:
	_show_tail_then_continue()

func _on_choice_selected_block(_line_idx: int, _choice_idx: int) -> void:
	_choice_picked = _choice_idx
	var blk := _talk_blocks[_block_idx]
	var ui := _ui()
	if ui == null:
		return

	var follow: Array[String] = []
	match _choice_idx:
		0: follow = blk.followup_choice0
		1: follow = blk.followup_choice1
		2: follow = blk.followup_choice2
		_: follow = []

	if follow.is_empty():
		_show_tail_then_continue()
	else:
		_connect_closed_once(func(): _show_tail_then_continue())
		ui.set_speaker_name(display_name)
		ui.show_lines(follow)

func _show_tail_then_continue() -> void:
	var blk := _talk_blocks[_block_idx]
	var ui := _ui()
	if ui == null:
		return

	_mark_played_if_once(blk)

	if blk.tail_lines.is_empty():
		_next_block_or_finish()
	else:
		_connect_closed_once(_next_block_or_finish)
		ui.set_speaker_name(display_name)
		ui.show_lines(blk.tail_lines)

func _end_conversation() -> void:
	_talking = false
	_times_spoken += 1
	_update_prompt()
	talk_finished.emit()
	print("END CONVO:", name)

	# Still emit the "talked_to" event so other requests can track it.
	if npc_id != StringName():
		EventBus.emit_talked_to(npc_id)

# --- block selection + tracking ---

func _get_blocks_for_this_talk() -> Array[DialogueBlock]:
	var source: Array[DialogueBlock] = []
	if _times_spoken == 0:
		source = blocks
	else:
		source = (repeat_blocks_override if repeat_blocks_override.size() > 0 else blocks)

	var first_visit := (_times_spoken == 0)
	var filtered: Array[DialogueBlock] = []
	for blk in source:
		if not (blk is DialogueBlock):
			continue
		if first_visit and not blk.show_on_first_visit:
			continue
		if (not first_visit) and not blk.show_on_repeat_visits:
			continue
		if blk.play_once and _was_played(blk):
			continue
		filtered.append(blk)
	return filtered

func _block_key(blk: DialogueBlock) -> StringName:
	if blk.block_id != StringName():
		return blk.block_id
	if blk.resource_path != "":
		return StringName(blk.resource_path)
	return StringName("%s_%d" % [display_name, _block_idx])

func _was_played(blk: DialogueBlock) -> bool:
	var k := _block_key(blk)
	return bool(_played_once.get(k, false))

func _mark_played_if_once(blk: DialogueBlock) -> void:
	if not blk.play_once:
		return
	var k := _block_key(blk)
	_played_once[k] = true

# --- helpers ---

func _ui() -> Node:
	for n in get_tree().get_nodes_in_group("DialogueUI"):
		return n
	return null

func _update_prompt() -> void:
	var grounded := (_player_body != null and _player_body.is_on_floor())
	_prompt.visible = _player_in and grounded and not _talking

func _connect_closed_once(fn: Callable) -> void:
	var ui := _ui()
	if ui == null:
		return
	if not ui.closed.is_connected(fn):
		ui.closed.connect(fn, CONNECT_ONE_SHOT)

func _connect_choice_once(fn: Callable) -> void:
	var ui := _ui()
	if ui == null:
		return
	if not ui.choice_selected.is_connected(fn):
		ui.choice_selected.connect(fn, CONNECT_ONE_SHOT)

func choice_reset() -> void:
	_block_idx = -1
	_choice_picked = -1
