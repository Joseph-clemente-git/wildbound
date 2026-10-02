extends TestCase
## Stage 18 of the battle simulation: the battle session and its 3D replay.


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	Game.profile.add_item("sword_training")
	Game.champion().weapon_id = "sword_training"
	Game.champion().skills.set_rank("weapon:sword", GameEnums.Rank.APPRENTICE)
	for flag in ["equipped_weapon", "trained_once", "first_trial_done"]:
		Game.set_flag(flag)


func _session(trial_id: String = "stonewall_bout") -> BattleSession:
	var trial := Content.trial(trial_id)
	check_eq(TrialSystem.enter(Game.champion(), trial), "")
	return BattleSession.start(trial, Game.champion(), 31)


func test_session_decides_and_applies_up_front() -> void:
	var coins := Game.profile.coins
	var session := _session()
	check(session.state.finished, "the whole battle is simulated before anything is shown")
	check(session.result.has("coins"), "and the result is already applied")
	check(Game.profile.coins > coins)
	check_eq(session.result["won"], session.outcome.player_won())
	check_eq(Game.champion().history[0]["trial_id"], "stonewall_bout", "the bout is on record")
	if not session.outcome.player_won():
		check(Game.champion().knocked_out, "a defeat is a knockout, whether or not it is watched")
	check_eq(session.result["simulation"]["reason"], session.outcome.reason)


func test_timeline_interpolates_between_keyframes() -> void:
	var session := _session()
	var timeline := ReplayTimeline.new(session.battle_log)
	check_near(timeline.duration, session.outcome.duration, 0.001)
	check_eq(timeline.combatant_count(), 2)
	var a: Dictionary = timeline.keyframes[10]
	var b: Dictionary = timeline.keyframes[11]
	var middle := (float(a["time"]) + float(b["time"])) * 0.5
	var sample: Dictionary = timeline.sample(middle)[0]
	var expected := ReplayTimeline._vec(a["combatants"][0]["position"]).lerp(ReplayTimeline._vec(b["combatants"][0]["position"]), 0.5)
	check(sample["position"].distance_to(expected) < 0.001, "halfway between keyframes")
	check_eq(timeline.sample(-1.0)[0]["position"], ReplayTimeline._vec(timeline.keyframes[0]["combatants"][0]["position"]))
	var end := timeline.sample(timeline.duration + 5.0)
	check_eq(end.size(), 2, "clamps past the end")


func test_timeline_events_and_action_spans() -> void:
	var session := _session()
	var timeline := ReplayTimeline.new(session.battle_log)
	var all := timeline.events_between(-1.0, timeline.duration)
	check_eq(all.size(), session.battle_log.events.size(), "every event plays exactly once")
	var halves := timeline.events_between(-1.0, timeline.duration * 0.5).size() \
			+ timeline.events_between(timeline.duration * 0.5, timeline.duration).size()
	check_eq(halves, all.size(), "no event lost or doubled across windows")
	var first_swing := {}
	for event in session.battle_log.events:
		if event["type"] == "action_start" and event["actor"] == 0 and event["action"] == "attack":
			first_swing = event
			break
	check(not first_swing.is_empty(), "Bruno swung")
	var span := timeline.span_at(0, float(first_swing["time"]) + 0.01)
	check_eq(span.get("action", ""), "attack")
	check(float(span["end"]) > float(span["start"]), "with its real length")


func _replay(session: BattleSession) -> Node3D:
	Router.params = {"session": session}
	var screen: Node3D = load(Router.ROUTES["replay"]).instantiate()
	root.add_child(screen)
	Router.params = {}
	return screen


func test_replay_plays_controls_and_finishes() -> void:
	var session := _session()
	var screen := _replay(session)
	check_eq(screen.visuals.size(), 2, "both combatants have bodies")
	check(screen.find_child("Speed4", true, false) != null and screen.find_child("Skip", true, false) != null)
	screen.set_speed(4.0)
	check_eq(screen.speed, 4.0)
	screen.toggle_pause()
	check(screen.paused)
	screen.toggle_pause()
	screen.advance(2.0)
	var start: Vector2 = ReplayTimeline._vec(session.battle_log.keyframes[0]["combatants"][0]["position"])
	var moved: Vector3 = screen.visuals[0].position
	check(Vector2(moved.x, moved.z).distance_to(start) > 0.1, "bodies follow the simulation")
	screen.advance(session.outcome.duration + 1.0)
	check(screen.finished)
	check(screen._banner.visible, "the outcome is announced")
	var title: Label = screen._banner.find_child("Title", true, false)
	check_eq(title.text, "Victory" if session.outcome.player_won() else ("Draw" if session.outcome.winner_team < 0 else "Defeat"))
	screen.restart()
	check_eq(screen.time, 0.0)
	check(not screen.finished and not screen._banner.visible, "watch it again")
	screen.free()


func test_replays_show_projectiles_and_new_bodies() -> void:
	var session := _session("ridge_challenge")
	var screen := _replay(session)
	check(screen.visuals[1] is ProceduralEagleVisual, "Aquila has its own body")
	var flew := false
	var step := 0.1
	var t := 0.0
	while t < session.outcome.duration:
		screen.advance(step)
		t += step
		if screen.visuals[1].position.y > 1.0:
			flew = true
			break
	check(flew, "the eagle is shown aloft")
	screen.free()


func test_prep_starts_the_simulation() -> void:
	Router.params = {"trial": "stonewall_bout", "champion": Game.champion().uid}
	var prep: Node = load(Router.ROUTES["battle_prep"]).instantiate()
	root.add_child(prep)
	Router.params = {}
	var energy := Game.champion().energy
	var session: BattleSession = prep.start_simulation()
	check(session != null)
	check_eq(Game.champion().energy, energy - Content.trial("stonewall_bout").energy_cost, "entry is paid")
	check(session.state.finished)
	prep.free()
