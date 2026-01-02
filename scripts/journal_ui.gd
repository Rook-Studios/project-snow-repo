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
		var notes: String = String(r.get("notes", ""))
		var state: String = String(r.get("state", ""))

		# Notes (shown next to title)
		var notes_bb := ""
		if notes.strip_edges() != "":
			notes_bb = " %s" % notes

		# Optional progress suffix for count-based tasks
		var progress_bb := ""
		if r.has("need") and r.has("count"):
			var need := int(r.get("need", 0))
			var count := int(r.get("count", 0))
			if need > 1:
				progress_bb = "  [i](%d/%d)[/i]" % [count, need]

		var bb := "[b][i]%s -[/i][/b]%s%s" % [title, notes_bb, progress_bb]

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
