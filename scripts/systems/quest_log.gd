class_name QuestLog
extends RefCounted
## Chapter 1 objectives: the first quest that teaches the game through the
## story (story §16, §48). Each objective completes when its flag is set.

const CHAPTER_ONE := [
	{"flag": "inspected_champion", "station": "champion",
			"text": "Meet {champion}", "hint": "Tap {champion} in the lodge yard and choose Inspect."},
	{"flag": "viewed_skill_matrix", "station": "champion",
			"text": "Study the Skill Matrix", "hint": "Open {champion}'s Skill Matrix to see what they have learned."},
	{"flag": "met_first_trainer", "station": "trainers",
			"text": "Meet the Swordmaster at the Trainer Board", "hint": "A mentor is waiting at the Trainer Board."},
	{"flag": "trained_once", "station": "training",
			"text": "Train with Corin", "hint": "Visit the Training Yard and choose a skill for Corin to develop."},
	{"flag": "equipped_weapon", "station": "equipment",
			"text": "Equip the Lodge Sword", "hint": "Open the Equipment Hall at the bench and equip the sword."},
	{"flag": "first_trial_done", "station": "journey",
			"text": "Enter the First Steps Trial", "hint": "The Map Board lists the local trials."},
	{"flag": "rested_once", "station": "recovery",
			"text": "Let {champion} rest", "hint": "Champions recover energy at the Rest Area."},
	{"flag": "cleared_stonewall_bout", "station": "journey",
			"text": "Win the Stonewall Bout against Rook", "hint": "Rook guards like a wall. Heavy attacks and patience help."},
	{"flag": "cleared_meadow_sprint", "station": "journey",
			"text": "Win the Meadow Sprint Bout against Juniper", "hint": "Juniper dodges a lot. Punish the end of her attacks."},
	{"flag": "cleared_valley_regional", "station": "journey",
			"text": "Win the Home Valley Regional Trial", "hint": "Marla wields sword and Fire Aether. Prepare well."},
	{"flag": "chapter_one_complete", "station": "journey",
			"text": "Chapter 1 complete — the road beyond awaits", "hint": "New regions arrive in Chapter 2."},
]


## The first unfinished objective, or {} when the chapter is complete.
static func current() -> Dictionary:
	for objective: Dictionary in CHAPTER_ONE:
		if not Game.is_flag_set(objective["flag"]):
			return objective
	return {}


static func progress() -> Vector2i:
	var done := 0
	for objective: Dictionary in CHAPTER_ONE:
		if Game.is_flag_set(objective["flag"]):
			done += 1
	return Vector2i(done, CHAPTER_ONE.size())


static func text(objective: Dictionary, key: String = "text") -> String:
	return StoryDirector.format(str(objective.get(key, "")))
