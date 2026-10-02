extends TestCase
## Stage 10 of the battle simulation: damage and defense.

const A := CombatantState.Action
const P := CombatantState.Phase

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	for item_id in ["sword_training", "hammer_iron", "armor_heavy"]:
		Game.profile.add_item(item_id)
	champion.weapon_id = "sword_training"
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.NOVICE)


func _state(attacker: CombatantSpec, defender: CombatantSpec, seed_value: int = 4) -> BattleState:
	var players: Array[CombatantSpec] = [attacker]
	var opponents: Array[CombatantSpec] = [defender]
	return BattleState.create(Content.arena("meadow_ring"), players, opponents, seed_value)


## Applies one hit of `kind` from combatant 0 to combatant 1; returns damage.
func _deal(state: BattleState, kind: String, extra: Dictionary = {}) -> float:
	var frame := SimFrame.new(1, 0.0, 1.0 / 30.0)
	var hit := {"attacker": 0, "target": 1, "kind": kind, "combo": 1, "swing": 1, "ability": "",
			"direction": Vector2(0, -1), "via": "melee"}
	hit.merge(extra, true)
	frame.hits.append(hit)
	var before := state.combatants[1].health
	DamagePhase.new().run(state, frame)
	return before - state.combatants[1].health


func _me() -> CombatantSpec:
	return CombatantSpec.from_champion(champion)


func _rook() -> CombatantSpec:
	return CombatantSpec.from_opponent(Content.opponent("rook"))


func test_damage_follows_the_formula() -> void:
	var state := _state(_me(), _rook())
	var me := state.combatants[0]
	var rook := state.combatants[1]
	var dealt := _deal(state, "light")
	var expected := me.spec.derived.damage * (1.0 - rook.spec.derived.mitigation)
	var spread := DamagePhase.variation(me, {"kind": "light"})
	check(dealt >= expected * (1.0 - spread) - 0.001 and dealt <= expected * (1.0 + spread) + 0.001,
			"%.1f within %.0f%% of %.1f" % [dealt, spread * 100.0, expected])
	check_eq(rook.health, rook.max_health - dealt, "health actually drops")


func test_heavy_and_combo_finishers_hit_harder() -> void:
	var state := _state(_me(), _rook())
	var me := state.combatants[0]
	check(DamagePhase.raw_damage(me, {"kind": "heavy"}) > DamagePhase.raw_damage(me, {"kind": "light", "combo": 1}) * 1.5)
	check(DamagePhase.raw_damage(me, {"kind": "light", "combo": 3}) > DamagePhase.raw_damage(me, {"kind": "light", "combo": 1}))


func test_attack_and_strength_raise_damage() -> void:
	var base := _me()
	var strong := _me()
	strong.stats["attack"] = 80.0
	strong.refresh()
	check(strong.derived.damage > base.derived.damage, "Attack raises offensive output")
	var heavy_base := _me()
	heavy_base.weapon = Content.weapon("hammer_iron")
	heavy_base.refresh()
	var heavy_strong := _me()
	heavy_strong.weapon = Content.weapon("hammer_iron")
	heavy_strong.stats["strength"] = 85.0
	heavy_strong.refresh()
	check(heavy_strong.derived.heavy_damage > heavy_base.derived.heavy_damage * 1.1,
			"Strength drives heavy blows harder than light ones")


func test_defense_and_armor_reduce_damage() -> void:
	var light_target := _me()
	var heavy_target := _me()
	heavy_target.armor = Content.armor("armor_heavy")
	heavy_target.stats["defense"] = 70.0
	heavy_target.refresh()
	var a := _state(_rook(), light_target, 9)
	var b := _state(_rook(), heavy_target, 9)
	var into_light := _deal(a, "heavy")
	var into_heavy := _deal(b, "heavy")
	check(into_heavy < into_light * 0.85, "armor and Defense absorb (%.1f vs %.1f)" % [into_heavy, into_light])


func test_mastery_makes_damage_consistent() -> void:
	var novice := _me()
	var expert := _me()
	expert.skills["weapon:sword"] = GameEnums.Rank.EXPERT
	expert.refresh()
	var a := _state(novice, _rook())
	var b := _state(expert, _rook())
	check(DamagePhase.variation(b.combatants[0], {"kind": "light"}) < DamagePhase.variation(a.combatants[0], {"kind": "light"}),
			"an expert swings more consistently")
	var spread_novice := _spread(novice)
	var spread_expert := _spread(expert)
	check(spread_expert < spread_novice, "observed spread %.2f vs %.2f" % [spread_expert, spread_novice])


func _spread(attacker: CombatantSpec) -> float:
	var low := INF
	var high := 0.0
	for i in 40:
		var state := _state(attacker, _rook(), 100 + i)
		var dealt := _deal(state, "light")
		low = minf(low, dealt)
		high = maxf(high, dealt)
	return (high - low) / ((high + low) * 0.5)


func test_punishing_an_opening() -> void:
	var calm := _state(_me(), _rook(), 7)
	var exposed := _state(_me(), _rook(), 7)
	exposed.combatants[1].action = A.HEAVY
	exposed.combatants[1].phase = P.RECOVERY
	var normal := _deal(calm, "light")
	var punish := _deal(exposed, "light")
	check(punish > normal * 1.1, "hitting a recovering hammer pays (%.1f vs %.1f)" % [punish, normal])
	check(DamagePhase.is_open(exposed.combatants[1]))
	exposed.combatants[1].action = A.HEAVY
	exposed.combatants[1].phase = P.ACTIVE
	check(not DamagePhase.is_open(exposed.combatants[1]), "not while the blow is landing")


func test_art_damage_scales_with_mastery() -> void:
	var foundation := _me()
	foundation.skills["magic:fire"] = GameEnums.Rank.FOUNDATION
	foundation.ability = Content.ability("ember_bolt")
	foundation.refresh()
	var skilled := _me()
	skilled.skills["magic:fire"] = GameEnums.Rank.SKILLED
	skilled.ability = Content.ability("ember_bolt")
	skilled.refresh()
	var a := _state(foundation, _rook())
	var b := _state(skilled, _rook())
	var hit := {"kind": "cast", "ability": "ember_bolt"}
	check_near(DamagePhase.raw_damage(a.combatants[0], hit), Content.ability("ember_bolt").damage, 0.001)
	check(DamagePhase.raw_damage(b.combatants[0], hit) > DamagePhase.raw_damage(a.combatants[0], hit))


func test_evaded_and_blocked_hits() -> void:
	var a := _state(_me(), _rook(), 3)
	var b := _state(_me(), _rook(), 3)
	var c := _state(_me(), _rook(), 3)
	var clean := _deal(a, "light")
	var guarded := _deal(b, "light", {"outcome": "blocked"})
	check_eq(_deal(c, "light", {"outcome": "evaded"}), 0.0, "an evaded blow does nothing")
	check_near(guarded, clean * b.combatants[1].spec.derived.block_factor, 0.01, "a guard lets only a little through")


func test_a_scripted_fight_reaches_a_knockout() -> void:
	var state := _state(_me(), _rook(), 21)
	var sim := BattleSimulator.create(state)
	sim.use_phase(ScriptedDecisionPhase.new(func(s: BattleState, f: CombatantState, _fr: SimFrame) -> Dictionary:
		var t := s.target_of(f)
		if f.position.distance_to(t.position) > f.spec.derived.attack_range + 0.4:
			return {"move": (t.position - f.position).normalized()}
		return {"action": "attack" if f.team == 0 else "heavy"}))
	var battle_log := sim.run()
	check(sim.state.finished)
	check(sim.state.winner_team >= 0, "health ran out for someone: a decided battle")
	check_eq(battle_log.events_of("battle_end")[0]["reason"], "knockout")
	check(not battle_log.events_of("damage").is_empty())
	var replay := BattleSimulator.create(_state(_me(), _rook(), 21))
	replay.use_phase(sim.phases[0])
	check_eq(JSON.stringify(replay.run().events), JSON.stringify(battle_log.events), "the same seed, the same fight")
