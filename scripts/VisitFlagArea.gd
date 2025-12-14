# res://scripts/components/VisitFlagArea.gd
extends Node
class_name VisitFlagArea

@export var flag_name: StringName
@export var area_path: NodePath
@export var require_player_group := true
@export var player_group_name: StringName = &"Player"
@export var trigger_once := true
@export var set_on_enter := true
@export var clear_on_exit := false
@export var chime: AudioStream
@export var chime_bus: StringName = &"SFX"  # set to your SFX bus name

var _fired := false
var _area: Area3D
var _sfx2d: AudioStreamPlayer   # <-- 2D, not 3D

func _ready() -> void:
	_area = (get_node_or_null(area_path) as Area3D) if area_path != NodePath() else _find_parent_area()
	if not _area:
		push_error("VisitFlagArea: couldn't find an Area3D. Assign 'area_path' or make an ancestor an Area3D.")
		return

	_area.body_entered.connect(_on_body_entered)
	if clear_on_exit:
		_area.body_exited.connect(_on_body_exited)

	if chime:
		_sfx2d = AudioStreamPlayer.new()
		_sfx2d.stream = chime
		_sfx2d.bus = String(chime_bus)
		add_child(_sfx2d)  # 2D sound; position doesn’t matter

func _on_body_entered(body: Node) -> void:
	if trigger_once and _fired:
		return
	if not _passes_filter(body):
		return
	if set_on_enter and flag_name != StringName():
		if not Flags.is_true(flag_name):
			Flags.set_true(flag_name)
			if _sfx2d: _sfx2d.play()
			print(flag_name)
		_fired = true

func _on_body_exited(body: Node) -> void:
	if not _passes_filter(body):
		return
	if clear_on_exit and flag_name != StringName():
		Flags.set_false(flag_name)

func _passes_filter(body: Node) -> bool:
	return body.is_in_group(player_group_name) if require_player_group else (body is CharacterBody3D)

func _find_parent_area() -> Area3D:
	var p := get_parent()
	while p:
		if p is Area3D:
			return p
		p = p.get_parent()
	return null
