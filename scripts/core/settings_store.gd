extends Node
## Player preferences (autoload "Settings"), stored separately from the save.
##
## Also registers the keyboard / gamepad input actions so desktop testing works
## alongside the on-screen touch controls.

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"
const SECTION := "settings"

const DEFAULTS := {
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"show_hints": true,
	"controls_scale": 1.0,
	"left_handed": false,
	"vibration": true,
	# Accessibility (ui-ux-game checklist)
	"text_scale": 1.0,
	"colorblind": "off",
	"high_contrast": false,
	"shake_strength": 0.7,
	"reduce_motion": false,
	"reduce_flashes": false,
	"hud_opacity": 1.0,
	"toggle_block": false,
	"combat_assist": false,
	"comfort_setup_done": false,
}

const COLORBLIND_MODES: Array[String] = ["off", "deuteranopia", "protanopia", "tritanopia"]

## action -> physical keys and joypad buttons.
const ACTIONS := {
	"move_left": {"keys": [KEY_A, KEY_LEFT], "joy": []},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "joy": []},
	"move_forward": {"keys": [KEY_W, KEY_UP], "joy": []},
	"move_back": {"keys": [KEY_S, KEY_DOWN], "joy": []},
	"attack": {"keys": [KEY_J], "joy": [JOY_BUTTON_X]},
	"heavy": {"keys": [KEY_K], "joy": [JOY_BUTTON_Y]},
	"dodge": {"keys": [KEY_SPACE], "joy": [JOY_BUTTON_A]},
	"block": {"keys": [KEY_L], "joy": [JOY_BUTTON_RIGHT_SHOULDER]},
	"magic": {"keys": [KEY_U], "joy": [JOY_BUTTON_B]},
	"sprint": {"keys": [KEY_SHIFT], "joy": [JOY_BUTTON_LEFT_SHOULDER]},
	"pause": {"keys": [KEY_ESCAPE], "joy": [JOY_BUTTON_START]},
}

var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	_ensure_audio_buses()
	_register_input_actions()
	load_settings()


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key)
	save_settings()
	changed.emit(key, value)


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		for key: String in DEFAULTS:
			var value: Variant = file.get_value(SECTION, key, DEFAULTS[key])
			if typeof(value) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and value is int):
				_values[key] = value
	for key: String in _values:
		_apply(key)


func save_settings() -> void:
	var file := ConfigFile.new()
	for key: String in _values:
		file.set_value(SECTION, key, _values[key])
	file.save(PATH)


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate()
	for key: String in _values:
		_apply(key)
		changed.emit(key, _values[key])
	save_settings()


func _apply(key: String) -> void:
	match key:
		"master_volume":
			_set_bus_volume("Master", _values[key])
		"music_volume":
			_set_bus_volume("Music", _values[key])
		"sfx_volume":
			_set_bus_volume("SFX", _values[key])
		"text_scale", "colorblind", "high_contrast":
			UiTheme.refresh(_values["colorblind"], _values["high_contrast"], _values["text_scale"])


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(bus, linear <= 0.001)


func _ensure_audio_buses() -> void:
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func _register_input_actions() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.25)
		for key: int in ACTIONS[action]["keys"]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = key as Key
			InputMap.action_add_event(action, key_event)
		for button: int in ACTIONS[action]["joy"]:
			var joy_event := InputEventJoypadButton.new()
			joy_event.button_index = button as JoyButton
			InputMap.action_add_event(action, joy_event)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)


func _add_joy_axis(action: String, axis: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)
