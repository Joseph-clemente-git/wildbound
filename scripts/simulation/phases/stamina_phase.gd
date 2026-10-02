class_name StaminaPhase
extends SimulationPhase
## Stamina Update: what this tick's effort cost and how much breath came back.
##
## - Every action begun this tick is paid for: attacks and heavy attacks by
##   weapon (×armor, ×attack-control skill), dodges (×armor, ×dodge-control
##   skill), Arts by their own cost.
## - A held guard drains stamina every second (block-control skill eases
##   it), and every blocked blow costs its guard drain.
## - After spending, stamina recovers at the Endurance-driven rate once a
##   short delay has passed — slower while guarding.
## - Running dry exhausts: no attacks, dodges, casts or guard until the
##   exhaustion passes (recovery-control skill shortens it), and slower feet.
##   A guard that runs dry breaks.
##
## A combatant may begin an action it cannot fully pay for — overexertion is
## allowed, and it ends in exhaustion.

const A := CombatantState.Action
## Regeneration rate while guarding, relative to normal.
const GUARD_REGEN_FACTOR := 0.35


func _init() -> void:
	super("stamina")


func run(state: BattleState, frame: SimFrame) -> void:
	var spent := {}
	for event in frame.events:
		if event["type"] == "action_start":
			var fighter := state.combatants[event["actor"]]
			spent[fighter.index] = float(spent.get(fighter.index, 0.0)) + action_cost(fighter, event["action"])
		elif event["type"] == "technique":
			var used := Content.technique(event["technique"])
			if used != null:
				spent[event["actor"]] = float(spent.get(event["actor"], 0.0)) + used.stamina_cost
	for hit in frame.hits:
		if hit.get("outcome", "") == "blocked":
			spent[hit["target"]] = float(spent.get(hit["target"], 0.0)) + float(hit.get("guard_drain", 0.0))
	for fighter in state.combatants:
		if not fighter.is_alive():
			continue
		var cost := float(spent.get(fighter.index, 0.0))
		if fighter.action == A.BLOCK:
			cost += fighter.spec.derived.block_drain * frame.delta
		var aloft := TerrainRules.flight_cost(fighter, frame.delta)
		if cost > 0.0:
			fighter.stamina -= cost + aloft
			fighter.regen_delay = Content.config.stamina_regen_delay
		elif aloft > 0.0:
			fighter.stamina -= aloft  # staying aloft costs breath but does not stop recovery
		elif fighter.regen_delay > 0.0:
			fighter.regen_delay = maxf(fighter.regen_delay - frame.delta, 0.0)
		if cost <= 0.0 and fighter.regen_delay <= 0.0:
			var rate := fighter.spec.derived.stamina_regen * (GUARD_REGEN_FACTOR if fighter.action == A.BLOCK else 1.0) \
					* TerrainRules.regen_factor(state, fighter)
			fighter.stamina = minf(fighter.stamina + rate * frame.delta, fighter.max_stamina)
		if fighter.stamina <= 0.0:
			fighter.stamina = 0.0
			if not fighter.is_exhausted():
				_exhaust(fighter, frame)


## What beginning `action` costs this combatant.
static func action_cost(fighter: CombatantState, action: String) -> float:
	var derived := fighter.spec.derived
	match action:
		"attack":
			return derived.attack_stamina
		"heavy":
			return derived.heavy_stamina
		"dodge":
			return derived.dodge_stamina
		"cast":
			return fighter.spec.ability.stamina_cost if fighter.spec.ability != null else 0.0
	return 0.0


func _exhaust(fighter: CombatantState, frame: SimFrame) -> void:
	fighter.exhausted_time = fighter.spec.derived.exhaustion_seconds
	frame.emit("exhausted", fighter.index)
	if fighter.action == A.BLOCK:
		frame.emit("guard_break", fighter.index)
		ForcePhase.stagger(fighter, ForcePhase.GUARD_BREAK_SECONDS, frame, "guard_break", -1)
