extends TestCase
## Stage 6 of the battle simulation: the combat state model. Both sides are
## built into the same data shape; the battle state holds everything the
## simulation will need and nothing depends on species.

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	for item_id in ["sword_training", "hammer_iron", "armor_heavy"]:
		Game.profile.add_item(item_id)
	champion.weapon_id = "hammer_iron"
	champion.armor_id = "armor_heavy"
	champion.skills.set_rank("weapon:hammer", GameEnums.Rank.APPRENTICE)
	champion.skills.set_rank("magic:fire", GameEnums.Rank.FOUNDATION)
	champion.equipped_ability = "ember_bolt"
	champion.wins = 3
	champion.losses = 2
	champion.energy = 64.0
	champion.happiness = 81.0


func test_champion_spec_captures_every_input() -> void:
	var spec := CombatantSpec.from_champion(champion)
	check_eq(spec.id, champion.uid)
	check_eq(spec.source, "champion")
	check_eq(spec.movement_type, GameEnums.MovementType.GROUND)
	for stat: String in GameEnums.STATS:
		check_near(spec.get_stat(stat), champion.final_stat(stat), 0.001, "final %s includes equipment" % stat)
	check_eq(spec.rank_of("weapon:hammer"), GameEnums.Rank.APPRENTICE)
	check_eq(spec.weapon_mastery, GameEnums.Rank.APPRENTICE)
	check_eq(spec.magic_mastery, GameEnums.Rank.FOUNDATION)
	check_eq(spec.skills.size(), SkillCatalog.all_skill_targets().size(), "the whole Skill Matrix")
	check_eq(spec.battle_experience, 5)
	check_eq(spec.weapon.id, "hammer_iron")
	check_eq(spec.armor.id, "armor_heavy")
	check_eq(spec.ability.id, "ember_bolt")
	check_eq(spec.energy, 64.0)
	check_eq(spec.happiness, 81.0)
	check(spec.tendency("magic_chance") > 0.0, "a champion with an Art may use it")
	check_near(spec.tendency("preferred_range"), spec.derived.attack_range * 0.9, 0.001)
	var reference := CombatStats.for_champion(champion)
	check_near(spec.derived.max_health, reference.max_health, 0.001, "one formula with the previews")
	check_near(spec.derived.heavy_damage, reference.heavy_damage, 0.001)
	check_near(spec.derived.move_speed, reference.move_speed, 0.001)


func test_unusable_art_is_left_out() -> void:
	champion.skills.set_rank("magic:fire", GameEnums.Rank.NONE)
	var spec := CombatantSpec.from_champion(champion)
	check(spec.ability == null)
	check_eq(spec.magic_mastery, GameEnums.Rank.NONE)


func test_opponent_spec_has_the_same_shape() -> void:
	var marla := Content.opponent("marla")
	var spec := CombatantSpec.from_opponent(marla)
	check_eq(spec.source, "opponent")
	check_eq(spec.battle_experience, marla.battles_fought)
	check_eq(spec.weapon_mastery, marla.rank_of("weapon:sword"))
	check_eq(spec.magic_mastery, marla.rank_of("magic:fire"))
	check_eq(spec.ability.id, "ember_bolt")
	check_near(spec.tendency("aggression"), marla.aggression)
	check_near(spec.tendency("caution"), marla.caution)
	check_near(spec.derived.max_health, CombatStats.for_opponent(marla).max_health, 0.001)
	var mine := CombatantSpec.from_champion(champion).to_dict()
	var theirs := spec.to_dict()
	check_eq(mine.keys(), theirs.keys(), "champions and opponents become the same data")


func test_spec_is_a_snapshot() -> void:
	var spec := CombatantSpec.from_champion(champion)
	champion.weapon_id = "sword_training"
	champion.skills.set_rank("weapon:hammer", GameEnums.Rank.MASTER)
	champion.energy = 1.0
	check_eq(spec.weapon.id, "hammer_iron", "a set-up battle does not change under it")
	check_eq(spec.rank_of("weapon:hammer"), GameEnums.Rank.APPRENTICE)
	check_eq(spec.energy, 64.0)


func test_movement_comes_from_the_animal() -> void:
	var hawk := AnimalData.new()
	hawk.id = "test_hawk"
	hawk.movement_type = GameEnums.MovementType.FLYING
	hawk.base_stats = Content.animal("humanoid_dog").base_stats.duplicate()
	champion.animal_id = "humanoid_dog"
	var spec := CombatantSpec.from_champion(champion)
	spec.animal = hawk
	spec._finish()
	check_eq(spec.movement_type, GameEnums.MovementType.FLYING, "no species check decides movement")


func test_one_v_one_battle_state() -> void:
	var state := BattleState.for_fight(Content.trial("stonewall_bout"), champion)
	check_eq(state.validate().size(), 0, "valid: %s" % [state.validate()])
	check_eq(state.combatants.size(), 2)
	var hero := state.team(BattleState.PLAYER_TEAM)[0]
	var rook := state.team(BattleState.OPPONENT_TEAM)[0]
	check_eq(hero.spec.id, champion.uid)
	check_eq(rook.spec.id, "rook")
	check_eq(hero.position, Vector2(0, 5), "starts at the arena's spawn")
	check_eq(rook.position, Vector2(0, -5))
	check(hero.facing.dot((rook.position - hero.position).normalized()) > 0.999, "faces the opponent")
	check_eq(hero.target_index, rook.index)
	check_eq(hero.health, hero.max_health)
	check_eq(hero.stamina, hero.max_stamina)
	check_eq(hero.action, CombatantState.Action.IDLE)
	check_eq(state.tick, 0)
	check(not state.finished)
	check_eq(state.winner_team, -1)
	check_eq(state.nearest_enemy(hero), rook)
	check_eq(state.living(BattleState.OPPONENT_TEAM).size(), 1)
	check_eq(state.arena.id, "meadow_ring")


func test_teams_scale_past_one_v_one() -> void:
	var arena := Content.arena("meadow_ring")
	var players: Array[CombatantSpec] = [CombatantSpec.from_champion(champion), CombatantSpec.from_opponent(Content.opponent("pip")),
			CombatantSpec.from_opponent(Content.opponent("juniper"))]
	var opponents: Array[CombatantSpec] = [CombatantSpec.from_opponent(Content.opponent("rook")),
			CombatantSpec.from_opponent(Content.opponent("marla")), CombatantSpec.from_opponent(Content.opponent("pip"))]
	var state := BattleState.create(arena, players, opponents, 7)
	check_eq(state.combatants.size(), 6, "3v3")
	check_eq(state.validate().size(), 0, "everyone starts somewhere open: %s" % [state.validate()])
	check_eq(state.team(0).size(), 3)
	check_eq(state.enemies_of(state.combatants[0]).size(), 3)
	for fighter in state.combatants:
		check(state.target_of(fighter) != null and state.target_of(fighter).team != fighter.team, "targets an enemy")


func test_snapshots_are_deterministic() -> void:
	var trial := Content.trial("stonewall_bout")
	var a := BattleState.for_fight(trial, champion)
	var b := BattleState.for_fight(trial, champion)
	check_eq(a.battle_seed, b.battle_seed, "the same fight and record give the same seed")
	check_eq(JSON.stringify(a.snapshot()), JSON.stringify(b.snapshot()))
	check_eq(a.rng.randi(), b.rng.randi(), "the same controlled variation")
	champion.wins += 1
	var c := BattleState.for_fight(trial, champion)
	check(c.battle_seed != a.battle_seed, "a new bout varies a little")
	var fixed := BattleState.for_fight(trial, champion, 1234)
	check_eq(fixed.battle_seed, 1234, "a seed can be given for replays and tests")
	var snapshot := a.snapshot()
	check_eq(snapshot["combatants"].size(), 2)
	check(snapshot["combatants"][0].has("health") and snapshot["combatants"][0].has("position"))


func test_validation_catches_bad_starts() -> void:
	var arena := Content.arena("meadow_ring").duplicate() as ArenaData
	arena.obstacles = [Vector4(0, 5, 1.0, 1.0)]
	var players: Array[CombatantSpec] = [CombatantSpec.from_champion(champion)]
	var opponents: Array[CombatantSpec] = [CombatantSpec.from_opponent(Content.opponent("rook"))]
	var state := BattleState.create(arena, players, opponents, 1)
	check(" ".join(state.validate()).contains("inside an obstacle"))
	var empty: Array[CombatantSpec] = []
	check(" ".join(BattleState.create(Content.arena("meadow_ring"), players, empty, 1).validate()).contains("team 1 has no"))


func test_engine_has_no_species_code() -> void:
	for file_name in DirAccess.get_files_at("res://scripts/simulation"):
		if not file_name.ends_with(".gd"):
			continue
		var source := FileAccess.get_file_as_string("res://scripts/simulation".path_join(file_name))
		for banned in ["humanoid_dog", "\"dog\"", "bird", "fish"]:
			check(not source.contains(banned), "%s mentions %s" % [file_name, banned])
