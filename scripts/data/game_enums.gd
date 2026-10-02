class_name GameEnums
extends RefCounted
## Shared identifiers used across data, gameplay, UI and save files.
##
## Identifiers that are persisted (stats, skills, schools, weapon types...) are
## plain Strings so save files stay human-readable and stable across versions.
## Enums are only used for small closed sets that are never re-ordered.

enum MovementType { GROUND, FLYING, SWIMMING, AMPHIBIOUS }

## Unified rank scale shared by skills, weapon mastery, magic mastery and
## stat descriptors. Weapon mastery starts at NOVICE, magic at FOUNDATION.
enum Rank { NONE, FOUNDATION, NOVICE, APPRENTICE, SKILLED, EXPERT, MASTER }

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

enum TrainerCategory { ATTRIBUTE, WEAPON, MAGIC, GENERAL }

enum ArmorWeight { LIGHT, MEDIUM, HEAVY }

enum BattleFormat { ONE_V_ONE, TWO_V_TWO, THREE_V_THREE }

## Kinds of fight the Journey offers. Append only: values are stored in content.
enum ChallengeType {
	STORY_BATTLE, LOCAL_TRIAL, REGIONAL_TRIAL, TRAINER_CHALLENGE,
	WILD_ENCOUNTER, ELITE_TRIAL, CHAMPION_BATTLE,
}

# --- Core combat stats -------------------------------------------------------

const STATS: Array[String] = [
	"health", "attack", "strength", "attack_speed",
	"defense", "agility", "evasion", "endurance",
]

const STAT_NAMES := {
	"health": "Health",
	"attack": "Attack",
	"strength": "Strength",
	"attack_speed": "Attack Speed",
	"defense": "Defense",
	"agility": "Agility",
	"evasion": "Evasion",
	"endurance": "Endurance",
}

## Extra potential-only attribute: how far the animal can take Aether Arts.
const MAGIC_POTENTIAL := "magic"

# --- Weapons and magic -------------------------------------------------------

const WEAPON_TYPES: Array[String] = ["sword", "hammer", "dagger", "spear", "axe", "shield", "bow"]

const WEAPON_TYPE_NAMES := {
	"sword": "Sword", "hammer": "Hammer", "dagger": "Dagger", "spear": "Spear",
	"axe": "Axe", "shield": "Shield", "bow": "Bow",
}

const MAGIC_SCHOOLS: Array[String] = ["fire", "frost", "wind", "earth", "lightning", "nature"]

const MAGIC_SCHOOL_NAMES := {
	"fire": "Fire", "frost": "Frost", "wind": "Wind",
	"earth": "Earth", "lightning": "Lightning", "nature": "Nature",
}

# --- Ranks and rarity ---------------------------------------------------------

const RANK_NAMES: Array[String] = [
	"None", "Foundation", "Novice", "Apprentice", "Skilled", "Expert", "Master",
]

const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

## How the world describes each rarity (story §5).
const RARITY_TITLES: Array[String] = [
	"Local instructor", "Experienced specialist", "Recognized master",
	"Renowned expert", "Historical-level master",
]

const RARITY_COLORS: Array[Color] = [
	Color("b9b2a2"), Color("7fbf6a"), Color("5f9ed8"), Color("b07ad8"), Color("e8b04a"),
]

const MOVEMENT_TYPE_NAMES: Array[String] = ["Ground", "Flying", "Swimming", "Amphibious"]

const ARMOR_WEIGHT_NAMES: Array[String] = ["Light", "Medium", "Heavy"]

const CHALLENGE_TYPE_NAMES: Array[String] = [
	"Story Battle", "Local Trial", "Regional Trial", "Trainer Challenge",
	"Wild Encounter", "Elite Trial", "Champion Battle",
]


static func rank_name(rank: int) -> String:
	return RANK_NAMES[clampi(rank, 0, RANK_NAMES.size() - 1)]


static func rarity_name(rarity: int) -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]


static func rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


static func challenge_type_name(challenge_type: int) -> String:
	return CHALLENGE_TYPE_NAMES[clampi(challenge_type, 0, CHALLENGE_TYPE_NAMES.size() - 1)]


static func stat_name(stat: String) -> String:
	return STAT_NAMES.get(stat, stat.capitalize())


## Development targets are addressed with "kind:id" strings, e.g.
## "stat:agility", "skill:dodge", "weapon:sword", "magic:fire".
static func target_kind(target: String) -> String:
	return target.get_slice(":", 0)


static func target_id(target: String) -> String:
	return target.get_slice(":", 1)
