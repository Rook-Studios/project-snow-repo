Project Snow

1.Make sure required autoloads exist:
	Requests, EventBus, WorldState (and DialogueUI is in the scene + in group "DialogueUI").

2.Instance NPC_VisitArea.tscn into the level (or any NPC scene that has InteractZone (Area3D) + Prompt3D (Label3D)) and ensure the InteractZone collision shape is sized correctly.

3.Assign script: NPCVisitArea.gd to the NPC root node.

4.Set NPC identity (optional but recommended):
	display_name = name shown in dialogue
	npc_id = unique ID (used for talk-based requests + EventBus tracking)

5.Set basic dialogue (so the NPC actually talks):
	Fill first_visit_intro and/or repeat_intro (optional)
	Add blocks (DialogueBlock resources) for the main conversation
	Optional: fill repeat_blocks_override for different repeat-talk block list

6.Set quest trigger fields (this is what starts the request at end of convo):
	start_visit_request_id = unique request ID (e.g. visit_square)
	start_visit_request_title = journal title (e.g. "Visit the Town Square")
	start_visit_request_notes = extra journal notes (e.g. "Head to the fountain.")
	start_visit_area_id = target area ID to complete it (e.g. town_square)
	
7.Place a completion trigger in the world:
	add a QuestArea (Area3D) where the player must go and set its area_id to exactly match the NPC’s start_visit_area_id (e.g. town_square). Ensure it has a collision shape and is monitoring.

8.Optional: make NPC change dialogue after request completion:
	request_id_for_this_npc = same request ID (e.g. visit_square)
	Fill after_request_done_intro and/or after_request_done_blocks (used when Requests.is_done(request_id_for_this_npc) is true)

9.Test checklist (in-game):
	Talk to NPC → request appears in Journal (Active)
	Enter matching QuestArea → request becomes Done + toast popup (if enabled)
	WorldState updates (flag = request id, counters increment; NPC also increments npcs_talked_to)

10.Common failure points:
	empty start_visit_request_id, mismatched start_visit_area_id vs QuestArea area_id, missing collisions/monitoring, or dialogue never reaches _end_conversation() (quest starts at convo end).
