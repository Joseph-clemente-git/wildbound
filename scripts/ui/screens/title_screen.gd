extends Node3D
## Title screen over the atmospheric Home Valley shot (story §9-10, §25).
##
## First launch shows only NEW JOURNEY / SETTINGS / CREDITS. Once a journey
## exists CONTINUE becomes the primary action, and shortcuts into the lodge
## appear only after the systems they lead to have been introduced.

const INTRO_SECONDS := 6.5
const CAMERA_START := Vector3(9.0, 7.5, 27.0)
const CAMERA_END := Vector3(-2.6, 1.9, 14.0)
const LOOK_START := Vector3(0.0, 1.0, 0.0)
const LOOK_END := Vector3(1.2, 1.7, 0.0)
const DOG_START := Vector3(1.4, 0.0, 19.0)
const DOG_END := Vector3(2.0, 0.0, 9.2)

var _camera: Camera3D
var _dog: ProceduralDogVisual
var _ui_root: Control
var _menu: Control
var _intro_time := 0.0
var _intro_running := false
var _look_target := LOOK_START


func _ready() -> void:
	WorldBuilder.home_valley(self, "dusk")
	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_dog = ProceduralDogVisual.new()
	add_child(_dog)
	_build_ui()
	Sfx.play_ambient()
	var intro: bool = Router.params.get("intro", false)
	if intro:
		_intro_running = true
		_dog.position = DOG_START
		_dog.set_locomotion(0.45)
		_menu.modulate.a = 0.0
		_update_intro(0.0)
	else:
		_finish_intro()


func _process(delta: float) -> void:
	if _intro_running:
		_intro_time += delta
		_update_intro(_intro_time / INTRO_SECONDS)
		if _intro_time >= INTRO_SECONDS:
			_finish_intro()
	else:
		# Gentle idle drift so the shot never feels frozen.
		var t := 0.0 if Settings.get_value("reduce_motion") else Time.get_ticks_msec() / 1000.0
		_camera.position = CAMERA_END + Vector3(sin(t * 0.15) * 0.6, sin(t * 0.21) * 0.15, 0)
		_camera.look_at(LOOK_END)


func _unhandled_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed)
	if _intro_running and tapped:
		_finish_intro()


func _update_intro(progress: float) -> void:
	var eased := ease(clampf(progress, 0.0, 1.0), -1.8)
	_camera.position = CAMERA_START.lerp(CAMERA_END, eased)
	_look_target = LOOK_START.lerp(LOOK_END, eased)
	_camera.look_at(_look_target)
	_dog.position = DOG_START.lerp(DOG_END, clampf(progress, 0.0, 1.0))


func _finish_intro() -> void:
	_intro_running = false
	_dog.position = DOG_END
	# Turn three-quarters toward the camera to greet the Keeper.
	var to_camera := CAMERA_END - DOG_END
	_dog.rotation.y = atan2(-to_camera.x, -to_camera.z) + 0.35
	_dog.set_locomotion(0.0)
	_camera.position = CAMERA_END
	_camera.look_at(LOOK_END)
	var tween := create_tween()
	tween.tween_property(_menu, "modulate:a", 1.0, 0.8)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.theme = UiTheme.get_theme()
	layer.add_child(_ui_root)
	# Soft vignette on the left so the menu reads over the scenery.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.06, 0.05, 0.82))
	gradient.set_color(1, Color(0.05, 0.06, 0.05, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(1, 0)
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size.x = 640
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(shade)

	var safe := UiKit.safe_area(40)
	_ui_root.add_child(safe)
	_menu = UiKit.vbox(14)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(_menu)
	var title := UiKit.label("WILDBOUND", "TitleLabel")
	title.add_theme_font_size_override("font_size", UiTheme.fs(72))
	_menu.add_child(title)
	var subtitle := UiKit.label("Chronicles of the Aether", "HeadingLabel")
	_menu.add_child(subtitle)
	_menu.add_child(_gap(18))
	_populate_menu()


func _populate_menu() -> void:
	var has_save := Saves.has_save()
	var buttons := UiKit.vbox(12)
	buttons.custom_minimum_size.x = 380
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_menu.add_child(buttons)
	if has_save:
		buttons.add_child(UiKit.primary_button("Continue", _on_continue))
		for shortcut: Array in _unlocked_shortcuts():
			buttons.add_child(UiKit.button(shortcut[0], _open_lodge_panel.bind(shortcut[1])))
		buttons.add_child(UiKit.button("New Journey", _on_new_journey))
	else:
		buttons.add_child(UiKit.primary_button("New Journey", _on_new_journey))
	var row := UiKit.hbox(12)
	row.add_child(UiKit.button("Settings", func() -> void: SettingsPanel.open(_ui_root)))
	row.add_child(UiKit.button("Credits", func() -> void: CreditsPanel.open(_ui_root)))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		row.add_child(UiKit.button("Quit", func() -> void: get_tree().quit()))
	for child in row.get_children():
		(child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(row)


## Lodge shortcuts that only appear once the story has introduced them.
func _unlocked_shortcuts() -> Array:
	var result: Array = []
	var entries := [
		["Journey", "journey", "world_map_unlocked"],
		["Champions", "champion", "inspected_champion"],
		["Mentors", "trainers", "met_first_trainer"],
		["Equipment Hall", "equipment", "equipped_weapon"],
		["Codex", "codex", "codex_unlocked"],
	]
	for entry: Array in entries:
		if Game.is_flag_set(entry[2]):
			result.append([entry[0], entry[1]])
	return result


func _on_continue() -> void:
	if Game.continue_journey():
		Router.go("lodge")
	else:
		UiKit.toast(_ui_root, "The journey could not be loaded.", UiTheme.BAD)


func _on_new_journey() -> void:
	if not Settings.get_value("comfort_setup_done"):
		SettingsPanel.comfort_setup(_ui_root, _on_new_journey)
		return
	if Saves.has_save():
		UiKit.confirm(_ui_root, "Begin a new journey?",
				"Starting over replaces your current lodge, champions and mentors.",
				"Begin anew", _start_new_journey)
	else:
		_start_new_journey()


func _start_new_journey() -> void:
	if ResourceLoader.exists(Router.ROUTES["story"]):
		Game.new_journey()
		Router.go("story", {"event": "opening"})
	else:
		UiKit.toast(_ui_root, "The road to the lodge is still being built.", UiTheme.WARN)


func _open_lodge_panel(panel: String) -> void:
	if Game.continue_journey():
		if panel == "journey":
			Router.go("journey")
		else:
			Router.go("lodge", {"panel": panel})


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	return gap
