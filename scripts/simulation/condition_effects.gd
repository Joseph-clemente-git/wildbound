class_name ConditionEffects
extends RefCounted
## How a combatant's condition lightly shapes the fight (Stage 23). Condition
## is never decisive: it nudges, it does not decide.
##
## - Energy (after paying the fight's entry): a rested champion fights at full
##   breath; below FRESH_ENERGY the stamina pool and its recovery shrink, down
##   to TIRED_STAMINA at 0 energy.
## - Happiness is composure: a champion in a good mood reads the fight a
##   little faster and times its answers a little better; an unhappy one
##   hesitates. Inside the content band nothing changes.
##
## The same rules apply to champions and opponents.

const FRESH_ENERGY := 50.0
## Stamina pool and recovery at 0 energy, relative to rested.
const TIRED_STAMINA := 0.85
## Happiness band in which mood changes nothing.
const CONTENT_LOW := 50.0
const CONTENT_HIGH := 80.0
## Largest change to reaction time and timing error at the extremes of mood.
const UNHAPPY_SLOWDOWN := 0.12
const HAPPY_SHARPNESS := 0.05


## Multiplier on the stamina pool and its recovery.
static func stamina_factor(energy: float) -> float:
	if energy >= FRESH_ENERGY:
		return 1.0
	return lerpf(TIRED_STAMINA, 1.0, clampf(energy / FRESH_ENERGY, 0.0, 1.0))


## -1 (miserable) .. 0 (content) .. +1 (delighted).
static func composure(happiness: float) -> float:
	if happiness < CONTENT_LOW:
		return -clampf((CONTENT_LOW - happiness) / CONTENT_LOW, 0.0, 1.0)
	if happiness > CONTENT_HIGH:
		return clampf((happiness - CONTENT_HIGH) / (100.0 - CONTENT_HIGH), 0.0, 1.0)
	return 0.0


## Multiplier on reaction time and on the timing error of defensive answers.
static func focus_factor(happiness: float) -> float:
	var mood := composure(happiness)
	return 1.0 - mood * (HAPPY_SHARPNESS if mood > 0.0 else UNHAPPY_SLOWDOWN)


## Applies the condition to derived combat numbers.
static func apply(derived: CombatStats, energy: float) -> void:
	var breath := stamina_factor(energy)
	derived.max_stamina *= breath
	derived.stamina_regen *= breath


## Player-facing notes for previews ("" when condition changes nothing).
static func notes(energy: float, happiness: float) -> PackedStringArray:
	var result := PackedStringArray()
	if stamina_factor(energy) < 0.97:
		result.append("Tired: about %d%% less stamina and slower recovery." % roundi((1.0 - stamina_factor(energy)) * 100.0))
	var mood := composure(happiness)
	if mood < -0.1:
		result.append("Low mood: slower to react and less precise.")
	elif mood > 0.1:
		result.append("High spirits: a little sharper in reading the fight.")
	return result


## Energy a battle costs beyond its entry: long, breathless fights tire.
static func battle_fatigue(duration: float, exhaustions: int) -> float:
	return minf(floorf(duration / 60.0) * 2.0 + exhaustions * 2.0, 8.0)


## Mood change from how the fight went, on top of the win/loss change: a
## hard-fought loss stings less, a one-sided one more; a clean win lifts.
static func spirit(won: bool, dealt_ratio: float, health_left_ratio: float) -> float:
	if won:
		return 2.0 if health_left_ratio >= 0.6 else 0.0
	if dealt_ratio >= 0.6:
		return 2.0
	if dealt_ratio < 0.15:
		return -2.0
	return 0.0
