extends TestCase
## Content integrity: every reference between data files must resolve.


func test_all_categories_loaded() -> void:
	check_eq(Content.list("animals").size(), 1, "animals")
	check_eq(Content.list("weapons").size(), GameEnums.WEAPON_TYPES.size(), "weapons")
	check_eq(Content.list("armor").size(), 3, "armor")
	check_eq(Content.list("magic").size(), GameEnums.MAGIC_SCHOOLS.size(), "schools")
	check(Content.list("trainers").size() >= 19, "at least 19 trainer definitions")
	check(Content.list("techniques").size() >= 3, "techniques")
	check(Content.list("trials").size() >= 2, "trials")
	check_eq(Content.list("regions").size(), 6, "regions")


func test_dog_is_balanced() -> void:
	var dog := Content.animal("humanoid_dog")
	check(dog != null, "dog missing")
	check_eq(dog.validate().size(), 0, "dog validation: %s" % [dog.validate()])
	check_eq(dog.movement_type, GameEnums.MovementType.GROUND)
	check_eq(AnimalData.describe_value(dog.get_base("agility")), "High")
	check_eq(AnimalData.describe_value(dog.get_base("attack")), "Medium")


func test_every_weapon_type_and_school_has_data() -> void:
	var types := {}
	for weapon: WeaponData in Content.list("weapons"):
		types[weapon.weapon_type] = true
	for weapon_type: String in GameEnums.WEAPON_TYPES:
		check(types.has(weapon_type), "no weapon of type " + weapon_type)
	for school: String in GameEnums.MAGIC_SCHOOLS:
		var data := Content.school(school)
		check(data != null and not data.abilities.is_empty(), "school without abilities: " + school)


func test_mvp_content_available() -> void:
	check(Content.weapon("sword_training").available)
	check(Content.weapon("hammer_iron").available)
	check(Content.school("fire").available)
	check(Content.school("wind").available)
	check(Content.ability("ember_bolt") != null)
	check(Content.ability("gale_push") != null)


func test_trainer_disciplines_are_valid_targets() -> void:
	for trainer: TrainerData in Content.list("trainers"):
		check(not trainer.primary_discipline.is_empty(), trainer.id + " has no primary discipline")
		for target in trainer.primary_discipline + trainer.secondary_discipline:
			check(SkillCatalog.is_valid_target(target), "%s teaches unknown %s" % [trainer.id, target])
		for trait_id in trainer.traits:
			check(TrainerTraits.TRAITS.has(trait_id), "%s has unknown trait %s" % [trainer.id, trait_id])
		for technique_id in trainer.teachable_techniques:
			check(Content.technique(technique_id) != null, "%s teaches unknown technique %s" % [trainer.id, technique_id])
		check(Content.region(trainer.region_id) != null, trainer.id + " region missing")


func test_required_trainer_titles_exist() -> void:
	var titles := {}
	for trainer: TrainerData in Content.list("trainers"):
		titles[trainer.title] = true
	for title: String in ["Strength Trainer", "Attack Trainer", "Agility Trainer", "Defense Trainer",
			"Evasion Trainer", "Endurance Trainer", "Swordmaster", "Axemaster", "Hammermaster",
			"Spearmaster", "Duelist", "Guardian", "Ranger", "Fire Mage", "Frost Mage", "Wind Mage",
			"Earth Mage", "Lightning Mage", "Nature Mage"]:
		check(titles.has(title), "missing trainer: " + title)


func test_technique_prerequisites_are_valid() -> void:
	for technique: TechniqueData in Content.list("techniques"):
		check(not technique.prerequisites.is_empty(), technique.id + " has no prerequisites")
		for target: String in technique.prerequisites:
			check(SkillCatalog.is_valid_target(target), "%s requires unknown %s" % [technique.id, target])


func test_trials_and_opponents_resolve() -> void:
	for trial: TrialData in Content.list("trials"):
		check(Content.opponent(trial.opponent_id) != null, trial.id + " opponent missing")
		check(Content.arena(trial.arena_id) != null, trial.id + " arena missing")
		check(Content.region(trial.region_id) != null, trial.id + " region missing")
	for opponent: OpponentData in Content.list("opponents"):
		check(Content.weapon(opponent.weapon_id) != null, opponent.id + " weapon missing")
		check(Content.armor(opponent.armor_id) != null, opponent.id + " armor missing")
		check(Content.animal(opponent.animal_id) != null, opponent.id + " animal missing")
		if not opponent.magic_ability_id.is_empty():
			check(Content.ability(opponent.magic_ability_id) != null, opponent.id + " ability missing")
		for stat: String in GameEnums.STATS:
			check(opponent.stats.has(stat), "%s missing stat %s" % [opponent.id, stat])


func test_rarity_tables_cover_every_rarity() -> void:
	var config := Content.config
	var count := GameEnums.RARITY_NAMES.size()
	check_eq(config.rarity_efficiency.size(), count)
	check_eq(config.rarity_rank_cap.size(), count)
	check_eq(config.rarity_stat_cap.size(), count)
	check_eq(config.rarity_technique_tier.size(), count)
	check_eq(config.rarity_secondary.size(), count)
	check_eq(config.rarity_trait_slots.size(), count)
	for i in count - 1:
		check(config.rarity_efficiency[i] < config.rarity_efficiency[i + 1], "efficiency must rise with rarity")
