extends CanvasLayer

@onready var _active: VBoxContainer    = $Panel/MarginContainer/VBoxContainer/ActiveList
@onready var _completed: VBoxContainer = $Panel/MarginContainer/VBoxContainer/CompletedList

@export var toggle_action: StringName = &"journal"

func _ready() -> void:
	visible = false

	# Listen to Requests updates
	Requests.request_started.connect(_on_requests_changed)
	Requests.request_updated.connect(_on_requests_changed)
	Requests.request_completed.connect(_on_requests_changed)

	_refresh()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(toggle_action):
		visible = !visible
		get_viewport().set_input_as_handled()

func _on_requests_changed(_id: StringName) -> void:
	_refresh()

func _refresh() -> void:
	# Clear old entries
	for c in _active.get_children():
		c.queue_free()
	for c in _completed.get_children():
		c.queue_free()

	# Rebuild from Requests
	for id in Requests.requests.keys():
		var r: Dictionary = Requests.requests[id]

		var title: String = String(r.get("title", String(id)))
		var state: String = String(r.get("state", ""))

		# Optional progress suffix for count-based tasks
		var suffix := ""
		if r.has("need") and r.has("count"):
			var need := int(r.get("need", 0))
			var count := int(r.get("count", 0))
			# Only show if it's actually meaningful
			if need > 1:
				suffix = " — [i]%d/%d[/i]" % [count, need]

		var bb := "[b]%s[/b]%s" % [title, suffix]
		var rtl := _make_rich_line(bb)

		if state == "done":
			_completed.add_child(rtl)
		elif state == "active":
			_active.add_child(rtl)
		else:
			rtl.queue_free() # ignore unknown states for now

func _make_rich_line(bbcode: String) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.text = bbcode
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.scroll_following = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rtl
