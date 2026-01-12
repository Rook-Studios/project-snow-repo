extends Node

@onready var sub_viewport: SubViewport = $"../SubViewport"
@onready var player = get_tree().get_first_node_in_group("Player")

# Base internal resolution (1x)
@export var base_height: int = 240
@export var width_4_3: int = 320
@export var width_16_9: int = 426  # 240 * 16/9 ≈ 426.66

# Current state
var _base_width: int = 320
var _scale: int = 1  # 1 or 2

func _ready() -> void:
	_apply_resolution()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ratio"):
		_toggle_ratio()
		_apply_ui_layout()
	
	#player.debug.text = str(_base_width)

	if Input.is_action_just_pressed("res_double"): # add this action in InputMap
		_toggle_double_res()

func _toggle_ratio() -> void:
	_base_width = (width_16_9 if _base_width == width_4_3 else width_4_3)
	_apply_resolution()

func _toggle_double_res() -> void:
	_scale = 2 if _scale == 1 else 1
	_apply_resolution()

func _apply_resolution() -> void:
	sub_viewport.size = Vector2i(_base_width * _scale, base_height * _scale)

func _apply_ui_layout() -> void:
	var is_4_3 := (_base_width == width_4_3)
	var sd := Vector2(0.8, 0.8) if is_4_3 else Vector2.ONE
	var pd := Vector2(170, 760) if is_4_3 else Vector2(170, 720)
	var sj := Vector2(0.8, 0.8) if is_4_3 else Vector2(0.9, 0.9)
	var pj := Vector2(160, -75) if is_4_3 else Vector2(-40, -40)

	var dlg := get_tree().get_first_node_in_group("DialogueUI")
	if dlg:
		var p := dlg.get_node("Panel") as Control
		p.scale = sd
		p.position = pd
	var jrn := get_tree().get_first_node_in_group("JournalUI")
	if jrn:
		var p := jrn.get_node("Panel") as Control
		p.scale = sj
		p.position = pj
