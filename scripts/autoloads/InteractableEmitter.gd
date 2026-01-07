extends Node
class_name InteractableEmitter

@export_group("Identity")
@export var object_id: StringName = &""

@export_group("Prompt")
@export var prompt_verb: String = "Interact"
@export var prompt_path: NodePath = ^"../Prompt3D" # points to sibling by default
@export var show_prompt_only_when_grounded: bool = true

@export_group("Zone")
@export var zone_path: NodePath = ^"../InteractZone" # points to sibling by default

@export_group("Input")
@export var interact_action: StringName = &"interact"

@export_group("Flavour Text")
@export var speaker_name: String = " "
@export_multiline var flavour_lines: Array[String] = []
@export var show_flavour_on_interact: bool = true

@export_group("Flavour Voice Blip (optional)")
@export var flavour_voice_stream: AudioStream
@export var flavour_voice_pitch_min: float = 0.95
@export var flavour_voice_pitch_max: float = 1.05
@export var flavour_voice_blip_every: int = 2

var _player_in := false
var _player_body: CharacterBody3D = null

# Prevent re-triggering flavour text while it's already open
var _flavour_lock := false

@onready var _zone: Area3D = get_node_or_null(zone_path) as Area3D
@onready var _prompt: Label3D = get_node_or_null(prompt_path) as Label3D


func _ready() -> void:
	if _prompt:
		_prompt.visible = false
		_update_prompt_text()

	if InputHints != null:
		if not InputHints.scheme_changed.is_connected(_on_scheme_changed):
			InputHints.scheme_changed.connect(_on_scheme_changed)

	if _zone:
		_zone.body_entered.connect(_on_body_entered)
		_zone.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	_update_prompt_visible()


func _unhandled_input(e: InputEvent) -> void:
	if not _player_in:
		return
	if object_id == StringName():
		return

	# If flavour text is currently showing, don't restart it.
	if _flavour_lock:
		return

	# If DialogueUI is already open (NPC talk, other flavour text), don't interact through it.
	var ui := _dialogue_ui()
	if ui != null and ui.is_open():
		return

	if e.is_action_pressed(interact_action):
		if show_prompt_only_when_grounded and _player_body and not _player_body.is_on_floor():
			return

		# 1) Emit interaction event (so INTERACT_OBJECT requests can complete)
		# If flavour will be shown, delay completion until dialogue closes.
		var will_show_flavour := show_flavour_on_interact and flavour_lines.size() > 0 and ui != null
		if not will_show_flavour:
			EventBus.emit_interacted(object_id)


		# 2) Optional: show flavour text via DialogueUI
		if show_flavour_on_interact and flavour_lines.size() > 0 and ui != null:
			_flavour_lock = true

			ui.set_speaker_name(speaker_name)

			# Generic blip voice for objects (optional)
			ui.set_voice(flavour_voice_stream, flavour_voice_pitch_min, flavour_voice_pitch_max, flavour_voice_blip_every)

			# Unlock once the dialogue closes (ONE SHOT so we don't leak connections)
			if not ui.closed.is_connected(_on_ui_closed_unlock):
				ui.closed.connect(_on_ui_closed_unlock, CONNECT_ONE_SHOT)

			ui.show_lines(flavour_lines)

		get_viewport().set_input_as_handled()


func _on_ui_closed_unlock() -> void:
	_flavour_lock = false
	EventBus.emit_interacted(object_id)


func _on_body_entered(b: Node) -> void:
	if b is CharacterBody3D and b.is_in_group("Player"):
		_player_body = b
		_player_in = true
		_update_prompt_visible()


func _on_body_exited(b: Node) -> void:
	if b == _player_body:
		_player_body = null
	if b is CharacterBody3D and b.is_in_group("Player"):
		_player_in = false
	_update_prompt_visible()


func _on_scheme_changed(_is_controller: bool) -> void:
	_update_prompt_text()


func _update_prompt_text() -> void:
	if not _prompt:
		return
	var using_controller := InputHints != null and InputHints.using_controller
	_prompt.text = ("Press A to %s" % prompt_verb) if using_controller else ("Press E to %s" % prompt_verb)


func _update_prompt_visible() -> void:
	if not _prompt:
		return
	if not _player_in:
		_prompt.visible = false
		return
	if show_prompt_only_when_grounded and _player_body and not _player_body.is_on_floor():
		_prompt.visible = false
		return
	_prompt.visible = true


func _dialogue_ui() -> Node:
	# get_first_node_in_group exists in Godot 4.x; this is just wrapped for clarity.
	return get_tree().get_first_node_in_group("DialogueUI")
