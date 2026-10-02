class_name SettingsPanel
extends RefCounted
## Settings dialog shared by the title screen and the in-game menus, organised
## in tabs. Accessibility is a first-class tab (ui-ux-game: "accessibility is
## not optional"), and its key options are also offered in the first-launch
## comfort setup.

const TABS := [["Audio", "audio"], ["Display", "display"], ["Controls", "controls"], ["Accessibility", "access"]]
const TEXT_SIZES := [["90%", 0.9], ["100%", 1.0], ["125%", 1.25], ["150%", 1.5]]
const COLORBLIND_LABELS := {"off": "Off", "deuteranopia": "Deuteranopia", "protanopia": "Protanopia", "tritanopia": "Tritanopia"}


static func open(parent: Node, allow_delete_save: bool = true, tab: String = "audio") -> void:
	var content := UiKit.modal(parent, "Settings", 820.0)
	content.get_parent().custom_minimum_size.y = 600
	var tabs := UiKit.hbox(8)
	content.add_child(tabs)
	var body := UiKit.vbox(14)
	content.add_child(UiKit.scroll(body))
	# Lambdas capture locals by value: share the callable through a dictionary.
	var holder := {}
	var show_tab := func(key: String) -> void:
		var self_call: Callable = holder["show"]
		UiKit.clear(tabs)
		for entry: Array in TABS:
			var button := UiKit.button(entry[0], self_call.bind(entry[1]),
					"TabButtonSelected" if entry[1] == key else "TabButton")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tabs.add_child(button)
		UiKit.clear(body)
		match key:
			"audio":
				body.add_child(_slider("Master volume", "master_volume"))
				body.add_child(_slider("Music & ambience", "music_volume"))
				body.add_child(_slider("Effects", "sfx_volume"))
				body.add_child(_toggle("Vibration", "vibration", "Short pulses when hitting or being hit."))
			"display":
				body.add_child(_slider("Camera shake", "shake_strength", 0.0, 1.0, "0 turns it off."))
				body.add_child(_slider("Battle controls opacity", "hud_opacity", 0.35, 1.0))
				body.add_child(_toggle("Show tutorial hints", "show_hints"))
			"controls":
				body.add_child(_slider("Control size", "controls_scale", 0.8, 1.3))
				body.add_child(_toggle("Left-handed layout", "left_handed", "Joystick on the right, actions on the left."))
				body.add_child(_toggle("Toggle Block", "toggle_block", "Tap once to raise the guard, tap again to lower it."))
				body.add_child(UiKit.label("Keyboard: WASD move · J attack · K heavy · Space dodge · L block · U Aether · Shift sprint · Esc pause",
						"DimLabel", true))
			"access":
				_accessibility(body)
		var footer_holder := body
		footer_holder.add_child(HSeparator.new())
		var footer := UiKit.hbox(14)
		footer.add_child(UiKit.button("Reset defaults", func() -> void:
			Settings.reset_to_defaults()
			self_call.call(key)))
		if allow_delete_save and Saves.has_save():
			var delete := UiKit.button("Delete journey", func() -> void:
				UiKit.confirm(parent, "Delete journey?",
						"Your lodge, champions and mentors will be lost. This cannot be undone.",
						"Delete", func() -> void:
							Saves.delete_save()
							UiKit.close_modal(content)
							Router.go("title")))
			delete.add_theme_color_override("font_color", UiTheme.BAD)
			footer.add_child(delete)
		footer_holder.add_child(footer)
	holder["show"] = show_tab
	show_tab.call(tab)
	var done_row := UiKit.hbox()
	done_row.alignment = BoxContainer.ALIGNMENT_END
	done_row.add_child(UiKit.primary_button("Done", func() -> void: UiKit.close_modal(content), 200))
	content.add_child(done_row)


## Accessibility options (also reused by the first-launch comfort setup).
static func _accessibility(body: VBoxContainer) -> void:
	body.add_child(_choice("Text size", "text_scale", TEXT_SIZES))
	var colour_options: Array = []
	for mode: String in Settings.COLORBLIND_MODES:
		colour_options.append([COLORBLIND_LABELS[mode], mode])
	body.add_child(_choice("Colour-blind palette", "colorblind", colour_options))
	body.add_child(_toggle("High contrast", "high_contrast", "Darker panels, brighter text and borders."))
	body.add_child(_toggle("Reduce motion", "reduce_motion", "Fewer camera drifts, slide-ins and hit pauses."))
	body.add_child(_toggle("Reduce flashes", "reduce_flashes", "No bright hit flashes."))
	body.add_child(_toggle("Combat assist", "combat_assist",
			"Opponents telegraph longer and perfect dodge/block windows are wider. Change any time, no penalty."))
	body.add_child(_toggle("Toggle Block", "toggle_block", "No need to hold the Block button."))


## First-launch "Before we begin" comfort setup (accessibility in the setup
## flow, not buried in menus). Calls `on_done` when the player continues.
static func comfort_setup(parent: Node, on_done: Callable) -> void:
	var content := UiKit.modal(parent, "Before we begin", 760.0)
	content.add_child(UiKit.label("Make the journey comfortable. You can change these any time in Settings.", "DimLabel", true))
	var body := UiKit.vbox(12)
	content.add_child(body)
	body.add_child(_choice("Text size", "text_scale", TEXT_SIZES))
	var colour_options: Array = []
	for mode: String in Settings.COLORBLIND_MODES:
		colour_options.append([COLORBLIND_LABELS[mode], mode])
	body.add_child(_choice("Colour-blind palette", "colorblind", colour_options))
	body.add_child(_toggle("Combat assist", "combat_assist", "Longer telegraphs and wider timing windows."))
	body.add_child(_toggle("Show tutorial hints", "show_hints"))
	var row := UiKit.hbox()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UiKit.primary_button("Begin the journey", func() -> void:
		Settings.set_value("comfort_setup_done", true)
		UiKit.close_modal(content)
		on_done.call(), 280))
	content.add_child(row)


static func _slider(text: String, key: String, min_value: float = 0.0, max_value: float = 1.0,
		hint: String = "") -> Control:
	var column := UiKit.vbox(2)
	var row := UiKit.hbox(16)
	var name_label := UiKit.label(text)
	name_label.custom_minimum_size.x = 300
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.05
	slider.value = float(Settings.get_value(key))
	slider.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN * 0.75)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := UiKit.label("%d%%" % roundi(slider.value * 100.0), "DimLabel")
	value_label.custom_minimum_size.x = 64
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % roundi(value * 100.0)
		Settings.set_value(key, value))
	row.add_child(slider)
	row.add_child(value_label)
	column.add_child(row)
	if not hint.is_empty():
		column.add_child(UiKit.label(hint, "DimLabel", true))
	return column


static func _toggle(text: String, key: String, hint: String = "") -> Control:
	var column := UiKit.vbox(0)
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = Settings.get_value(key)
	toggle.custom_minimum_size.y = UiTheme.TOUCH_MIN * 0.8
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(on: bool) -> void:
		Sfx.play("ui_click")
		Settings.set_value(key, on))
	column.add_child(toggle)
	if not hint.is_empty():
		column.add_child(UiKit.label(hint, "DimLabel", true))
	return column


## Segmented choice: [[label, value], ...]
static func _choice(text: String, key: String, choices: Array) -> Control:
	var column := UiKit.vbox(6)
	column.add_child(UiKit.label(text))
	var row := UiKit.hbox(8)
	column.add_child(row)
	var holder := {}
	var refresh := func() -> void:
		var self_call: Callable = holder["refresh"]
		UiKit.clear(row)
		for choice: Array in choices:
			var selected: bool = Settings.get_value(key) == choice[1]
			var button := UiKit.button(("✓ " if selected else "") + str(choice[0]), func() -> void:
				Settings.set_value(key, choice[1])
				self_call.call(), "TabButtonSelected" if selected else "TabButton")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(button)
	holder["refresh"] = refresh
	refresh.call()
	return column
