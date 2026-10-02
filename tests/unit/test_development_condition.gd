extends TestCase
## Stages 22-23 of the battle simulation: the mentors read the fight and point
## at development their trainers can give; energy and happiness lightly shape
## the fight and change after it.

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.APPRENTICE)


func _tally(values: Dictionary, team: int, health_ratio: float) -> Dictionary:
	var tally := {"team": team, "health_ratio": health_ratio}
	for key: String in BattleOutcome.TALLIES:
		tally[key] = 0
	tally.merge(values, true)
	return tally


func _simulation(won: bool, mine: Dictionary, theirs: Dictionary = {}, foe_health: float = 0.5) -> Dictionary:
	return {"winner_team": 0 if won else 1, "fighters": [
		_tally(mine, 0, 0.6 if won else 0.0), _tally(theirs, 1, 0.0 if won else foe_health)]}


# --- Stage 22: trainer development -----------------------------------------------

func test_review_reads_strengths_and_weaknesses_from_the_fight() -> void:
	var review := BattleReview.review(champion, Game.profile, _simulation(false,
			{"exhaustions": 2, "dodges": 4, "whiffs": 3, "blows_evaded_by_foe": 3, "hits_landed": 2},
			{"hits_landed": 7}), {})
	var weak := _texts(review["weaknesses"])
	var strong := _texts(review["strengths"])
	check(weak.contains("ran out of breath 2 times"), weak)
	check(weak.contains("dodged, blocked or missed"), weak)
	check(strong.contains("dodged 4 times"), strong)
	check(not weak.contains("little answer"), "four dodges against seven blows is an answer: %s" % weak)


func test_a_defeat_points_at_the_fix_with_an_owned_trainer() -> void:
	TrainerManager.recruit(Game.profile, "swordmaster_corin", true)
	TrainerManager.recruit(Game.profile, "endurance_tamsin", true)
	var review := BattleReview.review(champion, Game.profile, _simulation(false,
			{"exhaustions": 1, "dodges": 4}), {"endurance": 6.0})
	var suggestion: Dictionary = review["suggestion"]
	check_eq(suggestion.get("trainer", ""), "endurance_tamsin", "the stamina problem goes to Tamsin")
	check_eq(suggestion.get("target", ""), "stat:endurance")
	check_eq(suggestion.get("track", ""), "endurance")
	check(str(suggestion.get("reason", "")).contains("ran out of breath"))


func test_a_victory_builds_on_what_worked() -> void:
	TrainerManager.recruit(Game.profile, "swordmaster_corin", true)
	TrainerManager.recruit(Game.profile, "endurance_tamsin", true)
	var review := BattleReview.review(champion, Game.profile, _simulation(true,
			{"exhaustions": 1, "openings_punished": 3}), {})
	check_eq(review["suggestion"].get("trainer", ""), "swordmaster_corin")
	check_eq(review["suggestion"].get("target", ""), "skill:timing")


func test_only_trainers_the_keeper_has_are_suggested() -> void:
	var review := BattleReview.review(champion, Game.profile, _simulation(false, {"exhaustions": 2}), {})
	for trainer_id in Game.profile.owned_trainers:
		check(trainer_id != "endurance_tamsin")
	check(review["suggestion"].get("trainer", "") != "endurance_tamsin", "Tamsin is not at the lodge")


func test_suggestion_tells_what_banked_experience_training_converts() -> void:
	TrainerManager.recruit(Game.profile, "endurance_tamsin", true)
	champion.experience.add("endurance", 30.0)
	var review := BattleReview.review(champion, Game.profile, _simulation(false, {"exhaustions": 1}), {})
	check_near(float(review["suggestion"]["banked"]), 30.0, 0.01)


func test_simulated_results_carry_the_review() -> void:
	TrainerManager.recruit(Game.profile, "swordmaster_corin", true)
	var trial := Content.trial("stonewall_bout")
	TrialSystem.enter(champion, trial)
	var result := BattleSession.start(trial, champion, 17).result
	check(result.has("review"), "the mentors read the fight")
	var review: Dictionary = result["review"]
	check(not (review["strengths"] as Array).is_empty() or not (review["weaknesses"] as Array).is_empty(),
			"something worth saying")
	Router.params = {"outcome": result}
	var screen: Node = load(Router.ROUTES["result"]).instantiate()
	root.add_child(screen)
	Router.params = {}
	check(screen.find_child("MentorNotes", true, false) != null, "shown on the result screen")
	screen.free()


# --- Stage 23: energy and happiness ----------------------------------------------

func test_energy_trims_stamina_only_when_tired() -> void:
	check_eq(ConditionEffects.stamina_factor(100.0), 1.0)
	check_eq(ConditionEffects.stamina_factor(50.0), 1.0, "rested enough")
	check_near(ConditionEffects.stamina_factor(0.0), ConditionEffects.TIRED_STAMINA, 0.001)
	champion.energy = 100.0
	var rested := CombatantSpec.from_champion(champion)
	champion.energy = 10.0
	var tired := CombatantSpec.from_champion(champion)
	check(tired.derived.max_stamina < rested.derived.max_stamina, "a tired champion has less breath")
	check(tired.derived.stamina_regen < rested.derived.stamina_regen, "and recovers it slower")
	check(tired.derived.max_stamina > rested.derived.max_stamina * 0.8, "but only a little")
	check_eq(tired.derived.damage, rested.derived.damage, "energy does not change how hard it hits")


func test_happiness_is_composure() -> void:
	champion.happiness = 65.0
	var content := CombatantSpec.from_champion(champion)
	champion.happiness = 75.0
	var also_content := CombatantSpec.from_champion(champion)
	check_eq(DecisionPhase.reaction_time(content), DecisionPhase.reaction_time(also_content), "no change inside the band")
	champion.happiness = 10.0
	var unhappy := CombatantSpec.from_champion(champion)
	champion.happiness = 100.0
	var delighted := CombatantSpec.from_champion(champion)
	check(DecisionPhase.reaction_time(unhappy) > DecisionPhase.reaction_time(content), "an unhappy champion hesitates")
	check(DecisionPhase.timing_error(unhappy) > DecisionPhase.timing_error(content))
	check(DecisionPhase.reaction_time(delighted) < DecisionPhase.reaction_time(content), "high spirits sharpen")
	check(DecisionPhase.reaction_time(unhappy) < DecisionPhase.reaction_time(content) * 1.15, "lightly")


func test_condition_applies_to_opponents_too() -> void:
	var opponent := Content.opponent("rook").duplicate() as OpponentData
	var fresh := CombatantSpec.from_opponent(opponent)
	opponent.energy = 0.0
	opponent.happiness = 0.0
	var worn := CombatantSpec.from_opponent(opponent)
	check(worn.derived.max_stamina < fresh.derived.max_stamina)
	check(DecisionPhase.reaction_time(worn) > DecisionPhase.reaction_time(fresh))


func test_condition_is_never_decisive_alone() -> void:
	# The same fight, rested and content vs tired and low: the outcome may
	# shift, but a champion's build still carries it most of the time.
	var wins := [0, 0]
	for variant in 2:
		for seed_value in 8:
			before_each()
			Game.profile.add_item("sword_training")
			champion.energy = 100.0 if variant == 0 else 5.0
			champion.happiness = 70.0 if variant == 0 else 20.0
			var state := BattleState.for_fight(Content.trial("first_steps"), champion, 500 + seed_value)
			var sim := BattleSimulator.create(state)
			sim.run()
			if sim.outcome().player_won():
				wins[variant] += 1
	check(wins[1] <= wins[0], "condition never helps: %s" % [wins])
	check(wins[0] - wins[1] <= 4, "and it nudges rather than decides: %s" % [wins])


func test_battles_change_condition_by_how_they_went() -> void:
	var trial := Content.trial("stonewall_bout")
	champion.energy = 80.0
	champion.happiness = 70.0
	var result := TrialSystem.apply_result({"trial_id": trial.id, "opponent_id": trial.opponent_id, "won": false,
			"forfeited": false, "duration": 130.0, "experience": {}, "growths": [], "fatigue": 6.0, "spirit": -2.0})
	check_near(champion.energy, 74.0, 0.01, "a long, breathless fight tires")
	check_near(float(result["happiness"]), float(Content.config.happiness_loss) - 2.0, 0.01, "a one-sided loss stings")
	check_eq(ConditionEffects.battle_fatigue(30.0, 0), 0.0, "a short, steady fight costs only its entry")
	check(ConditionEffects.battle_fatigue(150.0, 3) <= 8.0, "fatigue is capped")
	check(ConditionEffects.spirit(false, 0.7, 0.0) > 0.0, "a hard-fought loss stings less")
	check(ConditionEffects.spirit(false, 0.05, 0.0) < 0.0)
	check(ConditionEffects.spirit(true, 1.0, 0.9) > 0.0, "a clean win lifts")


func test_prep_shows_the_condition() -> void:
	champion.energy = 40.0
	check(ConditionEffects.notes(15.0, 70.0).size() == 1, "tired")
	check(ConditionEffects.notes(80.0, 20.0)[0].contains("Low mood"))
	check(ConditionEffects.notes(80.0, 70.0).is_empty(), "nothing to say when fine")
	var notes := ChampionSelection.notes(champion, Content.trial("stonewall_bout"))
	check(", ".join(notes).contains("tired"), ", ".join(notes))


func _texts(lessons: Array) -> String:
	var parts := PackedStringArray()
	for lesson: Dictionary in lessons:
		parts.append(str(lesson["text"]))
	return " | ".join(parts)
