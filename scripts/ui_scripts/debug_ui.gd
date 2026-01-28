extends CanvasLayer

@onready var fps_label: Label = $VBoxContainer/fps_label
@onready var player_label: Label = $VBoxContainer/player_label
@onready var input_label: Label = $VBoxContainer/input_label
@onready var ui_label: Label = $VBoxContainer/ui_state_label
@onready var quest_label: Label = $VBoxContainer/quest_label
@onready var position_label: Label = $VBoxContainer/position_label


@onready var player := get_tree().get_first_node_in_group("Player")

func _physics_process(_delta: float) -> void:
	_update_fps()
	_update_player()
	_update_input()
	_update_ui()
	_update_quests()
	_update_position()


func _update_fps() -> void:
	var fps := Engine.get_frames_per_second()
	var ms = 1000.0 / max(fps, 1)
	fps_label.text = "FPS: %d  (%.1f ms)" % [fps, ms]


func _update_player() -> void:
	if not player:
		player_label.text = "Player: <none>"
		return

	var v = player.velocity
	player_label.text = "Grounded: %s  Vel: (%.2f, %.2f, %.2f)" % [
		str(player.is_on_floor()),
		v.x, v.y, v.z
	]


func _update_input() -> void:
	var mouse := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	var using_controller := InputHints != null and InputHints.using_controller

	input_label.text = "Input: %s  Mouse: %s" % [
		("Controller" if using_controller else "Mouse"),
		("Captured" if mouse else "Free")
	]


func _update_ui() -> void:
	var dlg := get_tree().get_first_node_in_group("DialogueUI")
	var jrn := get_tree().get_first_node_in_group("JournalUI")

	ui_label.text = "Dialogue: %s  Journal: %s" % [
		("Open" if dlg and dlg.is_open() else "Closed"),
		("Open" if jrn and jrn.visible else "Closed")
	]


func _update_quests() -> void:
	if Requests == null:
		quest_label.text = "Requests: <none>"
		return

	var active := Requests.active_ids().size()
	var done := Requests.completed_total()
	var talked := WorldState.get_counter(&"npcs_talked_to")

	quest_label.text = "Requests: %d active / %d done | NPCs talked: %d" % [
		active, done, talked
	]

func _update_position() -> void:
	position_label.text = "X: %.1f, Y: %.1f" % [
		player.position.x, player.position.y
	]
