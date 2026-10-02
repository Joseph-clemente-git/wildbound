class_name BattleHud
extends Control
## Minimal combat HUD (mechanics §68, story §35): both fighters' health and
## stamina, exhaustion, the attuned Aether Art, hints and pause. The arena
## stays the visual priority; controls live at the bottom corners.

signal pause_requested

var joystick: TouchJoystick
var pad: ActionPad
var _player: Combatant
var _opponent: Combatant
var _player_bars: Dictionary = {}
var _opponent_bars: Dictionary = {}
var _hint_panel: PanelContainer
var _hint_label: Label
var _hint_tween: Tween
var _banner: Label
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	joystick = TouchJoystick.new()
	joystick.anchor_right = 0.45
	joystick.anchor_bottom = 1.0
	joystick.anchor_top = 0.3
	add_child(joystick)
	pad = ActionPad.new()
	add_child(pad)
	_apply_opacity()
	Settings.changed.connect(func(key: String, _v: Variant) -> void:
		if key == "hud_opacity":
			_apply_opacity())
	var safe := UiKit.safe_area(14)
	add_child(safe)
	var column := UiKit.vbox(8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	var top := UiKit.hbox(16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	top.add_child(_fighter_block(_player_bars, false))
	var pause := UiKit.button("II", func() -> void: pause_requested.emit(), "", 64)
	pause.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(pause)
	top.add_child(_fighter_block(_opponent_bars, true))
	_status = UiKit.label("")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UiTheme.WARN)
	column.add_child(_status)
	_hint_panel = UiKit.panel("CardPanel")
	_hint_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.86), 14, UiTheme.ACCENT, 2, 12))
	_hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hint_panel.custom_minimum_size.x = 560
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label = UiKit.label("", "", true)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint_label)
	_hint_panel.modulate.a = 0.0
	column.add_child(_hint_panel)
	_banner = UiKit.label("", "TitleLabel")
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", UiTheme.fs(64))
	_banner.modulate.a = 0.0
	add_child(_banner)


func _fighter_block(bars: Dictionary, mirrored: bool) -> Control:
	var block := UiKit.vbox(4)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UiKit.label("")
	name_label.add_theme_constant_override("outline_size", 6)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	block.add_child(name_label)
	var fill := ProgressBar.FILL_END_TO_BEGIN if mirrored else ProgressBar.FILL_BEGIN_TO_END
	# Health with a trailing "damage" bar so every hit reads instantly.
	var health_stack := Control.new()
	health_stack.custom_minimum_size.y = 20
	health_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trail := UiKit.bar(1, 1, Color(1.0, 0.92, 0.75, 0.85), 20)
	trail.fill_mode = fill
	trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_stack.add_child(trail)
	var health := UiKit.bar(1, 1, UiTheme.HEALTH, 20)
	health.fill_mode = fill
	health.add_theme_stylebox_override("background", UiTheme.box(Color(0, 0, 0, 0), 8, Color.TRANSPARENT, 0, 0))
	health.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_stack.add_child(health)
	var health_text := _bar_label("HP", mirrored)
	health_stack.add_child(health_text)
	block.add_child(health_stack)
	var stamina_stack := Control.new()
	stamina_stack.custom_minimum_size.y = 14
	stamina_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamina_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stamina := UiKit.bar(1, 1, UiTheme.STAMINA, 14)
	stamina.fill_mode = fill
	stamina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stamina_stack.add_child(stamina)
	var stamina_text := _bar_label("STA", mirrored)
	stamina_text.add_theme_font_size_override("font_size", UiTheme.fs(12))
	stamina_stack.add_child(stamina_text)
	block.add_child(stamina_stack)
	bars["name"] = name_label
	bars["health"] = health
	bars["trail"] = trail
	bars["health_text"] = health_text
	bars["stamina"] = stamina
	bars["stamina_text"] = stamina_text
	return block


## Bars carry text labels so state never relies on colour alone.
func _bar_label(prefix: String, mirrored: bool) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 8
	label.offset_right = -8
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", UiTheme.fs(14))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.set_meta("prefix", prefix)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func bind(player: Combatant, opponent: Combatant, subtitle: String) -> void:
	_player = player
	_opponent = opponent
	_player_bars["name"].text = player.display_name
	_opponent_bars["name"].text = "%s — %s" % [opponent.display_name, subtitle]
	if player.ability != null:
		pad.set_magic(player.ability.display_name, MagicVisuals.school_color(player.ability.school), true)
	else:
		pad.set_magic("", UiTheme.AETHER, false)


func _process(_delta: float) -> void:
	if _player == null:
		return
	_update_bars(_player_bars, _player)
	_update_bars(_opponent_bars, _opponent)
	if _player.ability != null:
		pad.set_cooldown(_player.cooldown / maxf(_player.ability.cooldown, 0.01))
	if _player.is_exhausted():
		_status.text = "Exhausted — back off and breathe!"
	elif _player.stamina_ratio() < 0.2:
		_status.text = "Low stamina"
	else:
		_status.text = ""


func _update_bars(bars: Dictionary, fighter: Combatant) -> void:
	var health: ProgressBar = bars["health"]
	var trail: ProgressBar = bars["trail"]
	health.max_value = fighter.stats.max_health
	trail.max_value = fighter.stats.max_health
	health.value = fighter.health
	# The trail lingers, then drains toward the real value.
	trail.value = maxf(fighter.health, move_toward(trail.value, fighter.health, fighter.stats.max_health * 0.006))
	(bars["health_text"] as Label).text = "HP %d" % ceili(fighter.health)
	var stamina: ProgressBar = bars["stamina"]
	stamina.max_value = fighter.stats.max_stamina
	stamina.value = fighter.stamina
	var low := fighter.stamina_ratio() < 0.25 or fighter.is_exhausted()
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 90.0) if low and not Settings.get_value("reduce_motion") else 1.0
	stamina.modulate = Color(1, 0.6, 0.6, pulse) if fighter.is_exhausted() else Color(1, 1, 1, pulse)
	(bars["stamina_text"] as Label).text = "EXHAUSTED" if fighter.is_exhausted() else "STA %d" % roundi(fighter.stamina)


func show_hint(text: String, seconds: float = 5.0) -> void:
	_hint_label.text = text
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_panel, "modulate:a", 1.0, 0.25)
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, 0.5)


func show_banner(text: String, color: Color = UiTheme.TEXT, seconds: float = 1.2) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tween.tween_interval(seconds)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.3)


func _apply_opacity() -> void:
	var alpha: float = Settings.get_value("hud_opacity")
	joystick.modulate.a = alpha
	pad.modulate.a = alpha


func set_controls_visible(on: bool) -> void:
	joystick.visible = on
	pad.visible = on
