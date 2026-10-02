extends TestCase
## Stage 14 of the battle simulation: weapons behave differently, and
## learned techniques change what happens.

const A := CombatantState.Action
const P := CombatantState.Phase

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"


func _spec(weapon_id: String = "sword_training", techniques: Array = [], ability_id: String = "") -> CombatantSpec:
	var spec := CombatantSpec.from_champion(champion)
	spec.weapon = Content.weapon(weapon_id)
	spec.techniques = PackedStringArray(techniques)
	if not ability_id.is_empty():
		spec.ability = Content.ability(ability_id)
	spec.refresh()
	return spec


func _state(attacker: CombatantSpec, defender: CombatantSpec) -> BattleState:
	var players: Array[CombatantSpec] = [attacker]
	var opponents: Array[CombatantSpec] = [defender]
	var state := BattleState.create(Content.arena("meadow_ring"), players, opponents, 6)
	state.combatants[0].position = Vector2(0, 1)
	state.combatants[0].facing = Vector2(0, -1)
	state.combatants[1].position = Vector2(0, -0.6)
	state.combatants[1].facing = Vector2(0, 1)
	return state


## Runs one hit from 0 to 1 through contact-independent steps (damage, force).
func _land(state: BattleState, kind: String, extra: Dictionary = {}) -> SimFrame:
	var frame := SimFrame.new(1, state.time, 1.0 / 30.0)
	var hit := {"attacker": 0, "target": 1, "kind": kind, "combo": 1, "swing": 1, "ability": "",
			"direction": Vector2(0, -1), "via": "melee", "outcome": "hit", "technique": "", "flank": false}
	hit.merge(extra, true)
	frame.hits.append(hit)
	DamagePhase.new().run(state, frame)
	ForcePhase.new().run(state, frame)
	return frame


func test_clean_blows_flinch() -> void:
	var state := _state(_spec(), _spec())
	var target := state.combatants[1]
	target.action = A.ATTACK
	target.phase = P.WINDUP
	_land(state, "light")
	check_eq(target.action, A.FLINCH, "the wind-up is interrupted")


func test_hammer_hyper_armor() -> void:
	var state := _state(_spec(), _spec("hammer_iron"))
	var hammer := state.combatants[1]
	hammer.action = A.HEAVY
	hammer.phase = P.WINDUP
	var frame := _land(state, "light")
	check_eq(hammer.action, A.HEAVY, "a hammer's heavy swing shrugs off a sword cut")
	check_eq(frame.events_of("armored").size(), 1)
	check(hammer.stagger_meter > 0.0, "though poise still feels it")
	_land(state, "heavy")
	check(hammer.action != A.HEAVY, "a heavy blow still breaks through")
	var sword_state := _state(_spec(), _spec())
	sword_state.combatants[1].action = A.HEAVY
	sword_state.combatants[1].phase = P.WINDUP
	_land(sword_state, "light")
	check_eq(sword_state.combatants[1].action, A.FLINCH, "a sword's heavy has no such armor")


func test_dagger_flanks() -> void:
	var dagger := _state(_spec("dagger_wolf"), _spec())
	var front := DamagePhase.raw_damage(dagger.combatants[0], {"kind": "light"}) \
			* WeaponRules.damage_factor(dagger, dagger.combatants[0], dagger.combatants[1], {"kind": "light", "flank": false})
	var behind := DamagePhase.raw_damage(dagger.combatants[0], {"kind": "light"}) \
			* WeaponRules.damage_factor(dagger, dagger.combatants[0], dagger.combatants[1], {"kind": "light", "flank": true})
	check_near(behind / front, 1.0 + Content.weapon("dagger_wolf").flank_bonus, 0.001)
	var sword := _state(_spec(), _spec())
	check_eq(WeaponRules.damage_factor(sword, sword.combatants[0], sword.combatants[1], {"kind": "light", "flank": true}), 1.0)
	var hit := {"kind": "light", "combo": 1}
	sword.combatants[1].facing = Vector2(0, -1)  # turned away
	WeaponRules.shape_hit(sword, sword.combatants[0], sword.combatants[1], hit)
	check(hit["flank"], "a blow from behind is a flank")


func test_shield_strengthens_the_guard() -> void:
	var plain := _state(_spec("hammer_iron"), _spec())
	var shielded := _state(_spec("hammer_iron"), _spec("shield_oak"))
	var a := {"kind": "heavy", "via": "melee", "combo": 1}
	var b := a.duplicate()
	for state: BattleState in [plain, shielded]:
		state.combatants[1].action = A.BLOCK
		state.combatants[1].phase = P.ACTIVE
		state.combatants[1].phase_time = 1.0
	DefenseRules.resolve(plain.combatants[0], plain.combatants[1], a)
	DefenseRules.resolve(shielded.combatants[0], shielded.combatants[1], b)
	check(b["guard_drain"] < a["guard_drain"] * 0.6, "a shield pays less stamina per blow")
	check(WeaponRules.guard_factor(shielded.combatants[1]) < WeaponRules.guard_factor(plain.combatants[1]))


func test_bow_is_weak_up_close() -> void:
	var state := _state(_spec("bow_yew"), _spec())
	var hit := {"kind": "light", "via": "projectile", "flank": false}
	var close := WeaponRules.damage_factor(state, state.combatants[0], state.combatants[1], hit)
	state.combatants[1].position = Vector2(0, -8)
	var far := WeaponRules.damage_factor(state, state.combatants[0], state.combatants[1], hit)
	check(close < far, "point-blank shots are weak")


func test_riposte_after_a_guard() -> void:
	var state := _state(_spec("sword_training", ["riposte"]), _spec())
	var me := state.combatants[0]
	var hit := {"kind": "light", "combo": 1}
	WeaponRules.shape_hit(state, me, state.combatants[1], hit)
	check_eq(hit["technique"], "", "no guard, no riposte")
	me.last_guard_time = state.time - 0.3
	WeaponRules.shape_hit(state, me, state.combatants[1], hit)
	check_eq(hit["technique"], "riposte")
	check_near(WeaponRules.damage_factor(state, me, state.combatants[1], hit), Content.technique("riposte").power, 0.001)
	var untaught := _state(_spec(), _spec())
	untaught.combatants[0].last_guard_time = untaught.time - 0.3
	WeaponRules.shape_hit(untaught, untaught.combatants[0], untaught.combatants[1], hit)
	check_eq(hit["technique"], "", "techniques must be learned")


func test_guard_break_technique() -> void:
	var state := _state(_spec("hammer_iron", ["guard_break"]), _spec())
	var defender := state.combatants[1]
	defender.action = A.BLOCK
	defender.phase = P.ACTIVE
	var frame := _land(state, "heavy", {"outcome": "blocked", "technique": "guard_break"})
	check_eq(defender.action, A.STAGGER, "the guard is broken outright")
	check_eq(frame.events_of("guard_break").size(), 1)


func test_flame_slash_sets_burning() -> void:
	var state := _state(_spec("sword_training", ["flame_slash"], "ember_bolt"), _spec())
	var hit := {"kind": "heavy", "combo": 0}
	WeaponRules.shape_hit(state, state.combatants[0], state.combatants[1], hit)
	check_eq(hit["technique"], "flame_slash", "fire attuned")
	_land(state, "heavy", {"technique": "flame_slash"})
	check_eq(state.combatants[1].effects.size(), 1)
	check_eq(state.combatants[1].effects[0]["kind"], "burn")
	var no_fire := _state(_spec("sword_training", ["flame_slash"]), _spec())
	WeaponRules.shape_hit(no_fire, no_fire.combatants[0], no_fire.combatants[1], hit)
	check_eq(hit["technique"], "", "needs its school attuned")


func test_wind_dash_extends_dodges() -> void:
	var dasher := CombatantState.create(_spec("dagger_wolf", ["wind_dash"], "gale_push"), 0)
	check_near(WeaponRules.dodge_factor(dasher), Content.technique("wind_dash").power, 0.001)
	check_eq(WeaponRules.dodge_factor(CombatantState.create(_spec(), 0)), 1.0)


func test_sword_and_hammer_fight_differently() -> void:
	var sword := _brawl("sword_training")
	var hammer := _brawl("hammer_iron")
	check(sword["strikes"] > hammer["strikes"] * 1.5, "the sword strikes far more often (%d vs %d)" % [sword["strikes"], hammer["strikes"]])
	check(sword["flinches"] > 0, "quick cuts keep interrupting")
	check(hammer["knockdowns"] > 0 and sword["knockdowns"] == 0, "only the hammer floors its target")
	check(hammer["push_per_blow"] > sword["push_per_blow"] * 3.0,
			"each hammer blow drives the target back (%.2f vs %.2f)" % [hammer["push_per_blow"], sword["push_per_blow"]])


## 8 seconds of the champion pressing a sparring partner with `weapon_id`.
func _brawl(weapon_id: String) -> Dictionary:
	var players: Array[CombatantSpec] = [_spec(weapon_id)]
	var opponents: Array[CombatantSpec] = [CombatantSpec.from_opponent(Content.opponent("pip"))]
	var sim := BattleSimulator.create(BattleState.create(Content.arena("meadow_ring"), players, opponents, 12))
	sim.use_phase(ScriptedDecisionPhase.new(func(s: BattleState, f: CombatantState, _fr: SimFrame) -> Dictionary:
		if f.team == 1:
			return {}
		var t := s.target_of(f)
		if f.position.distance_to(t.position) > f.spec.derived.attack_range + 0.4:
			return {"move": (t.position - f.position).normalized()}
		return {"action": "heavy" if f.combo_step == 0 and weapon_id == "hammer_iron" else "attack"}))
	for i in 240:
		sim.step()
	var pushes := sim.battle_log.events_of("knockback")
	var push := 0.0
	for event in pushes:
		push += float(event["force"])
	return {"strikes": sim.battle_log.events_of("strike").size(),
			"flinches": sim.battle_log.events_of("flinch").size(),
			"knockdowns": sim.battle_log.events_of("knockdown").size(),
			"push_per_blow": push / maxf(pushes.size(), 1.0)}
