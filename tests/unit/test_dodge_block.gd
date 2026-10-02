extends TestCase
## Stage 11 of the battle simulation: dodging and blocking, decided by
## timing and position at the moment of contact.

const A := CombatantState.Action
const P := CombatantState.Phase

var champion: Champion
var plan: Dictionary = {}
var sim: BattleSimulator


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"
	plan = {}
	sim = _make()


func _make(attacker: CombatantSpec = null) -> BattleSimulator:
	var players: Array[CombatantSpec] = [attacker if attacker != null else CombatantSpec.from_opponent(Content.opponent("rook"))]
	var opponents: Array[CombatantSpec] = [CombatantSpec.from_champion(champion)]
	var made := BattleSimulator.create(BattleState.create(Content.arena("meadow_ring"), players, opponents, 5))
	made.use_phase(ScriptedDecisionPhase.new(func(_s: BattleState, fighter: CombatantState, _f: SimFrame) -> Dictionary:
		return plan.get(fighter.index, {})))
	# Face-to-face at striking distance.
	made.state.combatants[0].position = Vector2(0, 1)
	made.state.combatants[0].facing = Vector2(0, -1)
	made.state.combatants[1].position = Vector2(0, -0.6)
	made.state.combatants[1].facing = Vector2(0, 1)
	return made


func _attacker() -> CombatantState:
	return sim.state.combatants[0]


func _defender() -> CombatantState:
	return sim.state.combatants[1]


## Starts a light attack; the defender acts `defend` when the wind-up has
## `lead` seconds left. Returns the hits of the exchange.
func _exchange(defend: Dictionary, lead: float, hold: bool = true) -> Array[Dictionary]:
	plan[0] = {"action": "attack"}
	var hits: Array[Dictionary] = []
	var started := false
	for i in 60:
		var frame := sim.step()
		plan.erase(0)
		var attacker := _attacker()
		if not started and attacker.action == A.ATTACK and attacker.phase == P.WINDUP \
				and attacker.phase_length - attacker.phase_time <= lead:
			plan[1] = defend
			started = true
		elif started and not hold:
			plan.erase(1)
		hits.append_array(frame.hits)
	return hits


func test_unguarded_blows_land() -> void:
	var hits := _exchange({}, 0.0)
	check_eq(hits.size(), 1)
	check_eq(hits[0]["outcome"], "hit")
	check(_defender().health < _defender().max_health)


func test_well_timed_dodge_evades() -> void:
	var hits := _exchange({"action": "dodge", "dodge_dir": Vector2.RIGHT}, 0.03, false)
	if hits.is_empty():
		# The sidestep may also carry the defender out of reach entirely — also a successful dodge.
		check(sim.battle_log.events_of("whiff").size() == 1, "dodged out of reach")
	else:
		check_eq(hits[0]["outcome"], "evaded", "inside the protected window")
	check_eq(_defender().health, _defender().max_health, "no damage")


func test_dodging_in_place_shows_the_protected_window() -> void:
	var defender := _defender()
	defender.action = A.DODGE
	defender.phase = P.ACTIVE
	defender.phase_time = 0.0
	var hit := {"kind": "light", "via": "melee", "combo": 1}
	DefenseRules.resolve(_attacker(), defender, hit)
	check_eq(hit["outcome"], "evaded")
	check(hit["perfect"], "right at the start of the dodge")
	defender.phase_time = defender.spec.derived.perfect_window
	DefenseRules.resolve(_attacker(), defender, hit)
	check_eq(hit["outcome"], "evaded")
	check(not hit["perfect"])
	defender.phase = P.RECOVERY
	DefenseRules.resolve(_attacker(), defender, hit)
	check_eq(hit["outcome"], "hit", "a dodge's recovery is not protected")


func test_late_dodge_is_hit() -> void:
	var defender := _defender()
	defender.action = A.DODGE
	defender.phase = P.RECOVERY
	var hits := _exchange({}, 0.0)
	check_eq(hits.size(), 1)
	check_eq(hits[0]["outcome"], "hit")


func test_guard_blocks_and_pays_stamina() -> void:
	var hits := _exchange({"action": "block"}, 0.5)
	check_eq(hits.size(), 1)
	check_eq(hits[0]["outcome"], "blocked")
	check(hits[0]["guard_drain"] > 0.0, "a guard pays for what it absorbs")
	var taken := _defender().max_health - _defender().health
	check(taken > 0.0 and taken < hits[0]["damage"] / _defender().spec.derived.block_factor * 0.5, "most damage stopped")
	check_eq(sim.battle_log.events_of("block").size(), 1)


func test_heavier_weapons_press_the_guard() -> void:
	var sword := CombatantSpec.from_champion(champion)
	var hammer := CombatantSpec.from_champion(champion)
	hammer.weapon = Content.weapon("hammer_iron")
	hammer.refresh()
	check(hammer.derived.guard_pressure > sword.derived.guard_pressure * 1.5)


func test_a_guard_raised_just_in_time_parries() -> void:
	var hits := _exchange({"action": "block"}, Content.config.simulation_block_raise_seconds + 0.04)
	check_eq(hits.size(), 1)
	check_eq(hits[0]["outcome"], "parried", "raised moments before the blow")
	check_eq(_defender().health, _defender().max_health)
	check_eq(sim.battle_log.events_of("parry").size(), 1)


func test_timing_skill_widens_the_perfect_window() -> void:
	var trained := CombatantSpec.from_champion(champion)
	trained.skills["skill:timing"] = GameEnums.Rank.EXPERT
	trained.refresh()
	check(trained.derived.perfect_window > CombatantSpec.from_champion(champion).derived.perfect_window)


func test_guard_must_face_the_blow() -> void:
	var defender := _defender()
	defender.action = A.BLOCK
	defender.phase = P.ACTIVE
	defender.phase_time = 1.0
	check(DefenseRules.faces(defender, _attacker().position))
	defender.facing = Vector2(0, -1)  # turned away
	check(not DefenseRules.faces(defender, _attacker().position))
	var hit := {"kind": "light", "via": "melee", "combo": 1}
	DefenseRules.resolve(_attacker(), defender, hit)
	check_eq(hit["outcome"], "hit", "a guard does not cover the back")
	defender.facing = Vector2(0, 1)
	defender.phase = P.WINDUP
	DefenseRules.resolve(_attacker(), defender, hit)
	check_eq(hit["outcome"], "hit", "a guard still rising does not protect")


func test_block_skill_and_defense_strengthen_the_guard() -> void:
	var base := CombatantSpec.from_champion(champion)
	var trained := CombatantSpec.from_champion(champion)
	trained.skills["skill:block"] = GameEnums.Rank.EXPERT
	trained.stats["defense"] = 80.0
	trained.refresh()
	check(trained.derived.block_factor < base.derived.block_factor, "less gets through a trained guard")


func test_dodged_shots_fly_on_blocked_shots_stop() -> void:
	champion.skills.set_rank("magic:fire", GameEnums.Rank.FOUNDATION)
	var caster := CombatantSpec.from_champion(champion)
	caster.ability = Content.ability("ember_bolt")
	caster.refresh()
	sim = _make(caster)
	_attacker().position = Vector2(0, 6)
	_attacker().facing = Vector2(0, -1)
	_defender().position = Vector2(0, -2)
	var defender := _defender()
	defender.action = A.DODGE
	defender.phase = P.ACTIVE
	defender.phase_length = 99.0  # hold the protected window for the test
	plan[0] = {"action": "cast"}
	for i in 90:
		sim.step()
		plan.erase(0)
	check_eq(sim.battle_log.events_of("evade").size(), 1, "the bolt passes through the dodge once")
	check_eq(sim.battle_log.events_of("projectile_faded").size(), 1, "and flies on")
	sim = _make(caster)
	_attacker().position = Vector2(0, 6)
	_attacker().facing = Vector2(0, -1)
	_defender().position = Vector2(0, -2)
	plan[1] = {"action": "block"}
	plan[0] = {"action": "cast"}
	for i in 90:
		sim.step()
		plan.erase(0)
	check_eq(sim.battle_log.events_of("block").size(), 1, "a raised guard takes the bolt")
	check(sim.battle_log.events_of("projectile_faded").is_empty(), "and stops it")
