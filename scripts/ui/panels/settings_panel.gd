class_name SettingsPanel
extends RefCounted
## Settings dialog shared by the title screen and the in-game menus.


static func open(parent: Node, allow_delete_save: bool = true) -> void:
	var content := UiKit.modal(parent, "Settings", 760.0)
	var body := UiKit.vbox(14)
	content.add_child(UiKit.scroll(body))
	content.get_parent().custom_minimum_size.y = 560
	body.add_child(_slider("Master volume", "master_volume"))
	body.add_child(_slider("Music & ambience", "music_volume"))
	body.add_child(_slider("Effects", "sfx_volume"))
	body.add_child(_slider("Control size", "controls_scale", 0.8, 1.3))
	body.add_child(_toggle("Show tutorial hints", "show_hints"))
	body.add_child(_toggle("Camera shake", "camera_shake"))
	body.add_child(_toggle("Vibration", "vibration"))
	body.add_child(_toggle("Left-handed controls (swap sides)", "left_handed"))
	var footer := UiKit.hbox(14)
	footer.add_child(UiKit.button("Reset defaults", func() -> void:
		Settings.reset_to_defaults()
		UiKit.close_modal(content)
		open(parent, allow_delete_save)))
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
	footer.add_child(UiKit.spacer(false))
	footer.add_child(UiKit.primary_button("Done", func() -> void: UiKit.close_modal(content), 180))
	content.add_child(footer)


static func _slider(text: String, key: String, min_value: float = 0.0, max_value: float = 1.0) -> Control:
	var row := UiKit.hbox(16)
	var name_label := UiKit.label(text)
	name_label.custom_minimum_size.x = 300
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.05
	slider.value = Settings.get_value(key)
	slider.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN * 0.75)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, value))
	row.add_child(slider)
	return row


static func _toggle(text: String, key: String) -> Control:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = Settings.get_value(key)
	toggle.custom_minimum_size.y = UiTheme.TOUCH_MIN * 0.8
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(on: bool) -> void:
		Sfx.play("ui_click")
		Settings.set_value(key, on))
	return toggle
