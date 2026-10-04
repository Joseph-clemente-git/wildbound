extends TestCase
## Stage 24 of the battle simulation: battles, recruits and natural skills
## survive saving; saved battles replay identically; old saves migrate.

const TEST_SAVE := "user://test_saved_battles.json"

var champion: Champion


func before_each() -> void:
	Game.autosave = true
	Saves.path_override = TEST_SAVE
	Saves.delete_save()
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.APPRENTICE)


func after_each() -> void:
	Saves.delete_save()
	Saves.path_override = ""
	Game.autosave = false


func _fight(trial_id: String, seed_value: int) -> BattleSession:
	var trial := Content.trial(trial_id)
	champion.energy = 100.0
	champion.knocked_out = false
	TrialSystem.enter(champion, trial)
	return BattleSession.start(trial, champion, seed_value)


func _reload() -> void:
	Game.save()
	Game.close_journey()
	check(Game.continue_journey(), "the save loads")
	champion = Game.champion()


func test_specs_survive_a_round_trip() -> void:
	champion.happiness = 33.0
	champion.energy = 21.0
	var spec := CombatantSpec.from_champion(champion)
	var plain: Dictionary = JSON.parse_string(JSON.stringify(BattleRecord.pack(_log_of(spec))))["combatants"][0]
	var back := CombatantSpec.from_dict(plain)
	var original := spec.to_dict()
	var restored := back.to_dict()
	for key in ["id", "animal", "weapon", "armor", "ability", "movement", "battle_experience", "weapon_mastery"]:
		check_eq(str(restored[key]), str(original[key]), key)
	for group in ["stats", "skills", "tendencies"]:
		for entry: String in original[group]:
			check_near(float(restored[group][entry]), float(original[group][entry]), 0.0001, "%s %s" % [group, entry])
	check_near(back.derived.max_stamina, spec.derived.max_stamina, 0.001, "condition included")
	check_near(back.derived.damage, spec.derived.damage, 0.001)
	check(back.palette.get("fur", Color.BLACK).is_equal_approx(spec.palette.get("fur", Color.BLACK)) \
			or (back.palette["fur"] as Color).to_html() == (spec.palette["fur"] as Color).to_html(), "colours restored")


func test_a_saved_battle_replays_identically() -> void:
	var session := _fight("stonewall_bout", 77)
	_reload()
	var entry: Dictionary = champion.history[0]
	check(BattleRecord.has_replay(entry), "the latest battle keeps its replay")
	var again := BattleRecord.rewatch(entry)
	check(again != null)
	check(again.rewatch, "watching only")
	check_eq(again.outcome.winner_team, session.outcome.winner_team)
	check_near(again.outcome.duration, session.outcome.duration, 0.0001)
	check_eq(again.battle_log.events.size(), session.battle_log.events.size(), "event for event")
	check_eq(JSON.stringify(again.battle_log.final), JSON.stringify(session.battle_log.final), "tick for tick")


func test_rewatching_changes_nothing() -> void:
	_fight("stonewall_bout", 5)
	var before := JSON.stringify(Game.to_dict())
	var again := BattleRecord.rewatch(champion.history[0])
	check(again.result.is_empty(), "no result applied")
	check_eq(JSON.stringify(Game.to_dict()), before, "the lodge is untouched")


func test_only_recent_battles_keep_replays() -> void:
	for i in BattleRecord.REPLAY_LIMIT + 2:
		_fight("first_steps", 200 + i)
	_reload()
	for i in champion.history.size():
		check_eq(BattleRecord.has_replay(champion.history[i]), i < BattleRecord.REPLAY_LIMIT, "entry %d" % i)
	var size := JSON.stringify(Game.to_dict()).length()
	check(size < 120000, "the save stays small (%d bytes)" % size)


func test_battle_records_survive_with_their_summary() -> void:
	var session := _fight("stonewall_bout", 9)
	_reload()
	var entry: Dictionary = champion.history[0]
	check_eq(entry["won"], session.outcome.player_won())
	check_eq(entry["reason"], session.outcome.reason)
	check_eq(entry["opponent"], "rook")
	check_eq(champion.wins + champion.losses, 1)


func test_recruits_and_natural_skills_are_saved() -> void:
	var finn := Content.opponent("finn")
	var name := TrialSystem.recruit(finn)
	check(not name.is_empty())
	var shark: Champion = Game.champions[-1]
	var flight_rank := GameEnums.Rank.FOUNDATION
	shark.skills.set_rank("skill:flight", flight_rank)
	_reload()
	check_eq(Game.champions.size(), 2, "the recruit stays")
	var loaded: Champion = Game.champions[-1]
	check_eq(loaded.animal_id, "humanoid_shark")
	check(loaded.skills.get_rank("skill:swimming") >= GameEnums.Rank.NOVICE, "its swimming")
	check_eq(loaded.skills.get_rank("skill:flight"), flight_rank, "and what it learned")
	check_eq(loaded.weapon_id, finn.weapon_id)


func test_version_one_saves_migrate() -> void:
	var game := Game.to_dict()
	var shark := Champion.create(Content.animal("humanoid_shark"), "Finn", Game.now()).to_dict()
	(shark["skills"]["ranks"] as Dictionary).erase("skill:swimming")
	(game["champions"] as Array).append(shark)
	(game["champions"][0] as Dictionary)["history"] = [{"trial": "Old Bout", "trial_id": "stonewall_bout",
			"opponent": "rook", "won": true, "duration": 40.0, "time": 1.0}]
	var migrated := Saves.migrate({"version": 1, "game": game})
	check(not migrated.is_empty())
	check(Game.load_from_dict(migrated))
	var loaded: Champion = Game.champions[1]
	check_eq(loaded.skills.get_rank("skill:swimming"), int(Content.animal("humanoid_shark").starting_skills["skill:swimming"]),
			"the shark gets its natural swimming back")
	var old: Dictionary = Game.champions[0].history[0]
	check_eq(old["reason"], "")
	check(not BattleRecord.has_replay(old), "old records simply cannot be watched")
	check_eq(Saves.VERSION, 3)



func test_renamed_first_mentor_stays_in_old_saves() -> void:
	var game := Game.to_dict()
	var profile: Dictionary = game["profile"]
	profile["owned_trainers"] = ["swordmaster_corin"]
	profile["active_trainers"] = ["swordmaster_corin"]
	profile["trainer_sessions"] = {"swordmaster_corin": 3}
	var migrated := Saves.migrate({"version": 2, "game": game})
	check(Game.load_from_dict(migrated))
	check(TrainerManager.is_active(Game.profile, "swordmaster_yenbi"), "Yenbi is still the lodge's mentor")
	check_eq(int(Game.profile.trainer_sessions.get("swordmaster_yenbi", 0)), 3, "and remembers her lessons")
	check(not Game.profile.trainer_sessions.has("swordmaster_corin"))


func test_story_mentor_is_restored_if_a_save_lost_her() -> void:
	Game.set_flag("met_first_trainer")
	var game := Game.to_dict()
	(game["profile"] as Dictionary)["owned_trainers"] = []
	(game["profile"] as Dictionary)["active_trainers"] = []
	check(Game.load_from_dict(game))
	check(TrainerManager.is_active(Game.profile, "swordmaster_yenbi"))
	Game.new_journey("Bruno")
	check(Game.load_from_dict(Game.to_dict()))
	check(Game.profile.owned_trainers.is_empty(), "a Keeper who has not met her yet does not get her early")

func test_journey_lists_recent_battles() -> void:
	_fight("stonewall_bout", 12)
	var screen: Node = load(Router.ROUTES["journey"]).instantiate()
	root.add_child(screen)
	var list := screen.find_child("RecentBattles", true, false)
	check(list != null, "recent battles are listed")
	check_eq(list.get_child_count(), 1)
	screen.free()


func _log_of(spec: CombatantSpec) -> BattleLog:
	var players: Array[CombatantSpec] = [spec]
	var opponents: Array[CombatantSpec] = [CombatantSpec.from_opponent(Content.opponent("rook"))]
	return BattleLog.begin(BattleState.create(Content.arena("meadow_ring"), players, opponents, 3), 30)
