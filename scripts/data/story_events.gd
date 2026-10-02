class_name StoryEvents
extends RefCounted
## Narrative beats for Chapter 1 (story §11-22, §48).
##
## A beat is a Dictionary: {"speaker": id, "text": String, "shot": camera shot,
## "action": "kind:arg"}. `{champion}` and `{keeper}` are substituted.
## Actions: set_flag, give_item, recruit, name_champion, unlock_codex, coins.

const SPEAKERS := {
	"narrator": {"name": "", "color": Color("d8cdb8")},
	"maren": {"name": "Old Maren", "color": Color("e3a857")},
	"champion": {"name": "{champion}", "color": Color("f0dcb8")},
	"corin": {"name": "Corin Ashvale", "color": Color("9fb8d8")},
	"keeper": {"name": "{keeper}", "color": Color("8cc46f")},
}

## Grey-muzzled palette for the aging mentor.
const MAREN_PALETTE := {
	"fur": Color("8a7d6e"), "fur_light": Color("ddd5c8"), "fur_dark": Color("4a4038"),
	"scarf": Color("6a3d5a"), "cloth": Color("5a4a5a"),
}

const EVENTS := {
	"opening": [
		{"speaker": "narrator", "shot": "valley",
				"text": "Long ago, the lands were joined by ancient paths, and animals lived alongside the forces of nature."},
		{"speaker": "narrator", "shot": "valley",
				"text": "Some learned to channel an ancient energy called Aether — to strengthen their bodies, master weapons and protect their homes."},
		{"speaker": "narrator", "shot": "circle",
				"text": "Communities created the Grand Trials: peaceful contests where champions proved their skill. But lately, the old Aether sites have begun to fail…"},
		{"speaker": "narrator", "shot": "lodge",
				"text": "You walk the last stretch of the valley road toward a small training lodge, a letter from its keeper in your pocket."},
		{"speaker": "maren", "shot": "porch",
				"text": "You came! Good. My knees have stopped agreeing with my ambitions, Keeper — this lodge needs someone with younger legs."},
		{"speaker": "maren", "shot": "porch",
				"text": "The local Champion Trial is approaching. If the lodge has no champion in it, the valley will forget us. Coin will dry up, and the doors will close."},
		{"speaker": "maren", "shot": "dog",
				"text": "And this one has been waiting for someone to believe in them. Young, quick, a heart too big for that scarf — but no path yet."},
		{"speaker": "champion", "shot": "dog", "text": "*bounces forward, tail wagging, and sniffs your hand*"},
		{"speaker": "maren", "shot": "dog", "action": "name_champion",
				"text": "Every champion deserves a name spoken by their Keeper. What will you call them?"},
		{"speaker": "maren", "shot": "porch",
				"text": "{champion}. A fine name. Champions here are not tools, Keeper. They are companions. They learn by living — every dodge, every fall, every win."},
		{"speaker": "maren", "shot": "porch", "action": "give_item:token_mentor",
				"text": "Take this token. It steadied my first champion's breath. Now — the lodge is yours. Train {champion}, enter the local trial, and keep our doors open."},
		{"speaker": "narrator", "shot": "lodge", "action": "set_flag:opening_done",
				"text": "Your journey begins with something simple: one companion, one trial, one small lodge."},
	],
	"meet_swordmaster": [
		{"speaker": "corin",
				"text": "So you're the new Keeper. Maren wrote that you'd need a sword teacher. Corin Ashvale — I retired from the Grand Trials, but not from teaching."},
		{"speaker": "corin",
				"text": "Look at {champion}'s footwork. That dog already has natural strengths — quick feet, a good dodge, lungs for a long fight."},
		{"speaker": "corin",
				"text": "Fighting is how champions learn. Every battle leaves experience behind. My job is to take that experience and direct it."},
		{"speaker": "corin",
				"text": "Mastery comes from mentors; techniques come from mastery. Here — a lodge sword. Light, honest, forgiving. Every champion can learn any weapon."},
		{"speaker": "corin", "action": "recruit:swordmaster_corin",
				"text": "I'll join your lodge's mentorship circle. Your lodge can only keep one active mentor for now — as its reputation grows, so will the circle."},
		{"speaker": "corin", "action": "give_item:sword_training",
				"text": "Come to the Training Yard when you're ready for a first lesson."},
	],
	"after_first_trial": [
		{"speaker": "maren",
				"text": "I watched from the porch. {champion} has potential — I saw it in every step. But that was only the beginning."},
		{"speaker": "maren",
				"text": "Did you notice what {champion} learned? Battles leave their mark: dodging sharpens evasion, blocking hardens defense, even a defeat teaches survival."},
		{"speaker": "maren",
				"text": "Rest {champion} at the Rest Area, then let your mentors build on that experience. That is how a champion grows."},
		{"speaker": "maren", "action": "set_flag:world_map_unlocked",
				"text": "And take this map. The Home Valley holds more trials: Rook the stonewall and Juniper of the meadow. Beat them both and the Regional Trial will open."},
		{"speaker": "maren", "action": "unlock_codex:aether",
				"text": "Oh, and the Aether Circle beside the lodge is awake again. Fire and Wind mages pass through the valley — any champion can learn the Aether Arts."},
	],
	"chapter_one_complete": [
		{"speaker": "maren",
				"text": "The champion of the Home Valley! Keeper, the whole valley is talking about our little lodge."},
		{"speaker": "maren",
				"text": "But I did not ask you here only to save the lodge. Marla told me the Aether sites beyond Greenwood and Stonepass are failing. Wild creatures grow restless."},
		{"speaker": "maren",
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
