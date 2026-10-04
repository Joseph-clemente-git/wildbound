extends LodgePanel
## Skill Network: the Skill Matrix drawn as a network of what leads to what
## (SkillNetwork). The graph fills the sheet; the side card explains the
## selected skill or technique — rank, what it needs, what it opens and which
## mentors teach it — and leads straight to training or learning it.
## Options: {"select": node id}.

const DETAIL_WIDTH := 380.0
const S := SkillNetwork.State

var network: SkillNetwork
var view: SkillNetworkView
var _selected := ""
var _camera: Dictionary = {}
var _detail: VBoxContainer


func _init() -> void:
	sheet_width = 1.0
	scrolling = false


func _ready() -> void:
	_selected = str(options.get("select", ""))
	super._ready()
	# Full width covers the lodge HUD, so the sheet is opaque.
	var style := sheet.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style != null:
		style.bg_color.a = 1.0
		sheet.add_theme_stylebox_override("panel", style)


func rebuild() -> void:
	if view != null and is_instance_valid(view) and view.is_inside_tree():
		_camera = view.camera()
	super.rebuild()


func build(container: VBoxContainer) -> void:
	var champion := Game.champion()
	set_title(champion.name)
	set_tabs(preload("res://scripts/ui/panels/champion_panel.gd").TABS, "network", _select_tab)
	Game.set_flag("viewed_skill_matrix")
	network = SkillNetwork.build(champion, Game.profile)
	if not network.nodes.has(_selected):
		_selected = network.suggested()

	var toolbar := UiKit.hbox(10)
	for entry: Array in [["Learned", UiTheme.ACCENT], ["Mastered", UiTheme.GOOD], ["Ready", UiTheme.AETHER],
			["Needs a mentor", UiTheme.ACCENT_DARK], ["Locked", Color(UiTheme.TEXT_DIM, 0.5)]]:
		toolbar.add_child(_legend_chip(entry[0], entry[1]))
	toolbar.add_child(_legend_line("Requirement met", UiTheme.ACCENT))
	toolbar.add_child(_legend_line("Not met yet", UiTheme.TEXT_DIM))
	toolbar.add_child(UiKit.spacer(false))
	for entry: Array in [["−", "ZoomOut"], ["+", "ZoomIn"], ["Fit", "Fit"]]:
		var button := UiKit.button(entry[0], _camera_action.bind(entry[1]), "", 64)
		button.name = entry[1]
		toolbar.add_child(button)
	container.add_child(toolbar)

	var split := UiKit.hbox(12)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(split)
	var frame := UiKit.panel("CardPanel")
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.BG, 0.92), 14, UiTheme.BORDER, 1, 0))
	split.add_child(frame)
	view = SkillNetworkView.new()
	view.name = "Network"
	view.selected = _selected
	view.network = network
	view.node_selected.connect(_on_selected)
	frame.add_child(view)
	if not _camera.is_empty():
		view.restore_camera(_camera)

	var side := UiKit.panel("CardPanel")
	side.name = "Details"
	side.custom_minimum_size.x = DETAIL_WIDTH
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(side)
	_detail = UiKit.vbox(10)
	side.add_child(UiKit.scroll(_detail))
	_show_details()


func _select_tab(tab: String) -> void:
	if tab != "network":
		host.switch_to("champion", {"tab": tab})


func _camera_action(action: String) -> void:
	match action:
		"ZoomIn":
			view.zoom_by(1.2)
		"ZoomOut":
			view.zoom_by(1.0 / 1.2)
		_:
			view.fit()


func _legend_chip(text: String, color: Color) -> Control:
	var row := UiKit.hbox(6)
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(18, 18)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, 5, color, 3, 0))
	row.add_child(swatch)
	row.add_child(UiKit.label(text, "DimLabel"))
	return row


## A link sample for the legend: amber when the requirement is met.
func _legend_line(text: String, color: Color) -> Control:
	var row := UiKit.hbox(6)
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(22, 4)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	row.add_child(UiKit.label(text, "DimLabel"))
	return row


func _on_selected(id: String) -> void:
	_selected = id
	# Deferred: the button that asked for this may be one of the rows being replaced.
	_show_details.call_deferred()


## Selects a node from the side card and brings it into view.
func select(id: String) -> void:
	view.select(id, true)


# --- Side card ---------------------------------------------------------------------

func _show_details() -> void:
	UiKit.clear(_detail)
	var entry := network.node(_selected)
	if entry.is_empty():
		return
	var champion := Game.champion()
	var name_label := UiKit.label(entry["name"])
	name_label.add_theme_font_size_override("font_size", UiTheme.fs(28))
	name_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	_detail.add_child(name_label)
	_detail.add_child(UiKit.label("%s · %s" % [SkillNetwork.GROUP_NAMES[entry["group"]],
			SkillNetworkView.NetworkNode.status_text(entry)], "DimLabel", true))
	if not str(entry["description"]).is_empty():
		_detail.add_child(UiKit.label(entry["description"], "", true))

	if entry["kind"] in ["skill", "weapon", "magic"]:
		var rank: int = entry["rank"]
		if rank > 0 and entry["state"] != S.MASTERED:
			_detail.add_child(UiKit.stat_row("Rank", "%s · %d%% to %s" % [GameEnums.rank_name(rank),
					roundi(float(entry["progress"]) * 100.0), GameEnums.rank_name(rank + 1)],
					float(entry["progress"]), UiTheme.ACCENT))
		elif rank > 0:
			_detail.add_child(UiKit.stat_row("Rank", "%s — the highest %s can reach" % [GameEnums.rank_name(rank), champion.name]))
		if int(entry["cap"]) < GameEnums.Rank.MASTER:
			_detail.add_child(UiKit.label("Potential: up to %s." % GameEnums.rank_name(entry["cap"]), "DimLabel", true))
		var track := SkillCatalog.conversion_track(entry["id"])
		if not track.is_empty() and champion.experience.get_xp(track) > 0.5:
			_detail.add_child(UiKit.stat_row("Banked experience", "%d %s" % [roundi(champion.experience.get_xp(track)),
					ExperienceTracks.track_name(track)]))

	_add_links("Needs", entry["needs"].map(func(need: Dictionary) -> Array:
		return [need["id"], "%s %s %s" % ["✓" if need["met"] else "✗", network.node(need["id"])["name"],
				GameEnums.rank_name(need["need"])]]))
	_add_links("Opens", entry["opens"].map(func(id: String) -> Array:
		return [id, "→ %s" % network.node(id)["name"]]))
	_add_mentors(entry)
	_add_action(entry)
	if network.has_hidden:
		_detail.add_child(HSeparator.new())
		_detail.add_child(UiKit.label("More of the network reveals itself as %s's training goes on." % champion.name, "DimLabel", true))


func _section(text: String) -> void:
	var heading := UiKit.label(text)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	_detail.add_child(heading)


## Rows that jump to another node: [[id, text], ...].
func _add_links(heading: String, links: Array) -> void:
	if links.is_empty():
		return
	_section(heading)
	for link: Array in links:
		var button := UiKit.button(link[1], select.bind(link[0]), "FlatButton")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 52
		_detail.add_child(button)


func _add_mentors(entry: Dictionary) -> void:
	_section("Mentors")
	var teachers: Array = entry["teachers"]
	var active: Array = entry["active_teachers"]
	if teachers.is_empty():
		_detail.add_child(UiKit.label("No mentor in your lodge teaches this yet." if entry["kind"] != "technique"
				else "No mentor teaches this.", "DimLabel", true))
		return
	var owned := TrainerManager.owned(Game.profile)
	for trainer: TrainerData in teachers:
		var note := "active" if active.has(trainer) else ("in your lodge, not active" if owned.has(trainer) else
				"%s, not in your lodge" % GameEnums.rarity_name(trainer.rarity))
		_detail.add_child(UiKit.label("%s, %s — %s" % [trainer.display_name, trainer.title, note],
				"" if active.has(trainer) else "DimLabel", true))


func _add_action(entry: Dictionary) -> void:
	var state: int = entry["state"]
	if entry["kind"] == "technique":
		var technique: TechniqueData = entry["technique"]
		if state == S.LEARNED:
			_detail.add_child(UiKit.label("Known. It triggers by itself in battle when its moment comes.", "DimLabel", true))
			return
		if state == S.LOCKED:
			_detail.add_child(UiKit.label("Reach every rank it needs first.", "DimLabel", true))
			return
		var learn := UiKit.primary_button("Learn (%d coins)" % technique.coin_cost, _learn.bind(technique))
		learn.name = "Act"
		var blocker := TechniqueSystem.learn_blocker(Game.champion(), technique, Game.profile)
		learn.disabled = not blocker.is_empty()
		_detail.add_child(learn)
		if not blocker.is_empty():
			_detail.add_child(UiKit.label(blocker, "DimLabel", true))
		return
	if state == S.MASTERED:
		return
	if state == S.LOCKED:
		_detail.add_child(UiKit.label("Train what it needs first.", "DimLabel", true))
		return
	var active: Array = entry["active_teachers"]
	if active.is_empty():
		var find := UiKit.button("Find a mentor", host.switch_to.bind("trainers"))
		find.name = "Act"
		_detail.add_child(find)
		return
	var trainer: TrainerData = active[0]
	var train := UiKit.primary_button("Train with %s" % trainer.display_name,
			host.switch_to.bind("training", {"trainer": trainer.id, "target": entry["id"]}))
	train.name = "Act"
	_detail.add_child(train)


func _learn(technique: TechniqueData) -> void:
	var champion := Game.champion()
	var error := TechniqueSystem.learn(champion, technique, Game.profile)
	if error.is_empty():
		Sfx.play("growth")
		toast("%s learned %s!" % [champion.name, technique.display_name], UiTheme.GOOD)
		Game.save()
	else:
		toast(error, UiTheme.BAD)
