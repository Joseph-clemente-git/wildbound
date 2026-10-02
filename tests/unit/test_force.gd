extends TestCase
## Stage 13 of the battle simulation: stagger, knockdown and knockback.

const A := CombatantState.Action

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	for item_id in ["sword_training", "hammer_iron", "armor_heavy"]:
		Game.profile.add_item(item_id)
	champion.weapon_id = "sword_training"


func _spec(weapon_id: String = "sword_training", armor_id: String = "armor_light", stats: Dictionary = {}) -> CombatantSpec:
	var spec := CombatantSpec.from_champion(champion)
	spec.weapon = Content.weapon(weapon_id)
	spec.armor = Content.armor(armor_id)
	for stat: String in stats:
		spec.stats[stat] = stats[stat]
	spec.refresh()
	return spec


func _state(attacker: CombatantSpec, defender: CombatantSpec) -> BattleState:
	var players: Array[CombatantSpec] = [attacker]
	var opponents: Array[CombatantSpec] = [defender]
	return BattleState.create(Content.arena("meadow_ring"), players, opponents, 2)


## Lands `count` hits of `kind` from 0 on 1 through the force step.
func _land(state: BattleState, kind: String, count: int = 1, outcome: String = "hit") -> SimFrame:
	var frame := SimFrame.new(1, 0.0, 1.0 / 30.0)
	for i in count:
		frame.hits.append({"attacker": 0, "target": 1, "kind": kind, "combo": 1, "swing": i, "ability": "",
				"direction": Vector2(0, -1), "via": "melee", "outcome": outcome})
	ForcePhase.new().run(state, frame)
	return frame


func test_light_blows_build_toward_a_stagger() -> void:
	var state := _state(_spec(), _spec())
	var target := state.combatants[1]
	_land(state, "light")
	check(target.stagger_meter > 0.0)
	check(target.action != A.STAGGER, "one sword cut does not stagger")
	var hits := 1
	while target.action != A.STAGGER and hits < 20:
		_land(state, "light")
		hits += 1
	check(hits > 1 and hits < 20, "repeated cuts break poise (%d)" % hits)
	check_eq(target.stagger_meter, 0.0, "the meter resets on a stagger")


func test_hammer_heavies_stagger_and_knock_down() -> void:
	var state := _state(_spec("hammer_iron", "armor_light", {"strength": 75.0}), _spec())
	var frame := _land(state, "heavy")
	var target := state.combatants[1]
	check(target.action == A.STAGGER or target.action == A.KNOCKDOWN, "one hammer blow is enough")
	check(not frame.events_of("knockback").is_empty())
	check(target.push_velocity.dot(Vector2(0, -1)) > 0.0, "pushed along the blow")


func test_strength_is_not_attack() -> void:
	var strong := _spec("sword_training", "armor_light", {"strength": 90.0})
	var sharp := _spec("sword_training", "armor_light", {"attack": 90.0})
	check(strong.derived.stagger_power > sharp.derived.stagger_power, "Strength staggers")
	check(strong.derived.knockback_power > sharp.derived.knockback_power, "Strength pushes")
	check(sharp.derived.damage > strong.derived.damage, "Attack cuts")


func test_defense_and_armor_resist_force() -> void:
	var light := _state(_spec("hammer_iron"), _spec())
	var heavy := _state(_spec("hammer_iron"), _spec("sword_training", "armor_heavy", {"defense": 80.0}))
	_land(light, "light")
	_land(heavy, "light")
	check(heavy.combatants[1].stagger_meter < light.combatants[1].stagger_meter, "armor shrinks stagger")
	check(heavy.combatants[1].spec.derived.poise > light.combatants[1].spec.derived.poise, "Defense raises poise")
	check(heavy.combatants[1].push_velocity.length() < light.combatants[1].push_velocity.length(), "and resists the push")


func test_stagger_interrupts_and_recovers() -> void:
	var state := _state(_spec("hammer_iron", "armor_light", {"strength": 80.0}), _spec())
	var target := state.combatants[1]
	target.action = A.HEAVY
	target.phase = CombatantState.Phase.WINDUP
	_land(state, "heavy")
	check(target.action in [A.STAGGER, A.KNOCKDOWN], "the wind-up is lost")
	var nimble := _spec("sword_training", "armor_light", {"agility": 95.0})
	var stiff := _spec("sword_training", "armor_light", {"agility": 10.0})
	check(ForcePhase.stagger_seconds(CombatantState.create(nimble, 0), 0.5) < ForcePhase.stagger_seconds(CombatantState.create(stiff, 0), 0.5),
			"Agility recovers faster")
	var trained := _spec()
	trained.skills["skill:recovery"] = GameEnums.Rank.EXPERT
	trained.refresh()
	check(ForcePhase.stagger_seconds(CombatantState.create(trained, 0), 0.5) < ForcePhase.stagger_seconds(CombatantState.create(_spec(), 0), 0.5),
			"recovery skill too")


func test_guards_feel_a_little_force() -> void:
	var open := _state(_spec("hammer_iron"), _spec())
	var guarded := _state(_spec("hammer_iron"), _spec())
	_land(open, "heavy")
	_land(guarded, "heavy", 1, "blocked")
	check(guarded.combatants[1].action != A.STAGGER and guarded.combatants[1].action != A.KNOCKDOWN, "a guard holds")
	check(guarded.combatants[1].stagger_meter > 0.0, "but feels the pressure")
	check(guarded.combatants[1].push_velocity.length() < open.combatants[1].push_velocity.length() * 0.6)


func test_parry_staggers_the_attacker() -> void:
	var state := _state(_spec(), _spec())
	var frame := _land(state, "light", 1, "parried")
	check_eq(state.combatants[0].action, A.STAGGER)
	check_eq(frame.events_of("staggered")[0]["reason"], "parried")


func test_the_meter_drains_and_pushes_slide_out() -> void:
	var state := _state(_spec("hammer_iron"), _spec())
	var sim := BattleSimulator.create(state)
	var target := state.combatants[1]
	target.stagger_meter = target.spec.derived.poise * 0.5
	target.push_velocity = Vector2(0, -6)
	var start := target.position
	for i in 60:
		sim.step()
	check_eq(target.stagger_meter, 0.0, "left alone, poise returns")
	check(target.push_velocity.length() < 0.01, "the push slides out")
	check(target.position.distance_to(start) > 1.0, "after carrying the body back")


func test_a_broken_guard_staggers() -> void:
	var state := _state(_spec(), _spec())
	var sim := BattleSimulator.create(state)
	var defender := state.combatants[1]
	defender.action = A.BLOCK
	defender.phase = CombatantState.Phase.ACTIVE
	defender.stamina = 0.05
	sim.use_phase(ScriptedDecisionPhase.new(func(_s: BattleState, f: CombatantState, _f2: SimFrame) -> Dictionary:
		return {"action": "block"} if f.index == 1 else {}))
	sim.step()
	check_eq(sim.battle_log.events_of("guard_break").size(), 1)
	check_eq(defender.action, A.STAGGER)
