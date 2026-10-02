class_name BattleState
extends RefCounted
## The complete state of one simulated battle: the arena, every combatant on
## every team, the clock and the seeded random source. The simulation reads
## and advances this; nothing about the battle lives anywhere else, so the
## same state can be stepped headless, replayed in 3D or saved for review.
##
## Teams make the format: one combatant per side is 1v1, two is 2v2, and so
## on. Team 0 is the Keeper's side.

const PLAYER_TEAM := 0
const OPPONENT_TEAM := 1

var trial_id := ""
var arena: ArenaData
var layout: ArenaLayout
var combatants: Array[CombatantState] = []
var tick := 0
var time := 0.0
## Seed for every bit of controlled variation, kept so a battle can be
## replayed exactly.
var battle_seed := 0
var rng := RandomNumberGenerator.new()
var finished := false
## -1 while undecided.
var winner_team := -1


## Sets up a battle between two teams of specs on an arena: positions from
## the arena's spawns, everyone facing the other side at full health and
## stamina.
static func create(arena_data: ArenaData, player_specs: Array[CombatantSpec],
		opponent_specs: Array[CombatantSpec], seed_value: int, trial: String = "") -> BattleState:
	var state := BattleState.new()
	state.trial_id = trial
	state.arena = arena_data
	state.layout = ArenaLayout.from_arena(arena_data)
	state.battle_seed = seed_value
	state.rng.seed = seed_value
	for team in 2:
		var specs: Array[CombatantSpec] = player_specs if team == PLAYER_TEAM else opponent_specs
		for slot in specs.size():
			var fighter := CombatantState.create(specs[slot], team)
			fighter.index = state.combatants.size()
			fighter.position = state.layout.spawn_point(team, slot)
			state.combatants.append(fighter)
	for fighter in state.combatants:
		var target := state.nearest_enemy(fighter)
		if target != null:
			fighter.target_index = target.index
			fighter.facing = (target.position - fighter.position).normalized()
	return state


## The usual MVP battle: the chosen champion against the fight's opponent.
## The seed is derived from the fight and the champion's record unless given.
static func for_fight(trial: TrialData, champion: Champion, seed_value: int = 0) -> BattleState:
	if seed_value == 0:
		seed_value = hash("%s|%s|%d" % [trial.id, champion.uid, champion.wins + champion.losses])
	var players: Array[CombatantSpec] = [CombatantSpec.from_champion(champion)]
	var opponents: Array[CombatantSpec] = [CombatantSpec.from_opponent(Content.opponent(trial.opponent_id))]
	return create(Content.arena(trial.arena_id), players, opponents, seed_value, trial.id)


func team(team_index: int) -> Array[CombatantState]:
	var result: Array[CombatantState] = []
	for fighter in combatants:
		if fighter.team == team_index:
			result.append(fighter)
	return result


func living(team_index: int) -> Array[CombatantState]:
	var result: Array[CombatantState] = []
	for fighter in team(team_index):
		if fighter.is_alive():
			result.append(fighter)
	return result


func enemies_of(fighter: CombatantState) -> Array[CombatantState]:
	var result: Array[CombatantState] = []
	for other in combatants:
		if other.team != fighter.team:
			result.append(other)
	return result


func nearest_enemy(fighter: CombatantState) -> CombatantState:
	var best: CombatantState = null
	var best_distance := INF
	for other in enemies_of(fighter):
		if not other.is_alive():
			continue
		var distance := fighter.position.distance_to(other.position)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best


func target_of(fighter: CombatantState) -> CombatantState:
	if fighter.target_index < 0 or fighter.target_index >= combatants.size():
		return null
	return combatants[fighter.target_index]


## Problems that would make the battle unfair or impossible to simulate.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for team_index in 2:
		if team(team_index).is_empty():
			problems.append("team %d has no combatants" % team_index)
	for fighter in combatants:
		if not layout.is_open(fighter.position, CombatantState.BODY_RADIUS):
			problems.append("%s starts outside the ring or inside an obstacle" % fighter.spec.display_name)
		if fighter.max_health <= 0.0 or fighter.max_stamina <= 0.0:
			problems.append("%s has no health or stamina" % fighter.spec.display_name)
		for other in combatants:
			if other.index > fighter.index and \
					fighter.position.distance_to(other.position) < CombatantState.BODY_RADIUS * 2.0:
				problems.append("%s and %s start on top of each other" % [fighter.spec.display_name, other.spec.display_name])
	return problems


## Plain data describing the battle right now. Two runs with the same inputs
## and seed produce identical snapshots at every tick.
func snapshot() -> Dictionary:
	var fighters: Array = []
	for fighter in combatants:
		fighters.append(fighter.to_dict())
	return {
		"trial": trial_id, "arena": layout.id, "tick": tick, "time": snappedf(time, 0.0001),
		"seed": battle_seed, "rng_state": rng.state, "finished": finished, "winner_team": winner_team,
		"combatants": fighters,
	}
