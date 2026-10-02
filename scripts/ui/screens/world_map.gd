extends Control
## World Map (story §23): Maren's parchment map of the Home Valley and the
## regions beyond. Regions open with story progress; locked regions show
## what their chapter will introduce.

const PATHS := [
	["home_valley", "greenwood"], ["home_valley", "stonepass"], ["greenwood", "high_cliffs"],
	["stonepass", "lakeward"], ["lakeward", "ancient_wilds"], ["high_cliffs", "ancient_wilds"],
]
const PARCHMENT := Color("e9dcbc")
const INK := Color("5a4630")

var _map: Control
var _info: VBoxContainer
var _selected := "home_valley"
var _nodes: Dictionary = {}


func _ready() -> void:
	if not Game.is_active() or not Game.is_flag_set("world_map_unlocked"):
		Router.go("lodge" if Game.is_active() else "title")
		return
	theme = UiTheme.get_theme()
	var background := ColorRect.new()
	background.color = UiTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var safe := UiKit.safe_area(18)
	add_child(safe)
	var row := UiKit.hbox(16)
	safe.add_child(row)
	_map = Control.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_stretch_ratio = 1.7
	_map.draw.connect(_draw_map)
	_map.resized.connect(_place_nodes)
	row.add_child(_map)
	var side := UiKit.panel("SheetPanel")
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	var column := UiKit.vbox(12)
	side.add_child(column)
	_info = UiKit.vbox(10)
	column.add_child(UiKit.scroll(_info))
	column.add_child(UiKit.primary_button("Return to the lodge", func() -> void: Router.go("lodge")))
	for region: RegionData in Content.list("regions"):
		var button := Button.new()
		button.text = region.display_name if _is_known(region) else "?"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 56)
		button.pressed.connect(_select.bind(region.id))
		_map.add_child(button)
		_nodes[region.id] = button
	_place_nodes.call_deferred()
	_select(_selected)


func _is_open(region: RegionData) -> bool:
	return Game.is_flag_set(region.unlock_flag)


## Regions appear by name once the Keeper has heard of them.
func _is_known(region: RegionData) -> bool:
	return _is_open(region) or region.chapter <= 2 or Game.is_flag_set("chapter_one_complete")


func _place_nodes() -> void:
	for region: RegionData in Content.list("regions"):
		var button: Button = _nodes[region.id]
		var open := _is_open(region)
		button.add_theme_stylebox_override("normal", UiTheme.box(region.color.darkened(0.1) if open else Color(INK, 0.55), 28,
				UiTheme.ACCENT if region.id == _selected else PARCHMENT, 3, 14))
		button.add_theme_stylebox_override("hover", UiTheme.box(region.color, 28, UiTheme.ACCENT, 3, 14))
		button.add_theme_stylebox_override("pressed", UiTheme.box(region.color.darkened(0.3), 28, UiTheme.ACCENT, 3, 14))
		button.add_theme_color_override("font_color", PARCHMENT if not open else Color.WHITE)
		button.reset_size()
		button.position = region.map_position * _map.size - button.size * 0.5
	_map.queue_redraw()


func _draw_map() -> void:
	var size := _map.size
	_map.draw_rect(Rect2(Vector2.ZERO, size), PARCHMENT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Mountains along the northern ridge, forest dots in the west, a lake in the east.
	for i in 14:
		var base := Vector2(size.x * (0.45 + i * 0.04), size.y * (0.18 + 0.06 * sin(i)))
		var h := size.y * rng.randf_range(0.05, 0.09)
		_map.draw_colored_polygon(PackedVector2Array([base + Vector2(-h * 0.7, 0), base + Vector2(0, -h),
				base + Vector2(h * 0.7, 0)]), Color(INK, 0.25))
	for i in 40:
		var spot := Vector2(size.x * rng.randf_range(0.3, 0.55), size.y * rng.randf_range(0.25, 0.5))
		_map.draw_circle(spot, size.y * 0.012, Color("4f6b3a", 0.35))
	_map.draw_circle(Vector2(size.x * 0.74, size.y * 0.55), size.y * 0.09, Color("6f9ac0", 0.45))
	# Paths between regions.
	for path: Array in PATHS:
		var a := Content.region(path[0])
		var b := Content.region(path[1])
		var from := a.map_position * size
		var to := b.map_position * size
		var open := _is_open(a) and _is_open(b)
		_map.draw_dashed_line(from, to, Color(INK, 0.7 if open else 0.35), 4.0, 14.0)
	_map.draw_rect(Rect2(Vector2.ZERO, size), INK, false, 4.0)
	_map.draw_string(UiTheme.heading_font(), Vector2(18, size.y - 22), "The Known Lands", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 28, Color(INK, 0.8))


func _select(region_id: String) -> void:
	_selected = region_id
	Sfx.play("ui_click")
	_place_nodes()
	UiKit.clear(_info)
	var region := Content.region(region_id)
	if not _is_known(region):
		_info.add_child(UiKit.heading("Unknown lands"))
		_info.add_child(UiKit.label("Beyond the known borders. Rumours speak of failing Aether.", "DimLabel", true))
		return
	_info.add_child(UiKit.heading(region.display_name))
	_info.add_child(UiKit.label("Chapter %d · %s" % [region.chapter, region.difficulty], "DimLabel"))
	_info.add_child(UiKit.label(region.description, "", true))
	var features := UiKit.label("• " + "\n• ".join(region.features), "DimLabel", true)
	_info.add_child(features)
	if not _is_open(region):
		var locked := UiKit.label("The road is not open yet. %s" % ("It opens in Chapter %d." % region.chapter), "", true)
		locked.add_theme_color_override("font_color", UiTheme.WARN)
		_info.add_child(locked)
		return
	var trials := Content.list("trials").filter(func(t: TrialData) -> bool: return t.region_id == region.id)
	_info.add_child(UiKit.label("Trials", "HeadingLabel"))
	for trial: TrialData in trials:
		var cleared := Game.is_flag_set(trial.cleared_flag())
		var row := UiKit.hbox(10)
		var name_label := UiKit.label("%s%s" % [trial.display_name, " ✓" if cleared else ""], "", true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var prepare := UiKit.button("Prepare", func() -> void: Router.go("battle_prep", {"trial": trial.id}))
		prepare.disabled = not TrialSystem.is_unlocked(trial)
		row.add_child(prepare)
		_info.add_child(row)
