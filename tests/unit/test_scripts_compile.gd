extends TestCase
## Every script in the project must load and compile.


func test_all_scripts_compile() -> void:
	for path in _scripts("res://scripts") + _scripts("res://tests"):
		var script := load(path) as GDScript
		check(script != null and script.can_instantiate(), "script failed to compile: " + path)


func test_all_scenes_load() -> void:
	for path in _files("res://scenes", ".tscn"):
		var scene := load(path) as PackedScene
		check(scene != null and scene.can_instantiate(), "scene failed to load: " + path)


func _scripts(root: String) -> Array[String]:
	return _files(root, ".gd")


func _files(root: String, extension: String) -> Array[String]:
	var result: Array[String] = []
	for file_name in DirAccess.get_files_at(root):
		if file_name.ends_with(extension):
			result.append(root.path_join(file_name))
	for dir_name in DirAccess.get_directories_at(root):
		result.append_array(_files(root.path_join(dir_name), extension))
	return result
