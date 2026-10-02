extends LodgePanel
## Trainer Board: the lodge's active mentorship circle, its roster, mentors
## who can be recruited and those rumoured in other regions (mechanics §63,
## story §29). Active mentors are limited by the lodge's reputation (max 5).

var _replacing := ""  # inactive mentor waiting to take an active slot


func build(container: VBoxContainer) -> void:
	set_title("Trainer Board")
	var profile := Game.profile
	var slots := profile.trainer_slots()
	var next := profile.next_slot_level()
	var header := card("Active Mentors  %d / %d" % [profile.active_trainers.size(), slots],
			"The %s can keep %d active mentorship contract%s.%s Mentors train every champion of the lodge." % [
			profile.lodge_title(), slots, "" if slots == 1 else "s",
			(" Another opens at Keeper level %d." % next) if next > 0 else ""])
	if not _replacing.is_empty():
		var note := UiKit.label("Choose an active mentor to replace with %s." % Content.trainer(_replacing).display_name, "", true)
		note.add_theme_color_override("font_color", UiTheme.ACCENT)
		header.add_child(note)
		header.add_child(UiKit.button("Cancel", func() -> void:
			_replacing = ""
			rebuild()))
	for trainer in TrainerManager.active(profile):
		_trainer_card(trainer, "active")
	var inactive := TrainerManager.owned(profile).filter(func(t: TrainerData) -> bool:
		return not TrainerManager.is_active(profile, t.id))
	if not inactive.is_empty():
		card("Lodge Roster", "Mentors who know your lodge but are not under active contract.")
		for trainer: TrainerData in inactive:
			_trainer_card(trainer, "roster")
	var recruitable := TrainerManager.recruitable(profile)
	if not recruitable.is_empty():
		card("Available Mentors", "Specialists in the regions you can reach. Signing a contract costs coins once.")
		for trainer in recruitable:
			_trainer_card(trainer, "recruit")
	var rumored := TrainerManager.rumored(profile)
	if not rumored.is_empty():
		var titles := PackedStringArray()
		for trainer in rumored:
			titles.append("%s (%s)" % [trainer.title, Content.region(trainer.region_id).display_name])
		card("Rumoured Mentors", "Further along the journey: " + ", ".join(titles) + ".")


func _trainer_card(trainer: TrainerData, mode: String) -> void:
	var column := card("")
	var top := UiKit.hbox(10)
	var name_label := UiKit.label("%s — %s" % [trainer.display_name, trainer.title])
	name_label.add_theme_font_size_override("font_size", UiTheme.fs(24))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var rarity := UiKit.label(GameEnums.rarity_name(trainer.rarity))
	rarity.add_theme_color_override("font_color", GameEnums.rarity_color(trainer.rarity))
	top.add_child(rarity)
	column.add_child(top)
	column.add_child(UiKit.label("%s · %s" % [GameEnums.RARITY_TITLES[trainer.rarity], trainer.description], "DimLabel", true))
	var details := PackedStringArray()
	details.append("Primary: " + trainer.discipline_label(trainer.primary_discipline))
	if not trainer.secondary_discipline.is_empty():
		details.append("Secondary: %s%s" % [trainer.discipline_label(trainer.secondary_discipline),
				"" if TrainerManager.teaches_secondary(trainer) else " (needs Uncommon+)"])
	details.append("Efficiency ×%.2f · Teaches skills to %s · Stats to %d" % [TrainerManager.rarity_efficiency(trainer),
			GameEnums.rank_name(TrainerManager.rank_cap(trainer)), roundi(TrainerManager.stat_cap(trainer))])
	var traits := PackedStringArray()
	for trait_id in TrainerManager.active_traits(trainer):
		traits.append("%s — %s" % [TrainerTraits.trait_name(trait_id), TrainerTraits.get_trait(trait_id).get("description", "")])
	if not traits.is_empty():
		details.append("Trait: " + "; ".join(traits))
	var techniques := TrainerManager.teachable_techniques(trainer)
	if not techniques.is_empty():
		details.append("Techniques: " + ", ".join(techniques.map(func(t: TechniqueData) -> String: return t.display_name)))
	if mode != "recruit":
		var bond := TrainerManager.bond_level(Game.profile, trainer.id)
		details.append("Sessions taught: %d · Bond %d/5" % [int(Game.profile.trainer_sessions.get(trainer.id, 0)), bond])
	column.add_child(UiKit.label("\n".join(details), "", true))
	var actions := UiKit.hbox(10)
	match mode:
		"active":
			if _replacing.is_empty():
				actions.add_child(UiKit.primary_button("Train", host.switch_to.bind("training", {"trainer": trainer.id})))
				actions.add_child(UiKit.button("Deactivate", _deactivate.bind(trainer.id)))
			else:
				actions.add_child(UiKit.primary_button("Replace", _replace.bind(trainer.id)))
		"roster":
			if TrainerManager.free_slots(Game.profile) > 0:
				actions.add_child(UiKit.primary_button("Activate", _activate.bind(trainer.id)))
			else:
				actions.add_child(UiKit.button("Replace an active mentor", func() -> void:
					_replacing = trainer.id
					rebuild()))
		"recruit":
			var recruit := UiKit.primary_button("Recruit (◉ %d)" % trainer.recruit_cost, _recruit.bind(trainer.id))
			recruit.disabled = not Game.profile.can_afford(trainer.recruit_cost)
			actions.add_child(recruit)
			actions.add_child(UiKit.label("“%s”" % trainer.greeting, "DimLabel", true))
	column.add_child(actions)


func _report(error: String, success: String) -> void:
	if error.is_empty():
		Sfx.play("ui_confirm")
		toast(success, UiTheme.GOOD)
		Game.save()
	else:
		toast(error, UiTheme.BAD)
	rebuild()


func _activate(trainer_id: String) -> void:
	_report(TrainerManager.activate(Game.profile, trainer_id), "%s is now an active mentor." % Content.trainer(trainer_id).display_name)


func _deactivate(trainer_id: String) -> void:
	_report(TrainerManager.deactivate(Game.profile, trainer_id), "%s steps back from active duty." % Content.trainer(trainer_id).display_name)


func _replace(old_id: String) -> void:
	var new_id := _replacing
	_replacing = ""
	_report(TrainerManager.replace(Game.profile, old_id, new_id), "%s takes over the slot." % Content.trainer(new_id).display_name)


func _recruit(trainer_id: String) -> void:
	_report(TrainerManager.recruit(Game.profile, trainer_id), "%s joined your lodge." % Content.trainer(trainer_id).display_name)
