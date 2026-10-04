extends LodgePanel
## Skill Network: the champion's Skill Matrix as the Aether Weave
## (SkillNetworkView), full screen. Around the weave:
##
## - the champion card (top left): a live portrait, how much of the weave is
##   lit, energy and bond;
## - the inscription (top): the selected stone's name, family, state and what
##   it does;
## - the stone card (right): rank, what it needs, what it opens, the mentors
##   who teach it and the step to take — train it, learn it or find a mentor;
## - the legend and the camera controls (bottom).
##
## Options: {"select": node id}.

const S := SkillNetwork.State
const CARD_WIDTH := 372.0
const LEFT_WIDTH := 372.0
const EDGE := 16.0

var network: SkillNetwork
var view: SkillNetworkView
var _selected := ""
var _camera: Dictionary = {}
var _detail: VBoxContainer
var _action: VBoxContainer
var _banner_name: Label
var _banner_kind: Label
var _banner_text: Label
var _portrait: SubViewport


func _init() -> void:
	immersive = true
	scrolling = false


func _ready() -> void:
	_selected = str(options.get("select", ""))
	super._ready()


func rebuild() -> void:
	if view != null and is_instance_valid(view) and view.is_inside_tree():
		_camera = view.camera()
	super.rebuild()


func build(container: VBoxContainer) -> void:
	var champion := Game.champion()
	Game.set_flag("viewed_skill_matrix")
	network = SkillNetwork.build(champion, Game.profile)
	if not network.nodes.has(_selected):
		_selected = network.suggested()
	var insets := UiKit.safe_insets()

	var stage := Control.new()
	stage.name = "Stage"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(stage)

	view = SkillNetworkView.new()
	view.name = "Network"
	view.selected = _selected
	view.network = network
	view.title = champion.name
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.node_selected.connect(_on_selected)
	stage.add_child(view)
	if not _camera.is_empty():
		view.restore_camera(_camera)
	stage.resized.connect(_fit_free_area.bind(stage, insets))

	_build_champion_card(stage, champion, insets)
	_build_banner(stage, insets)
	_build_top_buttons(stage, insets)
	_build_stone_card(stage, insets)
	_build_footer(stage, insets)
	_show_details()


## The weave frames content in the space the overlays leave open.
func _fit_free_area(stage: Control, insets: Vector4) -> void:
	var left := EDGE + insets.x
	var top := 130.0 + insets.y
	var right := stage.size.x - CARD_WIDTH - EDGE * 2.0 - insets.z
	var bottom := stage.size.y - 96.0 - insets.w
	view.free_rect = Rect2(left, top, maxf(right - left, 200.0), maxf(bottom - top, 160.0))


# --- Overlays ----------------------------------------------------------------------

static func weave_box(alpha: float = 0.9, radius: int = 16) -> StyleBoxFlat:
	var style := UiTheme.box(Color(SkillOrb.SOCKET, alpha), radius, UiTheme.BORDER, 2, 16)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	return style


## A framed panel with small bronze diamonds set into its corners.
static func weave_panel(alpha: float = 0.9) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", weave_box(alpha))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.draw.connect(func() -> void:
		for corner in [Vector2(10, 10), Vector2(panel.size.x - 10, 10), Vector2(10, panel.size.y - 10),
				Vector2(panel.size.x - 10, panel.size.y - 10)]:
			SkillOrb._diamond(panel, corner, 4.5, UiTheme.ACCENT))
	return panel


func _place(control: Control, anchors: Array, offsets: Array) -> void:
	control.anchor_left = anchors[0]
	control.anchor_top = anchors[1]
	control.anchor_right = anchors[2]
	control.anchor_bottom = anchors[3]
	control.offset_left = offsets[0]
	control.offset_top = offsets[1]
	control.offset_right = offsets[2]
	control.offset_bottom = offsets[3]


func _build_champion_card(stage: Control, champion: Champion, insets: Vector4) -> void:
	var card := weave_panel()
	card.name = "ChampionCard"
	_place(card, [0, 0, 0, 0], [EDGE + insets.x, EDGE + insets.y, EDGE + insets.x + LEFT_WIDTH, EDGE + insets.y + 112])
	stage.add_child(card)
	var row := UiKit.hbox(14)
	card.add_child(row)
	row.add_child(_build_portrait(champion))
	var column := UiKit.vbox(2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var name_label := UiKit.label(champion.name, "HeadingLabel")
	name_label.add_theme_font_size_override("font_size", UiTheme.fs(28))
	column.add_child(name_label)
	column.add_child(UiKit.label("%s · %s" % [champion.data().display_name, champion.capability_name()], "DimLabel"))
	var lit := network.count_in(S.LEARNED) + network.count_in(S.MASTERED)
	var stones := UiKit.label("✦ %d of %d stones lit · %d ready" % [lit, network.order.size(), network.count_in(S.READY)])
	stones.name = "StonesLit"
	stones.add_theme_font_size_override("font_size", UiTheme.fs(18))
	stones.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(stones)
	var bars := UiKit.hbox(8)
	for entry: Array in [[champion.energy / champion.max_energy(), UiTheme.ENERGY],
			[champion.happiness / champion.max_happiness(), UiTheme.HAPPINESS]]:
		var bar := UiKit.bar(entry[0], 1.0, entry[1], 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bars.add_child(bar)
	column.add_child(bars)


## The champion, alive in a round window: its own body in its own gear.
func _build_portrait(champion: Champion) -> Control:
	var frame := Panel.new()
	frame.name = "Portrait"
	frame.custom_minimum_size = Vector2(84, 84)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color("223029"), 42, Color.TRANSPARENT, 0, 0))
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	_portrait = SubViewport.new()
	_portrait.own_world_3d = true
	_portrait.msaa_3d = Viewport.MSAA_2X
	holder.add_child(_portrait)
	var scene := Node3D.new()
	_portrait.add_child(scene)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("223029")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f1e2c4")
	environment.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 150, 0)
	key.light_energy = 1.2
	key.light_color = Color("ffe2b0")
	scene.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, -20, 0)
	rim.light_energy = 0.7
	rim.light_color = UiTheme.AETHER
	scene.add_child(rim)
	var figure := FightStage.champion_figure(champion)
	figure.rotation.y = PI * 0.85
	scene.add_child(figure)
	var camera := Camera3D.new()
	camera.fov = 26.0
	camera.transform = Transform3D(Basis(), Vector3(0, 1.48, 2.35)).looking_at(Vector3(0, 1.38, 0), Vector3.UP)
	scene.add_child(camera)
	var ring := Panel.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", UiTheme.box(Color.TRANSPARENT, 42, UiTheme.ACCENT, 3, 0))
	frame.add_child(ring)
	return frame


func _build_banner(stage: Control, insets: Vector4) -> void:
	var banner := weave_panel(0.88)
	banner.name = "Inscription"
	var left := EDGE * 2.0 + insets.x + LEFT_WIDTH
	_place(banner, [0, 0, 1, 0], [left, EDGE + insets.y, -(EDGE * 2.0 + insets.z + 236.0), EDGE + insets.y + 112])
	stage.add_child(banner)
	var column := UiKit.vbox(2)
	banner.add_child(column)
	var top := UiKit.hbox(12)
	column.add_child(top)
	_banner_name = UiKit.label("", "HeadingLabel")
	_banner_name.add_theme_font_size_override("font_size", UiTheme.fs(28))
	top.add_child(_banner_name)
	_banner_kind = UiKit.label("", "DimLabel")
	_banner_kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_banner_kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_banner_kind)
	_banner_text = UiKit.label("", "", true)
	_banner_text.add_theme_font_size_override("font_size", UiTheme.fs(19))
	_banner_text.max_lines_visible = 2
	_banner_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_banner_text)


func _build_top_buttons(stage: Control, insets: Vector4) -> void:
	var row := UiKit.hbox(10)
	_place(row, [1, 0, 1, 0], [-(EDGE + insets.z + 236.0), EDGE + insets.y, -(EDGE + insets.z), EDGE + insets.y + 64])
	row.alignment = BoxContainer.ALIGNMENT_END
	stage.add_child(row)
	var matrix := UiKit.button("☰ Matrix", _select_tab.bind("skills"), "", 150)
	matrix.name = "MatrixButton"
	matrix.tooltip_text = "The Skill Matrix as a list"
	row.add_child(matrix)
	var close := UiKit.button("✕", func() -> void: close_requested.emit(), "", 64)
	close.name = "Close"
	row.add_child(close)
	for button: Button in [matrix, close]:
		for state in ["normal", "hover", "pressed"]:
			var style := weave_box(0.92 if state == "normal" else 1.0, 14)
			if state != "normal":
				style.border_color = UiTheme.ACCENT
			button.add_theme_stylebox_override(state, style)


func _build_stone_card(stage: Control, insets: Vector4) -> void:
	var card := weave_panel()
	card.name = "Details"
	_place(card, [1, 0, 1, 1], [-(EDGE + insets.z + CARD_WIDTH), EDGE * 2.0 + insets.y + 112 + 16,
			-(EDGE + insets.z), -(EDGE + insets.w + 84)])
	stage.add_child(card)
	var column := UiKit.vbox(10)
	card.add_child(column)
	_detail = UiKit.vbox(10)
	column.add_child(UiKit.scroll(_detail))
	_action = UiKit.vbox(6)
	column.add_child(_action)


func _build_footer(stage: Control, insets: Vector4) -> void:
	var legend := weave_panel(0.85)
	legend.name = "Legend"
	_place(legend, [0, 1, 0, 1], [EDGE + insets.x, -(EDGE + insets.w + 68), EDGE + insets.x + 760, -(EDGE + insets.w)])
	stage.add_child(legend)
	var row := UiKit.hbox(14)
	legend.add_child(row)
	for state: int in [S.LOCKED, S.OPEN, S.READY, S.LEARNED, S.MASTERED]:
		var swatch := LegendStone.new()
		swatch.state = state
		swatch.custom_minimum_size = Vector2(34, 34)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(UiKit.label(SkillNetwork.STATE_NAMES[state], "DimLabel"))
	var zoom := UiKit.hbox(10)
	_place(zoom, [1, 1, 1, 1], [-(EDGE + insets.z + CARD_WIDTH), -(EDGE + insets.w + 64), -(EDGE + insets.z), -(EDGE + insets.w)])
	zoom.alignment = BoxContainer.ALIGNMENT_END
	stage.add_child(zoom)
	var hint := UiKit.label("Drag · Pinch · Tap", "DimLabel")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom.add_child(hint)
	for entry: Array in [["−", "ZoomOut"], ["+", "ZoomIn"], ["◎", "Fit"]]:
		var button := UiKit.button(entry[0], _camera_action.bind(entry[1]), "", 64)
		button.name = entry[1]
		button.tooltip_text = {"ZoomOut": "Zoom out", "ZoomIn": "Zoom in", "Fit": "Show the whole weave"}[entry[1]]
		button.add_theme_stylebox_override("normal", weave_box(0.92, 14))
		zoom.add_child(button)


## A tiny stone for the legend, drawn the same way as the weave's.
class LegendStone extends Control:
	var state := 0

	func _draw() -> void:
		var entry := {"id": "skill:attack", "group": SkillNetwork.GROUP_FUNDAMENTALS, "kind": "technique",
				"state": state, "rank": 0}
		var factor := size.y / 64.0
		draw_set_transform(size * 0.5, 0.0, Vector2(factor, factor))
		SkillOrb.draw(self, Vector2.ZERO, 22.0, entry)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Behaviour ---------------------------------------------------------------------

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


func _on_selected(id: String) -> void:
	_selected = id
	# Deferred: the button that asked for this may be one of the rows being replaced.
	_show_details.call_deferred()


## Selects a stone from the card and brings it into view.
func select(id: String) -> void:
	view.select(id, true)


func _show_details() -> void:
	UiKit.clear(_detail)
	UiKit.clear(_action)
	var entry := network.node(_selected)
	if entry.is_empty():
		return
	var champion := Game.champion()
	_banner_name.text = entry["name"]
	_banner_name.add_theme_color_override("font_color", SkillOrb.color_of(entry).lightened(0.15))
	_banner_kind.text = "%s · %s" % [SkillNetwork.GROUP_NAMES[entry["group"]],
			SkillNetworkView.NetworkNode.status_text(entry)]
	_banner_text.text = entry["description"]

	if entry["kind"] in ["skill", "weapon", "magic"]:
		var rank: int = entry["rank"]
		if rank > 0 and entry["state"] != S.MASTERED:
			_detail.add_child(UiKit.stat_row("Rank", "%s · %d%% to %s" % [GameEnums.rank_name(rank),
					roundi(float(entry["progress"]) * 100.0), GameEnums.rank_name(rank + 1)],
					float(entry["progress"]), UiTheme.ACCENT))
		elif rank > 0:
			_detail.add_child(UiKit.stat_row("Rank", "%s — the highest %s can reach" % [GameEnums.rank_name(rank), champion.name]))
		else:
			_detail.add_child(UiKit.stat_row("Rank", "Not yet learned"))
		if int(entry["cap"]) < GameEnums.Rank.MASTER:
			_detail.add_child(UiKit.label("Potential: up to %s." % GameEnums.rank_name(entry["cap"]), "DimLabel", true))
		var track := SkillCatalog.conversion_track(entry["id"])
		if not track.is_empty() and champion.experience.get_xp(track) > 0.5:
			_detail.add_child(UiKit.stat_row("Banked experience", "%d %s" % [roundi(champion.experience.get_xp(track)),
					ExperienceTracks.track_name(track)]))
	elif entry["kind"] == "stat":
		_detail.add_child(UiKit.stat_row("Rank", GameEnums.rank_name(entry["rank"])))

	_add_links("Needs", entry["needs"].map(func(need: Dictionary) -> Array:
		return [need["id"], "%s  %s · %s" % ["✓" if need["met"] else "✗", network.node(need["id"])["name"],
				GameEnums.rank_name(need["need"])], need["met"]]))
	_add_links("Opens", entry["opens"].map(func(id: String) -> Array:
		return [id, "→  %s" % network.node(id)["name"], SkillOrb.is_lit(network.node(id)["state"])]))
	_add_mentors(entry)
	_add_action(entry)
	if network.has_hidden:
		_detail.add_child(UiKit.label("More of the weave will be carved as %s's training goes on." % champion.name,
				"DimLabel", true))


func _section(text: String) -> void:
	var heading := UiKit.label(text.to_upper())
	heading.add_theme_font_size_override("font_size", UiTheme.fs(16))
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	_detail.add_child(heading)


## Rows that jump to another stone: [[id, text, done], ...].
func _add_links(heading: String, links: Array) -> void:
	if links.is_empty():
		return
	_section(heading)
	for link: Array in links:
		var button := UiKit.button(link[1], select.bind(link[0]), "FlatButton")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 50
		button.add_theme_color_override("font_color", UiTheme.TEXT if link[2] else UiTheme.TEXT_DIM)
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
			_action.add_child(UiKit.label("Known. It triggers by itself in battle when its moment comes.", "DimLabel", true))
			return
		if state == S.LOCKED:
			_action.add_child(UiKit.label("Light every stone it needs first.", "DimLabel", true))
			return
		var learn := UiKit.primary_button("Learn (%d coins)" % technique.coin_cost, _learn.bind(technique))
		learn.name = "Act"
		var blocker := TechniqueSystem.learn_blocker(Game.champion(), technique, Game.profile)
		learn.disabled = not blocker.is_empty()
		_action.add_child(learn)
		if not blocker.is_empty():
			_action.add_child(UiKit.label(blocker, "DimLabel", true))
		return
	if state == S.MASTERED:
		return
	if state == S.LOCKED:
		_action.add_child(UiKit.label("Light the stones it needs first.", "DimLabel", true))
		return
	var active: Array = entry["active_teachers"]
	if active.is_empty():
		var find := UiKit.button("Find a mentor", host.switch_to.bind("trainers"))
		find.name = "Act"
		_action.add_child(find)
		return
	var trainer: TrainerData = active[0]
	var train := UiKit.primary_button("Train with %s" % trainer.display_name,
			host.switch_to.bind("training", {"trainer": trainer.id, "target": entry["id"]}))
	train.name = "Act"
	_action.add_child(train)


func _learn(technique: TechniqueData) -> void:
	var champion := Game.champion()
	var error := TechniqueSystem.learn(champion, technique, Game.profile)
	if error.is_empty():
		Sfx.play("growth")
		toast("%s learned %s!" % [champion.name, technique.display_name], UiTheme.GOOD)
		Game.save()
	else:
		toast(error, UiTheme.BAD)
