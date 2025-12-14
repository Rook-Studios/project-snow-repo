# res://scripts/npc/SimpleDialogueNPC.gd
extends Node3D
class_name SimpleDialogueNPC

signal talk_started
signal talk_finished

@export_group("Identity")
@export var display_name: String = "Villager"

@export_group("Visit Intros")
@export_multiline var first_visit_intro: Array[String] = []
@export_multiline var repeat_intro: Array[String] = []

@export_group("Dialogue Blocks")
@export var blocks: Array[DialogueBlock] = []                 # base set (used on first visit and by default)
@export var repeat_blocks_override: Array[DialogueBlock] = [] # NEW: if non-empty, use these on repeats

@export_group("Voice Blips")
@export var voice_stream: AudioStream
@export var voice_pitch_min: float = 0.95
@export var voice_pitch_max: float = 1.05
@export var voice_blip_every: int = 2

@export_group("Interaction")
@export var prompt_text: String = "[E] Talk"

@onready var _zone: Area3D = $InteractZone
@onready var _prompt: Label3D = $Prompt3D

var _player_in := false
var _talking := false
var _times_spoken := 0

# runtime state
var _block_idx := -1
var _choice_picked := -1

# NEW: the per-conversation list we’ll walk after filtering
var _talk_blocks: Array[DialogueBlock] = []

# NEW: memory for play_once blocks this session
var _played_once: Dictionary = {}  # key:StringName -> true


func _ready() -> void:
	_prompt.visible = false
	_prompt.text = prompt_text
	if _zone:
		_zone.body_entered.connect(func(b):
			if b is CharacterBody3D:
				_player_in = true
				_update_prompt())
		_zone.body_exited.connect(func(b):
			if b is CharacterBody3D:
				_player_in = false
				_update_prompt())

func _unhandled_input(e: InputEvent) -> void:
	if _player_in and not _talking and e.is_action_pressed("interact"):
		_start_conversation()

func _start_conversation() -> void:
	var ui := _ui()
	if ui == null: return

	_talking = true
	choice_reset()

	ui.set_speaker_name(display_name)
	ui.set_voice(voice_stream, voice_pitch_min, voice_pitch_max, voice_blip_every)

	# NEW: decide which block list we’ll use THIS talk
	_talk_blocks = _get_blocks_for_this_talk()

	# show visit-specific intro
	var intro: Array[String] = []
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
	if ui == null: return

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
	if ui == null: return

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
	if ui == null: return

	# mark play_once blocks as consumed (so future talks will skip them)
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

# --- NEW: block selection + tracking ---

func _get_blocks_for_this_talk() -> Array[DialogueBlock]:
	var source: Array[DialogueBlock] = []
	if _times_spoken == 0:
		source = blocks
	else:
		# if you provide an override list for repeats, we use it
		if repeat_blocks_override.size() > 0:
			source = repeat_blocks_override
		else:
			source = blocks

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
	# fallbacks so keys are stable even if arrays reorder:
	if blk.resource_path != "":
		return StringName(blk.resource_path)
	# last resort: use display_name + index for this talk
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
	_prompt.visible = _player_in and not _talking

func _connect_closed_once(fn: Callable) -> void:
	var ui := _ui()
	if ui == null: return
	if not ui.closed.is_connected(fn):
		ui.closed.connect(fn, CONNECT_ONE_SHOT)

func _connect_choice_once(fn: Callable) -> void:
	var ui := _ui()
	if ui == null: return
	if not ui.choice_selected.is_connected(fn):
		ui.choice_selected.connect(fn, CONNECT_ONE_SHOT)

func choice_reset() -> void:
	_block_idx = -1
	_choice_picked = -1
