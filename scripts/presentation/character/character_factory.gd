class_name CharacterFactory
extends RefCounted
## Chooses a body for an animal: its Blender model when one is assigned in
## AnimalData.model_scene, otherwise the procedural rig named by visual_id.
## Gameplay never needs to know which one it got.


static func create(animal: AnimalData, palette: Dictionary = {}) -> CharacterVisual:
	if animal != null and animal.model_scene != null:
		var imported := animal.model_scene.instantiate() as Node3D
		if imported != null:
			return GltfCharacterVisual.new(imported)
	var colours := animal.palette.duplicate() if animal != null else {}
	colours.merge(palette, true)
	match animal.visual_id if animal != null else "":
		"procedural_shark":
			return ProceduralSharkVisual.new(colours)
		"procedural_eagle":
			return ProceduralEagleVisual.new(colours)
		_:
			return ProceduralDogVisual.new(colours)


static func for_champion(champion: Champion) -> CharacterVisual:
	return create(champion.data(), champion.palette)


static func for_opponent(opponent: OpponentData) -> CharacterVisual:
	return create(Content.animal(opponent.animal_id), opponent.palette)
