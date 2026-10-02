class_name OpponentData
extends Resource
## A rival champion the Keeper can choose to fight.
##
## An opponent is described with the same building blocks as the player's
## champion — an animal, developed stats, Skill Matrix ranks, battle
## experience, equipment, Aether Arts and condition — so the combat
## simulation can treat both sides alike. Nothing here is a win chance or a
## power score: what happens in a fight emerges from these inputs.
##
## The player never sees these numbers directly. `ScoutingReport` turns them
## into the partial, descriptive picture shown before a fight.

## Tendency fields read by `tendency()`; every one is a 0..1 preference
## except `preferred_range`, which is in metres.
const TENDENCIES: Array[String] = [
	"aggression", "caution", "mobility", "heavy_chance", "magic_chance", "preferred_range",
]

@export var id: String = ""
@export var display_name: String = ""
@export var title: String = ""
## Who they are, told the way a Keeper would hear it before a bout.
@export_multiline var bio: String = ""
## Species. Movement type and soft combat traits come from the AnimalData,
## never from this opponent's id.
@export var animal_id: String = "humanoid_dog"
@export var palette: Dictionary = {}
## Display only. Never used to decide a fight.
@export var level: int = 1

@export_group("Development")
## Developed stats before equipment (0-100 scale), like a champion's
## `developed_stat`. Equipment modifiers are applied on top, the same way.
@export var stats: Dictionary = {}
## Skill Matrix ranks by target ("weapon:sword": 3, "skill:block": 3...).
## Unlisted fundamentals and disciplines are at Foundation; unlisted weapons
## and schools are unlearned.
@export var skills: Dictionary = {}
## Advanced techniques this opponent has learned.
@export var techniques: PackedStringArray = []
## Bouts fought: how much real combat this opponent has lived through.
@export var battles_fought: int = 0

@export_group("Build")
@export var weapon_id: String = "sword_training"
@export var armor_id: String = "armor_light"
@export var accessory_id: String = ""
@export var magic_ability_id: String = ""

@export_group("Condition")
@export_range(0.0, 100.0) var energy: float = 100.0
@export_range(0.0, 100.0) var happiness: float = 70.0

@export_group("Tendencies")
## How readily it commits to attacks.
@export_range(0.0, 1.0) var aggression: float = 0.5
## How early it backs off, guards or recovers when hurt or tired.
@export_range(0.0, 1.0) var caution: float = 0.4
## How often it circles and repositions instead of holding its ground.
@export_range(0.0, 1.0) var mobility: float = 0.4
## Preference for heavy attacks over light ones.
@export_range(0.0, 1.0) var heavy_chance: float = 0.25
## Preference for Aether Arts when one is ready.
@export_range(0.0, 1.0) var magic_chance: float = 0.0
## Distance it tries to fight from, in metres.
@export var preferred_range: float = 1.8


@export_group("Story")
@export_multiline var intro_line: String = ""
@export_multiline var win_line: String = ""
@export_multiline var lose_line: String = ""
@export var sort_order: int = 0


## Skill Matrix rank of any skill target, with the defaults described on `skills`.
func rank_of(target: String) -> int:
	if skills.has(target):
		return int(skills[target])
	if GameEnums.target_kind(target) == "skill":
		return GameEnums.Rank.FOUNDATION
	return GameEnums.Rank.NONE


func get_stat(stat: String) -> float:
	return float(stats.get(stat, 30.0))


func tendency(key: String) -> float:
	return float(get(key)) if TENDENCIES.has(key) else 0.0


## Equipped item ids in slot order, skipping empty slots.
func equipment_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id: String in [weapon_id, armor_id, accessory_id]:
		if not item_id.is_empty():
			result.append(item_id)
	return result


## Checks the opponent's own data. Cross-references to other content (the
## weapon, animal, ability...) are checked by the content tests.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id.is_empty():
		problems.append("missing id")
	if display_name.is_empty():
		problems.append("missing display name")
	for stat: String in GameEnums.STATS:
		if not stats.has(stat):
			problems.append("missing stat " + stat)
		elif get_stat(stat) < 1.0 or get_stat(stat) > 100.0:
			problems.append("stat %s outside 1-100" % stat)
	for stat: String in stats:
		if not GameEnums.STATS.has(stat):
			problems.append("unknown stat " + stat)
	for target: String in skills:
		var kind := GameEnums.target_kind(target)
		if kind == "stat" or not SkillCatalog.is_valid_target(target):
			problems.append("unknown skill " + target)
		elif rank_of(target) < GameEnums.Rank.FOUNDATION or rank_of(target) > GameEnums.Rank.MASTER:
			problems.append("rank of %s outside Foundation-Master" % target)
	if weapon_id.is_empty():
		problems.append("no weapon")
	if battles_fought < 0:
		problems.append("negative battles fought")
	for key: String in TENDENCIES:
		if key != "preferred_range" and (tendency(key) < 0.0 or tendency(key) > 1.0):
			problems.append("tendency %s outside 0-1" % key)
	if preferred_range <= 0.0:
		problems.append("preferred range must be positive")
	return problems
