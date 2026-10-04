extends LodgePanel
## Champion screen: overview, Skill Matrix and experience (mechanics §61-62,
## story §18, §27). The Skill Matrix reveals itself in stages as the story
## introduces each part.

## Tabs shared with the Skill Network panel, which opens as its own wide sheet.
const TABS := [["Overview", "overview"], ["Skill Matrix", "skills"], ["Skill Network", "network"],
		["Experience", "experience"]]

var _tab := "overview"


func _ready() -> void:
	_tab = "skills" if panel_id == "skills" else str(options.get("tab", _tab))
	super._ready()


func build(container: VBoxContainer) -> void:
	var champion := Game.champion()
	set_title(champion.name)
	set_tabs(TABS, _tab, _select_tab)
	match _tab:
		"skills":
			Game.set_flag("viewed_skill_matrix")
			_build_matrix(container, champion)
		"experience":
			_build_experience(container, champion)
		_:
			_build_overview(container, champion)


func _select_tab(tab: String) -> void:
	if tab == "network":
		host.switch_to("skill_network")
		return
	_tab = tab
	rebuild()


# --- Overview ----------------------------------------------------------------------

func _build_overview(container: VBoxContainer, champion: Champion) -> void:
	var animal := champion.data()
	var header := card("%s · Level %d" % [animal.display_name, champion.level],
			"%s · %s movement · %s" % [champion.capability_name(),
			GameEnums.MOVEMENT_TYPE_NAMES[animal.movement_type], animal.personality])
	header.add_child(UiKit.stat_row("Level progress", "%d / %d XP" % [champion.xp, Champion.xp_to_next(champion.level)],
			float(champion.xp) / Champion.xp_to_next(champion.level)))
	header.add_child(UiKit.stat_row("Energy (physical condition)", "%d / %d" % [champion.energy, champion.max_energy()],
			champion.energy / champion.max_energy(), UiTheme.ENERGY))
	header.add_child(UiKit.stat_row("Bond (%s)" % champion.mood_name(), "%d / %d" % [champion.happiness, champion.max_happiness()],
			champion.happiness / champion.max_happiness(), UiTheme.HAPPINESS))
	if champion.knocked_out:
		header.add_child(UiKit.label("Knocked out — needs rest before training or trials.", "", true))
	header.add_child(UiKit.label("Record: %d wins · %d losses" % [champion.wins, champion.losses], "DimLabel"))

	var stats := card("Attributes", "Natural attributes grow from battle experience and trainer development, up to the animal's potential.")
	stats.add_child(StatBar.legend())
	for stat: String in GameEnums.STATS:
		var row := UiKit.hbox(12)
		var name_label := UiKit.label(GameEnums.stat_name(stat))
		name_label.custom_minimum_size.x = 150
		row.add_child(name_label)
		row.add_child(StatBar.new().setup(champion, stat))
		var value := UiKit.label("%d" % roundi(champion.final_stat(stat)))
		value.custom_minimum_size.x = 44
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		var rank := UiKit.label(GameEnums.rank_name(champion.stat_rank(stat)), "DimLabel")
		rank.custom_minimum_size.x = 100
		row.add_child(rank)
		stats.add_child(row)

	var gear := card("Build")
	var weapon := Content.weapon(champion.weapon_id)
	var armor := Content.armor(champion.armor_id)
	var accessory := Content.accessory(champion.accessory_id)
	var ability := Content.ability(champion.equipped_ability)
	gear.add_child(UiKit.stat_row("Weapon", "%s%s" % [weapon.display_name if weapon else "Bare paws",
			(" (%s)" % GameEnums.rank_name(champion.skills.get_rank("weapon:" + weapon.weapon_type))) if weapon else ""]))
	gear.add_child(UiKit.stat_row("Armor", armor.display_name if armor else "None"))
	gear.add_child(UiKit.stat_row("Accessory", accessory.display_name if accessory else "None"))
	gear.add_child(UiKit.stat_row("Aether Art", ability.display_name if ability else "None"))
	var actions := UiKit.hbox(10)
	for entry: Array in [["Train", "training"], ["Equip", "equipment"], ["Aether", "aether"]]:
		var button := UiKit.button(entry[0], host.switch_to.bind(entry[1]))
		button.disabled = not LodgeHud.is_panel_unlocked(entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	gear.add_child(actions)

	var balance := card("Nature of the %s" % animal.display_name)
	balance.add_child(UiKit.rich("[color=#8cc46f]Strengths[/color]: %s\n[color=#d9674e]Weaknesses[/color]: %s\n[color=#7fd3d8]Counterplay[/color]: %s" % [
			", ".join(animal.strengths), ", ".join(animal.weaknesses), ", ".join(animal.counterplay)]))


# --- Skill Matrix ------------------------------------------------------------------

func _revealed(stage: String) -> bool:
	return Game.is_flag_set(SkillCatalog.REVEAL_FLAGS.get(stage, ""))


func _build_matrix(container: VBoxContainer, champion: Champion) -> void:
	var animal := champion.data()
	var foundation := card("Natural Foundation", "What %s was born with. Training potential limits how far each attribute can grow." % champion.name)
	foundation.add_child(UiKit.stat_row("Movement type", GameEnums.MOVEMENT_TYPE_NAMES[animal.movement_type]))
	var potentials := PackedStringArray()
	for stat: String in GameEnums.STATS:
		potentials.append("%s %d" % [GameEnums.stat_name(stat), roundi(champion.potential(stat))])
	potentials.append("Aether %d" % roundi(animal.get_potential(GameEnums.MAGIC_POTENTIAL)))
	foundation.add_child(UiKit.label("Potential: " + " · ".join(potentials), "DimLabel", true))
	foundation.add_child(UiKit.label("Combat capability: %s" % champion.capability_name()))
	var natural := SkillCatalog.NATURAL_ORDER.filter(func(skill: String) -> bool:
		return champion.skills.get_rank("skill:" + skill) > 0)
	if not natural.is_empty():
		var nature := card(SkillCatalog.CATEGORY_NAMES[SkillCatalog.NATURAL],
				"How this body moves through water and air. It decides how terrain helps or hinders it.")
		for skill: String in natural:
			nature.add_child(_skill_row(champion, "skill:" + skill))

	var fundamentals := card(SkillCatalog.CATEGORY_NAMES[SkillCatalog.FUNDAMENTALS])
	var hidden := 0
	for skill: String in SkillCatalog.FUNDAMENTAL_ORDER:
		var target := "skill:" + skill
		if _revealed(SkillCatalog.reveal_stage(target)):
			fundamentals.add_child(_skill_row(champion, target))
		else:
			hidden += 1
	if hidden > 0:
		fundamentals.add_child(UiKit.label("%d more fundamentals will reveal themselves through training." % hidden, "DimLabel", true))

	if _revealed("discipline"):
		var discipline := card(SkillCatalog.CATEGORY_NAMES[SkillCatalog.DISCIPLINE], "Refinements that improve control rather than raw damage.")
		for skill: String in SkillCatalog.DISCIPLINE_ORDER:
			discipline.add_child(_skill_row(champion, "skill:" + skill))
	if _revealed("weapons"):
		var weapons := card(SkillCatalog.CATEGORY_NAMES[SkillCatalog.WEAPONS],
				"Using a weapon builds familiarity (up to %s). Mastery beyond that needs a weapon trainer." % \
				GameEnums.rank_name(Content.config.natural_rank_cap))
		for weapon_type: String in GameEnums.WEAPON_TYPES:
			weapons.add_child(_skill_row(champion, "weapon:" + weapon_type))
	if _revealed("magic"):
		var magic := card(SkillCatalog.CATEGORY_NAMES[SkillCatalog.MAGIC], "Every champion can learn every school of Aether.")
		for school: String in GameEnums.MAGIC_SCHOOLS:
			magic.add_child(_skill_row(champion, "magic:" + school))
	if _revealed("techniques"):
		_build_techniques(champion)
	else:
		card("More to discover", "Defense, Block, weapons, Aether Arts and advanced techniques appear as %s's training begins." % champion.name)


func _skill_row(champion: Champion, target: String) -> Control:
	var column := UiKit.vbox(4)
	var top := UiKit.hbox(10)
	var name_label := UiKit.label(SkillCatalog.target_name(target))
	name_label.custom_minimum_size.x = 190
	top.add_child(name_label)
	var rank := champion.skills.get_rank(target)
	var cap := champion.rank_cap(target)
	var bar := UiKit.bar(champion.skills.progress_ratio(target) if rank > 0 else 0.0, 1.0, UiTheme.ACCENT, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(bar)
	var rank_label := UiKit.label(GameEnums.rank_name(rank) if rank > 0 else "Unlearned")
	rank_label.custom_minimum_size.x = 120
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if rank == 0:
		rank_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	top.add_child(rank_label)
	column.add_child(top)
	var notes := PackedStringArray()
	if cap < GameEnums.Rank.MASTER:
		notes.append("Potential: %s" % GameEnums.rank_name(cap))
	var track := SkillCatalog.conversion_track(target)
	if not track.is_empty() and champion.experience.get_xp(track) > 0.5:
		notes.append("%s exp %d banked" % [ExperienceTracks.track_name(track), roundi(champion.experience.get_xp(track))])
	var teachers := PackedStringArray()
	for trainer in TrainerManager.owned(Game.profile):
		if TrainerManager.coverage(trainer).has(target):
			teachers.append(trainer.title)
	notes.append("Trainer: " + (", ".join(teachers) if not teachers.is_empty() else "none in your lodge yet"))
	var missing := TrainingSystem.missing_prerequisites(champion, target)
	if not missing.is_empty():
		notes.append("Requires " + ", ".join(missing))
	var note_label := UiKit.label(" · ".join(notes), "DimLabel", true)
	column.add_child(note_label)
	return column


func _build_techniques(champion: Champion) -> void:
	var techniques := card("Advanced Techniques", "Combinations of skills unlock techniques, learned from a mentor who teaches them. They trigger contextually in battle.")
	for technique: TechniqueData in Content.list("techniques"):
		var status := TechniqueSystem.status(champion, technique)
		var known := TechniqueSystem.knows(champion, technique.id)
		var block := UiKit.vbox(4)
		var top := UiKit.hbox(10)
		var name_label := UiKit.label(technique.display_name)
		name_label.add_theme_color_override("font_color", UiTheme.GOOD if known else (UiTheme.ACCENT if status["met"] else UiTheme.TEXT_DIM))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_label)
		top.add_child(UiKit.label("Learned" if known else ("Available" if status["met"] else "Locked"), "DimLabel"))
		block.add_child(top)
		block.add_child(UiKit.label(technique.description, "DimLabel", true))
		var reqs := PackedStringArray()
		for req: Dictionary in status["requirements"]:
			reqs.append("%s %s %s" % ["✓" if req["met"] else "✗", SkillCatalog.target_name(req["target"]), GameEnums.rank_name(req["need"])])
		block.add_child(UiKit.label("  ".join(reqs), "", true))
		if not known:
			var teacher_names := PackedStringArray()
			for trainer in TechniqueSystem.known_teachers(technique):
				teacher_names.append("%s (%s)" % [trainer.title, GameEnums.rarity_name(trainer.rarity)])
			block.add_child(UiKit.label("Taught by: " + ", ".join(teacher_names), "DimLabel", true))
			var blocker := TechniqueSystem.learn_blocker(champion, technique, Game.profile)
			if status["met"]:
				var learn := UiKit.primary_button("Learn (%d coins)" % technique.coin_cost, _learn.bind(technique))
				learn.disabled = not blocker.is_empty()
				block.add_child(learn)
				if not blocker.is_empty():
					block.add_child(UiKit.label(blocker, "DimLabel", true))
		techniques.add_child(block)
		techniques.add_child(HSeparator.new())


func _learn(technique: TechniqueData) -> void:
	var error := TechniqueSystem.learn(Game.champion(), technique, Game.profile)
	if error.is_empty():
		Sfx.play("growth")
		toast("%s learned %s!" % [Game.champion().name, technique.display_name], UiTheme.GOOD)
		Game.save()
	else:
		toast(error, UiTheme.BAD)


# --- Experience ------------------------------------------------------------------

func _build_experience(container: VBoxContainer, champion: Champion) -> void:
	card("What %s has lived" % champion.name,
			"Experience Growth: battles fill these tracks. When one fills, %s naturally develops. Trainer Development: mentors convert banked experience into deliberate progress." % champion.name)
	var tracks := card("Experience tracks")
	var any := false
	for track: String in ExperienceTracks.CORE_TRACKS:
		tracks.add_child(_track_row(champion, track))
		any = true
	var familiarity := card("Familiarity", "Weapons and Aether Arts the champion has actually used.")
	var shown := 0
	for track: String in champion.experience.active_tracks():
		if GameEnums.target_kind(track) in ["weapon", "magic"]:
			familiarity.add_child(_track_row(champion, track))
			shown += 1
	if shown == 0:
		familiarity.add_child(UiKit.label("No weapon or Aether familiarity yet — it comes from using them in trials.", "DimLabel", true))
	if not any:
		tracks.add_child(UiKit.label("No experience yet.", "DimLabel"))


func _track_row(champion: Champion, track: String) -> Control:
	var data := champion.experience
	return UiKit.stat_row("%s Experience" % ExperienceTracks.track_name(track),
			"%d / %d · %d growth%s" % [roundi(data.get_xp(track)), roundi(data.threshold(track)),
			data.get_growths(track), "" if data.get_growths(track) == 1 else "s"], data.ratio(track), UiTheme.GOOD)
