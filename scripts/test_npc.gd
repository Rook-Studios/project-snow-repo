extends Node3D

@export var display_name: String = "Villager"
@export_multiline var intro_line: String = "Morning! Lovely winter day, isn't it?"
@export var intro_lines: Array[String] = []

# Optional voice for this NPC
@export var voice_stream: AudioStream
@export var voice_pitch_min: float = 0.95
@export var voice_pitch_max: float = 1.05
@export var voice_blip_every: int = 2

@onready var _zone: Area3D = $InteractZone
@onready var _prompt: Label3D = $Prompt3D

var _player_in_range := false
var _talking := false

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
		push_warning("DialogueUI not found in scene. Please instance scenes/ui/DialogueUI.tscn.")
		return

	_talking = true
	_update_prompt()

	# Build lines without name prefix (name is shown in its own label)
	var lines: Array[String] = []
	if intro_line.strip_edges() != "":
		lines.append(intro_line)
	for l in intro_lines:
		lines.append(l)

	# Set speaker name + voice, then show lines
	ui.set_speaker_name(display_name)
	ui.set_voice(voice_stream, voice_pitch_min, voice_pitch_max, voice_blip_every)
	ui.show_lines(lines)

	if not ui.closed.is_connected(_on_ui_closed):
		ui.closed.connect(_on_ui_closed)
	get_viewport().set_input_as_handled()

func _on_ui_closed() -> void:
	_talking = false
	_update_prompt()

func _find_dialogue_ui() -> Node:
	for n in get_tree().get_nodes_in_group("DialogueUI"):
		return n
	var root := get_tree().current_scene
	return root.get_node_or_null("DialogueUI") if root else null

func _update_prompt() -> void:
	_prompt.visible = _player_in_range and not _talking
