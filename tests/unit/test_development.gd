extends TestCase
## Trainers, rarity, mentorship slots, training, techniques and equipment.

var champion: Champion
var profile: OwnerProfile


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	profile = Game.profile
	profile.coins = 5000


func _hire(trainer_id: String) -> TrainerData:
	TrainerManager.recruit(profile, trainer_id, true)
	if not TrainerManager.is_active(profile, trainer_id):
		profile.active_trainers.clear()
		TrainerManager.activate(profile, trainer_id)
	return Content.trainer(trainer_id)


func test_slots_limit_active_mentors() -> void:
	check_eq(TrainerManager.recruit(profile, "swordmaster_yenbi", true), "")
	check(TrainerManager.is_active(profile, "swordmaster_yenbi"), "auto-activates in a free slot")
	check_eq(TrainerManager.recruit(profile, "agility_wren"), "")
	check(not TrainerManager.is_active(profile, "agility_wren"), "level 1 keeps one mentor")
	check(not TrainerManager.activate(profile, "agility_wren").is_empty(), "no free slot")
	check_eq(TrainerManager.replace(profile, "swordmaster_yenbi", "agility_wren"), "")
	check(TrainerManager.is_active(profile, "agility_wren"))
	check(not TrainerManager.is_active(profile, "swordmaster_yenbi"))
	profile.level = 5
	check_eq(TrainerManager.activate(profile, "swordmaster_yenbi"), "", "level 5 opens a second slot")
	check_eq(profile.active_trainers.size(), 2)
	check_eq(TrainerManager.deactivate(profile, "agility_wren"), "")
	check_eq(profile.active_trainers.size(), 1)


func test_recruiting_costs_coins_and_respects_regions() -> void:
	profile.coins = 10
	check(not TrainerManager.recruit(profile, "agility_wren").is_empty(), "too poor")
	var recruitable := TrainerManager.recruitable(profile)
	for trainer in recruitable:
		check_eq(trainer.region_id, "home_valley", "only open regions")
	check(not TrainerManager.rumored(profile).is_empty(), "later mentors are rumored")


func test_rarity_scales_capability_not_power() -> void:
	var common := Content.trainer("endurance_tamsin")
	var rare := Content.trainer("hammermaster_bram")
	check(TrainerManager.rarity_efficiency(common) < TrainerManager.rarity_efficiency(rare))
	check(TrainerManager.rank_cap(common) < TrainerManager.rank_cap(rare))
	check(TrainerManager.stat_cap(common) < TrainerManager.stat_cap(rare))
	check(not TrainerManager.teaches_secondary(common), "common mentors teach their primary only")
	check(TrainerManager.active_traits(common).is_empty())
	check_eq(TrainerManager.teachable_techniques(rare).size(), 1, "rare mentor teaches tier-2 Guard Break")
	var stats_before := CombatStats.for_champion(champion).summary()
	_hire("hammermaster_bram")
	check_eq(CombatStats.for_champion(champion).summary(), stats_before, "hiring changes no battle stats")


func test_training_costs_and_develops() -> void:
	var trainer := _hire("swordmaster_yenbi")
	var coins := profile.coins
	var energy := champion.energy
	var result := TrainingSystem.train(trainer, champion, "weapon:sword", profile)
	check(result["ok"], str(result["reason"]))
	check_eq(champion.skills.get_rank("weapon:sword"), GameEnums.Rank.NOVICE, "first session teaches the sword")
	check_eq(profile.coins, coins - int(result["coin_cost"]))
	check_eq(champion.energy, energy - float(result["energy_cost"]))
	check_eq(int(profile.trainer_sessions["swordmaster_yenbi"]), 1)


func test_training_requires_energy_and_activity() -> void:
	var trainer := _hire("swordmaster_yenbi")
	champion.energy = 5.0
	var result := TrainingSystem.preview(trainer, champion, "weapon:sword", profile)
	check(not result["ok"] and str(result["reason"]).contains("tired"))
	champion.energy = 100.0
	TrainerManager.deactivate(profile, "swordmaster_yenbi")
	result = TrainingSystem.preview(trainer, champion, "weapon:sword", profile)
	check(not result["ok"], "inactive mentors cannot train")


func test_trainer_rank_cap_and_coverage() -> void:
	var trainer := _hire("swordmaster_yenbi")  # Uncommon: up to Skilled
	for i in 80:
		champion.energy = 100.0
		TrainingSystem.train(trainer, champion, "weapon:sword", profile)
	check_eq(champion.skills.get_rank("weapon:sword"), GameEnums.Rank.SKILLED)
	var blocked := TrainingSystem.preview(trainer, champion, "weapon:sword", profile)
	check(not blocked["ok"], "cannot pass the trainer's tier")
	var off_topic := TrainingSystem.preview(trainer, champion, "magic:fire", profile)
	check(not off_topic["ok"], "a swordmaster does not teach fire")


func test_stat_training_respects_trainer_cap_and_potential() -> void:
	var trainer := _hire("endurance_tamsin")  # Common: stats up to 60
	for i in 60:
		champion.energy = 100.0
		TrainingSystem.train(trainer, champion, "stat:endurance", profile)
	check_near(champion.developed_stat("endurance"), 60.0, 0.05)
	check(not TrainingSystem.preview(trainer, champion, "stat:endurance", profile)["ok"])


func test_trainer_converts_banked_experience() -> void:
	var trainer := _hire("agility_wren")
	var plain := TrainingSystem.preview(trainer, champion, "stat:evasion", profile)
	champion.experience.add("evasion", 60.0)
	var guided := TrainingSystem.preview(trainer, champion, "stat:evasion", profile)
	check(guided["expected"] > plain["expected"], "experience makes training more effective")
	TrainingSystem.train(trainer, champion, "stat:evasion", profile)
	check(champion.experience.get_xp("evasion") < 60.0, "converted experience is consumed")


func test_discipline_prerequisites() -> void:
	var trainer := _hire("agility_wren")
	profile.level = 5
	var result := TrainingSystem.preview(trainer, champion, "skill:dodge_control", profile)
	check(not result["ok"] and str(result["reason"]).contains("Requires"), str(result["reason"]))
	champion.skills.set_rank("skill:dodge", GameEnums.Rank.APPRENTICE)
	check(TrainingSystem.preview(trainer, champion, "skill:dodge_control", profile)["ok"])


func test_overtraining_lowers_happiness() -> void:
	var trainer := _hire("swordmaster_yenbi")
	champion.energy = 35.0
	var happiness := champion.happiness
	var result := TrainingSystem.train(trainer, champion, "weapon:sword", profile)
	check(result["overtraining"])
	check(champion.happiness < happiness)


func test_magic_is_learned_through_a_mage() -> void:
	var mage := _hire("fire_mage_sera")
	var bolt := Content.ability("ember_bolt")
	check(not EquipmentSystem.can_use_ability(champion, bolt))
	check(not EquipmentSystem.equip_ability(champion, "ember_bolt").is_empty())
	TrainingSystem.train(mage, champion, "magic:fire", profile)
	check_eq(champion.skills.get_rank("magic:fire"), GameEnums.Rank.FOUNDATION)
	check_eq(EquipmentSystem.equip_ability(champion, "ember_bolt"), "")
	check_eq(champion.equipped_ability, "ember_bolt")
	check(not EquipmentSystem.equip_ability(champion, "flame_burst").is_empty(), "needs Skilled")


func test_technique_prerequisites_and_teacher() -> void:
	var riposte := Content.technique("riposte")
	var state := TechniqueSystem.status(champion, riposte)
	check(not state["met"])
	check_eq(state["requirements"].size(), 2)
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.APPRENTICE)
	champion.skills.set_rank("skill:block", GameEnums.Rank.APPRENTICE)
	check(TechniqueSystem.status(champion, riposte)["met"])
	check(not TechniqueSystem.learn_blocker(champion, riposte, profile).is_empty(), "needs an active teacher")
	_hire("swordmaster_yenbi")
	check_eq(TechniqueSystem.learn(champion, riposte, profile), "")
	check(TechniqueSystem.knows(champion, "riposte"))


func test_stat_prerequisites_use_stat_ranks() -> void:
	var guard_break := Content.technique("guard_break")
	champion.skills.set_rank("weapon:hammer", GameEnums.Rank.SKILLED)
	champion.skills.set_rank("skill:defense", GameEnums.Rank.SKILLED)
	check(not TechniqueSystem.status(champion, guard_break)["met"], "strength is only Apprentice")
	champion.add_trained("strength", 20.0)
	check_eq(champion.stat_rank("strength"), GameEnums.Rank.SKILLED)
	check(TechniqueSystem.status(champion, guard_break)["met"])


func test_equipment_buy_equip_and_project() -> void:
	check(not EquipmentSystem.equip(champion, profile, "hammer_iron").is_empty(), "must own it")
	check_eq(EquipmentSystem.buy(profile, "hammer_iron"), "")
	check(EquipmentSystem.buy(profile, "dagger_wolf") != "", "region-locked weapon")
	profile.add_item("sword_training")
	EquipmentSystem.equip(champion, profile, "sword_training")
	var projection := EquipmentSystem.projection(champion, "weapon", "hammer_iron")
	check(projection["Stagger"]["projected"] > projection["Stagger"]["current"], "hammer staggers more")
	check(projection["Attack Speed"]["projected"] < projection["Attack Speed"]["current"], "hammer is slower")
	check(projection["Mobility"]["projected"] < projection["Mobility"]["current"], "hammer is heavy")
	EquipmentSystem.equip(champion, profile, "hammer_iron")
	check_eq(champion.weapon_id, "hammer_iron")
	EquipmentSystem.unequip(champion, "weapon")
	check_eq(champion.weapon_id, "")


func test_armor_tradeoffs() -> void:
	var light := CombatStats.for_champion(champion, {"armor_id": "armor_light"})
	var heavy := CombatStats.for_champion(champion, {"armor_id": "armor_heavy"})
	check(heavy.mitigation > light.mitigation)
	check(heavy.knockback_taken < light.knockback_taken)
	check(heavy.move_speed < light.move_speed)
	check(heavy.dodge_distance < light.dodge_distance)
	check(heavy.dodge_stamina > light.dodge_stamina)
