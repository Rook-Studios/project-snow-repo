# res://scripts/components/QuestTrigger.gd
extends Node
class_name QuestTrigger

# When should this fire?
enum Trigger { OnTalkStart, OnChoiceAny, OnChoice0, OnChoice1, OnChoice2, OnFinish }
# What should it do?
enum Action  { Start, Advance, Complete }

@export var quest_name: StringName
@export var action: Action = Action.Start
@export var trigger: Trigger = Trigger.OnTalkStart
@export var once: bool = true
@export var line_index_filter: int = -1   # only fire if the choice originated from this line (optional)

# --- Creation helpers (for Start) ---
@export var create_if_missing: bool = true
@export var quest_title: String = ""
@export var quest_steps: Array[String] = []

# --- PREREQUISITES ---
# Quests that must be in a specific state:
@export var require_active: Array[StringName] = []      # all must be ACTIVE
@export var require_completed: Array[StringName] = []   # all must be COMPLETED
@export var require_not_started: Array[StringName] = [] # all must be NOT_STARTED (or absent)

# Flags that must be true/false (via your Flags autoload)
@export var require_flags_true: Array[StringName] = []
@export var require_flags_false: Array[StringName] = []

# Progression gates
@export var require_completed_count_at_least: int = 0   # total completed quests >= this

var _fired := false

func _ready() -> void:
	var npc := get_parent()
	if npc == null:
		push_warning("QuestTrigger should be a child of an NPC node that emits talk_started/choice_made/talk_finished.")
		return
	if npc.has_signal("talk_started"):
		npc.talk_started.connect(_on_talk_started)
	if npc.has_signal("choice_made"):
		npc.choice_made.connect(_on_choice_made)
	if npc.has_signal("talk_finished"):
		npc.talk_finished.connect(_on_talk_finished)

func _on_talk_started() -> void:
	if trigger == Trigger.OnTalkStart:
		_try_fire()

func _on_talk_finished() -> void:
	if trigger == Trigger.OnFinish:
		_try_fire()

func _on_choice_made(line_idx: int, choice_idx: int) -> void:
	# Optional: only fire if a specific line produced the choice
	if line_index_filter >= 0 and line_idx != line_index_filter:
		return

	match trigger:
		Trigger.OnChoiceAny:
			_try_fire()
		Trigger.OnChoice0:
			if choice_idx == 0: _try_fire()
		Trigger.OnChoice1:
			if choice_idx == 1: _try_fire()
		Trigger.OnChoice2:
			if choice_idx == 2: _try_fire()
		_:
			pass

func _try_fire() -> void:
	if _fired and once:
		return
	if quest_name == StringName():
		push_warning("QuestTrigger: quest_name is empty.")
		return

	# Gate behind prerequisites
	if not _prereqs_met():
		return

	# Create record if we're starting
	if create_if_missing and action == Action.Start:
		QuestManager.ensure(quest_name, quest_title, quest_steps)

	match action:
		Action.Start:
			QuestManager.start(quest_name, quest_title, quest_steps)
		Action.Advance:
			QuestManager.advance(quest_name)
		Action.Complete:
			QuestManager.complete(quest_name)

	_fired = true

func _prereqs_met() -> bool:
	# 1) quest state gating
	for q in require_active:
		if not QuestManager.is_active(q):
			return false

	for q in require_completed:
		if not QuestManager.is_completed(q):
			return false

	for q in require_not_started:
		# Not started if absent or explicitly NOT_STARTED
		if QuestManager.has(q) and QuestManager.state(q) != QuestManager.State.NOT_STARTED:
			return false

	# 2) flags gating
	for f in require_flags_true:
		if not Flags.is_true(f):
			return false
	for f in require_flags_false:
		if Flags.is_true(f):
			return false

	# 3) completed count
	if require_completed_count_at_least > 0:
		var total_completed := 0
		for k in QuestManager.quests.keys():
			if QuestManager.is_completed(k):
				total_completed += 1
		if total_completed < require_completed_count_at_least:
			return false

	return true
