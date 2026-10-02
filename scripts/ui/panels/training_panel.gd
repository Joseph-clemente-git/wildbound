extends LodgePanel
## Training: Champion → Trainer → Skill → Cost → Energy → Expected → Confirm
## (mechanics §64, story §28). Clearly separates natural Experience Growth
## from deliberate Trainer Development.

var _trainer_id := ""
var _target := ""
var _last_result := ""


func _ready() -> void:
	_trainer_id = options.get("trainer", "")
	_target = options.get("target", "")
	super._ready()


func build(container: VBoxContainer) -> void:
	set_title("Training Yard")
	var champion := Game.champion()
	var profile := Game.profile
	var active := TrainerManager.active(profile)
	if active.is_empty():
		var empty := card("No active mentor", "Mentors develop your champion deliberately. Visit the Trainer Board to activate one.")
		empty.add_child(UiKit.button("Open the Trainer Board", host.switch_to.bind("trainers")))
		return
	if _trainer_id.is_empty() or not TrainerManager.is_active(profile, _trainer_id):
		_trainer_id = active[0].id
	var trainer := Content.trainer(_trainer_id)

	var who := card("1 · Mentor", "%s has %d energy · %s" % [champion.name, roundi(champion.energy), champion.mood_name()])
	var row := UiKit.hbox(10)
	for entry in active:
		var button := UiKit.button(entry.title, _pick_trainer.bind(entry.id), "PrimaryButton" if entry.id == _trainer_id else "")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	who.add_child(row)
	who.add_child(UiKit.label("%s — %s %s · Efficiency ×%.2f · Teaches up to %s" % [trainer.display_name,
			GameEnums.rarity_name(trainer.rarity), trainer.title, TrainerManager.rarity_efficiency(trainer),
			GameEnums.rank_name(TrainerManager.rank_cap(trainer))], "DimLabel", true))

	var what := card("2 · Skill")
	var grid := UiKit.grid(2, 10)
	for target in TrainerManager.coverage(trainer):
		var preview := TrainingSystem.preview(trainer, champion, target, profile)
		var label := "%s · %s" % [SkillCatalog.target_name(target), _current_text(champion, target)]
		var button := UiKit.button(label, _pick_target.bind(target), "PrimaryButton" if target == _target else "")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not preview["ok"] and not str(preview["reason"]).contains("coins") and not str(preview["reason"]).contains("tired"):
			button.modulate = Color(1, 1, 1, 0.55)
		grid.add_child(button)
	what.add_child(grid)
	if _target.is_empty() or not TrainerManager.coverage(trainer).has(_target):
		_target = ""
		what.add_child(UiKit.label("Choose what %s should develop." % champion.name, "DimLabel"))
		_show_result()
		return

	var preview := TrainingSystem.preview(trainer, champion, _target, profile)
	var plan := card("3 · Session plan")
	plan.add_child(UiKit.stat_row("Current", _current_text(champion, _target)))
	if not str(preview["expected_text"]).is_empty():
		plan.add_child(UiKit.stat_row("Expected development", preview["expected_text"]))
	plan.add_child(UiKit.stat_row("Cost", "◉ %d coins" % preview["coin_cost"]))
	plan.add_child(UiKit.stat_row("Energy", "%d of %d" % [preview["energy_cost"], roundi(champion.energy)]))
	if preview["converted"] > 0.5:
		plan.add_child(UiKit.stat_row("Builds on battle experience",
				"%d %s exp" % [roundi(preview["converted"]), ExperienceTracks.track_name(SkillCatalog.conversion_track(_target))]))
	else:
		plan.add_child(UiKit.label("No matching battle experience banked — trials make training more effective.", "DimLabel", true))
	if not trainer.is_primary(_target):
		plan.add_child(UiKit.label("Secondary discipline: %s teaches this at reduced strength." % trainer.display_name, "DimLabel", true))
	if preview["overtraining"]:
		var warn := UiKit.label("%s is tired — training now will lower their bond." % champion.name, "", true)
		warn.add_theme_color_override("font_color", UiTheme.WARN)
		plan.add_child(warn)
	if not preview["ok"]:
		var reason := UiKit.label(preview["reason"], "", true)
		reason.add_theme_color_override("font_color", UiTheme.BAD)
		plan.add_child(reason)
	var confirm := UiKit.primary_button("Train", _train)
	confirm.disabled = not preview["ok"]
	plan.add_child(confirm)
	_show_result()


func _show_result() -> void:
	if _last_result.is_empty():
		return
	var result := card("Last session")
	result.add_child(UiKit.label(_last_result, "", true))


func _current_text(champion: Champion, target: String) -> String:
	if GameEnums.target_kind(target) == "stat":
		return "%d" % roundi(champion.developed_stat(GameEnums.target_id(target)))
	var rank := champion.skills.get_rank(target)
	return GameEnums.rank_name(rank) if rank > 0 else "Unlearned"


func _pick_trainer(trainer_id: String) -> void:
	_trainer_id = trainer_id
	_target = ""
	rebuild()


func _pick_target(target: String) -> void:
	_target = target
	rebuild()


func _train() -> void:
	var result := TrainingSystem.train(Content.trainer(_trainer_id), Game.champion(), _target, Game.profile)
	if not result["ok"]:
		toast(result["reason"], UiTheme.BAD)
		return
	Sfx.play("growth" if not result["ranks"].is_empty() else "ui_confirm")
	_last_result = result["text"]
	Game.set_flag("trained_once")
	Game.save()
	rebuild()
