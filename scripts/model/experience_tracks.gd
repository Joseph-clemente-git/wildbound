class_name ExperienceTracks
extends RefCounted
## Category experience a champion has banked from real battles (mechanics §10).
##
## Each track fills toward a growth threshold; crossing it triggers a natural
## growth event (see GrowthSystem). Weapon and magic familiarity use one track
## per weapon type / school ("weapon:sword", "magic:fire").

const CORE_TRACKS: Array[String] = [
	"offensive", "strength", "tempo", "agility", "evasion", "defense", "endurance", "resilience",
]

const TRACK_NAMES := {
	"offensive": "Offensive",
	"strength": "Strength",
	"tempo": "Attack-Speed",
	"agility": "Agility",
	"evasion": "Evasion",
	"defense": "Defense",
	"endurance": "Endurance",
	"resilience": "Resilience",
}

## Natural development each track feeds (mechanics §9-18, prompt 09).
const TRACK_TARGETS := {
	"offensive": ["stat:attack"],
	"strength": ["stat:strength"],
	"tempo": ["stat:attack_speed"],
	"agility": ["stat:agility"],
	"evasion": ["stat:evasion"],
	"defense": ["stat:defense"],
	"endurance": ["stat:endurance"],
	"resilience": ["stat:health", "stat:endurance"],
}

var xp: Dictionary = {}        # track -> banked experience toward next growth
var growths: Dictionary = {}   # track -> number of growth events so far
var lifetime: Dictionary = {}  # track -> total experience ever earned


static func is_valid_track(track: String) -> bool:
	if CORE_TRACKS.has(track):
		return true
	var kind := GameEnums.target_kind(track)
	var id := GameEnums.target_id(track)
	return (kind == "weapon" and GameEnums.WEAPON_TYPES.has(id)) \
			or (kind == "magic" and GameEnums.MAGIC_SCHOOLS.has(id))


static func track_name(track: String) -> String:
	if TRACK_NAMES.has(track):
		return TRACK_NAMES[track]
	return SkillCatalog.target_name(track).trim_suffix(" Arts")


## Development targets fed by a track.
static func targets_for(track: String) -> Array:
	if TRACK_TARGETS.has(track):
		return TRACK_TARGETS[track]
	return [track]  # weapon:/magic: tracks develop the matching familiarity


func get_xp(track: String) -> float:
	return float(xp.get(track, 0.0))


func get_growths(track: String) -> int:
	return int(growths.get(track, 0))


func get_lifetime(track: String) -> float:
	return float(lifetime.get(track, 0.0))


func threshold(track: String) -> float:
	var config := Content.config
	return config.growth_threshold_base * pow(config.growth_threshold_scale, get_growths(track))


func ratio(track: String) -> float:
	return clampf(get_xp(track) / threshold(track), 0.0, 1.0)


## Raw add (no weighting). Returns the new banked value.
func add(track: String, amount: float) -> float:
	if amount <= 0.0 or not is_valid_track(track):
		return get_xp(track)
	xp[track] = get_xp(track) + amount
	lifetime[track] = get_lifetime(track) + amount
	return xp[track]


## Removes banked experience (growth events, trainer conversion).
func consume(track: String, amount: float) -> float:
	var taken := minf(amount, get_xp(track))
	xp[track] = get_xp(track) - taken
	return taken


func record_growth(track: String) -> void:
	growths[track] = get_growths(track) + 1


func active_tracks() -> Array[String]:
	var result: Array[String] = []
	for track: String in lifetime:
		if get_lifetime(track) > 0.0:
			result.append(track)
	return result


func to_dict() -> Dictionary:
	return {"xp": xp.duplicate(), "growths": growths.duplicate(), "lifetime": lifetime.duplicate()}


static func from_dict(data: Dictionary) -> ExperienceTracks:
	var tracks := ExperienceTracks.new()
	for key: String in ["xp", "lifetime"]:
		var source: Dictionary = data.get(key, {})
		var target: Dictionary = tracks.xp if key == "xp" else tracks.lifetime
		for track: String in source:
			if is_valid_track(track):
				target[track] = float(source[track])
	for track: String in data.get("growths", {}):
		if is_valid_track(track):
			tracks.growths[track] = int(data["growths"][track])
	return tracks
