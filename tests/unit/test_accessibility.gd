extends TestCase
## Accessibility settings change the live theme and combat assists.


const KEYS := ["text_scale", "colorblind", "high_contrast", "combat_assist"]


## Start from defaults regardless of the player's saved settings.
func before_each() -> void:
	_restore(KEYS)


func _restore(keys: Array) -> void:
	for key: String in keys:
		Settings.set_value(key, Settings.DEFAULTS[key])


func test_text_scale_rebuilds_theme_in_place() -> void:
	var theme := UiTheme.get_theme()
	var base := theme.default_font_size
	Settings.set_value("text_scale", 1.5)
	check(theme.default_font_size >= roundi(base * 1.4), "fonts scale: %d -> %d" % [base, theme.default_font_size])
	check(UiTheme.get_theme() == theme, "same theme object, so open screens update")
	_restore(["text_scale"])
	check_eq(theme.default_font_size, base)


func test_colorblind_palettes_swap_semantic_colours() -> void:
	var good := UiTheme.GOOD
	for mode: String in ["deuteranopia", "protanopia", "tritanopia"]:
		Settings.set_value("colorblind", mode)
		check(UiTheme.GOOD != good, mode + " changes GOOD")
		check(UiTheme.GOOD.to_html() != UiTheme.BAD.to_html())
	Settings.set_value("high_contrast", true)
	check_eq(UiTheme.TEXT, Color("ffffff"))
	_restore(["colorblind", "high_contrast"])
	check_eq(UiTheme.GOOD, good)


func test_combat_assist_widens_windows_and_telegraphs() -> void:
	Game.autosave = false
	Game.new_journey("Bruno")
	var normal := Combatant.new()
	normal.setup_from_champion(Game.champion())
	var normal_foe := Combatant.new()
	normal_foe.setup_from_opponent(Content.opponent("rook"))
	Settings.set_value("combat_assist", true)
	var assisted := Combatant.new()
	assisted.setup_from_champion(Game.champion())
	var assisted_foe := Combatant.new()
	assisted_foe.setup_from_opponent(Content.opponent("rook"))
	check(assisted.stats.perfect_window > normal.stats.perfect_window)
	check(assisted_foe.telegraph > normal_foe.telegraph)
	_restore(["combat_assist"])
	for node in [normal, normal_foe, assisted, assisted_foe]:
		node.free()


func test_settings_dialog_tabs_build() -> void:
	var host := Control.new()
	root.add_child(host)
	for tab: String in ["audio", "display", "controls", "access"]:
		SettingsPanel.open(host, true, tab)
	SettingsPanel.comfort_setup(host, func() -> void: pass)
	check(host.get_child_count() >= 5)
	host.free()
