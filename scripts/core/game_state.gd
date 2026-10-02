extends Node
## Live game session (autoload "Game"). Completed by the profile milestone.

signal profile_changed


func is_flag_set(_flag: String) -> bool:
	return false


func new_journey() -> void:
	pass


func continue_journey() -> bool:
	return false
