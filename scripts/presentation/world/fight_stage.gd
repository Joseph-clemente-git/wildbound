class_name FightStage
extends RefCounted
## The 3D set used before a fight (opponent preview, battle preparation):
## the arena's mood and meadow, and combatants posed in their gear.


static func backdrop(parent: Node3D, arena: ArenaData) -> void:
	WorldBuilder.environment(parent, arena.mood if arena != null else "day")
	WorldBuilder.ground(parent, 80.0, {"ring_center": Vector2.ZERO, "ring_radius": 6.0})
	WorldBuilder.grass(parent, Rect2(-14, -14, 28, 28), 1600, [Vector3(0, 0, 6.3)], 8)
	WorldBuilder.forest_ring(parent, 10.0, 22.0, 30, 6, false)


static func champion_figure(champion: Champion) -> CharacterVisual:
	var ability := Content.ability(champion.equipped_ability)
	return _dress(CharacterFactory.for_champion(champion), Content.weapon(champion.weapon_id),
			Content.armor(champion.armor_id), ability.school if ability != null else "")


static func opponent_figure(opponent: OpponentData) -> CharacterVisual:
	var ability := Content.ability(opponent.magic_ability_id)
	return _dress(CharacterFactory.for_opponent(opponent), Content.weapon(opponent.weapon_id),
			Content.armor(opponent.armor_id), ability.school if ability != null else "")


static func _dress(figure: CharacterVisual, weapon: WeaponData, armor: ArmorData, school: String) -> CharacterVisual:
	figure.set_weapon(weapon.weapon_type if weapon != null else "")
	figure.set_armor(armor.weight_class if armor != null else -1)
	figure.set_aura(school)
	figure.play("combat_idle", -1.0, false)
	return figure
