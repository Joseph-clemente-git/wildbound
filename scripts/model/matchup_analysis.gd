class_name MatchupAnalysis
extends RefCounted
## The tactical preview before a fight: how this champion, in this build,
## lines up against this opponent in this arena. Plain words only — what the
## opponent brings, where the champion has an edge and what could go wrong.
## Never a win chance: the battle itself decides what happens.

const AXES: Array[String] = ["Strength", "Defense", "Mobility", "Range"]
const RANGE_ORDER: Array[String] = ["Short", "Medium", "Long"]
## One side's stamina must exceed the other's by this factor to matter.
const STAMINA_EDGE := 1.1

var you: ScoutingReport
var them: ScoutingReport
## The opponent's physical force band, e.g. "High".
var opponent_strength := ""
## The opponent's most important threat.
var threat := ""
## Where the champion has the edge, most important first.
var advantages := PackedStringArray()
## What could go wrong, most important first.
var risks := PackedStringArray()


static func analyse(champion: Champion, opponent: OpponentData, arena: ArenaData,
		overrides: Dictionary = {}) -> MatchupAnalysis:
	var result := MatchupAnalysis.new()
	result.you = ScoutingReport.for_champion(champion, overrides)
	result.them = ScoutingReport.for_opponent(opponent)
	result.opponent_strength = result.them.strength
	result.threat = result.them.threats[0] if not result.them.threats.is_empty() else "Nothing that stands out"
	result._weigh(champion, opponent, arena, overrides)
	return result


func main_advantage() -> String:
	return advantages[0] if not advantages.is_empty() else "None obvious"


func main_risk() -> String:
	return risks[0] if not risks.is_empty() else "Nothing stands out"


## How the bands compare on an axis: > 0 when the champion is ahead.
func edge(axis: String) -> int:
	return axis_rank(you, axis) - axis_rank(them, axis)


static func axis_rank(report: ScoutingReport, axis: String) -> int:
	match axis:
		"Strength":
			return ScoutingReport.BAND_NAMES.find(report.strength)
		"Defense":
			return ScoutingReport.BAND_NAMES.find(report.defense)
		"Mobility":
			return ScoutingReport.BAND_NAMES.find(report.mobility)
		"Range":
			return RANGE_ORDER.find(report.combat_range)
	return -1


## What switching to another build would change, one arrow per band moved,
## e.g. ["Defense ↑↑", "Mobility ↓"]. Empty when nothing visible changes.
static func option_effects(champion: Champion, overrides: Dictionary) -> PackedStringArray:
	var current := ScoutingReport.for_champion(champion)
	var projected := ScoutingReport.for_champion(champion, overrides)
	var effects := PackedStringArray()
	for axis: String in AXES:
		var change := axis_rank(projected, axis) - axis_rank(current, axis)
		if change != 0:
			effects.append("%s %s" % [axis, ("↑" if change > 0 else "↓").repeat(absi(change))])
	return effects


func _weigh(champion: Champion, opponent: OpponentData, arena: ArenaData, overrides: Dictionary) -> void:
	var weapon_id: String = overrides.get("weapon_id", champion.weapon_id)
	var weapon := Content.weapon(weapon_id) if not weapon_id.is_empty() else null
	var own_rank := champion.rank_of("weapon:" + weapon.weapon_type) if weapon != null else 0
	var their_weapon := Content.weapon(opponent.weapon_id)
	var their_rank := opponent.rank_of("weapon:" + their_weapon.weapon_type) if their_weapon != null else 0
	var tight := arena != null and arena.radius < 9.0
	var wide := arena != null and arena.radius >= 14.0
	var your_stamina := you.combat.max_stamina
	var their_stamina := them.combat.max_stamina

	# What could go wrong.
	if weapon == null:
		risks.append("Fighting without a weapon")
	elif own_rank < SkillCatalog.WEAPON_FIRST_RANK:
		risks.append("Untrained with the " + you.weapon_family)
	if axis_rank(them, "Strength") >= 3 and axis_rank(you, "Defense") <= 2:
		risks.append("Close-range pressure")
	if them.combat_range == "Long" and you.combat_range != "Long":
		risks.append("Being worn down from range")
	if edge("Mobility") < 0:
		risks.append("Being outmanoeuvred")
	if axis_rank(them, "Defense") >= 3 and axis_rank(you, "Strength") <= 2:
		risks.append("Breaking through their guard")
	if weapon != null and their_rank - own_rank >= 2:
		risks.append("Less weapon technique")
	if their_stamina > your_stamina * STAMINA_EDGE:
		risks.append("Tiring first in a long fight")
	if tight and axis_rank(them, "Strength") >= 3:
		risks.append("Tight ring: little room to escape pressure")

	# Where the champion has the edge.
	for axis: String in AXES:
		if edge(axis) > 0:
			advantages.append("Reach" if axis == "Range" else axis)
	if them.openings.has("Long recovery after heavy swings") and axis_rank(you, "Mobility") >= 2:
		advantages.append("Punishing slow recoveries")
	if weapon != null and own_rank > their_rank and own_rank >= SkillCatalog.WEAPON_FIRST_RANK:
		advantages.append("Better weapon technique")
	if your_stamina > their_stamina * STAMINA_EDGE or (them.openings.has("Tires quickly") and your_stamina >= their_stamina):
		advantages.append("Outlasting them")
	if wide and edge("Mobility") > 0:
		advantages.append("Room to outmanoeuvre")
