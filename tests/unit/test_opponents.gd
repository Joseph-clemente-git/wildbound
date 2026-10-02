extends TestCase
## Stage 1 of the battle simulation: the opponent data model and the partial
## scouting picture the player sees before choosing a fight.

const HIDDEN_KEYS := ["Health", "Attack", "Attack Speed", "Evasion", "Endurance", "Level"]


func test_every_opponent_validates_and_resolves() -> void:
	check(Content.list("opponents").size() >= 4, "opponents loaded")
	for opponent: OpponentData in Content.list("opponents"):
		check_eq(opponent.validate().size(), 0, "%s validation: %s" % [opponent.id, opponent.validate()])
		check(not opponent.bio.is_empty(), opponent.id + " needs a bio for the preview")
		check(Content.animal(opponent.animal_id) != null, opponent.id + " animal missing")
		var weapon := Content.weapon(opponent.weapon_id)
		check(weapon != null and weapon.available, opponent.id + " weapon missing or not in this milestone")
		if weapon != null:
			check(opponent.rank_of("weapon:" + weapon.weapon_type) >= SkillCatalog.WEAPON_FIRST_RANK,
					opponent.id + " must have learned its own weapon")
		check(Content.armor(opponent.armor_id) != null, opponent.id + " armor missing")
		if not opponent.accessory_id.is_empty():
			check(Content.accessory(opponent.accessory_id) != null, opponent.id + " accessory missing")
		if not opponent.magic_ability_id.is_empty():
			var ability := Content.ability(opponent.magic_ability_id)
			check(ability != null, opponent.id + " ability missing")
			if ability != null:
				check(Content.school(ability.school).available, opponent.id + " school not in this milestone")
				check(opponent.rank_of("magic:" + ability.school) >= ability.required_rank,
						opponent.id + " has not learned its Art well enough to use it")
		for technique_id in opponent.techniques:
			check(Content.technique(technique_id) != null, "%s knows unknown technique %s" % [opponent.id, technique_id])


func test_validation_catches_bad_data() -> void:
	var bad := OpponentData.new()
	bad.stats = {"health": 140.0, "speed": 10.0}
	bad.skills = {"weapon:trident": 2, "skill:block": 9, "stat:attack": 3}
	bad.aggression = 1.5
	bad.battles_fought = -1
	var problems := " | ".join(bad.validate())
	for expected in ["missing id", "missing stat attack", "health outside", "unknown stat speed",
			"unknown skill weapon:trident", "skill:block outside", "unknown skill stat:attack",
			"aggression outside", "negative battles"]:
		check(problems.contains(expected), "validation should report '%s' (got %s)" % [expected, problems])


func test_skill_matrix_defaults_match_a_champion() -> void:
	var rook := Content.opponent("rook")
	check_eq(rook.rank_of("weapon:hammer"), 3)
	check_eq(rook.rank_of("skill:block"), 3)
	check_eq(rook.rank_of("skill:dodge"), GameEnums.Rank.FOUNDATION, "fundamentals start at Foundation")
	check_eq(rook.rank_of("weapon:sword"), GameEnums.Rank.NONE, "unlisted weapons are unlearned")
	check_eq(rook.rank_of("magic:fire"), GameEnums.Rank.NONE, "unlisted schools are unlearned")


func test_equipment_modifies_opponents_like_champions() -> void:
	var rook := Content.opponent("rook")
	var hammer := Content.weapon("hammer_iron")
	var final := CombatStats.with_equipment(rook.stats, rook.equipment_ids())
	check_eq(final["agility"], rook.get_stat("agility") + float(hammer.stat_modifiers["agility"]),
			"the hammer's weight slows Rook exactly as it would slow a champion")
	var lighter := rook.duplicate() as OpponentData
	lighter.weapon_id = "sword_training"
	check(CombatStats.for_opponent(lighter).move_speed > CombatStats.for_opponent(rook).move_speed,
			"a lighter build moves faster")


func test_capability_is_shared_with_champions() -> void:
	Game.autosave = false
	Game.new_journey("Bruno")
	var champion := Game.champion()
	var opponent := OpponentData.new()
	opponent.skills = {}
	for target: String in champion.skills.ranks:
		opponent.skills[target] = champion.skills.get_rank(target)
	for target: String in SkillCatalog.all_skill_targets():
		if GameEnums.target_kind(target) == "skill" and not opponent.skills.has(target):
			opponent.skills[target] = GameEnums.Rank.NONE
	check_near(Champion.score_capability(opponent.rank_of, 0), champion.capability_score(), 0.0001,
			"same Skill Matrix, same capability")
	check_eq(ScoutingReport.for_opponent(_with(opponent)).capability, champion.capability_name())
	var marla := Content.opponent("marla")
	var pip := Content.opponent("pip")
	check(Champion.score_capability(marla.rank_of, marla.techniques.size())
			> Champion.score_capability(pip.rank_of, pip.techniques.size()), "the champion has learned more than Pip")


func test_tendencies_are_data() -> void:
	var juniper := Content.opponent("juniper")
	var rook := Content.opponent("rook")
	check(juniper.tendency("mobility") > rook.tendency("mobility"), "Juniper circles, Rook holds ground")
	check_near(rook.tendency("preferred_range"), rook.preferred_range)
	check_eq(rook.tendency("not_a_tendency"), 0.0)


func test_scouting_reads_each_build() -> void:
	var rook := ScoutingReport.for_opponent(Content.opponent("rook"))
	var juniper := ScoutingReport.for_opponent(Content.opponent("juniper"))
	var marla := ScoutingReport.for_opponent(Content.opponent("marla"))
	var pip := ScoutingReport.for_opponent(Content.opponent("pip"))
	check_eq(rook.weapon_family, "Hammer")
	check_eq(rook.armor_weight, "Heavy")
	check_eq(rook.magic_school, "None")
	check_eq(rook.movement, "Ground")
	check(_rank(rook.strength) >= 3, "Rook hits hard (%s)" % rook.strength)
	check(_rank(rook.defense) >= 3, "Rook is armored (%s)" % rook.defense)
	check(_rank(rook.mobility) <= 1, "Rook is slow (%s)" % rook.mobility)
	check(rook.threats.has("Heavy stagger"), "threats: %s" % [rook.threats])
	check(rook.openings.has("Long recovery after heavy swings"), "openings: %s" % [rook.openings])
	check(rook.openings.has("Slow to reposition"))
	check(_rank(juniper.mobility) > _rank(rook.mobility))
	check(_rank(juniper.strength) < _rank(rook.strength))
	check(juniper.threats.has("Hard to pin down"), "threats: %s" % [juniper.threats])
	check(juniper.threats.has("Relentless pressure"), "tendencies show up as observed habits")
	check_eq(marla.magic_school, "Fire")
	check_eq(marla.combat_range, "Long", "Ember Bolt reaches far")
	check(marla.threats.has("Fire attacks from range"), "threats: %s" % [marla.threats])
	check(not marla.openings.has("No ranged options"))
	check(rook.combat_range != "Long")
	check(pip.openings.has("Tires quickly"), "openings: %s" % [pip.openings])


func test_changing_the_build_changes_the_read() -> void:
	var rook := Content.opponent("rook")
	var dagger_rook := rook.duplicate() as OpponentData
	dagger_rook.weapon_id = "dagger_wolf"
	dagger_rook.armor_id = "armor_light"
	var heavy := ScoutingReport.for_opponent(rook)
	var light := ScoutingReport.for_opponent(dagger_rook)
	check(_rank(light.strength) < _rank(heavy.strength), "a dagger carries less force than a hammer")
	check(_rank(light.mobility) > _rank(heavy.mobility), "light gear moves better")
	check(_rank(light.defense) < _rank(heavy.defense), "light gear guards worse")
	check_eq(light.weapon_family, "Dagger")


func test_scouting_hides_exact_numbers() -> void:
	for opponent: OpponentData in Content.list("opponents"):
		var fields := ScoutingReport.for_opponent(opponent).fields()
		for key: String in HIDDEN_KEYS:
			check(not fields.has(key), "%s preview exposes %s" % [opponent.id, key])
		for key: String in fields:
			check(fields[key] is String, "%s.%s must be descriptive text" % [opponent.id, key])
			check(not RegEx.create_from_string("[0-9%]").search(str(fields[key])),
					"%s.%s leaks a number: %s" % [opponent.id, key, fields[key]])
			check(not str(fields[key]).is_empty(), "%s.%s is blank" % [opponent.id, key])


func test_scouting_is_species_agnostic() -> void:
	var flyer := AnimalData.new()
	flyer.display_name = "Test Hawk"
	flyer.movement_type = GameEnums.MovementType.FLYING
	var swimmer := AnimalData.new()
	swimmer.display_name = "Test Otter"
	swimmer.movement_type = GameEnums.MovementType.SWIMMING
	var rook := Content.opponent("rook")
	var combat := CombatStats.for_opponent(rook)
	var weapon := Content.weapon(rook.weapon_id)
	var armor := Content.armor(rook.armor_id)
	check_eq(ScoutingReport.describe_build(combat, weapon, armor, null, flyer).movement, "Flying")
	check_eq(ScoutingReport.describe_build(combat, weapon, armor, null, swimmer).movement, "Swimming")


func _rank(band_name: String) -> int:
	return ScoutingReport.BAND_NAMES.find(band_name)


## Fills an in-memory opponent with valid defaults so it can be scouted.
func _with(opponent: OpponentData) -> OpponentData:
	opponent.id = "mirror"
	opponent.display_name = "Mirror"
	for stat: String in GameEnums.STATS:
		opponent.stats[stat] = 40.0
	return opponent
