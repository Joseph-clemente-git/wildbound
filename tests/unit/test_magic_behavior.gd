extends TestCase
## Stage 15 of the battle simulation: what Aether Arts do, and how they are
## answered.

const A := CombatantState.Action
const P := CombatantState.Phase

var champion: Champion
var plan: Dictionary = {}


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"
	plan = {}


func _caster(ability_id: String, rank: int = GameEnums.Rank.APPRENTICE) -> CombatantSpec:
	var spec := CombatantSpec.from_champion(champion)
	var ability := Content.ability(ability_id)
	spec.skills["magic:" + ability.school] = rank
	spec.ability = ability
	spec.refresh()
	return spec


func _sim(attacker: CombatantSpec, defender: CombatantSpec = null) -> BattleSimulator:
	var players: Array[CombatantSpec] = [attacker]
	var opponents: Array[CombatantSpec] = [defender if defender != null else CombatantSpec.from_opponent(Content.opponent("pip"))]
	var sim := BattleSimulator.create(BattleState.create(Content.arena("meadow_ring"), players, opponents, 4))
	sim.use_phase(ScriptedDecisionPhase.new(func(_s: BattleState, f: CombatantState, _fr: SimFrame) -> Dictionary:
		return plan.get(f.index, {})))
	sim.state.combatants[0].position = Vector2(0, 3)
	sim.state.combatants[0].facing = Vector2(0, -1)
	sim.state.combatants[1].position = Vector2(0, -1)
	sim.state.combatants[1].facing = Vector2(0, 1)
	return sim


func _cast_and_run(sim: BattleSimulator, ticks: int) -> void:
	plan[0] = {"action": "cast"}
	for i in ticks:
		sim.step()
		plan.erase(0)


func test_ember_bolt_burns() -> void:
	var sim := _sim(_caster("ember_bolt"))
	_cast_and_run(sim, 45)
	var target := sim.state.combatants[1]
	check_eq(target.effects.size(), 1, "the bolt leaves a burn")
	check_eq(target.effects[0]["kind"], "burn")
	var after_hit := target.health
	for i in 30:
		sim.step()
	check(target.health < after_hit, "the burn keeps hurting")
	var burns := 0
	for event in sim.battle_log.events_of("damage"):
		if event["kind"] == "burn":
			burns += 1
	check(burns >= 3, "in quarter-second pulses")
	for i in int(Content.ability("ember_bolt").burn_seconds * 30) + 5:
		sim.step()
	check(target.effects.is_empty(), "and burns out")


func test_effects_refresh_instead_of_stacking() -> void:
	var target := CombatantState.create(CombatantSpec.from_champion(champion), 1)
	EffectRules.burn(target, 4.0, 3.0, 0)
	EffectRules.burn(target, 4.0, 3.0, 0)
	EffectRules.burn(target, 6.0, 1.0, 0)
	check_eq(target.effects.size(), 1)
	check_eq(target.effects[0]["dps"], 6.0, "the stronger burn")
	check_eq(target.effects[0]["time"], 3.0, "and the longer time")


func test_slows_and_wards() -> void:
	var target := CombatantState.create(CombatantSpec.from_champion(champion), 1)
	EffectRules.on_art_hit(Content.ability("frost_shard"), target, target)
	check_near(EffectRules.speed_factor(target), 1.0 - Content.ability("frost_shard").slow_factor, 0.001, "Frost slows")
	var caster := CombatantState.create(CombatantSpec.from_champion(champion), 0)
	EffectRules.on_release(Content.ability("stone_ward"), caster)
	check_near(EffectRules.ward_factor(caster), 0.5, 0.001, "Earth wards its caster")
	var sim := _sim(CombatantSpec.from_champion(champion))
	var slowed := sim.state.combatants[1]
	EffectRules.apply(slowed, {"kind": "slow", "factor": 0.5, "time": 5.0, "source": 0})
	plan[1] = {"move": Vector2(1, 0)}
	for i in 45:
		sim.step()
	check(slowed.velocity.length() < slowed.spec.derived.move_speed * 0.55, "a slowed body moves slowly")


func test_wind_step_is_a_protected_dash() -> void:
	var sim := _sim(_caster("wind_step", GameEnums.Rank.SKILLED))
	var me := sim.state.combatants[0]
	var start := me.position
	plan[0] = {"action": "cast", "move": Vector2(1, 0)}
	sim.step()
	plan.erase(0)
	var dashed := false
	for i in 40:
		sim.step()
		if me.action == A.DODGE and me.phase == P.ACTIVE:
			dashed = true
	check(dashed, "the gust carries the caster as a protected dash")
	check(me.position.x - start.x > Content.ability("wind_step").speed * 0.8, "about the Art's distance (%.1f m)" % (me.position.x - start.x))
	check(me.cooldown("magic") > 0.0)


func test_gale_push_and_flame_burst_push_away() -> void:
	var gale := _sim(_caster("gale_push"))
	_cast_and_run(gale, 30)
	check(not gale.battle_log.events_of("knockback").is_empty(), "the gust shoves")
	check(gale.state.combatants[1].position.y < -1.0, "away from the caster")
	var burst := _sim(_caster("flame_burst", GameEnums.Rank.SKILLED))
	burst.state.combatants[1].position = Vector2(0, 1.5)
	_cast_and_run(burst, 40)
	check_eq(burst.battle_log.events_of("hit").size(), 1)
	check(burst.state.combatants[1].effects.size() == 1, "and burns")


func test_casting_can_be_interrupted() -> void:
	var sim := _sim(_caster("ember_bolt"), CombatantSpec.from_champion(champion))
	var me := sim.state.combatants[0]
	var foe := sim.state.combatants[1]
	foe.position = Vector2(0, 1.6)
	foe.facing = Vector2(0, 1)
	plan[0] = {"action": "cast"}
	plan[1] = {"action": "attack"}
	var stamina_before := me.stamina
	for i in 30:
		sim.step()
		plan.erase(0)
		plan.erase(1)
	check_eq(sim.battle_log.events_of("interrupted").size(), 1, "a cut during the wind-up breaks the cast")
	check(sim.battle_log.events_of("cast_release").is_empty(), "nothing is released")
	check_eq(me.cooldown("magic"), 0.0, "no cooldown started")
	check(me.stamina < stamina_before, "but the effort is spent")


func test_mastery_casts_faster() -> void:
	var novice := CombatantState.create(_caster("ember_bolt", GameEnums.Rank.FOUNDATION), 0)
	var master := CombatantState.create(_caster("ember_bolt", GameEnums.Rank.EXPERT), 0)
	check(ActionPhase.timings(master, A.CAST)[0] < ActionPhase.timings(novice, A.CAST)[0])


func test_magic_does_not_win_by_itself() -> void:
	var sim := _sim(_caster("ember_bolt"))
	sim.state.combatants[1].position = Vector2(0, -6)
	plan[0] = {"action": "cast"}
	var dodged := false
	for i in 120:
		var frame := sim.step()
		plan.erase(0)
		if not frame.events_of("projectile").is_empty():
			plan[1] = {"action": "dodge", "dodge_dir": Vector2.RIGHT}
			dodged = true
		elif dodged:
			plan.erase(1)
	check_eq(sim.state.combatants[1].health, sim.state.combatants[1].max_health, "a slow bolt is answered")
