extends TestCase
## Stage 12 of the battle simulation: stamina costs, recovery and exhaustion.

const A := CombatantState.Action

var champion: Champion
var plan: Dictionary = {}
var sim: BattleSimulator


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	for item_id in ["sword_training", "hammer_iron", "armor_heavy"]:
		Game.profile.add_item(item_id)
	champion.weapon_id = "sword_training"
	plan = {}
	sim = _make(CombatantSpec.from_champion(champion))


func _make(hero: CombatantSpec) -> BattleSimulator:
	var players: Array[CombatantSpec] = [hero]
	var opponents: Array[CombatantSpec] = [CombatantSpec.from_opponent(Content.opponent("rook"))]
	var made := BattleSimulator.create(BattleState.create(Content.arena("meadow_ring"), players, opponents, 8))
	made.use_phase(ScriptedDecisionPhase.new(func(_s: BattleState, fighter: CombatantState, _f: SimFrame) -> Dictionary:
		return plan.get(fighter.index, {})))
	return made


func _hero() -> CombatantState:
	return sim.state.combatants[0]


func _steps(count: int) -> void:
	for i in count:
		sim.step()


func test_actions_cost_their_stamina() -> void:
	var hero := _hero()
	plan[0] = {"action": "attack"}
	sim.step()
	plan.erase(0)
	check_near(hero.stamina, hero.max_stamina - hero.spec.derived.attack_stamina, 0.001)
	_steps(40)
	var before := hero.stamina
	plan[0] = {"action": "dodge"}
	sim.step()
	plan.erase(0)
	check_near(hero.stamina, before - hero.spec.derived.dodge_stamina, 0.5)


func test_heavy_weapons_and_armor_cost_more() -> void:
	var sword := CombatantSpec.from_champion(champion)
	var hammer := CombatantSpec.from_champion(champion)
	hammer.weapon = Content.weapon("hammer_iron")
	hammer.armor = Content.armor("armor_heavy")
	hammer.refresh()
	check(hammer.derived.attack_stamina > sword.derived.attack_stamina * 1.5)
	check(hammer.derived.heavy_stamina > sword.derived.heavy_stamina * 1.5)
	check(StaminaPhase.action_cost(CombatantState.create(hammer, 0), "dodge") > StaminaPhase.action_cost(CombatantState.create(sword, 0), "dodge"),
			"heavy armor makes dodging dearer")


func test_recovery_waits_then_follows_endurance() -> void:
	var hero := _hero()
	hero.stamina = 40.0
	hero.regen_delay = Content.config.stamina_regen_delay
	_steps(int(Content.config.stamina_regen_delay * sim.tick_rate) - 2)
	check_near(hero.stamina, 40.0, 0.001, "a breath before it comes back")
	_steps(32)
	check_near(hero.stamina - 40.0, hero.spec.derived.stamina_regen, hero.spec.derived.stamina_regen * 0.15,
			"about a second of Endurance-driven recovery")
	var fit := CombatantSpec.from_champion(champion)
	fit.stats["endurance"] = 90.0
	fit.refresh()
	check(fit.derived.stamina_regen > hero.spec.derived.stamina_regen and fit.derived.max_stamina > hero.max_stamina,
			"Endurance raises both the pool and the recovery")


func test_guarding_drains_and_slows_recovery() -> void:
	var hero := _hero()
	plan[0] = {"action": "block"}
	_steps(60)
	check(hero.stamina < hero.max_stamina, "a held guard costs breath")
	check_eq(hero.action, A.BLOCK)


func test_blocked_blows_drain_the_guard_until_it_breaks() -> void:
	var hero := _hero()
	var rook := sim.state.combatants[1]
	hero.position = Vector2(0, -0.6)
	hero.facing = Vector2(0, 1)
	rook.position = Vector2(0, 1)
	rook.facing = Vector2(0, -1)
	hero.stamina = 30.0
	plan[0] = {"action": "block"}
	plan[1] = {"action": "heavy"}
	var broke := false
	for i in 300:
		var frame := sim.step()
		if not frame.events_of("guard_break").is_empty():
			broke = true
			break
	check(broke, "a hammer's pressure breaks a tired guard")
	check(hero.is_exhausted())
	check(hero.action != A.BLOCK)


func test_exhaustion_stops_actions_and_slows_feet() -> void:
	var hero := _hero()
	hero.stamina = 3.0
	plan[0] = {"action": "heavy"}
	sim.step()
	check_eq(hero.action, A.HEAVY, "overexertion is allowed...")
	check(hero.is_exhausted(), "...and ends in exhaustion")
	check_eq(sim.battle_log.events_of("exhausted").size(), 1)
	_steps(int((hero.spec.derived.heavy_windup + hero.spec.derived.active * 1.2 + hero.spec.derived.heavy_recovery) * sim.tick_rate) + 2)
	hero.exhausted_time = 5.0  # hold the exhaustion while measuring
	plan[0] = {"action": "attack"}
	_steps(3)
	check(hero.action != A.ATTACK, "too tired to swing")
	plan[0] = {"move": Vector2(1, 0)}
	_steps(20)
	check(hero.is_exhausted())
	check(hero.velocity.length() < hero.spec.derived.move_speed * Content.config.exhausted_speed_factor + 0.05, "slower feet")
	_steps(int(hero.exhausted_time * sim.tick_rate) + 5)
	check(not hero.is_exhausted())
	plan[0] = {"action": "attack"}
	sim.step()
	check_eq(hero.action, A.ATTACK, "breath back, back to it")


func test_recovery_control_shortens_exhaustion() -> void:
	var trained := CombatantSpec.from_champion(champion)
	trained.skills["skill:recovery_control"] = GameEnums.Rank.EXPERT
	trained.refresh()
	check(trained.derived.exhaustion_seconds < CombatantSpec.from_champion(champion).derived.exhaustion_seconds)
