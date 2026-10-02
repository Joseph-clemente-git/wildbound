extends TestCase
## Stage 5 of the battle simulation: preparing a champion for a specific
## opponent — the tactical read, build options and the prep screen.

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	for flag in ["equipped_weapon", "trained_once", "first_trial_done", "cleared_first_steps",
			"cleared_stonewall_bout", "cleared_meadow_sprint"]:
		Game.set_flag(flag)
	champion = Game.champion()
	for item_id in ["sword_training", "hammer_iron", "armor_medium", "armor_heavy"]:
		Game.profile.add_item(item_id)
	champion.weapon_id = "sword_training"
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.NOVICE)


func _analyse(opponent_id: String, overrides: Dictionary = {}, arena_id: String = "meadow_ring") -> MatchupAnalysis:
	return MatchupAnalysis.analyse(champion, Content.opponent(opponent_id), Content.arena(arena_id), overrides)


func test_reads_rook_like_a_keeper_would() -> void:
	var read := _analyse("rook")
	check_eq(read.opponent_strength, "Very High")
	check_eq(read.threat, "Heavy stagger")
	check_eq(read.main_advantage(), "Mobility")
	check_eq(read.main_risk(), "Close-range pressure")
	check(read.advantages.has("Punishing slow recoveries"), "advantages: %s" % [read.advantages])
	check(read.risks.has("Breaking through their guard"), "risks: %s" % [read.risks])


func test_build_changes_the_read() -> void:
	var light := _analyse("rook")
	var heavy := _analyse("rook", {"armor_id": "armor_heavy"})
	check(MatchupAnalysis.axis_rank(heavy.you, "Defense") > MatchupAnalysis.axis_rank(light.you, "Defense"))
	check(light.risks.has("Close-range pressure"))
	check(not heavy.risks.has("Close-range pressure"), "heavier armor answers close-range pressure")
	var effects := " ".join(MatchupAnalysis.option_effects(champion, {"armor_id": "armor_heavy"}))
	check(effects.contains("Defense ↑") and effects.contains("Mobility ↓"), "effects: %s" % effects)
	var medium := " ".join(MatchupAnalysis.option_effects(champion, {"armor_id": "armor_medium"}))
	check(effects.length() > medium.length(), "plate is a bigger trade than leather: %s vs %s" % [effects, medium])
	var hammer := MatchupAnalysis.option_effects(champion, {"weapon_id": "hammer_iron"})
	check(" ".join(hammer).contains("Strength ↑"), "effects: %s" % [hammer])
	check(MatchupAnalysis.option_effects(champion, {"weapon_id": "sword_training"}).is_empty(), "same build, no change")


func test_skill_matrix_shapes_the_read() -> void:
	champion.weapon_id = "hammer_iron"
	check(_analyse("rook", {}).risks.has("Untrained with the Hammer"), "an unlearned weapon is a risk")
	champion.weapon_id = "sword_training"
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.EXPERT)
	check(_analyse("rook").advantages.has("Better weapon technique"))
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.NOVICE)
	check(_analyse("marla").risks.has("Less weapon technique"), "Marla is a Skilled swordfighter")


func test_magic_answers_range() -> void:
	check(_analyse("marla").risks.has("Being worn down from range"))
	champion.skills.set_rank("magic:fire", GameEnums.Rank.APPRENTICE)
	var with_fire := _analyse("marla", {"ability_id": "ember_bolt"})
	check(not with_fire.risks.has("Being worn down from range"), "a ranged Art answers a ranged threat")
	check_eq(with_fire.you.combat_range, "Long")
	champion.skills.set_rank("magic:fire", GameEnums.Rank.NONE)
	check_eq(_analyse("marla", {"ability_id": "ember_bolt"}).you.combat_range, "Medium", "an unlearned Art does nothing")


func test_arena_matters() -> void:
	var tight := Content.arena("meadow_ring").duplicate() as ArenaData
	tight.radius = 7.0
	var read := MatchupAnalysis.analyse(champion, Content.opponent("rook"), tight)
	check(read.risks.has("Tight ring: little room to escape pressure"), "risks: %s" % [read.risks])
	var wide := Content.arena("meadow_ring").duplicate() as ArenaData
	wide.radius = 18.0
	read = MatchupAnalysis.analyse(champion, Content.opponent("rook"), wide)
	check(read.advantages.has("Room to outmanoeuvre"), "advantages: %s" % [read.advantages])


func test_no_win_chance_anywhere() -> void:
	for opponent: OpponentData in Content.list("opponents"):
		var read := _analyse(opponent.id)
		var words := [read.opponent_strength, read.threat, read.main_advantage(), read.main_risk()]
		words.append_array(read.advantages)
		words.append_array(read.risks)
		for word: String in words:
			check(not RegEx.create_from_string("[0-9%]").search(word), "%s read leaks a number: %s" % [opponent.id, word])


func test_prep_screen_prepares_for_the_opponent() -> void:
	var screen := _open("stonewall_bout")
	var tactical := _all_text(screen.find_child("Tactical", true, false))
	for expected in ["Opponent Strength", "Very High", "Threat", "Heavy stagger", "Your Advantage", "Mobility",
			"Main Risk", "Close-range pressure"]:
		check(tactical.contains(expected), "tactical card shows " + expected)
	check(not RegEx.create_from_string("[0-9%]").search(tactical), "no numbers in the tactical read")
	var text := _all_text(screen)
	for banned in ["Difficulty", "Even match", "Very difficult", "chance", "Change build"]:
		check(not text.contains(banned), "prep no longer shows: " + banned)
	check(text.contains("Skill Matrix: Sword Novice"), "the relevant weapon mastery is shown")
	check(screen.find_child("Option_hammer_iron", true, false) != null, "owned weapons can be chosen here")
	check(screen.find_child("Option_armor_heavy", true, false) != null)
	check(screen.find_child("Option_none", true, false) != null, "fighting without an Art is a choice")
	screen.equip_item("armor_heavy")
	check_eq(champion.armor_id, "armor_heavy", "equipping from prep changes the champion's build")
	check_eq(screen.analysis.you.armor_weight, "Heavy", "and the read follows")
	screen.equip_item("hammer_iron")
	check_eq(champion.weapon_id, "hammer_iron")
	check(screen.analysis.risks.has("Untrained with the Hammer"))
	screen.free()


func test_prep_offers_learned_arts_only() -> void:
	var screen := _open("valley_regional")
	check(screen.find_child("Option_ember_bolt", true, false) == null, "Fire not learned yet")
	screen.free()
	champion.skills.set_rank("magic:fire", GameEnums.Rank.APPRENTICE)
	screen = _open("valley_regional")
	check(screen.find_child("Option_ember_bolt", true, false) != null)
	screen.equip_magic("ember_bolt")
	check_eq(champion.equipped_ability, "ember_bolt")
	check(not screen.analysis.risks.has("Being worn down from range"))
	screen.equip_magic("")
	check_eq(champion.equipped_ability, "")
	screen.free()


func _open(trial_id: String) -> Node:
	Router.params = {"trial": trial_id, "champion": champion.uid}
	var screen: Node = load(Router.ROUTES["battle_prep"]).instantiate()
	root.add_child(screen)
	Router.params = {}
	return screen


func _all_text(node: Node) -> String:
	if node == null:
		return ""
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	if node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_all_text(child))
	return "\n".join(parts)
