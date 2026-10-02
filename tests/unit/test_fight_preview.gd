extends TestCase
## Stage 3 of the battle simulation: the Opponent Preview between choosing a
## fight and choosing a champion.


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	for flag in ["equipped_weapon", "trained_once", "first_trial_done", "cleared_first_steps",
			"cleared_stonewall_bout", "cleared_meadow_sprint"]:
		Game.set_flag(flag)


func _open(trial_id: String) -> Node:
	Router.params = {"trial": trial_id}
	var screen: Node = load(Router.ROUTES["fight_preview"]).instantiate()
	root.add_child(screen)
	Router.params = {}
	return screen


func test_preview_answers_who_why_and_where() -> void:
	for trial: TrialData in ChallengeBoard.fights("home_valley"):
		var screen := _open(trial.id)
		var text := _all_text(screen)
		var opponent := Content.opponent(trial.opponent_id)
		check(text.contains(opponent.display_name), trial.id + ": who")
		check(text.contains(trial.reason), trial.id + ": why")
		check(text.contains(Content.arena(trial.arena_id).display_name), trial.id + ": where")
		check(text.contains(trial.challenge_type_name().to_upper()), trial.id + ": what kind of fight")
		for key in ["Animal", "Movement", "Capability", "Weapon", "Armor", "Magic",
				"Strength", "Defense", "Mobility", "Range"]:
			check(text.contains(key), "%s: shows %s" % [trial.id, key])
		check(screen.find_child("Continue", true, false) != null, trial.id + ": leads on to champion selection")
		screen.free()


func test_preview_matches_the_scouting_report() -> void:
	var screen := _open("stonewall_bout")
	var report := ScoutingReport.for_opponent(Content.opponent("rook"))
	var text := _all_text(screen)
	check(text.contains(report.strength) and text.contains(report.mobility))
	for threat in report.threats:
		check(text.contains(threat), "threat shown: " + threat)
	for opening in report.openings:
		check(text.contains(opening), "opening shown: " + opening)
	for feature in Content.arena("meadow_ring").features():
		check(text.contains(feature), "arena feature shown: " + feature)
	screen.free()


func test_preview_hides_exact_numbers() -> void:
	for trial: TrialData in ChallengeBoard.fights("home_valley"):
		var screen := _open(trial.id)
		var scouting := screen.find_child("Scouting", true, false)
		var watch := screen.find_child("Watch", true, false)
		check(scouting != null and watch != null, trial.id + ": scouting sections exist")
		var hidden := _all_text(scouting) + _all_text(watch)
		check(not RegEx.create_from_string("[0-9%]").search(hidden), "%s leaks numbers: %s" % [trial.id, hidden])
		var text := _all_text(screen)
		for banned in ["Level", "Health", "Evasion", "Endurance", "Attack Speed", "chance", "Even match", "Difficulty"]:
			check(not text.contains(banned), "%s preview exposes '%s'" % [trial.id, banned])
		screen.free()


func test_arena_describes_itself() -> void:
	var meadow := Content.arena("meadow_ring")
	check_eq(meadow.features().size(), 2)
	var tight := ArenaData.new()
	tight.radius = 7.0
	check(tight.features()[0].begins_with("Tight"), "small arenas favour pressure")
	check(tight.features()[1].contains("no cover"))
	var wide := ArenaData.new()
	wide.radius = 18.0
	for i in 6:
		wide.obstacles.append(Vector4(i, i, 0.5, 1.0))
	check(wide.features()[0].begins_with("Wide"))
	check(wide.features()[1].begins_with("Many"))


func test_magic_shows_on_the_opponent() -> void:
	var screen := _open("valley_regional")
	var text := _all_text(screen)
	check(text.contains("Fire"), "Marla's school is visible")
	check(text.contains("Fire attacks from range"))
	screen.free()


func _all_text(node: Node) -> String:
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	if node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_all_text(child))
	return "\n".join(parts)
