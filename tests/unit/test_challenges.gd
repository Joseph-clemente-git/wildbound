extends TestCase
## Stage 2 of the battle simulation: the Journey's fight board. The player
## chooses the fight; the board only knows what the story has opened.


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")


func test_every_fight_is_complete() -> void:
	for trial: TrialData in Content.list("trials"):
		check(trial.challenge_type >= 0 and trial.challenge_type < GameEnums.CHALLENGE_TYPE_NAMES.size(),
				trial.id + " has an unknown challenge type")
		check(not trial.reason.is_empty(), trial.id + " must say why the Keeper would fight it")
		check(Content.opponent(trial.opponent_id) != null, trial.id + " opponent")
		check(Content.arena(trial.arena_id) != null, trial.id + " arena")
		check(Content.region(trial.region_id) != null, trial.id + " region")
		for flag in trial.requires_flags:
			check(not ChallengeBoard.requirement_text(flag).contains("_"), "%s: '%s' needs plain words" % [trial.id, flag])


func test_challenge_types_are_open_for_later_modes() -> void:
	check_eq(GameEnums.CHALLENGE_TYPE_NAMES.size(), GameEnums.ChallengeType.size())
	check_eq(GameEnums.challenge_type_name(GameEnums.ChallengeType.WILD_ENCOUNTER), "Wild Encounter")
	check_eq(Content.trial("first_steps").challenge_type_name(), "Local Trial")
	check_eq(Content.trial("valley_regional").challenge_type_name(), "Regional Trial")


func test_regions_list_open_ones_first() -> void:
	var regions := ChallengeBoard.regions()
	check_eq(regions.size(), Content.list("regions").size(), "every region is listed")
	check_eq(regions[0].id, "home_valley")
	check(ChallengeBoard.is_region_open(regions[0]))
	check(not ChallengeBoard.is_region_open(Content.region("greenwood")), "later chapters stay closed")
	check_eq(ChallengeBoard.fights("home_valley").size(), 4)
	check_eq(ChallengeBoard.fights("home_valley")[0].id, "first_steps", "board order")
	check(ChallengeBoard.fights("greenwood").is_empty())


func test_status_follows_the_story() -> void:
	var first := Content.trial("first_steps")
	check_eq(ChallengeBoard.status(first), ChallengeBoard.Status.LOCKED)
	check(not ChallengeBoard.can_select(first))
	var needs := ChallengeBoard.requirements(first)
	check(needs.has("equip a weapon") and needs.has("train once"), "requirements: %s" % [needs])
	Game.set_flag("equipped_weapon")
	Game.set_flag("trained_once")
	check_eq(ChallengeBoard.status(first), ChallengeBoard.Status.AVAILABLE)
	check(ChallengeBoard.can_select(first))
	check_eq(ChallengeBoard.open_count("home_valley"), 1)
	Game.set_flag(first.cleared_flag())
	Game.set_flag("first_trial_done")
	check_eq(ChallengeBoard.status(first), ChallengeBoard.Status.CLEARED)
	check(ChallengeBoard.can_select(first), "repeatable fights can be fought again")
	check_eq(ChallengeBoard.open_count("home_valley"), 2, "both valley bouts open")
	var regional := Content.trial("valley_regional")
	check(ChallengeBoard.requirements(regional).has("win the Stonewall Bout"))


func test_one_time_fights_complete() -> void:
	var story := Content.trial("first_steps").duplicate() as TrialData
	story.repeatable = false
	story.requires_flags = PackedStringArray()
	check(ChallengeBoard.can_select(story))
	Game.set_flag(story.cleared_flag())
	check_eq(ChallengeBoard.status(story), ChallengeBoard.Status.COMPLETED)
	check(not ChallengeBoard.can_select(story))


func test_selection_does_not_depend_on_the_champion() -> void:
	Game.set_flag("equipped_weapon")
	Game.set_flag("trained_once")
	ConditionSystem.knock_out(Game.champion(), Game.now())
	Game.champion().energy = 0.0
	check(ChallengeBoard.can_select(Content.trial("first_steps")),
			"the fight is chosen first; champion readiness is checked when choosing who enters")


func test_journey_screen_lists_fights() -> void:
	Game.set_flag("equipped_weapon")
	Game.set_flag("trained_once")
	Game.set_flag("first_trial_done")
	Game.set_flag("cleared_first_steps")
	Router.params = {"region": "home_valley"}
	var screen: Control = load(Router.ROUTES["journey"]).instantiate()
	root.add_child(screen)
	check_eq(screen.selected_region, "home_valley")
	var cards: Array = screen._fights.get_children()
	check_eq(cards.size(), 4, "one card per fight")
	check(screen._fights.find_child("Fight_stonewall_bout", true, false).find_child("Select", true, false) != null,
			"an open fight can be selected")
	check(screen._fights.find_child("Fight_valley_regional", true, false).find_child("Select", true, false) == null,
			"a locked fight cannot")
	var text: String = _all_text(screen._fights)
	check(text.contains("Rook"), "the card says who you would face")
	check(text.contains("LOCAL TRIAL") and text.contains("REGIONAL TRIAL"))
	for banned in ["Even match", "Stronger", "Much weaker", "Very difficult", "%"]:
		check(not text.contains(banned), "no power comparison on the fight board: " + banned)
	screen.select_region("greenwood")
	check(_all_text(screen._fights).contains("Chapter 2"), "a closed region explains when it opens")
	check(screen._fights.find_child("Select", true, false) == null)
	screen.free()
	Router.params = {}


func _all_text(node: Node) -> String:
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	if node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_all_text(child))
	return "\n".join(parts)
