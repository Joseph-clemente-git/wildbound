extends TestCase
## Stage 8 of the battle simulation: timed actions and movement. Fighters are
## driven by scripted intents; hits, damage and stamina come in later stages.

const A := CombatantState.Action
const P := CombatantState.Phase

var champion: Champion
var plan: Dictionary = {}  # combatant index -> intent
var sim: BattleSimulator


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	for item_id in ["sword_training", "hammer_iron"]:
		Game.profile.add_item(item_id)
	champion.weapon_id = "sword_training"
	plan = {}
	sim = _make(champion)


func _make(who: Champion, trial_id: String = "stonewall_bout") -> BattleSimulator:
	var made := BattleSimulator.create(BattleState.for_fight(Content.trial(trial_id), who, 11))
	made.use_phase(ScriptedDecisionPhase.new(func(_s: BattleState, fighter: CombatantState, _f: SimFrame) -> Dictionary:
		return plan.get(fighter.index, {})))
	return made


func _hero() -> CombatantState:
	return sim.state.combatants[0]


func _rook() -> CombatantState:
	return sim.state.combatants[1]


func _steps(count: int) -> void:
	for i in count:
		sim.step()


## Ticks until `condition` holds, or -1.
func _ticks_until(condition: Callable, limit: int = 300) -> int:
	for i in limit:
		sim.step()
		if condition.call():
			return i + 1
	return -1


func test_attack_runs_windup_active_recovery() -> void:
	var hero := _hero()
	var d := hero.spec.derived
	plan[0] = {"action": "attack"}
	sim.step()
	plan.erase(0)
	check_eq(hero.action, A.ATTACK)
	check_eq(hero.phase, P.WINDUP)
	check_near(hero.phase_length, d.windup, 0.0001, "wind-up from weapon and Attack Speed")
	var to_strike := _ticks_until(func() -> bool: return hero.phase == P.ACTIVE)
	check(absf(to_strike * sim.tick_seconds - d.windup) < sim.tick_seconds, "strikes when the wind-up ends")
	check_eq(sim.battle_log.events_of("strike").size(), 1)
	check_eq(sim.battle_log.events_of("strike")[0]["kind"], "light")
	var total := to_strike + _ticks_until(func() -> bool: return hero.action != A.ATTACK)
	check(absf(total * sim.tick_seconds - (d.windup + d.active + d.recovery)) <= sim.tick_seconds * 2,
			"the whole swing takes wind-up + active + recovery")
	check_eq(sim.battle_log.events_of("action_end")[0]["action"], "attack")


func test_strike_is_handed_to_contact_resolution() -> void:
	plan[0] = {"action": "attack"}
	var contacts: Array = []
	for i in 30:
		var frame := sim.step()
		plan.erase(0)
		contacts.append_array(frame.contacts)
	check_eq(contacts.size(), 1, "one swing, one contact")
	check_eq(contacts[0]["attacker"], 0)
	check_eq(contacts[0]["target"], 1)


func test_weapons_have_different_rhythms() -> void:
	var sword := ActionPhase.timings(_hero(), A.ATTACK)
	var sword_heavy := ActionPhase.timings(_hero(), A.HEAVY)
	champion.weapon_id = "hammer_iron"
	sim = _make(champion)
	var hammer := ActionPhase.timings(_hero(), A.ATTACK)
	check(hammer[0] > sword[0] * 1.5, "a hammer winds up far longer than a sword")
	check(hammer[2] > sword[2], "and recovers longer")
	check(sword_heavy[0] > sword[0] and sword_heavy[2] > sword[2], "heavy attacks commit longer")


func test_attack_speed_and_mastery_quicken_swings() -> void:
	var base := ActionPhase.timings(_hero(), A.ATTACK)[0]
	var quick := CombatantSpec.from_champion(champion)
	quick.stats["attack_speed"] = 90.0
	quick.refresh()
	var trained := CombatantSpec.from_champion(champion)
	trained.skills["weapon:sword"] = GameEnums.Rank.EXPERT
	trained.refresh()
	check(quick.derived.windup < base, "Attack Speed shortens the wind-up")
	check(trained.derived.windup < base, "Expert sword handling shortens it too")
	check(trained.derived.combo_max > CombatantSpec.from_champion(champion).derived.combo_max, "and lengthens combos")


func test_light_attacks_chain_into_combos() -> void:
	var hero := _hero()
	plan[0] = {"action": "attack"}
	var combo_max := hero.spec.derived.combo_max
	_steps(int((hero.spec.derived.windup + hero.spec.derived.active + hero.spec.derived.recovery) * sim.tick_rate * (combo_max + 1)))
	var strikes := sim.battle_log.events_of("strike")
	check(strikes.size() >= combo_max, "kept swinging")
	for i in combo_max:
		check_eq(strikes[i]["combo"], i + 1, "combo step %d" % (i + 1))
	if strikes.size() > combo_max:
		check_eq(strikes[combo_max]["combo"], 1, "the chain resets after the last hit")


func test_committed_actions_cannot_be_cancelled() -> void:
	var hero := _hero()
	plan[0] = {"action": "heavy"}
	sim.step()
	plan[0] = {"action": "dodge"}
	_steps(3)
	check_eq(hero.action, A.HEAVY, "a heavy wind-up is a commitment")
	check(sim.battle_log.events_of("dodge").is_empty())


func test_dodge_travels_its_distance_then_stops() -> void:
	var hero := _hero()
	var start := hero.position
	plan[0] = {"action": "dodge", "dodge_dir": Vector2.RIGHT}
	sim.step()
	plan.erase(0)
	check_eq(hero.action, A.DODGE)
	check_eq(hero.phase, P.ACTIVE, "the protected window opens at once")
	_ticks_until(func() -> bool: return hero.action != A.DODGE)
	var travelled := hero.position.x - start.x
	check(absf(travelled - hero.spec.derived.dodge_distance) < hero.spec.derived.dodge_distance * 0.2,
			"travelled %.2f of %.2f" % [travelled, hero.spec.derived.dodge_distance])
	check(hero.velocity.length() < 0.01, "stops after the dodge")


func test_default_dodge_is_a_sidestep() -> void:
	var hero := _hero()
	var toward := (_rook().position - hero.position).normalized()
	plan[0] = {"action": "dodge"}
	sim.step()
	check(absf(hero.dodge_direction.dot(toward)) < 0.01, "sideways to the opponent")


func test_guard_raises_holds_and_drops() -> void:
	var hero := _hero()
	plan[0] = {"action": "block"}
	sim.step()
	check_eq(hero.action, A.BLOCK)
	check_eq(hero.phase, P.WINDUP, "a guard takes a moment to raise")
	_steps(4)
	check_eq(hero.phase, P.ACTIVE)
	check_eq(sim.battle_log.events_of("block_up").size(), 1)
	_steps(30)
	check_eq(hero.action, A.BLOCK, "held as long as wanted")
	plan[0] = {"action": "attack"}
	sim.step()
	check_eq(sim.battle_log.events_of("block_down").size(), 1)
	check_eq(hero.action, A.ATTACK, "guard drops into an attack")


func test_casting_needs_an_art_and_respects_cooldown() -> void:
	plan[0] = {"action": "cast"}
	_steps(5)
	check(sim.battle_log.events_of("cast_release").is_empty(), "no Art, no cast")
	champion.skills.set_rank("magic:fire", GameEnums.Rank.FOUNDATION)
	champion.equipped_ability = "ember_bolt"
	sim = _make(champion)
	var hero := _hero()
	var ember := Content.ability("ember_bolt")
	_ticks_until(func() -> bool: return not sim.battle_log.events_of("cast_release").is_empty())
	check_near(hero.cooldown("magic"), ember.cooldown, 0.05, "cooldown starts on release")
	_steps(int((ember.recovery + 0.5) * sim.tick_rate))
	check_eq(sim.battle_log.events_of("cast_release").size(), 1, "no second cast while cooling down")
	_steps(int(ember.cooldown * sim.tick_rate))
	check_eq(sim.battle_log.events_of("cast_release").size(), 2, "casts again once ready")


func test_movement_speed_and_responsiveness() -> void:
	var hero := _hero()
	plan[0] = {"move": Vector2(0, -1)}
	_steps(60)
	check_near(hero.velocity.length(), hero.spec.derived.move_speed, 0.05, "reaches its move speed")
	check_eq(hero.action, A.MOVE)
	var nimble := CombatantSpec.from_champion(champion)
	nimble.stats["agility"] = 95.0
	var heavy := CombatantSpec.from_champion(champion)
	heavy.stats["agility"] = 15.0
	var quick := CombatantState.create(nimble, 0)
	var slow := CombatantState.create(heavy, 0)
	check(MovementPhase.responsiveness(quick) > MovementPhase.responsiveness(slow), "Agility answers faster")
	plan.erase(0)
	_steps(40)
	check_eq(hero.action, A.IDLE, "stops when it stops wanting to move")


func test_movement_slows_while_guarding_and_plants_when_striking() -> void:
	var hero := _hero()
	hero.action = A.BLOCK
	check_near(MovementPhase.speed_factor(hero), Content.config.simulation_block_move_factor)
	hero.action = A.HEAVY
	hero.phase = P.WINDUP
	check(MovementPhase.speed_factor(hero) > 0.0, "can step in during the wind-up")
	hero.phase = P.ACTIVE
	check_eq(MovementPhase.speed_factor(hero), 0.0, "planted while the blow lands")


func test_ring_obstacles_and_bodies_stop_movement() -> void:
	var hero := _hero()
	plan[0] = {"move": Vector2(0, 1)}
	_steps(150)
	check(hero.position.length() <= sim.state.layout.radius - CombatantState.BODY_RADIUS + 0.001, "stays inside the ring")
	for fighter in sim.state.combatants:
		check(sim.state.layout.is_open(fighter.position, CombatantState.BODY_RADIUS - 0.001), "never inside an obstacle")
	var rock := sim.state.layout.obstacles[0]
	hero.position = Vector2(rock.x, rock.y) + Vector2(rock.z + 3.0, 0)
	hero.velocity = Vector2.ZERO
	plan[0] = {"move": Vector2(-1, 0)}
	_steps(90)
	check(hero.position.distance_to(Vector2(rock.x, rock.y)) >= rock.z + CombatantState.BODY_RADIUS - 0.001, "walks into a stone, not through it")
	plan[0] = {"move": (_rook().position - hero.position).normalized()}
	plan[1] = {"move": (hero.position - _rook().position).normalized()}
	for i in 200:
		plan[0] = {"move": (_rook().position - hero.position).normalized()}
		plan[1] = {"move": (hero.position - _rook().position).normalized()}
		sim.step()
	check(hero.position.distance_to(_rook().position) >= CombatantState.BODY_RADIUS * 2.0 - 0.01, "bodies do not overlap")


func test_turning_is_limited_and_tracks_the_target() -> void:
	var hero := _hero()
	hero.facing = Vector2(0, 1)  # facing away
	sim.step()
	var toward := (_rook().position - hero.position).normalized()
	check(hero.facing.dot(toward) < 0.99, "cannot spin instantly")
	_steps(30)
	check(hero.facing.dot(toward) > 0.99, "turns to face the opponent")


func test_stagger_timer_runs_out() -> void:
	var hero := _hero()
	hero.action = A.STAGGER
	hero.phase = P.RECOVERY
	hero.phase_time = 0.0
	hero.phase_length = 0.3
	plan[0] = {"action": "attack"}
	_steps(5)
	check_eq(hero.action, A.STAGGER, "cannot act while staggered")
	_steps(6)
	check(hero.action == A.ATTACK, "acts again once recovered")


func test_actions_are_deterministic() -> void:
	plan[0] = {"action": "attack", "move": Vector2(0, -1)}
	plan[1] = {"action": "heavy", "move": Vector2(0, 1)}
	_steps(120)
	var first := JSON.stringify(sim.battle_log.to_dict())
	sim = _make(champion)
	_steps(120)
	check_eq(JSON.stringify(sim.battle_log.to_dict()), first)
