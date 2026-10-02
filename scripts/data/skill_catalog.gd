class_name SkillCatalog
extends RefCounted
## Definition of the Skill Matrix hierarchy (mechanics §24-31, prompt 05).
##
## NATURAL FOUNDATION → COMBAT FUNDAMENTALS → COMBAT DISCIPLINE →
## WEAPON PROFICIENCY → MAGIC PROFICIENCY → ADVANCED TECHNIQUES
##
## Development targets are "kind:id" strings shared by training, experience,
## prerequisites and the save file: stat:<stat>, skill:<skill>,
## weapon:<weapon type>, magic:<school>.

const FUNDAMENTALS := "fundamentals"
const DISCIPLINE := "discipline"
const WEAPONS := "weapons"
const MAGIC := "magic"

const CATEGORY_NAMES := {
	FUNDAMENTALS: "Combat Fundamentals",
	DISCIPLINE: "Combat Discipline",
	WEAPONS: "Weapon Proficiency",
	MAGIC: "Aether Arts",
}

## Skill id -> definition. `reveal` names the story stage that shows it in the
## Skill Matrix (story §18: do not show 50 nodes on the first screen).
const SKILLS := {
	"movement": {"name": "Movement", "category": FUNDAMENTALS, "reveal": "basic",
			"description": "Footwork and turning. Makes repositioning more responsive."},
	"attack": {"name": "Attack", "category": FUNDAMENTALS, "reveal": "basic",
			"description": "Striking technique. Slightly improves attack damage."},
	"dodge": {"name": "Dodge", "category": FUNDAMENTALS, "reveal": "basic",
			"description": "Active evasion. Lengthens the dodge's protected window."},
	"stamina": {"name": "Stamina", "category": FUNDAMENTALS, "reveal": "basic",
			"description": "Breathing and pacing. Raises maximum stamina."},
	"defense": {"name": "Defense", "category": FUNDAMENTALS, "reveal": "defense",
			"description": "Bracing against blows. Improves damage mitigation."},
	"block": {"name": "Block", "category": FUNDAMENTALS, "reveal": "defense",
			"description": "Guarding with weapon and body. Blocks absorb more damage."},
	"recovery": {"name": "Recovery", "category": FUNDAMENTALS, "reveal": "defense",
			"description": "Shaking off hits. Shortens hit and stagger recovery."},
	"timing": {"name": "Timing", "category": DISCIPLINE, "reveal": "discipline",
			"description": "Reading the moment. Widens perfect dodge and block windows."},
	"positioning": {"name": "Positioning", "category": DISCIPLINE, "reveal": "discipline",
			"description": "Owning space. Reduces knockback taken."},
	"attack_control": {"name": "Attack Control", "category": DISCIPLINE, "reveal": "discipline",
			"description": "Efficient strikes. Attacks cost less stamina."},
	"defense_control": {"name": "Defense Control", "category": DISCIPLINE, "reveal": "discipline",
			"description": "Steady stance. Builds stagger more slowly."},
	"dodge_control": {"name": "Dodge Control", "category": DISCIPLINE, "reveal": "discipline",
			"description": "Clean evasions. Dodges cost less stamina."},
	"block_control": {"name": "Block Control", "category": DISCIPLINE, "reveal": "discipline",
			"description": "Disciplined guard. Holding a block drains less stamina."},
	"stamina_discipline": {"name": "Stamina Discipline", "category": DISCIPLINE, "reveal": "discipline",
			"description": "Recovering breath mid-fight. Faster stamina regeneration."},
	"recovery_control": {"name": "Recovery Control", "category": DISCIPLINE, "reveal": "discipline",
			"description": "Composure. Shorter exhaustion when stamina runs out."},
}

const FUNDAMENTAL_ORDER: Array[String] = ["movement", "attack", "defense", "dodge", "block", "stamina", "recovery"]
const DISCIPLINE_ORDER: Array[String] = [
	"timing", "positioning", "attack_control", "defense_control",
	"dodge_control", "block_control", "stamina_discipline", "recovery_control",
]

## Story flag that reveals each Skill Matrix stage.
const REVEAL_FLAGS := {
	"basic": "",
	"defense": "trained_once",
	"weapons": "trained_once",
	"discipline": "first_trial_done",
	"magic": "first_trial_done",
	"techniques": "first_trial_done",
}

## Lowest rank each kind of skill starts at when the animal first learns it.
const WEAPON_FIRST_RANK := GameEnums.Rank.NOVICE
const MAGIC_FIRST_RANK := GameEnums.Rank.FOUNDATION


static func all_skill_targets() -> Array[String]:
	var result: Array[String] = []
	for skill: String in FUNDAMENTAL_ORDER + DISCIPLINE_ORDER:
		result.append("skill:" + skill)
	for weapon: String in GameEnums.WEAPON_TYPES:
		result.append("weapon:" + weapon)
	for school: String in GameEnums.MAGIC_SCHOOLS:
		result.append("magic:" + school)
	return result


static func all_targets() -> Array[String]:
	var result: Array[String] = []
	for stat: String in GameEnums.STATS:
		result.append("stat:" + stat)
	result.append_array(all_skill_targets())
	return result


static func is_valid_target(target: String) -> bool:
	var kind := GameEnums.target_kind(target)
	var id := GameEnums.target_id(target)
	match kind:
		"stat":
			return GameEnums.STATS.has(id)
		"skill":
			return SKILLS.has(id)
		"weapon":
			return GameEnums.WEAPON_TYPES.has(id)
		"magic":
			return GameEnums.MAGIC_SCHOOLS.has(id)
	return false


static func category_of(target: String) -> String:
	match GameEnums.target_kind(target):
		"skill":
			return SKILLS.get(GameEnums.target_id(target), {}).get("category", FUNDAMENTALS)
		"weapon":
			return WEAPONS
		"magic":
			return MAGIC
	return "stat"


static func target_name(target: String) -> String:
	var id := GameEnums.target_id(target)
	match GameEnums.target_kind(target):
		"stat":
			return GameEnums.stat_name(id)
		"skill":
			return SKILLS.get(id, {}).get("name", id.capitalize())
		"weapon":
			return GameEnums.WEAPON_TYPE_NAMES.get(id, id.capitalize())
		"magic":
			return GameEnums.MAGIC_SCHOOL_NAMES.get(id, id.capitalize()) + " Arts"
	return target


static func description(target: String) -> String:
	var id := GameEnums.target_id(target)
	match GameEnums.target_kind(target):
		"skill":
			return SKILLS.get(id, {}).get("description", "")
		"weapon":
			return "Mastery of the %s: better handling, efficiency and new attack patterns." % \
					GameEnums.WEAPON_TYPE_NAMES.get(id, id)
		"magic":
			return "Mastery of %s Aether: unlocks and strengthens its arts." % \
					GameEnums.MAGIC_SCHOOL_NAMES.get(id, id)
		"stat":
			return "Natural attribute: %s." % GameEnums.stat_name(id)
	return ""


static func reveal_stage(target: String) -> String:
	match GameEnums.target_kind(target):
		"skill":
			return SKILLS.get(GameEnums.target_id(target), {}).get("reveal", "basic")
		"weapon":
			return "weapons"
		"magic":
			return "magic"
	return "basic"


## Highest rank a skill can reach for a given potential (0-100).
static func rank_cap_for_potential(potential: float) -> int:
	return clampi(ceili(potential / 100.0 * GameEnums.Rank.MASTER), GameEnums.Rank.FOUNDATION, GameEnums.Rank.MASTER)
