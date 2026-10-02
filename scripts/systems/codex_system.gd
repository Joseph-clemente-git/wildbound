class_name CodexSystem
extends RefCounted
## The Codex unlocks gradually as the journey reveals the world (story §32).

const LORE := {
	"aether": {"title": "Aether", "category": "Aether",
			"text": "The ancient energy that flows along the old paths. Champions channel it to strengthen body and spirit. Aether is a learnable discipline, not a species gift: any animal can study any school."},
	"grand_trials": {"title": "The Grand Trials", "category": "Stories",
			"text": "Organized contests where champions prove their skill. Defeat means a knockout, never worse — the Trials began as peaceful festivals between communities."},
	"lodge": {"title": "The Training Lodge", "category": "Stories",
			"text": "Old Maren's lodge has trained valley champions for three generations. A lodge can keep only a small circle of active mentors; as its reputation grows, so does that circle."},
	"wildbound": {"title": "The Age of the Wildbound", "category": "Stories",
			"text": "Long ago, animals who first channelled Aether were called the Wildbound. Their paths still connect the regions — and lately, those paths have grown quiet."},
}


static func unlock(entry_id: String) -> void:
	if Game.profile != null and Game.profile.unlock_codex(entry_id):
		Game.say("Codex updated.", UiTheme.AETHER)
		Game.set_flag("codex_unlocked")


## All visible entries grouped by category: {category: [{title, text}]}.
static func entries() -> Dictionary:
	var result := {}
	var profile := Game.profile
	for entry_id: String in LORE:
		if profile.codex.has(entry_id) or entry_id in ["grand_trials", "lodge", "wildbound"]:
			_add(result, LORE[entry_id]["category"], LORE[entry_id]["title"], LORE[entry_id]["text"])
	for champion in Game.champions:
		var animal := champion.data()
		_add(result, "Animals", animal.display_name,
				"%s\n\nStrengths: %s\nWeaknesses: %s\nCounterplay: %s" % [animal.description,
				", ".join(animal.strengths), ", ".join(animal.weaknesses), ", ".join(animal.counterplay)])
	for trainer in TrainerManager.owned(profile):
		_add(result, "Mentors", "%s — %s" % [trainer.display_name, trainer.title], trainer.description)
	for item_id in profile.owned_items:
		var item := Content.equipment(item_id)
		_add(result, "Equipment", item.display_name, item.description)
	for school: MagicSchoolData in Content.list("magic"):
		if profile.codex.has("aether") and school.available:
			_add(result, "Aether Arts", school.display_name, "%s\n\n%s" % [school.description, school.lore])
	for region: RegionData in Content.list("regions"):
		if profile.is_flag_set("world_map_unlocked"):
			var known := profile.is_flag_set(region.unlock_flag)
			_add(result, "Regions", region.display_name if known else region.display_name + " (rumoured)",
					region.description)
	for opponent: OpponentData in Content.list("opponents"):
		if _has_met(opponent.id):
			_add(result, "Rivals", "%s — %s" % [opponent.display_name, opponent.title], opponent.intro_line)
	var records := PackedStringArray()
	for champion in Game.champions:
		records.append("%s: %d wins, %d losses" % [champion.name, champion.wins, champion.losses])
		for entry: Dictionary in champion.history:
			records.append("  • %s — %s" % [entry.get("trial", "?"), "Victory" if entry.get("won", false) else "Defeat"])
	_add(result, "Battle Records", "Trial history", "\n".join(records))
	return result


static func _has_met(opponent_id: String) -> bool:
	for champion in Game.champions:
		for entry: Dictionary in champion.history:
			if entry.get("opponent", "") == opponent_id:
				return true
	return false


static func _add(result: Dictionary, category: String, title: String, text: String) -> void:
	if not result.has(category):
		result[category] = []
	result[category].append({"title": title, "text": text})
