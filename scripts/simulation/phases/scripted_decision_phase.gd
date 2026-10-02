class_name ScriptedDecisionPhase
extends SimulationPhase
## A Combat Decision stand-in that asks a script for each combatant's intent.
## Used by tests, tools and demos until the decision system (Stage 16)
## takes over the "decision" step.
##
## `provider` is Callable(state: BattleState, fighter: CombatantState,
## frame: SimFrame) -> Dictionary returning an ActionPhase intent.

var provider: Callable


func _init(intent_provider: Callable) -> void:
	super("decision")
	provider = intent_provider


func run(state: BattleState, frame: SimFrame) -> void:
	for fighter in state.combatants:
		if fighter.is_alive():
			var intent: Variant = provider.call(state, fighter, frame)
			if intent is Dictionary and not intent.is_empty():
				frame.intents[fighter.index] = intent
