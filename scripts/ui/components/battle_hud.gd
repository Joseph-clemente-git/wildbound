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
	var health := UiKit.bar(1, 1, UiTheme.HEALTH, 18)
	health.fill_mode = ProgressBar.FILL_END_TO_BEGIN if mirrored else ProgressBar.FILL_BEGIN_TO_END
	block.add_child(health)
	var stamina := UiKit.bar(1, 1, UiTheme.STAMINA, 10)
	stamina.fill_mode = health.fill_mode
	block.add_child(stamina)
	bars["name"] = name_label
	bars["health"] = health
	bars["stamina"] = stamina
	return block


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
	health.max_value = fighter.stats.max_health
	health.value = lerpf(health.value, fighter.health, 0.35)
	var stamina: ProgressBar = bars["stamina"]
	stamina.max_value = fighter.stats.max_stamina
	stamina.value = fighter.stamina
	stamina.modulate = Color(1, 0.6, 0.6) if fighter.is_exhausted() else Color.WHITE


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


func set_controls_visible(on: bool) -> void:
	joystick.visible = on
	pad.visible = on
