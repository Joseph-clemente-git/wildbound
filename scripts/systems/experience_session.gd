class_name ExperienceSession
extends RefCounted
## Collects the experience a champion earns during one battle (mechanics §10-23).
##
## Combat reports *meaningful events*; the session weighs each one by
## encounter difficulty, repetition (anti-farming), remaining potential and a
## per-battle cap before anything is banked. Nothing here grants stat points:
## banked experience only turns into growth through GrowthSystem thresholds.

## event -> {track: base experience}. "weapon"/"magic" resolve to the champion's
## current weapon type / school.
const EVENTS := {
	"hit": {"offensive": 3.0, "weapon": 2.0},
	"combo_hit": {"tempo": 3.0, "offensive": 1.0, "weapon": 1.5},
	"punish": {"offensive": 4.0, "tempo": 2.0, "weapon": 1.5},
	"heavy_hit": {"strength": 5.0, "weapon": 2.5},
	"stagger_caused": {"strength": 4.0},
	"guard_break": {"strength": 6.0, "offensive": 3.0},
	"technique": {"offensive": 3.0, "weapon": 3.0},
	"dodge": {"evasion": 4.0},
	"perfect_dodge": {"evasion": 7.0, "agility": 1.5},
	"dodge_heavy": {"evasion": 3.0},
	"dodge_magic": {"evasion": 5.0},
	"block": {"defense": 4.0},
	"perfect_block": {"defense": 6.0, "tempo": 1.0},
	"block_heavy": {"defense": 3.0},
	"reposition": {"agility": 4.0},
	"stamina_discipline": {"endurance": 4.0},
	"long_battle": {"endurance": 6.0},
	"heavy_damage_survived": {"resilience": 4.0},
	"survived_low_health": {"resilience": 12.0},
	"prolonged_defeat": {"resilience": 6.0},
	"magic_hit": {"magic": 5.0},
	"magic_cast": {"magic": 1.0},
}

var champion: Champion
var difficulty_ratio: float = 1.0
var difficulty_multiplier: float = 1.0
var weapon_track: String = ""
var magic_track: String = ""
## track -> experience earned this battle (after weighting)
var gains: Dictionary = {}
## event -> number of times reported
var event_counts: Dictionary = {}

var _repeats: Dictionary = {}  # event key -> {"count": int, "time": float}
var _committed := false


func _init(for_champion: Champion, opponent_power: float) -> void:
	champion = for_champion
	var own_power := maxf(champion.power_rating(), 1.0)
	difficulty_ratio = opponent_power / own_power
	difficulty_multiplier = PowerRating.difficulty_multiplier(difficulty_ratio)
	var weapon := Content.weapon(champion.weapon_id)
	weapon_track = "weapon:" + weapon.weapon_type if weapon != null else ""
	var ability := Content.ability(champion.equipped_ability)
	magic_track = "magic:" + ability.school if ability != null else ""


## Reports a combat event at battle time `time`. `variant` distinguishes events
## that are only "the same" when repeated in the same way (e.g. same attack).
## Returns the total experience awarded.
func report(event: String, time: float, variant: String = "") -> float:
	if _committed or not EVENTS.has(event):
		return 0.0
	event_counts[event] = int(event_counts.get(event, 0)) + 1
	var repeat := _repeat_factor(event + ":" + variant, time)
	var total := 0.0
	var table: Dictionary = EVENTS[event]
	for key: String in table:
		var track := _resolve_track(key)
		if track.is_empty():
			continue
		total += _award(track, float(table[key]) * repeat)
	return total


## Diminishing returns for repeating the same action in quick succession.
func _repeat_factor(key: String, time: float) -> float:
	var config := Content.config
	var entry: Dictionary = _repeats.get(key, {"count": 0.0, "time": time})
	var elapsed := maxf(time - float(entry["time"]), 0.0)
	# Memory fades: every quiet `repeat_memory_seconds` halves the repetition count.
	var count := float(entry["count"]) * pow(0.5, elapsed / config.repeat_memory_seconds)
	var factor := maxf(pow(config.repeat_decay, count), config.repeat_floor)
	_repeats[key] = {"count": count + 1.0, "time": time}
	return factor


func _resolve_track(key: String) -> String:
	match key:
		"weapon":
			return weapon_track
		"magic":
			return magic_track
	return key


func _award(track: String, base: float) -> float:
	var config := Content.config
	var amount := base * difficulty_multiplier * potential_factor(track)
	var earned := float(gains.get(track, 0.0))
	amount = clampf(amount, 0.0, maxf(config.per_battle_track_cap - earned, 0.0))
	if amount > 0.0:
		gains[track] = earned + amount
	return amount


## Experience slows as the champion nears its developmental potential.
func potential_factor(track: String) -> float:
	var config := Content.config
	var closeness := 0.0
	var kind := GameEnums.target_kind(track)
	if kind == "weapon" or kind == "magic":
		var cap := champion.rank_cap(track)
		closeness = float(champion.skills.get_rank(track)) / maxf(cap, 1.0)
	else:
		var targets := ExperienceTracks.targets_for(track)
		for target: String in targets:
			closeness += 1.0 - champion.potential_room(GameEnums.target_id(target))
		closeness /= maxf(targets.size(), 1.0)
	if closeness <= config.potential_slowdown_start:
		return 1.0
	var t := (closeness - config.potential_slowdown_start) / (1.0 - config.potential_slowdown_start)
	return lerpf(1.0, config.potential_min_factor, clampf(t, 0.0, 1.0))


func total() -> float:
	var sum := 0.0
	for track: String in gains:
		sum += float(gains[track])
	return sum


## Banks the experience on the champion and resolves growth events.
## Returns {"gains": {track: amount}, "growths": [growth events]}.
func commit() -> Dictionary:
	if _committed:
		return {"gains": gains, "growths": []}
	_committed = true
	for track: String in gains:
		champion.experience.add(track, float(gains[track]))
	var growths := GrowthSystem.process(champion)
	return {"gains": gains.duplicate(), "growths": growths}
