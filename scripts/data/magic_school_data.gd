class_name MagicSchoolData
extends Resource
## One of the Aether Arts schools. Every animal can learn every school.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_multiline var lore: String = ""
@export var color: Color = Color.WHITE
@export var region_id: String = "home_valley"
@export var available: bool = true
## Abilities in learning order.
@export var abilities: Array[MagicAbilityData] = []
@export var sort_order: int = 0


func ability_for_rank(rank: int) -> Array[MagicAbilityData]:
	var result: Array[MagicAbilityData] = []
	for ability in abilities:
		if ability.required_rank <= rank:
			result.append(ability)
	return result


func get_ability(ability_id: String) -> MagicAbilityData:
	for ability in abilities:
		if ability.id == ability_id:
			return ability
	return null
