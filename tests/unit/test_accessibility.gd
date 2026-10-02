extends TestCase
## Accessibility settings change the live theme and combat assists.


const KEYS := ["text_scale", "colorblind", "high_contrast", "replay_speed", "replay_commentary"]


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


func test_replay_follows_the_replay_settings() -> void:
	Game.autosave = false
	Game.new_journey("Bruno")
	Settings.set_value("replay_speed", 2.0)
	Settings.set_value("replay_commentary", false)
	var trial := Content.trial("first_steps")
	TrialSystem.enter(Game.champion(), trial)
	var session := BattleSession.start(trial, Game.champion(), 4)
	Router.params = {"session": session}
	var screen: Node = load(Router.ROUTES["replay"]).instantiate()
	root.add_child(screen)
	Router.params = {}
	check_eq(screen.speed, 2.0, "starts at the chosen speed")
	check(not screen._ticker.visible, "commentary off")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	screen._unhandled_input(tap)
	check(screen.paused, "a tap on the battle pauses")
	check(screen._paused_note.visible, "and says how to resume")
	screen._unhandled_input(tap)
	check(not screen.paused, "another tap resumes")
	var faster := InputEventAction.new()
	faster.action = "replay_faster"
	faster.pressed = true
	screen._unhandled_input(faster)
	check_eq(screen.speed, 4.0, "→ speeds up")
	var slower := InputEventAction.new()
	slower.action = "replay_slower"
	slower.pressed = true
	screen._unhandled_input(slower)
	screen._unhandled_input(slower)
	check_eq(screen.speed, 1.0, "← slows down, never below 1×")
	_restore(["replay_speed", "replay_commentary"])
	screen.free()


func test_settings_dialog_tabs_build() -> void:
	var host := Control.new()
	root.add_child(host)
	for tab: String in ["audio", "display", "controls", "access"]:
		SettingsPanel.open(host, true, tab)
	SettingsPanel.comfort_setup(host, func() -> void: pass)
	check(host.get_child_count() >= 5)
	host.free()
