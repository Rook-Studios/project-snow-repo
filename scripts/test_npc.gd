extends Node3D

@export var display_name: String = "Villager"
@export_multiline var intro_line: String = "Morning! Lovely winter day, isn't it?"

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
	print("talking initiated")
	var ui := _find_dialogue_ui()
	if ui == null:
		push_warning("DialogueUI not found in scene. Please instance scenes/DialogueUI.tscn in your world.")
		return
	_talking = true
	_update_prompt()
	ui.show_line("%s: %s" % [display_name, intro_line])

	# Avoid double-connecting across talks
	if not ui.closed.is_connected(_on_ui_closed):
		ui.closed.connect(_on_ui_closed)

	# IMPORTANT: consume the same input event so UI doesn't immediately close
	get_viewport().set_input_as_handled()


func _on_ui_closed() -> void:
	_talking = false
	_update_prompt()

func _find_dialogue_ui() -> Node:
	# Search the scene tree for a DialogueUI instance (by script or node name).
	# If you autoload it later, just return get_node("/root/DialogueUI")
	for n in get_tree().get_nodes_in_group("DialogueUI"):
		return n
	# Fallback by name:
	var root := get_tree().current_scene
	if root:
		var node := root.get_node_or_null("DialogueUI")
		if node: return node
	return null

func _update_prompt() -> void:
	_prompt.visible = _player_in_range and not _talking
