extends Node
## Scene navigation with a fade transition (autoload "Router").
##
## Dedicated scenes are only used where the gameplay context truly changes
## (title, story, lodge, map, arena, result). Lodge sub-screens are panels
## inside the Lodge scene instead of separate scenes.

signal route_changed(route: String)

const ROUTES := {
	"boot": "res://scenes/boot/boot.tscn",
	"title": "res://scenes/title/title_screen.tscn",
	"story": "res://scenes/story/story_scene.tscn",
	"lodge": "res://scenes/lodge/lodge.tscn",
	"world_map": "res://scenes/world_map/world_map.tscn",
	"battle_prep": "res://scenes/battle_prep/battle_prep.tscn",
	"arena": "res://scenes/arena/arena.tscn",
	"result": "res://scenes/result/battle_result.tscn",
}

const FADE_SECONDS := 0.28

## Parameters handed to the next scene (read them in the scene's _ready).
var params: Dictionary = {}
var current_route: String = ""

var _layer: CanvasLayer
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.05, 0.04, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)


func has_route(route: String) -> bool:
	return ROUTES.has(route)


func go(route: String, next_params: Dictionary = {}) -> void:
	if _busy:
		return
	if not ROUTES.has(route):
		push_error("Router: unknown route '%s'" % route)
		return
	_busy = true
	params = next_params
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	await tween.finished
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(ROUTES[route])
	if error != OK:
		push_error("Router: failed to load %s (%s)" % [route, error_string(error)])
	current_route = route
	await get_tree().process_frame
	route_changed.emit(route)
	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	await fade_in.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func is_transitioning() -> bool:
	return _busy
