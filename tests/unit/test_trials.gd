extends TestCase
## Trial entry, rewards, knockouts, story hooks and experience from a battle.


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	Game.profile.add_item("sword_training")
	Game.champion().weapon_id = "sword_training"


func _outcome(trial_id: String, won: bool, gains: Dictionary = {}) -> Dictionary:
	return {"trial_id": trial_id, "opponent_id": Content.trial(trial_id).opponent_id, "won": won,
			"forfeited": false, "duration": 70.0, "tallies": {}, "experience": gains, "growths": []}


func test_first_trial_requires_training_and_a_weapon() -> void:
	var trial := Content.trial("first_steps")
	check(not TrialSystem.is_unlocked(trial))
	Game.set_flag("equipped_weapon")
	Game.set_flag("trained_once")
	check(TrialSystem.is_unlocked(trial))
	check(not TrialSystem.is_unlocked(Content.trial("valley_regional")), "regional waits for both bouts")


func test_entry_costs_energy_and_respects_knockout() -> void:
	Game.set_flag("equipped_weapon")
	Game.set_flag("trained_once")
	var champion := Game.champion()
	var trial := Content.trial("first_steps")
	check_eq(TrialSystem.enter(champion, trial), "")
	check_eq(champion.energy, 100.0 - trial.energy_cost)
	ConditionSystem.knock_out(champion, Game.now())
	check(not TrialSystem.entry_blocker(champion, trial).is_empty())
	champion.knocked_out = false
	champion.energy = 5.0
	check(TrialSystem.entry_blocker(champion, trial).contains("energy"))


func test_victory_rewards_and_flags() -> void:
	var coins := Game.profile.coins
	var trial := Content.trial("first_steps")
	var result := TrialSystem.apply_result(_outcome("first_steps", true))
	check_eq(Game.profile.coins, coins + trial.coins + trial.first_clear_coins, "first victory bonus")
	check(Game.is_flag_set("first_trial_done"))
	check(Game.is_flag_set("cleared_first_steps"))
	check_eq(result["story"], "after_first_trial")
	check_eq(Game.champion().wins, 1)
	check(not Game.champion().knocked_out)
	var again := TrialSystem.apply_result(_outcome("first_steps", true))
	check_eq(again["coins"], trial.coins, "no bonus the second time")
	check_eq(again["story"], "", "story plays once")


func test_defeat_knocks_out_but_still_rewards_a_little() -> void:
	var coins := Game.profile.coins
	var result := TrialSystem.apply_result(_outcome("first_steps", false))
	check(Game.champion().knocked_out, "defeat is a knockout, never permanent")
	check(Game.profile.coins > coins, "a small purse for trying")
	check(Game.is_flag_set("first_trial_done"), "the tutorial trial counts either way")
	check(not Game.is_flag_set("cleared_first_steps"))
	check_eq(result["story"], "after_first_trial")
	check_eq(Game.champion().loss_streak, 1)


func test_regional_victory_completes_chapter_story() -> void:
	var result := TrialSystem.apply_result(_outcome("valley_regional", true))
	check_eq(result["story"], "chapter_one_complete")


func test_training_suggestion_points_at_a_mentor() -> void:
	TrainerManager.recruit(Game.profile, "swordmaster_corin", true)
	var suggestion := TrialSystem.suggest_training(Game.champion(), {"weapon:sword": 20.0, "evasion": 4.0})
	check_eq(suggestion["trainer"], "swordmaster_corin")
	check_eq(suggestion["target"], "weapon:sword")
	check(TrialSystem.suggest_training(Game.champion(), {"evasion": 2.0}).is_empty(), "nothing significant")


func test_recorded_battle_produces_experience() -> void:
	var battle := BattleManager.new()
	battle.auto_step = false
	root.add_child(battle)
	var hero := Combatant.new()
	hero.setup_from_champion(Game.champion())
	var foe := Combatant.new()
	foe.setup_from_opponent(Content.opponent("pip"))
	battle.add_child(hero)
	battle.add_child(foe)
	battle.setup(Content.arena("meadow_ring"), hero, foe)
	var trial := Content.trial("first_steps")
	var recorder := BattleRecorder.new(battle, Game.champion(), Content.opponent("pip"), trial)
	battle.ai = AiController.new(foe, Content.opponent("pip"), 11)
	battle.player_controller = AiController.new(hero, Content.opponent("juniper"), 12)
	battle.start()
	recorder.start()
	for i in 60 * 120:
		battle.step(1.0 / 60.0)
		if battle.finished:
			break
	var outcome := recorder.finish(battle.winner == hero)
	check(not outcome["experience"].is_empty(), "the fight taught something")
	check(outcome["tallies"]["hits"] + outcome["tallies"]["heavy_hits"] > 0)
	var result := TrialSystem.apply_result(outcome)
	check(result["coins"] > 0)
	check(Game.champion().experience.active_tracks().size() > 0)
	battle.free()
