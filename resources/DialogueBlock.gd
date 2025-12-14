# res://scripts/npc/DialogueBlock.gd
extends Resource
class_name DialogueBlock

@export_group("Block")
@export_multiline var lines: Array[String] = []

@export_group("Choice (optional)")
@export var choice_line_index: int = -1
@export var choice_labels: Array[String] = []

@export_group("Followups (unique per choice)")
@export_multiline var followup_choice0: Array[String] = []
@export_multiline var followup_choice1: Array[String] = []
@export_multiline var followup_choice2: Array[String] = []

@export_group("Tail (reconverge)")
@export_multiline var tail_lines: Array[String] = []


# --- NEW: simple visibility rules ---
@export_group("When To Show")
@export var show_on_first_visit: bool = true
@export var show_on_repeat_visits: bool = true
@export var play_once: bool = false              # show at most once (ever in this session)
@export var block_id: StringName                 # optional stable id (helps 'play_once' tracking)
