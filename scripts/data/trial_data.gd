class_name TrialData
extends Resource
## A fight the Keeper can choose on the Journey: who, where, why and what it
## costs and rewards (story §33). The challenge decides who can be fought;
## the battle itself decides what happens.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Why this fight matters to the Keeper right now (shown with the fight).
@export_multiline var reason: String = ""
@export var region_id: String = "home_valley"
@export var challenge_type: GameEnums.ChallengeType = GameEnums.ChallengeType.LOCAL_TRIAL
## False for fights that can only be won once (e.g. a story battle).
@export var repeatable: bool = true
@export var opponent_id: String = ""
@export var arena_id: String = "meadow_ring"
@export var energy_cost: int = 25
@export var coins: int = 80
@export var owner_xp: int = 50
@export var animal_xp: int = 45
## Extra rewards for the first victory.
@export var first_clear_coins: int = 60
@export var first_clear_owner_xp: int = 40
## Story flags that must be set before the fight is offered.
@export var requires_flags: PackedStringArray = []
## Story event played after the first victory ("" = none).
@export var story_after_win: String = ""
## Story event played after any first attempt (win or lose).
@export var story_after_first: String = ""
@export var tutorial: bool = false
@export var sort_order: int = 0


func cleared_flag() -> String:
	return "cleared_" + id


func challenge_type_name() -> String:
	return GameEnums.challenge_type_name(challenge_type)
