class_name KnockoutPhase
extends SimulationPhase
## Knockout: a combatant with no health left is knocked out, and the battle
## ends when only one team still has anyone standing. Knockouts are never
## deaths (story §36).


func _init() -> void:
	super("knockout")


func run(state: BattleState, frame: SimFrame) -> void:
	for fighter in state.combatants:
		if fighter.health <= 0.0 and fighter.action != CombatantState.Action.KO:
			fighter.health = 0.0
			fighter.action = CombatantState.Action.KO
			fighter.phase = CombatantState.Phase.NONE
			fighter.velocity = Vector2.ZERO
			frame.emit("knockout", fighter.index)
	var standing: Array[int] = []
	for team_index in 2:
		if not state.living(team_index).is_empty():
			standing.append(team_index)
	if standing.size() <= 1 and not state.finished:
		state.finished = true
		state.winner_team = standing[0] if standing.size() == 1 else -1
		frame.emit("battle_end", -1, -1, {"winner_team": state.winner_team, "reason": "knockout"})
