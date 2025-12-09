extends Node3D

@export var npc_id: StringName = "villager_a"
@export var display_name: String = "Villager"

# Dialogue data
@export var dialogue: Dialogue                     # assign a Dialogue .tres here
@export var start_by_day: Dictionary = {}          # e.g. {"1":"start", "2":"snow_chat"}

# Optional voice for this NPC (used by DialogueUI)
@export var voice_stream: AudioStream
@export var voice_pitch_min: float = 0.95
@export var voice_pitch_max: float = 1.05
@export var voice_blip_every: int = 2

@onready var _zone: Area3D = $InteractZone
@onready var _prompt: Label3D = $Prompt3D

var _player_in_range: bool = false
var _talking: bool = false

func _ready() -> void:
	_prompt.visible = false
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)
	# Listen for dialogue ending (from the manager)
	if not DialogueMgr.finished.is_connected(_on_dialogue_finished):
		DialogueMgr.finished.connect(_on_dialogue_finished)

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
	if dialogue == null:
		push_warning("No Dialogue resource assigned on NPC: %s" % name)
		return

	_talking = true
	_update_prompt()

	# Set speaker name & voice on the UI (purely presentational)
	DialogueUI.set_speaker_name(display_name)
	DialogueUI.set_voice(voice_stream, voice_pitch_min, voice_pitch_max, voice_blip_every)

	# Choose start node for the current day (fallback to dialogue.start_node)
	var day_key: String = str(DayMgr.current_day)
	var start_id: StringName = StringName(start_by_day.get(day_key, dialogue.start_node))

	# Begin conversation via the manager
	DialogueMgr.begin(npc_id, dialogue, start_id)

	# Consume the same input so UI doesn't immediately advance/close
	get_viewport().set_input_as_handled()

func _on_dialogue_finished(finished_npc_id: StringName) -> void:
	if finished_npc_id != npc_id:
		return
	_talking = false
	_update_prompt()

func _update_prompt() -> void:
	_prompt.visible = _player_in_range and not _talking
