extends TextureRect

@export var base_size := Vector2i(320, 240) # your SubViewport size

func _ready() -> void:
	resized.connect(_update_cover)
	_update_cover()

func _update_cover() -> void:
	var screen := get_viewport_rect().size
	var sx := screen.x / float(base_size.x)
	var sy := screen.y / float(base_size.y)
	var s = max(sx, sy) # cover (fills, crops)

	scale = Vector2(s, s)
	position = (screen - Vector2(base_size) * s) * 0.5
