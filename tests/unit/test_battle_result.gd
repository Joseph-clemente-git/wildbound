extends TestCase
## Stage 19 of the battle simulation: the result, told from the simulated
## battle — what happened, what was learned, what comes next.


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	Game.profile.add_item("sword_training")
	Game.champion().weapon_id = "sword_training"
	Game.champion().skills.set_rank("weapon:sword", GameEnums.Rank.APPRENTICE)
	for flag in ["equipped_weapon", "trained_once", "first_trial_done"]:
		Game.set_flag(flag)


func _session(trial_id: String, seed_value: int) -> BattleSession:
	var trial := Content.trial(trial_id)
	TrialSystem.enter(Game.champion(), trial)
	return BattleSession.start(trial, Game.champion(), seed_value)


func _screen(session: BattleSession) -> Node:
	Router.params = {"outcome": session.result, "session": session}
	var screen: Node = load(Router.ROUTES["result"]).instantiate()
	root.add_child(screen)
	Router.params = {}
	return screen


func test_result_reports_the_simulated_fight() -> void:
	var session := _session("stonewall_bout", 31)
	var screen := _screen(session)
	var headline: Label = screen.find_child("Headline", true, false)
	check_eq(headline.text, "Victory" if session.outcome.player_won() else "Defeat")
	var report := screen.find_child("Report", true, false)
	check(report != null, "a fight report")
	var text := _all_text(report)
	for row in ["Damage dealt", "Damage received", "Successful attacks", "Dodges", "Blocks & parries", "Staggers & knockdowns", "Knocked out"]:
		check(text.contains(row), "reports " + row)
	check(text.contains("Bruno") and text.contains("Rook"))
	var me := session.outcome.side(0)
	check(text.contains(str(roundi(float(me["damage_dealt"])))), "with the real numbers")
	check(_all_text(screen).contains(session.result["how"]), "says how it ended")
	check(screen.find_child("WatchAgain", true, false) != null, "the battle can be watched again")
	var rook := Content.opponent("rook")
	var said: Label = screen.find_child("OpponentLine", true, false)
	check_eq(said.text, rook.win_line if session.outcome.player_won() else rook.lose_line, "the opponent's line fits the outcome")
	screen.free()


func test_next_step_follows_the_outcome() -> void:
	for seed_value in [31, 32, 33, 34, 35, 36]:
		Game.champion().knocked_out = false
		Game.champion().energy = 100.0
		var session := _session("stonewall_bout", seed_value)
		var screen := _screen(session)
		var next: Button = screen.find_child("Next", true, false)
		check(next != null)
		if session.result["knocked_out"]:
			check_eq(next.text, "Rest & recover", "a knocked-out champion rests first")
		else:
			check_eq(next.text, "Back to the Journey", "otherwise, on to the next fight")
		screen.free()


func test_moments_tell_the_story() -> void:
	var session := _session("stonewall_bout", 31)
	var moments: Array = session.result["moments"]
	check(not moments.is_empty())
	check(moments.size() <= BattleMoments.MAX_MOMENTS)
	check(" ".join(moments).contains("Biggest blow"), "the biggest blow is told")
	check(str(session.result["how"]).begins_with("by knockout at") or str(session.result["how"]).begins_with("on the judges"))


func test_comebacks_are_noticed() -> void:
	var battle_log := BattleLog.new()
	battle_log.header = {"combatants": [{"name": "Bruno"}, {"name": "Rook"}]}
	var outcome := BattleOutcome.new()
	outcome.winner_team = 0
	outcome.reason = "knockout"
	outcome.duration = 61.0
	outcome.fighters = [{"team": 0, "lowest_health_ratio": 0.12, "exhaustions": 0}, {"team": 1}]
	var lines := " ".join(BattleMoments.tell(battle_log, outcome))
	check(lines.contains("comeback"), lines)
	check_eq(BattleMoments.how_it_ended(outcome), "by knockout at 1:01")


func test_recruits_are_announced() -> void:
	var session := _session("lakeshore_challenge", 3)
	session.result["recruited"] = "Finn"
	var screen := _screen(session)
	check(screen.find_child("Recruited", true, false) != null)
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
