extends CanvasLayer

@onready var _active: VBoxContainer    = $Panel/MarginContainer/VBoxContainer/ActiveList
@onready var _completed: VBoxContainer = $Panel/MarginContainer/VBoxContainer/CompletedList

@export var toggle_action: StringName = &"journal"   # optional: bind to a key

func _ready() -> void:
	visible = false

	# Connect QuestManager signals to our handlers
	QuestManager.quest_started.connect(_on_mgr_changed)
	QuestManager.quest_advanced.connect(_on_mgr_changed)
	QuestManager.quest_completed.connect(_on_mgr_completed)
	QuestManager.quest_failed.connect(_on_mgr_changed)
	QuestManager.journal_entry.connect(_on_mgr_note)

	_refresh()

func _on_mgr_changed(name: StringName, arg = null) -> void:
	# Fires on start/advance/failed (and others if you hook them)
	_refresh()

func _on_mgr_completed(name: StringName) -> void:
	print("Journal heard complete:", name)
	_refresh()

func _on_mgr_note(_name: StringName, _text: String) -> void:
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(toggle_action):
		visible = !visible
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	# Clear old entries
	for c in _active.get_children(): c.queue_free()
	for c in _completed.get_children(): c.queue_free()

	# Rebuild from manager each time
	for name in QuestManager.quests.keys():
		var q: Dictionary = QuestManager.quests[name]

		# Safe dictionary reads
		var title: String = String(q.get("title", String(name)))
		var steps: Array = q.get("steps", [])
		var step_idx: int = int(q.get("step", -1))

		var step_text := ""
		if step_idx >= 0 and step_idx < steps.size():
			step_text = String(steps[step_idx])

		var suffix := "" if step_text == "" else " — [i]%s[/i]" % step_text
		var bb := "[b]%s[/b]%s" % [title, suffix]
		var rtl := _make_rich_line(bb)

		# *** Use the manager's helpers instead of matching enum ints ***
		if QuestManager.is_completed(name):
			_completed.add_child(rtl)
		elif QuestManager.is_active(name):
			_active.add_child(rtl)
		else:
			rtl.queue_free() # skip NOT_STARTED/FAILED for now

func _refresh_with_note(_name: StringName, _text: String) -> void:
	_refresh()
	

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
