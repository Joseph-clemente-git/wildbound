extends Node
## Headless test runner. Run with:
##   godot --headless --path . res://tests/test_runner.tscn
## Optional filter: append `-- --filter=<substring>` to run matching files only.

const TEST_DIR := "res://tests/unit"


func _ready() -> void:
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
		var script: GDScript = load(TEST_DIR.path_join(file_name))
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.current_test = "%s::%s" % [file_name.get_basename(), method_name]
			case.before_each()
			case.call(method_name)
			total += 1
			if case.failures.is_empty():
				print("  ok   ", case.current_test)
			else:
				failed += 1
				for failure in case.failures:
					printerr("  FAIL ", failure)
	print("\n%d tests, %d failed" % [total, failed])
	get_tree().quit(1 if failed > 0 else 0)
