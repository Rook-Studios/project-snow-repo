# res://scripts/QuestTrigger.gd
extends Node
class_name QuestTrigger

# When should this fire?
enum Trigger { OnTalkStart, OnChoiceAny, OnChoice0, OnChoice1, OnChoice2, OnFinish }
# What should it do?
enum Action  { Start, Advance, Complete }

@export var quest_name: StringName
@export var action: Action = Action.Start
@export var trigger: Trigger = Trigger.OnTalkStart
@export var once: bool = true                  # fire only once
@export var line_index_filter: int = -1        # only fire if the choice happened on this line (optional)

# Optional: if the quest doesn't exist yet and we're starting it, create with these
@export var create_if_missing: bool = true
@export var quest_title: String = ""
@export var quest_steps: Array[String] = []    # journal steps (optional)

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

func _fire() -> void:
	if _fired and once:
		return
	if quest_name == StringName():
		push_warning("QuestTrigger: quest_name is empty.")
		return

	# Ensure record if we’re about to start (nice for one-liners)
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

func _on_talk_started() -> void:
	if trigger == Trigger.OnTalkStart:
		_fire()

func _on_talk_finished() -> void:
	if trigger == Trigger.OnFinish:
		_fire()

func _on_choice_made(line_idx: int, choice_idx: int) -> void:
	# Optional: only fire if a specific line spawned the choice
	if line_index_filter >= 0 and line_idx != line_index_filter:
		return

	match trigger:
		Trigger.OnChoiceAny:
			_fire()
		Trigger.OnChoice0:
			if choice_idx == 0: _fire()
		Trigger.OnChoice1:
			if choice_idx == 1: _fire()
		Trigger.OnChoice2:
			if choice_idx == 2: _fire()
		_:
			pass
