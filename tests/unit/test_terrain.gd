extends TestCase
## Terrain and movement types: water, air, the Natural Foundation skills,
## and the Shark and Eagle champions. Rules follow MovementType, never species.

const A := CombatantState.Action
const M := GameEnums.MovementType

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.APPRENTICE)


func _animal_spec(animal_id: String) -> CombatantSpec:
	var animal := Content.animal(animal_id)
	var someone := Champion.create(animal, "Test", Game.now())
	someone.weapon_id = "sword_training"
	someone.armor_id = "armor_light"
	someone.skills.set_rank("weapon:sword", GameEnums.Rank.APPRENTICE)
	return CombatantSpec.from_champion(someone)


func _state(arena: ArenaData, a: CombatantSpec, b: CombatantSpec, seed_value: int = 3) -> BattleState:
	var players: Array[CombatantSpec] = [a]
	var opponents: Array[CombatantSpec] = [b]
	return BattleState.create(arena, players, opponents, seed_value)


func test_new_animals_are_valid_content() -> void:
	for animal_id in ["humanoid_shark", "humanoid_eagle"]:
		var animal := Content.animal(animal_id)
		check(animal != null, animal_id)
		check_eq(animal.validate().size(), 0, "%s: %s" % [animal_id, animal.validate()])
	check_eq(Content.animal("humanoid_shark").movement_type, M.SWIMMING)
	check_eq(Content.animal("humanoid_eagle").movement_type, M.FLYING)
	check(Content.animal("humanoid_shark").starting_skills.has("skill:swimming"))
	check(Content.animal("humanoid_eagle").starting_skills.has("skill:flight"))
	for skill in ["skill:swimming", "skill:flight"]:
		check(SkillCatalog.is_valid_target(skill))
		check_eq(SkillCatalog.category_of(skill), SkillCatalog.NATURAL)


func test_bodies_share_the_rig() -> void:
	for animal_id in ["humanoid_shark", "humanoid_eagle"]:
		var body := CharacterFactory.create(Content.animal(animal_id))
		check(body is ProceduralDogVisual, animal_id + " uses the shared humanoid rig")
		check_eq(body.missing_clips().size(), 0, animal_id + " plays every clip")
		for key: String in CharacterAnimations.BONES:
			check(body.has_node(CharacterAnimations.BONES[key]), "%s bone %s" % [animal_id, key])
		body.set_weapon("hammer")
		body.set_armor(GameEnums.ArmorWeight.MEDIUM)
		body.free()
	check(CharacterFactory.create(Content.animal("humanoid_shark")) is ProceduralSharkVisual)
	check(CharacterFactory.create(Content.animal("humanoid_eagle")) is ProceduralEagleVisual)


func test_water_rules_follow_movement_type() -> void:
	var arena := Content.arena("valley_lakeshore")
	var state := _state(arena, _animal_spec("humanoid_dog"), _animal_spec("humanoid_shark"))
	var dog := state.combatants[0]
	var shark := state.combatants[1]
	var wet := Vector2(arena.water_zones[0].x, arena.water_zones[0].y)
	var dry := Vector2(0, 7)
	dog.position = wet
	shark.position = wet
	check(TerrainRules.speed_factor(state, dog) < 0.8, "a walker wades slowly")
	check(TerrainRules.speed_factor(state, shark) > 1.2, "a swimmer is quick in water")
	check(TerrainRules.dodge_factor(state, shark) > TerrainRules.dodge_factor(state, dog))
	check(TerrainRules.damage_factor(state, shark) > 1.0, "a swimmer hits harder in water")
	dog.position = dry
	shark.position = dry
	check_eq(TerrainRules.speed_factor(state, dog), 1.0)
	check(TerrainRules.speed_factor(state, shark) < 0.8, "a swimmer is slow on land")
	check(TerrainRules.regen_factor(state, shark) < 1.0, "and short of breath")
	check_eq(TerrainRules.damage_factor(state, shark), 1.0)


func test_swimming_skill_eases_water_for_anyone() -> void:
	var arena := Content.arena("valley_lakeshore")
	var novice := _animal_spec("humanoid_dog")
	var swimmer := _animal_spec("humanoid_dog")
	swimmer.skills["skill:swimming"] = GameEnums.Rank.SKILLED
	swimmer.refresh()
	var state := _state(arena, novice, swimmer)
	var wet := Vector2(arena.water_zones[0].x, arena.water_zones[0].y)
	state.combatants[0].position = wet
	state.combatants[1].position = wet
	check(TerrainRules.speed_factor(state, state.combatants[1]) > TerrainRules.speed_factor(state, state.combatants[0]))


func test_fliers_rise_strike_low_and_pay_for_it() -> void:
	var state := _state(Content.arena("windy_ridge"), _animal_spec("humanoid_dog"), _animal_spec("humanoid_eagle"))
	var sim := BattleSimulator.create(state)
	sim.use_phase(ScriptedDecisionPhase.new(func(_s: BattleState, _f: CombatantState, _fr: SimFrame) -> Dictionary:
		return {}))
	var eagle := state.combatants[1]
	var dog := state.combatants[0]
	for i in 45:
		sim.step()
	check_near(eagle.elevation, TerrainRules.CRUISE_HEIGHT, 0.01, "an eagle takes to the air")
	check_eq(dog.elevation, 0.0, "a dog stays on the ground")
	eagle.stamina = 40.0
	dog.stamina = 40.0
	for i in 30:
		sim.step()
	var grounded := _state(Content.arena("windy_ridge"), _animal_spec("humanoid_dog"), _animal_spec("humanoid_eagle"))
	grounded.layout.air_ceiling = 0.0
	var rested := BattleSimulator.create(grounded)
	rested.use_phase(ScriptedDecisionPhase.new(func(_s: BattleState, _f: CombatantState, _fr: SimFrame) -> Dictionary:
		return {}))
	grounded.combatants[1].stamina = 40.0
	for i in 30:
		rested.step()
	check(eagle.stamina < grounded.combatants[1].stamina - 5.0,
			"staying aloft costs breath (%.0f aloft vs %.0f landed)" % [eagle.stamina, grounded.combatants[1].stamina])
	eagle.position = dog.position + Vector2(0, -1.2)
	eagle.facing = Vector2(0, 1)
	dog.facing = Vector2(0, -1)
	check(not ContactPhase.in_reach(state, dog, eagle, dog.spec.derived.attack_range, 360.0), "a blade cannot reach it aloft")
	check(DecisionPhase.can_reach(state, eagle, dog), "but it can dive at the dog")
	eagle.action = A.ATTACK
	TerrainRules.fly(state, eagle, 0.2)
	check(eagle.elevation < 1.0, "swooping brings it low (%.2f)" % eagle.elevation)
	check(ContactPhase.in_reach(state, dog, eagle, dog.spec.derived.attack_range, 360.0), "within reach while it strikes")


func test_fliers_land_when_tired_and_fall_when_staggered() -> void:
	var state := _state(Content.arena("windy_ridge"), _animal_spec("humanoid_dog"), _animal_spec("humanoid_eagle"))
	var eagle := state.combatants[1]
	eagle.elevation = TerrainRules.CRUISE_HEIGHT
	eagle.stamina = eagle.max_stamina * 0.1
	TerrainRules.fly(state, eagle, 0.1)
	check(eagle.resting, "a tired flier lands to recover")
	for i in 30:
		TerrainRules.fly(state, eagle, 0.1)
	check_eq(eagle.elevation, 0.0)
	eagle.resting = false
	eagle.stamina = eagle.max_stamina
	eagle.elevation = TerrainRules.CRUISE_HEIGHT
	var frame := SimFrame.new(1, 0.0, 1.0 / 30.0)
	ForcePhase.stagger(eagle, 0.5, frame, "test", 0)
	check(eagle.grounded_time > 0.0, "a stagger knocks it out of the air")
	check_eq(TerrainRules.target_height(state, eagle), 0.0)


func test_wind_and_shots_reach_the_sky() -> void:
	var state := _state(Content.arena("windy_ridge"), _animal_spec("humanoid_dog"), _animal_spec("humanoid_eagle"))
	var dog := state.combatants[0]
	var eagle := state.combatants[1]
	eagle.elevation = TerrainRules.CRUISE_HEIGHT
	eagle.position = dog.position + Vector2(0, -2.5)
	dog.facing = Vector2(0, -1)
	var gale := Content.ability("gale_push")
	check(ContactPhase.in_reach(state, dog, eagle, gale.cast_range, gale.cone_degrees, ContactPhase.GUST_HEIGHT), "a gust reaches it")
	check(gale.grounds_fliers)
	var frame := SimFrame.new(1, 0.0, 1.0 / 30.0)
	frame.hits.append({"attacker": 0, "target": 1, "kind": "cast", "combo": 0, "swing": 1, "ability": "gale_push",
			"direction": Vector2(0, -1), "via": "area", "outcome": "hit"})
	ForcePhase.new().run(state, frame)
	check_eq(eagle.action, A.KNOCKDOWN, "wind brings a flier down")


func test_no_room_no_flight() -> void:
	var cave := Content.arena("windy_ridge").duplicate() as ArenaData
	cave.air_ceiling = 0.0
	var state := _state(cave, _animal_spec("humanoid_dog"), _animal_spec("humanoid_eagle"))
	check(not TerrainRules.can_fly(state, state.combatants[1]))


func test_fliers_pass_over_low_obstacles() -> void:
	var state := _state(Content.arena("windy_ridge"), _animal_spec("humanoid_dog"), _animal_spec("humanoid_eagle"))
	var eagle := state.combatants[1]
	var low := 2
	var stone := state.layout.obstacles[low]
	check(state.layout.obstacle_heights[low] < TerrainRules.CRUISE_HEIGHT)
	eagle.elevation = TerrainRules.CRUISE_HEIGHT
	eagle.position = Vector2(stone.x, stone.y)
	MovementPhase.new()._constrain(state, eagle)
	check_eq(eagle.position, Vector2(stone.x, stone.y), "flies over the stone")


func test_terrain_shapes_the_outcome_both_ways() -> void:
	var lake := Content.arena("valley_lakeshore")
	var dry := lake.duplicate() as ArenaData
	dry.water_zones = []
	var at_home := 0
	var ashore := 0
	for seed_value in 6:
		var finn := CombatantSpec.from_opponent(Content.opponent("finn"))
		var a := BattleSimulator.create(_state(lake, CombatantSpec.from_champion(champion), finn, 700 + seed_value))
		a.run()
		at_home += 1 if a.state.winner_team == 1 else 0
		var b := BattleSimulator.create(_state(dry, CombatantSpec.from_champion(champion), CombatantSpec.from_opponent(Content.opponent("finn")), 700 + seed_value))
		b.run()
		ashore += 1 if b.state.winner_team == 1 else 0
	check(at_home > ashore + 2, "a shark is far stronger in its water (%d vs %d of 6)" % [at_home, ashore])
	check(ashore < 3, "and weak on dry land — swimming is no automatic win")


func test_flight_is_mobility_not_immunity() -> void:
	var losses := 0
	for seed_value in 6:
		var sim := BattleSimulator.create(_state(Content.arena("windy_ridge"), CombatantSpec.from_champion(champion),
				CombatantSpec.from_opponent(Content.opponent("aquila")), 700 + seed_value))
		sim.run()
		check(sim.state.finished)
		losses += 1 if sim.state.winner_team == 0 else 0
	check(losses >= 1, "an eagle can be beaten from the ground (%d of 6)" % losses)


func test_beating_a_visitor_recruits_it() -> void:
	for flag in ["equipped_weapon", "trained_once", "first_trial_done"]:
		Game.set_flag(flag)
	var outcome := {"trial_id": "lakeshore_challenge", "opponent_id": "finn", "won": true, "forfeited": false,
			"duration": 40.0, "tallies": {}, "experience": {}, "growths": []}
	var result := TrialSystem.apply_result(outcome)
	check_eq(result["recruited"], "Finn")
	check_eq(Game.champions.size(), 2, "Finn joined")
	var finn := Game.champions[1]
	check_eq(finn.animal_id, "humanoid_shark")
	check_eq(finn.weapon_id, "hammer_iron", "with its hammer")
	check(Game.profile.owns_item("hammer_iron"))
	check(finn.skills.get_rank("skill:swimming") >= GameEnums.Rank.APPRENTICE)
	var again := TrialSystem.apply_result(outcome)
	check_eq(again["recruited"], "", "only once")
	check_eq(Game.champions.size(), 2)
	check(ChampionSelection.candidates(Content.trial("lakeshore_challenge")).size() == 2, "and can be chosen for fights")
