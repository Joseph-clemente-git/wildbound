extends TestCase
## Owner profile, champion, skill matrix, condition and save/load.

const TEST_SAVE := "user://test_save.json"


func before_each() -> void:
	Saves.path_override = TEST_SAVE
	Saves.delete_save()
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")


func test_new_journey_creates_dog_champion() -> void:
	var champion := Game.champion()
	check(champion != null)
	check_eq(champion.name, "Bruno")
	check_eq(champion.data().id, "humanoid_dog")
	check_eq(champion.data().movement_type, GameEnums.MovementType.GROUND)
	check_eq(champion.energy, 100.0)
	check_eq(Game.profile.coins, Content.config.starting_coins)
	check_eq(champion.skills.get_rank("skill:dodge"), GameEnums.Rank.NOVICE)
	check_eq(champion.capability_name(), "Untrained")


func test_trainer_slots_follow_owner_level() -> void:
	check_eq(OwnerProfile.slots_for_level(1), 1)
	check_eq(OwnerProfile.slots_for_level(4), 1)
	check_eq(OwnerProfile.slots_for_level(5), 2)
	check_eq(OwnerProfile.slots_for_level(10), 3)
	check_eq(OwnerProfile.slots_for_level(15), 4)
	check_eq(OwnerProfile.slots_for_level(20), 5)
	check_eq(OwnerProfile.slots_for_level(30), 5, "never above max")
	var profile := Game.profile
	check_eq(profile.next_slot_level(), 5)
	profile.add_xp(5000)
	check(profile.level > 5)
	check(profile.trainer_slots() >= 2)


func test_stats_respect_potential() -> void:
	var champion := Game.champion()
	var cap := champion.potential("strength")
	champion.add_trained("strength", 500.0)
	check_eq(champion.developed_stat("strength"), cap)
	champion.add_natural_growth("strength", 10.0)
	check_eq(champion.developed_stat("strength"), cap, "growth cannot pass potential")


func test_equipment_modifies_final_not_developed() -> void:
	var champion := Game.champion()
	var developed := champion.developed_stat("agility")
	champion.weapon_id = "hammer_iron"
	check_eq(champion.developed_stat("agility"), developed)
	check_near(champion.final_stat("agility"), developed - 4.0)


func test_level_does_not_grant_stats() -> void:
	var champion := Game.champion()
	var before := champion.developed_stat("attack")
	champion.add_xp(10000)
	check(champion.level > 1)
	check_eq(champion.developed_stat("attack"), before)


func test_skill_matrix_progress_and_caps() -> void:
	var matrix := SkillMatrix.new()
	var reached := matrix.add_progress("weapon:sword", 10.0)
	check_eq(matrix.get_rank("weapon:sword"), GameEnums.Rank.NOVICE, "weapons start at Novice")
	check_eq(reached.size(), 1)
	matrix.add_progress("weapon:sword", 10000.0, GameEnums.Rank.APPRENTICE)
	check_eq(matrix.get_rank("weapon:sword"), GameEnums.Rank.APPRENTICE, "capped")
	matrix.add_progress("magic:fire", 1.0)
	check_eq(matrix.get_rank("magic:fire"), GameEnums.Rank.FOUNDATION, "magic starts at Foundation")


func test_energy_and_happiness() -> void:
	var champion := Game.champion()
	check(champion.consume_energy(30))
	check_eq(champion.energy, 70.0)
	check(not champion.consume_energy(500), "cannot overspend")
	champion.restore_energy(500)
	check_eq(champion.energy, 100.0)
	champion.change_happiness(-500)
	check_eq(champion.happiness, 0.0)
	check(champion.happiness_factor() < 1.0)
	champion.change_happiness(500)
	check(champion.happiness_factor() > 1.0)


func test_passive_recovery_and_knockout() -> void:
	var champion := Game.champion()
	champion.energy = 50.0
	champion.last_energy_tick = Game.now()
	ConditionSystem.knock_out(champion, Game.now())
	check(not champion.can_fight())
	var later := Game.now() + Content.config.knockout_recovery_seconds + 1.0
	ConditionSystem.apply_passive(champion, later)
	check(not champion.knocked_out, "knockout wears off")
	check(champion.energy > 50.0, "energy regenerates over time")
	check(champion.experience.get_xp("resilience") > 0.0, "recovering teaches resilience")


func test_short_rest_and_care() -> void:
	var champion := Game.champion()
	champion.energy = 10.0
	check(ConditionSystem.short_rest(champion, Game.now()))
	check(not ConditionSystem.short_rest(champion, Game.now() + 1.0), "cooldown")
	var coins := Game.profile.coins
	ConditionSystem.knock_out(champion, Game.now())
	check(ConditionSystem.care(champion, Game.profile))
	check(not champion.knocked_out)
	check_eq(Game.profile.coins, coins - Content.config.care_coin_cost)


func test_save_and_load_round_trip() -> void:
	var champion := Game.champion()
	champion.add_natural_growth("evasion", 4.0)
	champion.experience.add("evasion", 42.0)
	champion.skills.add_progress("weapon:sword", 1.0)
	champion.techniques.append("riposte")
	champion.weapon_id = "sword_training"
	champion.happiness = 55.0
	Game.profile.owned_trainers.append("swordmaster_corin")
	Game.profile.active_trainers.append("swordmaster_corin")
	Game.profile.coins = 777
	Game.profile.set_flag("trained_once")
	check(Game.save(), "save succeeded")
	var expected := Game.to_dict()
	Game.close_journey()
	check(Game.continue_journey(), "load succeeded")
	var loaded := Game.champion()
	check_eq(Game.profile.coins, 777)
	check(Game.is_flag_set("trained_once"))
	check_eq(Game.profile.active_trainers, ["swordmaster_corin"])
	check_near(loaded.developed_stat("evasion"), champion.developed_stat("evasion"))
	check_near(loaded.experience.get_xp("evasion"), 42.0)
	check_eq(loaded.skills.get_rank("weapon:sword"), GameEnums.Rank.NOVICE)
	check_eq(loaded.techniques, ["riposte"] as Array[String])
	check_eq(loaded.weapon_id, "sword_training")
	check_near(loaded.happiness, 55.0)
	check_eq(JSON.stringify(Game.to_dict()), JSON.stringify(expected), "full state survives a round trip")


func test_corrupt_save_falls_back_to_backup() -> void:
	Game.profile.coins = 123
	Game.save()
	Game.profile.coins = 456
	Game.save()  # previous save becomes the backup
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	Game.close_journey()
	check(Game.continue_journey())
	check_eq(Game.profile.coins, 123)


func test_migrates_version_zero() -> void:
	var legacy := {"keeper_name": "Old", "coins": 5, "level": 2}
	var game := Saves.migrate(legacy)
	check(game.has("profile"))
	check_eq(int(game["profile"]["coins"]), 5)
