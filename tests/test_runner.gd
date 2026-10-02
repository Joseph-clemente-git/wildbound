extends Node
## Headless test runner. Run with:
##   godot --headless --path . res://tests/test_runner.tscn
## Optional filter: append `-- --filter=<substring>` to run matching files only.

const TEST_DIR := "res://tests/unit"


## Captures engine/script errors so a test that crashes midway still fails.
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		var kind := "SCRIPT ERROR" if error_type == ERROR_TYPE_SCRIPT else "ERROR"
		errors.append("%s: %s %s (%s:%d)" % [kind, code, rationale, file, line])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		_mutex.lock()
		var result := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return result


func _ready() -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var total := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TEST_DIR))
	files.sort()
	for file_name: String in files:
		if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
			continue
		if not filter.is_empty() and not file_name.contains(filter):
			continue
		var script := load(TEST_DIR.path_join(file_name)) as GDScript
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			printerr("  FAIL ", file_name, ": test file failed to load")
			continue
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.current_test = "%s::%s" % [file_name.get_basename(), method_name]
			catcher.take()
			case.before_each()
			case.call(method_name)
			var errors := catcher.take()
			if not case.allow_errors:
				for error in errors:
					case.failures.append("%s: %s" % [case.current_test, error])
			total += 1
			if case.failures.is_empty():
				print("  ok   ", case.current_test)
			else:
				failed += 1
				for failure in case.failures:
					printerr("  FAIL ", failure)
	print("\n%d tests, %d failed" % [total, failed])
	get_tree().quit(1 if failed > 0 else 0)
