extends Node3D
## Battle Preparation: get the chosen champion ready for this specific
## opponent. A tactical summary answers "how should I prepare?", the build
## can be changed here with each option's effect on the matchup, and the
## champion's relevant skills and condition sit beside the opponent's read.
## Never a win chance. START SIMULATION runs the battle and opens its
## replay. Params: {"trial": id, "champion": uid}

const SKILLS_SHOWN: Array[String] = ["skill:dodge", "skill:block", "skill:stamina", "skill:timing"]

var trial: TrialData
var opponent: OpponentData
var arena: ArenaData
var analysis: MatchupAnalysis
var _root: Control
var _figure: CharacterVisual
var _figure_look := ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_back()


func _back() -> void:
	Router.go("champion_select", {"trial": trial.id, "champion": Game.champion().uid})


func _ready() -> void:
	if not Game.is_active():
		Router.go("title")
		return
	trial = Content.trial(Router.params.get("trial", "first_steps"))
	# The champion chosen for this fight is the one prepared and sent in.
	var chosen: String = Router.params.get("champion", "")
	if not chosen.is_empty() and chosen != Game.selected_uid:
		Game.select_champion(chosen)
	opponent = Content.opponent(trial.opponent_id)
	arena = Content.arena(trial.arena_id)
	Router.back_requested.connect(_back)
	_backdrop()
	_refresh()
	Game.changed.connect(_refresh)


func _refresh() -> void:
	if not is_inside_tree():
		return
	analysis = MatchupAnalysis.analyse(Game.champion(), opponent, arena)
	_show_champion()
	_build_ui()


func _backdrop() -> void:
	FightStage.backdrop(self, arena)
	var rival := FightStage.opponent_figure(opponent)
	rival.position = Vector3(1.7, 0, -1.6)
	rival.rotation.y = deg_to_rad(-20)
	add_child(rival)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.5, 5.0)
	# Shift the frame so both champions stand to the right of the sheet.
	camera.h_offset = -2.8
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	Sfx.play_ambient()


## The champion is re-dressed whenever its build changes.
func _show_champion() -> void:
	var champion := Game.champion()
	var look := "%s|%s|%s|%s" % [champion.uid, champion.weapon_id, champion.armor_id, champion.equipped_ability]
	if look == _figure_look:
		return
	_figure_look = look
	if _figure != null:
		_figure.queue_free()
	_figure = FightStage.champion_figure(champion)
	_figure.rotation.y = deg_to_rad(25)
	add_child(_figure)


# --- Actions ----------------------------------------------------------------------

func equip_item(item_id: String) -> void:
	var error := EquipmentSystem.equip(Game.champion(), Game.profile, item_id)
	if not error.is_empty():
		UiKit.toast(_root, error, UiTheme.BAD)
		return
	Sfx.play("ui_confirm")
	if Content.weapon(item_id) != null:
		Game.set_flag("equipped_weapon")
	Game.save()


func equip_magic(ability_id: String) -> void:
	if ability_id.is_empty():
		EquipmentSystem.unequip_ability(Game.champion())
	else:
		var error := EquipmentSystem.equip_ability(Game.champion(), ability_id)
		if not error.is_empty():
			UiKit.toast(_root, error, UiTheme.BAD)
			return
		Sfx.play("cast")
	Game.save()


## Pays the entry, simulates the whole battle (the result is decided and
## applied here) and goes to watch it.
func _enter() -> void:
	var session := start_simulation()
	if session == null:
		return
	Sfx.play("ui_confirm")
	Router.go("replay", {"session": session})


func start_simulation() -> BattleSession:
	var error := TrialSystem.enter(Game.champion(), trial)
	if not error.is_empty():
		UiKit.toast(_root, error, UiTheme.BAD)
		return null
	return BattleSession.start(trial, Game.champion())


# --- Layout -----------------------------------------------------------------------

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
	column.add_child(UiKit.label("BATTLE PREPARATION · %s vs %s" % [Game.champion().name.to_upper(),
			opponent.display_name.to_upper()], "DimLabel", true))
	column.add_child(UiKit.heading(trial.display_name))
	var body := UiKit.vbox(12)
	column.add_child(UiKit.scroll(body))
	var champion := Game.champion()
	_tactical_card(body)
	_build_card(body, champion)
	_champion_card(body, champion)
	_comparison_card(body)
	_arena_card(body)
	var blocker := TrialSystem.entry_blocker(champion, trial)
	if not blocker.is_empty():
		var warn := UiKit.label(blocker, "", true)
		warn.add_theme_color_override("font_color", UiTheme.BAD)
		column.add_child(warn)
	var row := UiKit.hbox(12)
	row.add_child(UiKit.button("Back", _back, "", 150))
	row.add_child(UiKit.spacer(false))
	var enter := UiKit.primary_button("START SIMULATION", _enter, 280)
	enter.name = "Enter"
	enter.disabled = not blocker.is_empty()
	row.add_child(enter)
	column.add_child(row)


func _card(parent: VBoxContainer, title: String, node_name: String = "") -> VBoxContainer:
	var panel := UiKit.panel("CardPanel")
	if not node_name.is_empty():
		panel.name = node_name
	var column := UiKit.vbox(6)
	panel.add_child(column)
	var heading := UiKit.label(title, "", true)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	heading.add_theme_font_size_override("font_size", UiTheme.fs(24))
	column.add_child(heading)
	parent.add_child(panel)
	return column


func _tactical_card(body: VBoxContainer) -> void:
	var card := _card(body, "Tactical read", "Tactical")
	card.add_child(UiKit.stat_row("Opponent Strength", analysis.opponent_strength))
	card.add_child(UiKit.stat_row("Threat", analysis.threat))
	card.add_child(_colored_row("Your Advantage", analysis.main_advantage(), UiTheme.GOOD))
	card.add_child(_colored_row("Main Risk", analysis.main_risk(), UiTheme.BAD))
	if analysis.advantages.size() > 1 or analysis.risks.size() > 1:
		card.add_child(UiKit.label("Strengths here: %s" % (" · ".join(analysis.advantages) if not analysis.advantages.is_empty()
				else "none obvious"), "DimLabel", true))
		card.add_child(UiKit.label("Weaknesses here: %s" % (" · ".join(analysis.risks) if not analysis.risks.is_empty()
				else "none obvious"), "DimLabel", true))


func _colored_row(name: String, value: String, color: Color) -> Control:
	var row := UiKit.stat_row(name, value)
	var value_label := row.get_child(0).get_child(1) as Label
	value_label.add_theme_color_override("font_color", color)
	return row


func _build_card(body: VBoxContainer, champion: Champion) -> void:
	var card := _card(body, "Build for this fight", "Build")
	card.add_child(UiKit.label("Each option shows what it changes for %s." % champion.name, "DimLabel", true))
	var weapons: Array = EquipmentSystem.owned(Game.profile, "weapon").filter(
			func(item: EquipmentData) -> bool: return item.available)
	_option_row(card, "Weapon", weapons.map(func(item: WeaponData) -> Dictionary:
		var rank := champion.rank_of("weapon:" + item.weapon_type)
		return {"id": item.id, "text": "%s (%s)" % [item.display_name, GameEnums.rank_name(rank) if rank > 0 else "untrained"],
				"selected": item.id == champion.weapon_id, "overrides": {"weapon_id": item.id},
				"action": equip_item.bind(item.id)}))
	_option_row(card, "Armor", EquipmentSystem.owned(Game.profile, "armor").map(func(item: ArmorData) -> Dictionary:
		return {"id": item.id, "text": "%s (%s)" % [item.display_name, GameEnums.ARMOR_WEIGHT_NAMES[item.weight_class]],
				"selected": item.id == champion.armor_id, "overrides": {"armor_id": item.id},
				"action": equip_item.bind(item.id)}))
	var magic: Array = [{"id": "", "text": "No Aether Art", "selected": champion.equipped_ability.is_empty(),
			"overrides": {"ability_id": ""}, "action": equip_magic.bind("")}]
	for school: MagicSchoolData in Content.list("magic"):
		for ability in school.abilities:
			if EquipmentSystem.can_use_ability(champion, ability):
				magic.append({"id": ability.id, "text": "%s (%s %s)" % [ability.display_name, school.display_name,
						GameEnums.rank_name(EquipmentSystem.school_rank(champion, school.id))],
						"selected": ability.id == champion.equipped_ability, "overrides": {"ability_id": ability.id},
						"action": equip_magic.bind(ability.id)})
	_option_row(card, "Aether Art", magic)


func _option_row(card: VBoxContainer, title: String, options: Array) -> void:
	card.add_child(UiKit.label(title))
	if options.is_empty():
		card.add_child(UiKit.label("Nothing to choose from yet.", "DimLabel"))
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for option: Dictionary in options:
		var effects := "current" if option["selected"] else \
				" · ".join(MatchupAnalysis.option_effects(Game.champion(), option["overrides"]))
		var button := UiKit.button("%s\n%s" % [option["text"], effects if not effects.is_empty() else "no visible change"],
				option["action"], "TabButtonSelected" if option["selected"] else "TabButton")
		button.name = "Option_" + (option["id"] if not option["id"].is_empty() else "none")
		button.custom_minimum_size.y = 76
		flow.add_child(button)
	card.add_child(flow)


func _champion_card(body: VBoxContainer, champion: Champion) -> void:
	var card := _card(body, "%s · Level %d · %s" % [champion.name, champion.level, champion.capability_name()])
	var skills := PackedStringArray()
	var weapon := Content.weapon(champion.weapon_id)
	var ability := Content.ability(champion.equipped_ability)
	var targets: Array[String] = []
	if weapon != null:
		targets.append("weapon:" + weapon.weapon_type)
	if ability != null:
		targets.append("magic:" + ability.school)
	targets.append_array(SKILLS_SHOWN)
	for target: String in targets:
		var rank := champion.rank_of(target)
		skills.append("%s %s" % [SkillCatalog.target_name(target), GameEnums.rank_name(rank) if rank > 0 else "—"])
	card.add_child(UiKit.label("Skill Matrix: " + " · ".join(skills), "DimLabel", true))
	if not champion.techniques.is_empty():
		var names := PackedStringArray()
		for technique_id in champion.techniques:
			names.append(Content.technique(technique_id).display_name)
		card.add_child(UiKit.label("Techniques: " + ", ".join(names), "DimLabel", true))
	card.add_child(UiKit.stat_row("Energy", "%d (this fight costs %d)" % [roundi(champion.energy), trial.energy_cost],
			champion.energy / champion.max_energy(), UiTheme.ENERGY))
	card.add_child(UiKit.stat_row("Mood", champion.mood_name(), champion.happiness / champion.max_happiness(),
			UiTheme.HAPPINESS))
	# The fight is fought with the energy left after entering.
	for note in ConditionEffects.notes(maxf(champion.energy - trial.energy_cost, 0.0), champion.happiness):
		var line := UiKit.label(note, "DimLabel", true)
		line.name = "ConditionNote"
		card.add_child(line)


func _comparison_card(body: VBoxContainer) -> void:
	var card := _card(body, "%s — %s" % [opponent.display_name, opponent.title], "Comparison")
	var them := analysis.them
	card.add_child(UiKit.label("%s · %s · %s armor · %s" % [them.capability, them.weapon_family, them.armor_weight,
			"No magic" if them.magic_school == "None" else them.magic_school + " Arts"], "DimLabel", true))
	var grid := UiKit.grid(3, 10)
	for text in ["", Game.champion().name, opponent.display_name]:
		var header := UiKit.label(text, "DimLabel")
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(header)
	for axis: String in MatchupAnalysis.AXES:
		grid.add_child(UiKit.label(axis))
		var mine := UiKit.label(_band(analysis.you, axis))
		var edge := analysis.edge(axis)
		if edge != 0:
			mine.add_theme_color_override("font_color", UiTheme.GOOD if edge > 0 else UiTheme.BAD)
		grid.add_child(mine)
		grid.add_child(UiKit.label(_band(them, axis)))
	card.add_child(grid)


static func _band(report: ScoutingReport, axis: String) -> String:
	match axis:
		"Strength":
			return report.strength
		"Defense":
			return report.defense
		"Mobility":
			return report.mobility
	return report.combat_range


func _arena_card(body: VBoxContainer) -> void:
	var card := _card(body, "Arena: %s" % arena.display_name)
	card.add_child(UiKit.label("• " + "\n• ".join(arena.features()), "DimLabel", true))
	card.add_child(UiKit.label("Rewards: ◉ %d · Keeper XP %d%s" % [trial.coins, trial.owner_xp,
			"" if Game.is_flag_set(trial.cleared_flag()) else " (+◉ %d first victory)" % trial.first_clear_coins], "DimLabel", true))
