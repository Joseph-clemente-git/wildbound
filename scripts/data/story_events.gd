class_name StoryEvents
extends RefCounted
## Narrative beats for Chapter 1 (story §11-22, §48).
##
## A beat is a Dictionary: {"speaker": id, "text": String, "shot": camera shot,
## "action": "kind:arg"}. `{champion}` and `{keeper}` are substituted.
## Actions: set_flag, give_item, recruit, name_champion, unlock_codex, coins.

const SPEAKERS := {
	"narrator": {"name": "", "color": Color("d8cdb8")},
	"magnus": {"name": "Old Magnus", "color": Color("e3a857")},
	"champion": {"name": "{champion}", "color": Color("f0dcb8")},
	"yenbi": {"name": "Yenbi", "color": Color("e0605a")},
	"keeper": {"name": "{keeper}", "color": Color("8cc46f")},
}

## Old magnus, the lodge's owner: an old man with a white beard and a cane.
const OWNER_APPEARANCE := ProceduralHumanVisual.ELDER

const EVENTS := {
	"opening": [
		{"speaker": "narrator", "shot": "valley",
				"text": "Long ago, animals lived alongside the forces of nature — and some learned to channel Aether, to grow strong, master weapons and protect their homes."},
		{"speaker": "narrator", "shot": "circle",
				"text": "Communities held the Grand Trials, peaceful contests of skill. But lately, the old Aether sites have begun to fail…"},
		{"speaker": "magnus", "shot": "porch",
				"text": "You came! My knees have stopped agreeing with my ambitions, Keeper. The local trial is near — without a champion, this lodge will close."},
		{"speaker": "magnus", "shot": "dog",
				"text": "This one has been waiting for someone to believe in them. Young, quick, a heart too big for that scarf — but no path yet."},
		{"speaker": "champion", "shot": "dog", "text": "*bounces forward, tail wagging, and sniffs your hand*"},
		{"speaker": "magnus", "shot": "dog", "action": "name_champion",
				"text": "Every champion deserves a name spoken by their Keeper. What will you call them?"},
		{"speaker": "magnus", "shot": "porch", "action": "give_item:token_mentor",
				"text": "{champion}. A fine name. Champions learn by living — every dodge, every fall. Take my old token, and the lodge. Make us proud."},
		{"speaker": "narrator", "shot": "lodge", "action": "set_flag:opening_done",
				"text": "One companion, one trial, one small lodge. Your journey begins."},
	],
	"meet_swordmaster": [
		{"speaker": "yenbi",
				"text": "So you're the new Keeper. Magnus wrote that you'd need a sword teacher. I'm Yenbi — and don't let my age fool you. I reached the Grand Trials finals before I was fifteen."},
		{"speaker": "yenbi",
				"text": "Look at {champion}'s footwork. That dog already has natural strengths — quick feet, a good dodge, lungs for a long fight."},
		{"speaker": "yenbi",
				"text": "Fighting is how champions learn. Every battle leaves experience behind. My job is to take that experience and direct it."},
		{"speaker": "yenbi",
				"text": "Mastery comes from mentors; techniques come from mastery. Here — a lodge sword. Light, honest, forgiving. Every champion can learn any weapon."},
		{"speaker": "yenbi", "action": "recruit:swordmaster_yenbi",
				"text": "I'll join your lodge's mentorship circle. Your lodge can only keep one active mentor for now — as its reputation grows, so will the circle."},
		{"speaker": "yenbi", "action": "give_item:sword_training",
				"text": "Come to the Training Yard when you're ready for a first lesson."},
	],
	"after_first_trial": [
		{"speaker": "magnus",
				"text": "I watched from the porch. {champion} has potential — I saw it in every step. But that was only the beginning."},
		{"speaker": "magnus",
				"text": "Did you notice what {champion} learned? Battles leave their mark: dodging sharpens evasion, blocking hardens defense, even a defeat teaches survival."},
		{"speaker": "magnus",
				"text": "Rest {champion} at the Rest Area, then let your mentors build on that experience. That is how a champion grows."},
		{"speaker": "magnus", "action": "set_flag:world_map_unlocked",
				"text": "And take this map. The Home Valley holds more trials: Rook the stonewall and Juniper of the meadow. Beat them both and the Regional Trial will open."},
		{"speaker": "magnus", "action": "unlock_codex:aether",
				"text": "Oh, and the Aether Circle beside the lodge is awake again. Fire and Wind mages pass through the valley — any champion can learn the Aether Arts."},
	],
	"chapter_one_complete": [
		{"speaker": "magnus",
				"text": "The champion of the Home Valley! Keeper, the whole valley is talking about our little lodge."},
		{"speaker": "magnus",
				"text": "But I did not ask you here only to save the lodge. Marla told me the Aether sites beyond Greenwood and Stonepass are failing. Wild creatures grow restless."},
		{"speaker": "magnus",
				"text": "The trials are connected to it somehow. Champions from every region are being called. The road beyond the valley is open to you now."},
		{"speaker": "narrator", "action": "set_flag:chapter_one_complete",
				"text": "CHAPTER 1 — FIRST STEPS — COMPLETE. New regions appear on your map. The journey continues in Chapter 2: The Road Beyond."},
	],
}


static func get_event(event_id: String) -> Array:
	return EVENTS.get(event_id, [])


static func speaker_name(speaker: String, champion_name: String, keeper_name: String) -> String:
	var raw: String = SPEAKERS.get(speaker, {}).get("name", speaker.capitalize())
	return raw.replace("{champion}", champion_name).replace("{keeper}", keeper_name)


static func speaker_color(speaker: String) -> Color:
	return SPEAKERS.get(speaker, {}).get("color", UiTheme.TEXT)
