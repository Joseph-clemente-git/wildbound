class_name TrialData
extends Resource
## An organized trial: an opponent, a trial ground and rewards (story §33).

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var region_id: String = "home_valley"
## "local", "regional", "special" or "story".
@export var tier: String = "local"
@export var opponent_id: String = ""
@export var arena_id: String = "meadow_ring"
@export var energy_cost: int = 25
@export var coins: int = 80
@export var owner_xp: int = 50
@export var animal_xp: int = 45
## Extra rewards for the first victory.
@export var first_clear_coins: int = 60
@export var first_clear_owner_xp: int = 40
## Story flags that must be set before the trial is offered.
@export var requires_flags: PackedStringArray = []
## Story event played after the first victory ("" = none).
@export var story_after_win: String = ""
## Story event played after any first attempt (win or lose).
@export var story_after_first: String = ""
@export var tutorial: bool = false
@export var sort_order: int = 0


func cleared_flag() -> String:
	return "cleared_" + id
