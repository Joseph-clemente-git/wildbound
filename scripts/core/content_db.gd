extends Node
## Content database (autoload "Content").
##
## Loads every data resource under res://data/<category>/ and indexes it by its
## `id`. Gameplay code asks this database for definitions instead of hard-coding
## species, weapons or trainers, which keeps new content purely data-driven.

const CONFIG_PATH := "res://data/config/game_config.tres"

## Category name -> directory. Each resource in a directory must expose `id`.
const CATEGORIES := {
	"animals": "res://data/animals",
	"weapons": "res://data/weapons",
	"armor": "res://data/armor",
	"accessories": "res://data/accessories",
	"magic": "res://data/magic",
	"trainers": "res://data/trainers",
	"techniques": "res://data/techniques",
	"opponents": "res://data/opponents",
	"arenas": "res://data/arenas",
	"trials": "res://data/trials",
	"regions": "res://data/regions",
}

var config: GameConfig
var _tables: Dictionary = {}  # category -> {id: Resource}


func _init() -> void:
	reload()


func reload() -> void:
	config = load(CONFIG_PATH) as GameConfig if ResourceLoader.exists(CONFIG_PATH) else null
	if config == null:
		config = GameConfig.new()
	_tables.clear()
	for category: String in CATEGORIES:
		_tables[category] = _load_directory(CATEGORIES[category])


func get_item(category: String, id: String) -> Resource:
	var table: Dictionary = _tables.get(category, {})
	return table.get(id)


func has_item(category: String, id: String) -> bool:
	return _tables.get(category, {}).has(id)


## All resources of a category, sorted by `sort_order` (if present) then id.
func list(category: String) -> Array:
	var items: Array = _tables.get(category, {}).values()
	items.sort_custom(_compare_items)
	return items


func ids(category: String) -> Array:
	return list(category).map(func(item: Resource) -> String: return item.id)


func _load_directory(path: String) -> Dictionary:
	var result := {}
	if not DirAccess.dir_exists_absolute(path):
		return result
	# list_directory() resolves exported .remap files transparently.
	for file_name: String in ResourceLoader.list_directory(path):
		if file_name.ends_with("/") or not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			continue
		var resource := load(path.path_join(file_name))
		if resource == null or not ("id" in resource):
			push_warning("Content: skipped %s (no id)" % file_name)
			continue
		if String(resource.id).is_empty():
			push_warning("Content: skipped %s (empty id)" % file_name)
			continue
		if result.has(resource.id):
			push_error("Content: duplicate id '%s' in %s" % [resource.id, path])
		result[resource.id] = resource
	return result


static func _compare_items(a: Resource, b: Resource) -> bool:
	var order_a: int = a.sort_order if "sort_order" in a else 0
	var order_b: int = b.sort_order if "sort_order" in b else 0
	if order_a != order_b:
		return order_a < order_b
	return String(a.id) < String(b.id)
