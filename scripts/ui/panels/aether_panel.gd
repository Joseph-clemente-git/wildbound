extends LodgePanel
## Aether Arts at the Aether Circle (mechanics §66, story §31): schools,
## mastery, familiarity, known and locked abilities, and who can teach them.


func build(container: VBoxContainer) -> void:
	set_title("Aether Circle")
	Game.set_flag("visited_aether")
	var champion := Game.champion()
	var equipped := Content.ability(champion.equipped_ability)
	var top := card("Attuned Art", "Aether is a learnable discipline, not a species gift. Every champion can learn every school. One art is attuned for trials (the Magic button).")
	top.add_child(UiKit.label(equipped.display_name if equipped else "None attuned"))
	if equipped != null:
		top.add_child(UiKit.button("Release attunement", func() -> void:
			EquipmentSystem.unequip_ability(champion)
			Game.save()))
	for school: MagicSchoolData in Content.list("magic"):
		_school_card(champion, school)


func _school_card(champion: Champion, school: MagicSchoolData) -> void:
	var target := "magic:" + school.id
	var rank := champion.skills.get_rank(target)
	var column := card("%s Aether" % school.display_name, school.description)
	if not school.available:
		var region := Content.region(school.region_id)
		column.add_child(UiKit.label("Studied in %s — later in the journey." % (region.display_name if region else "a distant region"), "DimLabel"))
		return
	column.add_child(UiKit.stat_row("Mastery", GameEnums.rank_name(rank) if rank > 0 else "Unlearned",
			champion.skills.progress_ratio(target) if rank > 0 else 0.0, school.color))
	column.add_child(UiKit.stat_row("Familiarity experience", "%d / %d" % [roundi(champion.experience.get_xp(target)),
			roundi(champion.experience.threshold(target))], champion.experience.ratio(target), UiTheme.GOOD))
	column.add_child(UiKit.label("Potential: %s" % GameEnums.rank_name(champion.rank_cap(target)), "DimLabel"))
	var teachers := PackedStringArray()
	for trainer: TrainerData in Content.list("trainers"):
		if trainer.primary_discipline.has(target):
			var state := "active" if TrainerManager.is_active(Game.profile, trainer.id) else \
					("in your lodge" if Game.profile.owned_trainers.has(trainer.id) else "not recruited")
			teachers.append("%s (%s)" % [trainer.display_name, state])
	column.add_child(UiKit.label("Trainer requirement: " + ", ".join(teachers), "DimLabel", true))
	for ability in school.abilities:
		var usable := EquipmentSystem.can_use_ability(champion, ability)
		var row := UiKit.vbox(4)
		var head := UiKit.hbox(10)
		var name_label := UiKit.label(ability.display_name)
		name_label.add_theme_color_override("font_color", school.color if usable else UiTheme.TEXT_DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		head.add_child(UiKit.label("Known" if usable else "Locked — needs %s" % GameEnums.rank_name(ability.required_rank), "DimLabel"))
		row.add_child(head)
		row.add_child(UiKit.label(ability.description, "DimLabel", true))
		row.add_child(UiKit.label("Stamina %d · Cast %.2fs · Recovery %.2fs · Range %.0fm" % [ability.stamina_cost,
				ability.cast_time, ability.recovery, ability.cast_range], "DimLabel"))
		row.add_child(UiKit.label("Counterplay: " + ability.counterplay, "DimLabel", true))
		if usable and champion.equipped_ability != ability.id:
			row.add_child(UiKit.primary_button("Attune", _attune.bind(ability.id)))
		column.add_child(row)


func _attune(ability_id: String) -> void:
	var error := EquipmentSystem.equip_ability(Game.champion(), ability_id)
	if error.is_empty():
		Sfx.play("cast")
		Game.save()
	else:
		toast(error, UiTheme.BAD)
