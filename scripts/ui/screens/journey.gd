extends Control
## Journey (battle selection): choose a region, see the fights it offers and
## pick the one you want. Every fight says who you would face, why it
## matters, where it happens and what it costs — never a win chance.
## Params: {"region": id} selects a region on arrival.

const REGION_COLUMN_WIDTH := 300.0

var selected_region := ""
var _regions: VBoxContainer
var _fights: VBoxContainer
var _region_title: Label
var _region_text: Label


func _ready() -> void:
	if not Game.is_active():
		Router.go("title")
		return
	theme = UiTheme.get_theme()
	Router.back_requested.connect(_back)
	Game.changed.connect(_refresh)
	var background := ColorRect.new()
	background.color = UiTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var safe := UiKit.safe_area(18)
	add_child(safe)
	var column := UiKit.vbox(14)
	safe.add_child(column)
	column.add_child(_header())
	var row := UiKit.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var left := UiKit.panel("SheetPanel")
	left.custom_minimum_size.x = REGION_COLUMN_WIDTH
	row.add_child(left)
	var left_column := UiKit.vbox(10)
	left.add_child(left_column)
	left_column.add_child(UiKit.label("REGIONS", "DimLabel"))
	_regions = UiKit.vbox(8)
	left_column.add_child(UiKit.scroll(_regions))
	_build_recent(left_column)
	var right := UiKit.panel("SheetPanel")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var right_column := UiKit.vbox(10)
	right.add_child(right_column)
	_region_title = UiKit.heading("")
	right_column.add_child(_region_title)
	_region_text = UiKit.label("", "DimLabel", true)
	right_column.add_child(_region_text)
	_fights = UiKit.vbox(12)
	right_column.add_child(UiKit.scroll(_fights))
	selected_region = _initial_region(Router.params.get("region", ""))
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_back()


func _back() -> void:
	Router.go("lodge")


## The champion's latest saved battles, ready to watch again.
func _build_recent(parent: VBoxContainer) -> void:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in Game.champion().history:
		if BattleRecord.has_replay(entry):
			entries.append(entry)
	if entries.is_empty():
		return
	parent.add_child(UiKit.label("RECENT BATTLES", "DimLabel"))
	var list := UiKit.vbox(6)
	list.name = "RecentBattles"
	parent.add_child(list)
	for entry in entries:
		var opponent := Content.opponent(str(entry.get("opponent", "")))
		var seconds := roundi(float(entry.get("duration", 0.0)))
		var text := "▶ %s vs %s · %d:%02d" % ["Won" if entry.get("won", false) else "Lost",
				opponent.display_name if opponent != null else "?", seconds / 60, seconds % 60]
		list.add_child(UiKit.button(text, watch_again.bind(entry)))


## Replays a saved battle (nothing is applied again).
func watch_again(entry: Dictionary) -> void:
	var session := BattleRecord.rewatch(entry)
	if session != null:
		Router.go("replay", {"session": session})


func _header() -> Control:
	var header := UiKit.hbox(12)
	var titles := UiKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UiKit.heading("Journey"))
	titles.add_child(UiKit.label("Choose who to fight. Your champion and its build come next.", "DimLabel", true))
	header.add_child(titles)
	if Game.is_flag_set("world_map_unlocked"):
		header.add_child(UiKit.button("World Map", func() -> void: Router.go("world_map"), "", 180))
	header.add_child(UiKit.button("Lodge", _back, "", 150))
	return header


## The requested region if it exists, else the first open one with a fight
## still to win, else the first open region.
static func _initial_region(requested: String) -> String:
	if Content.region(requested) != null:
		return requested
	var open := ChallengeBoard.regions().filter(func(region: RegionData) -> bool:
		return ChallengeBoard.is_region_open(region))
	for region: RegionData in open:
		if ChallengeBoard.open_count(region.id) > 0:
			return region.id
	return open[0].id if not open.is_empty() else "home_valley"


func select_region(region_id: String) -> void:
	selected_region = region_id
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	_build_regions()
	_build_fights()


func _build_regions() -> void:
	UiKit.clear(_regions)
	for region: RegionData in ChallengeBoard.regions():
		var open := ChallengeBoard.is_region_open(region)
		var note := ""
		if not open:
			note = "Chapter %d" % region.chapter
		elif ChallengeBoard.open_count(region.id) > 0:
			note = "%d to win" % ChallengeBoard.open_count(region.id)
		var text := region.display_name + ("\n" + note if not note.is_empty() else "")
		var button := UiKit.button(text, select_region.bind(region.id),
				"TabButtonSelected" if region.id == selected_region else "TabButton")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 76
		if not open:
			button.modulate = Color(1, 1, 1, 0.6)
		_regions.add_child(button)


func _build_fights() -> void:
	UiKit.clear(_fights)
	var region := Content.region(selected_region)
	_region_title.text = region.display_name
	_region_text.text = region.description
	if not ChallengeBoard.is_region_open(region):
		var locked := UiKit.label("The road there is not open yet. It opens in Chapter %d." % region.chapter, "", true)
		locked.add_theme_color_override("font_color", UiTheme.WARN)
		_fights.add_child(locked)
		if not region.features.is_empty():
			_fights.add_child(UiKit.label("• " + "\n• ".join(region.features), "DimLabel", true))
		return
	var fights := ChallengeBoard.fights(region.id)
	if fights.is_empty():
		_fights.add_child(UiKit.label("No one here is looking for a fight yet.", "DimLabel", true))
	for trial: TrialData in fights:
		_fights.add_child(_fight_card(trial))


func _fight_card(trial: TrialData) -> Control:
	var status := ChallengeBoard.status(trial)
	var opponent := Content.opponent(trial.opponent_id)
	var arena := Content.arena(trial.arena_id)
	var panel := UiKit.panel("CardPanel")
	panel.name = "Fight_" + trial.id
	var column := UiKit.vbox(6)
	panel.add_child(column)
	var top := UiKit.hbox(8)
	var kind := UiKit.label(trial.challenge_type_name().to_upper(), "DimLabel")
	kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(kind)
	var badge := UiKit.label(_status_text(status), "DimLabel")
	badge.add_theme_color_override("font_color", _status_color(status))
	top.add_child(badge)
	column.add_child(top)
	var name_label := UiKit.label(trial.display_name)
	name_label.add_theme_font_size_override("font_size", UiTheme.fs(24))
	name_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(name_label)
	column.add_child(UiKit.label("vs %s — %s" % [opponent.display_name, opponent.title], "", true))
	column.add_child(UiKit.label(trial.reason if not trial.reason.is_empty() else trial.description, "", true))
	var first_bonus := "" if Game.is_flag_set(trial.cleared_flag()) else " (+%d first victory)" % trial.first_clear_coins
	var action := UiKit.hbox(12)
	var details := UiKit.label("%s · Energy %d · Reward ◉ %d%s" % [arena.display_name, trial.energy_cost,
			trial.coins, first_bonus], "DimLabel", true)
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.add_child(details)
	match status:
		ChallengeBoard.Status.LOCKED:
			column.add_child(action)
			var needs := UiKit.label("Requires: " + ", ".join(ChallengeBoard.requirements(trial)), "", true)
			needs.add_theme_color_override("font_color", UiTheme.WARN)
			column.add_child(needs)
			return panel
		ChallengeBoard.Status.COMPLETED:
			pass
		_:
			var select := UiKit.primary_button("Fight again" if status == ChallengeBoard.Status.CLEARED
					else "Select Fight", select_fight.bind(trial.id), 220)
			select.name = "Select"
			action.add_child(select)
	column.add_child(action)
	return panel


func select_fight(trial_id: String) -> void:
	var trial := Content.trial(trial_id)
	if trial == null or not ChallengeBoard.can_select(trial):
		return
	Router.go("fight_preview", {"trial": trial_id})


static func _status_text(status: ChallengeBoard.Status) -> String:
	match status:
		ChallengeBoard.Status.AVAILABLE:
			return "NEW"
		ChallengeBoard.Status.CLEARED:
			return "✓ CLEARED"
		ChallengeBoard.Status.COMPLETED:
			return "✓ COMPLETED"
	return "LOCKED"


static func _status_color(status: ChallengeBoard.Status) -> Color:
	match status:
		ChallengeBoard.Status.AVAILABLE:
			return UiTheme.ACCENT
		ChallengeBoard.Status.CLEARED, ChallengeBoard.Status.COMPLETED:
			return UiTheme.GOOD
	return UiTheme.WARN
