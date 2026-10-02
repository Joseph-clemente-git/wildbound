class_name CooldownPhase
extends SimulationPhase
## Cooldown / Recovery: counts down cooldowns, exhaustion and lasting effects.
## What those timers mean for combat is decided by the phases that set them.


func _init() -> void:
	super("recovery")


func run(state: BattleState, frame: SimFrame) -> void:
	for fighter in state.combatants:
		if not fighter.is_alive():
			continue
		for key: String in fighter.cooldowns.keys():
			var left := float(fighter.cooldowns[key]) - frame.delta
			if left <= 0.0:
				fighter.cooldowns.erase(key)
				frame.emit("cooldown_ready", fighter.index, -1, {"key": key})
			else:
				fighter.cooldowns[key] = left
		if fighter.exhausted_time > 0.0:
			fighter.exhausted_time = maxf(fighter.exhausted_time - frame.delta, 0.0)
			if fighter.exhausted_time == 0.0:
				frame.emit("recovered_breath", fighter.index)
		for i in range(fighter.effects.size() - 1, -1, -1):
			var effect := fighter.effects[i]
			effect["time"] = float(effect["time"]) - frame.delta
			if float(effect["time"]) <= 0.0:
				fighter.effects.remove_at(i)
				frame.emit("effect_ended", fighter.index, -1, {"kind": effect.get("kind", "")})
