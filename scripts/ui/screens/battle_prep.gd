extends Node3D
## Battle Preparation (mechanics §67, story §34): review the champion, build,
## Skill Matrix highlights, energy, the opponent and the trial ground, then
## ENTER TRIAL. Params: {"trial": id}

var trial: TrialData
var opponent: OpponentData
var _root: Control


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_back()


func _back() -> void:
	Router.go("journey", {"region": trial.region_id})


func _ready() -> void:
	if not Game.is_active():
		Router.go("title")
		return
	trial = Content.trial(Router.params.get("trial", "first_steps"))
	opponent = Content.opponent(trial.opponent_id)
	Router.back_requested.connect(_back)
	_backdrop()
	_build_ui()
	Game.changed.connect(_build_ui)


func _backdrop() -> void:
	var arena := Content.arena(trial.arena_id)
	WorldBuilder.environment(self, arena.mood)
	WorldBuilder.ground(self, 80.0, {"ring_center": Vector2.ZERO, "ring_radius": 6.0})
	WorldBuilder.grass(self, Rect2(-14, -14, 28, 28), 1600, [Vector3(0, 0, 6.3)], 8)
	WorldBuilder.forest_ring(self, 10.0, 22.0, 30, 6, false)
	var champion := Game.champion()
	var dog := CharacterFactory.for_champion(champion)
	dog.position = Vector3(0.0, 0, 0.0)
	dog.rotation.y = deg_to_rad(25)
	var weapon := Content.weapon(champion.weapon_id)
	dog.set_weapon(weapon.weapon_type if weapon else "")
	var armor := Content.armor(champion.armor_id)
	dog.set_armor(armor.weight_class if armor else -1)
	var ability := Content.ability(champion.equipped_ability)
	dog.set_aura(ability.school if ability else "")
	dog.play("combat_idle", -1.0, false)
	add_child(dog)
	var rival := CharacterFactory.for_opponent(opponent)
	rival.position = Vector3(1.7, 0, -1.6)
	rival.rotation.y = deg_to_rad(-20)
	var rival_weapon := Content.weapon(opponent.weapon_id)
	rival.set_weapon(rival_weapon.weapon_type if rival_weapon else "")
	rival.set_armor(Content.armor(opponent.armor_id).weight_class)
	rival.play("combat_idle", -1.0, false)
	add_child(rival)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.5, 5.0)
	# Shift the frame so both champions stand to the right of the sheet.
	camera.h_offset = -2.8
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	Sfx.play_ambient()


func _build_ui() -> void:
	if _root != null:
		_root.queue_free()
	var layer := get_node_or_null("UI") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "UI"
		add_child(layer)
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_root)
	var sheet := UiKit.panel("SheetPanel")
	sheet.anchor_right = 0.6
	sheet.anchor_bottom = 1.0
	var insets := UiKit.safe_insets()
	sheet.offset_left = 16 + insets.x
	sheet.offset_top = 16 + insets.y
	sheet.offset_bottom = -16 - insets.w
	_root.add_child(sheet)
	var column := UiKit.vbox(10)
	sheet.add_child(column)
	column.add_child(UiKit.label("BATTLE PREPARATION", "DimLabel"))
	column.add_child(UiKit.heading(trial.display_name))
	var body := UiKit.vbox(12)
	column.add_child(UiKit.scroll(body))
	var champion := Game.champion()
	_champion_card(body, champion)
	_opponent_card(body, champion)
	_arena_card(body)
	var blocker := TrialSystem.entry_blocker(champion, trial)
	if not blocker.is_empty():
		var warn := UiKit.label(blocker, "", true)
		warn.add_theme_color_override("font_color", UiTheme.BAD)
		column.add_child(warn)
	var row := UiKit.hbox(12)
	row.add_child(UiKit.button("Back", _back))
	row.add_child(UiKit.button("Change build", func() -> void: Router.go("lodge", {"panel": "equipment"})))
	row.add_child(UiKit.spacer(false))
	var enter := UiKit.primary_button("ENTER TRIAL", _enter, 240)
	enter.disabled = not blocker.is_empty()
	row.add_child(enter)
	column.add_child(row)


func _card(parent: VBoxContainer, title: String) -> VBoxContainer:
	var panel := UiKit.panel("CardPanel")
	var column := UiKit.vbox(6)
	panel.add_child(column)
	var heading := UiKit.label(title)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	heading.add_theme_font_size_override("font_size", UiTheme.fs(24))
	column.add_child(heading)
	parent.add_child(panel)
	return column


func _champion_card(body: VBoxContainer, champion: Champion) -> void:
	var card := _card(body, "%s · Level %d · %s" % [champion.name, champion.level, champion.capability_name()])
	var weapon := Content.weapon(champion.weapon_id)
	var armor := Content.armor(champion.armor_id)
	var ability := Content.ability(champion.equipped_ability)
	var weapon_text := "Bare paws"
	if weapon != null:
		var rank := champion.skills.get_rank("weapon:" + weapon.weapon_type)
		weapon_text = "%s (%s)" % [weapon.display_name, GameEnums.rank_name(rank) if rank > 0 else "untrained"]
	card.add_child(UiKit.stat_row("Weapon", weapon_text))
	card.add_child(UiKit.stat_row("Armor", "%s%s" % [armor.display_name if armor else "None",
			(" — " + GameEnums.ARMOR_WEIGHT_NAMES[armor.weight_class]) if armor else ""]))
	card.add_child(UiKit.stat_row("Aether Art", ability.display_name if ability else "None attuned"))
	var skills := PackedStringArray()
	for target: String in ["skill:dodge", "skill:block", "skill:stamina", "skill:timing"]:
		var rank := champion.skills.get_rank(target)
		skills.append("%s %s" % [SkillCatalog.target_name(target), GameEnums.rank_name(rank) if rank > 0 else "—"])
	card.add_child(UiKit.label("Skill Matrix: " + " · ".join(skills), "DimLabel", true))
	if not champion.techniques.is_empty():
		var names := PackedStringArray()
		for technique_id in champion.techniques:
			names.append(Content.technique(technique_id).display_name)
		card.add_child(UiKit.label("Techniques: " + ", ".join(names), "DimLabel", true))
	var stats := CombatStats.for_champion(champion)
	card.add_child(UiKit.label("Health %d · Stamina %d · Damage %d · Defense %d%% · Dodge %.1fm" % [
			stats.max_health, stats.max_stamina, stats.damage, roundi(stats.mitigation * 100.0), stats.dodge_distance], "DimLabel", true))
	card.add_child(UiKit.stat_row("Energy", "%d (trial costs %d)" % [roundi(champion.energy), trial.energy_cost],
			champion.energy / champion.max_energy(), UiTheme.ENERGY))


func _opponent_card(body: VBoxContainer, champion: Champion) -> void:
	var card := _card(body, "Opponent: %s — %s" % [opponent.display_name, opponent.title])
	var weapon := Content.weapon(opponent.weapon_id)
	var ability := Content.ability(opponent.magic_ability_id)
	card.add_child(UiKit.label("Level %d · %s · %s%s" % [opponent.level, weapon.display_name,
			Content.armor(opponent.armor_id).display_name, (" · " + ability.display_name) if ability else ""], "", true))
	var ratio := PowerRating.for_opponent(opponent) / maxf(champion.power_rating(), 1.0)
	card.add_child(UiKit.label("Difficulty: %s (experience ×%.2f)" % [PowerRating.difficulty_label(ratio),
			PowerRating.difficulty_multiplier(ratio)], "DimLabel"))
	card.add_child(UiKit.label("Style: " + ", ".join(style_notes(opponent)), "DimLabel", true))


static func style_notes(data: OpponentData) -> PackedStringArray:
	var notes := PackedStringArray()
	if data.aggression >= 0.6:
		notes.append("aggressive")
	elif data.aggression <= 0.4:
		notes.append("patient")
	if data.block_skill >= 0.5:
		notes.append("guards often")
	if data.dodge_skill >= 0.5:
		notes.append("evasive")
	if data.heavy_chance >= 0.35:
		notes.append("heavy hitter")
	if data.telegraph >= 1.3:
		notes.append("telegraphs attacks")
	if not data.magic_ability_id.is_empty():
		notes.append("uses %s" % Content.ability(data.magic_ability_id).display_name)
	if not data.phases.is_empty():
		notes.append("changes tactics mid-fight")
	if notes.is_empty():
		notes.append("balanced")
	return notes


func _arena_card(body: VBoxContainer) -> void:
	var arena := Content.arena(trial.arena_id)
	var card := _card(body, "Trial ground: %s" % arena.display_name)
	card.add_child(UiKit.label(arena.description, "DimLabel", true))
	card.add_child(UiKit.label("Rewards: ◉ %d · Keeper XP %d%s" % [trial.coins, trial.owner_xp,
			"" if Game.is_flag_set(trial.cleared_flag()) else " (+◉ %d first victory)" % trial.first_clear_coins], "DimLabel"))


func _enter() -> void:
	var error := TrialSystem.enter(Game.champion(), trial)
	if not error.is_empty():
		UiKit.toast(_root, error, UiTheme.BAD)
		return
	Sfx.play("ui_confirm")
	Router.go("arena", {"trial": trial.id, "entered": true})
