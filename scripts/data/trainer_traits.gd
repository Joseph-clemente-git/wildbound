class_name TrainerTraits
extends RefCounted
## Special trainer traits (mechanics §35). Effects are read by the training
## system only; traits never change battle stats directly.
##
## Effect keys:
##   progress_bonus: {target_or_kind: multiplier}  — "magic" matches any magic:*
##   energy_factor: multiplier on training energy cost
##   coin_factor: multiplier on training coin cost
##   conversion_factor: multiplier on experience conversion
##   happiness_bonus: extra happiness after a session
##   no_overtraining: overtraining causes no happiness loss

const TRAITS := {
	"counter_training": {
		"name": "Counter Training",
		"description": "Drills punishing openings: timing and block control develop faster.",
		"effects": {"progress_bonus": {"skill:timing": 1.3, "skill:block_control": 1.3, "skill:block": 1.15}},
	},
	"heavy_drills": {
		"name": "Heavy Drills",
		"description": "Weighted training: strength develops faster, sessions are tiring.",
		"effects": {"progress_bonus": {"stat:strength": 1.3}, "energy_factor": 1.15},
	},
	"light_feet": {
		"name": "Light Feet",
		"description": "Playful movement games that cost less energy.",
		"effects": {"energy_factor": 0.75, "happiness_bonus": 2},
	},
	"aether_focus": {
		"name": "Aether Focus",
		"description": "Meditative study: Aether Arts develop faster.",
		"effects": {"progress_bonus": {"magic": 1.25}},
	},
	"experience_reader": {
		"name": "Experience Reader",
		"description": "Reads what the champion learned in battle and builds on it.",
		"effects": {"conversion_factor": 1.6},
	},
	"wandering_teacher": {
		"name": "Wandering Teacher",
		"description": "Asks little payment — the road provides.",
		"effects": {"coin_factor": 0.7},
	},
	"patient_mentor": {
		"name": "Patient Mentor",
		"description": "Never pushes a tired champion too hard.",
		"effects": {"no_overtraining": true, "happiness_bonus": 1},
	},
	"defensive_doctrine": {
		"name": "Defensive Doctrine",
		"description": "Improved defensive training for defense and block skills.",
		"effects": {"progress_bonus": {"skill:defense": 1.25, "skill:block": 1.25, "stat:defense": 1.2}},
	},
}


static func get_trait(trait_id: String) -> Dictionary:
	return TRAITS.get(trait_id, {})


static func trait_name(trait_id: String) -> String:
	return get_trait(trait_id).get("name", trait_id.capitalize())


static func effect(trait_ids: PackedStringArray, key: String, default: Variant) -> Variant:
	var result: Variant = default
	for trait_id in trait_ids:
		var effects: Dictionary = get_trait(trait_id).get("effects", {})
		if not effects.has(key):
			continue
		var value: Variant = effects[key]
		if value is bool:
			result = result or value
		elif value is float or value is int:
			result = (result * value) if key.ends_with("factor") else (result + value)
	return result


## Combined progress multiplier from traits for a target.
static func progress_bonus(trait_ids: PackedStringArray, target: String) -> float:
	var bonus := 1.0
	for trait_id in trait_ids:
		var table: Dictionary = get_trait(trait_id).get("effects", {}).get("progress_bonus", {})
		if table.has(target):
			bonus *= float(table[target])
		elif table.has(GameEnums.target_kind(target)):
			bonus *= float(table[GameEnums.target_kind(target)])
	return bonus
