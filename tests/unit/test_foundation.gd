extends TestCase


func test_config_loads_with_defaults() -> void:
	check(Content.config != null, "config missing")
	check_eq(Content.config.max_active_trainers, 5)
	check_eq(Content.config.trainer_slot_levels[1], 1)


func test_routes_point_to_existing_scenes() -> void:
	for route: String in ["boot"]:
		check(ResourceLoader.exists(Router.ROUTES[route]), "missing scene for " + route)


func test_input_actions_registered() -> void:
	for action: String in Settings.ACTIONS:
		check(InputMap.has_action(action), "missing action " + action)


func test_sfx_hooks_synthesize() -> void:
	for hook: String in Sfx.RECIPES:
		var stream: AudioStreamWAV = Sfx._stream_for(hook)
		check(stream != null and stream.data.size() > 0, "empty sfx " + hook)


func test_theme_builds() -> void:
	var theme := UiTheme.get_theme()
	check(theme.has_stylebox("normal", "PrimaryButton"))
