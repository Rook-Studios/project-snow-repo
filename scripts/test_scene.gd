extends Node3D

@onready var npc := $NPC_NoRequest2

func _ready() -> void:
	if WorldState == null:
		push_error("WorldState autoload missing")
		return
