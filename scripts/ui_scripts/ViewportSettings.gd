extends Node

@onready var sub_viewport = $"../SubViewport"

var ratio : = 320

func _process(delta):
	if Input.is_action_just_pressed("ratio"):
		if ratio == 320:
			sub_viewport.size.x = 426
			ratio = 426
		elif ratio == 426:
			sub_viewport.size.x = 320
			ratio = 320
		
