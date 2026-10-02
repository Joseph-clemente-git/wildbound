extends Node3D
## The Lodge: the player's 3D home hub (story §13-15, §45).
##
## The world presents the systems: tap the champion, the Training Yard, the
## Equipment Bench, the Aether Circle, the Trainer Board, the Rest Area or the
## Map Board. Contextual actions appear for the selected thing; sub-screens
## open as panels inside this scene instead of loading new scenes.
## Params: {"panel": id} opens a panel on arrival.

const CAMERA_OFFSET := Vector3(0.0, 8.0, 10.0)
const PAN_LIMITS := Rect2(-10.0, -9.0, 20.0, 16.0)
const TAP_SLOP := 14.0

## Station id -> [label, panel to open, actions]
const STATIONS := {
	"champion": ["", "champion", [["Inspect", "champion"], ["Train", "training"], ["Equip", "equipment"], ["Aether", "aether"]]],
	"training": ["Training Yard", "training", [["Train", "training"]]],
	"trainers": ["Trainer Board", "trainers", [["Mentors", "trainers"]]],
	"equipment": ["Equipment Bench", "equipment", [["Equipment Hall", "equipment"]]],
	"aether": ["Aether Circle", "aether", [["Aether Arts", "aether"]]],
	"recovery": ["Rest Area", "recovery", [["Rest", "recovery"]]],
	"journey": ["Map Board", "journey", [["Journey", "journey"]]],
}

var champion_visual: CharacterVisual
var hud: LodgeHud
var panels: PanelHost

var _camera: Camera3D
var _focus := Vector3(0.0, 0.0, -1.0)
var _focus_target := Vector3(0.0, 0.0, -1.0)
var _zoom := 0.85
var _press_position := Vector2.ZERO
var _pressing := false
var _dragged := false
var _dialogue: DialogueBox
var _context: Control
var _markers: Dictionary = {}  # station -> Label3D
var _dog_target := Vector3.ZERO
var _dog_wait := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if not Game.is_active():
		Router.go("title")
		return
	WorldBuilder.home_valley(self, "day")
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_spawn_champion()
	_spawn_mentors()
	_build_station_areas()
	_build_ui()
	Sfx.play_ambient()
	Game.changed.connect(_refresh)
	Router.back_requested.connect(_on_back)
	Game.notice.connect(func(text: String, color: Color) -> void: UiKit.toast(hud, text, color))
	_refresh()
	_update_camera(1.0)
	var panel: String = Router.params.get("panel", "")
	if not panel.is_empty():
		open_panel(panel, Router.params.get("panel_options", {}))


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_dog(delta)
	var t := Time.get_ticks_msec() / 1000.0
	for station: String in _markers:
		var marker: Label3D = _markers[station]
		marker.position.y = 3.0 + sin(t * 3.0) * 0.15


# --- Input: tap to select, drag to pan ---------------------------------------------

var _touches: Dictionary = {}  # finger -> position, for pinch zoom
var _pinch_distance := 0.0


func _on_back() -> void:
	if _dialogue.visible:
		return
	if panels.has_open_panel():
		panels.close()
	elif _context != null:
		_close_context()
	else:
		hud.call("_open_menu")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_back()
		return
	if _dialogue.visible or panels.has_open_panel():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
			_pinch_distance = 0.0
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var points: Array = _touches.values()
			var distance: float = (points[0] as Vector2).distance_to(points[1])
			if _pinch_distance > 0.0:
				_zoom = clampf(_zoom * _pinch_distance / maxf(distance, 1.0), 0.6, 1.4)
			_pinch_distance = distance
			_dragged = true
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pressing = true
			_dragged = false
			_press_position = event.position
		elif _pressing:
			_pressing = false
			if not _dragged:
				_tap(event.position)
	elif event is InputEventScreenDrag and _pressing:
		if event.position.distance_to(_press_position) > TAP_SLOP:
			_dragged = true
		if _dragged:
			_pan(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - 0.08, 0.6, 1.4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + 0.08, 0.6, 1.4)
	elif event is InputEventMagnifyGesture:
		_zoom = clampf(_zoom / event.factor, 0.6, 1.4)


func _pan(relative: Vector2) -> void:
	var scale := 0.02 * _zoom * (720.0 / maxf(get_viewport().get_visible_rect().size.y, 1.0))
	_focus_target += Vector3(-relative.x, 0.0, -relative.y) * scale
	_focus_target.x = clampf(_focus_target.x, PAN_LIMITS.position.x, PAN_LIMITS.end.x)
	_focus_target.z = clampf(_focus_target.z, PAN_LIMITS.position.y, PAN_LIMITS.end.y)


func _tap(screen_position: Vector2) -> void:
	var from := _camera.project_ray_origin(screen_position)
	var to := from + _camera.project_ray_normal(screen_position) * 80.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_close_context()
		return
	var station: String = hit["collider"].get_meta("station", "")
	if not station.is_empty():
		select_station(station)


func _update_camera(delta: float) -> void:
	_focus = _focus.lerp(_focus_target, clampf(delta * 6.0, 0.0, 1.0))
	_camera.position = _focus + CAMERA_OFFSET * _zoom
	_camera.look_at(_focus + Vector3(0, 0.8, 0))


func focus_on(station: String) -> void:
	var point: Vector3 = champion_visual.position if station == "champion" else WorldBuilder.STATIONS.get(station, Vector3.ZERO)
	_focus_target = Vector3(point.x, 0.0, point.z + 1.0)


# --- Stations ------------------------------------------------------------------------

func select_station(station: String) -> void:
	Sfx.play("ui_click")
	focus_on(station)
	if station == "trainers" and not Game.is_flag_set("met_first_trainer"):
		play_dialogue("meet_swordmaster", func() -> void:
			Game.set_flag("met_first_trainer")
			_refresh())
		return
	_show_context(station)


func _show_context(station: String) -> void:
	_close_context()
	var info: Array = STATIONS[station]
	var champion := Game.champion()
	var title: String = info[0] if not info[0].is_empty() else champion.name
	_context = UiKit.panel("SheetPanel")
	_context.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_context.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_context.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_context.position.y -= 110
	var column := UiKit.vbox(10)
	_context.add_child(column)
	var header := UiKit.hbox(12)
	header.add_child(UiKit.heading(title))
	if station == "champion":
		var mood := UiKit.label("%s · %s" % [champion.capability_name(), champion.mood_name()], "DimLabel")
		mood.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(mood)
	header.add_child(UiKit.spacer(false))
	header.add_child(UiKit.button("✕", _close_context, "FlatButton", 64))
	column.add_child(header)
	var row := UiKit.hbox(12)
	for action: Array in info[2]:
		var panel_id: String = action[1]
		var enabled := LodgeHud.is_panel_unlocked(panel_id)
		var button := UiKit.button(action[0], open_panel.bind(panel_id), "", 170)
		button.disabled = not enabled
		if not enabled:
			button.tooltip_text = "Not yet — follow your objectives."
		row.add_child(button)
	column.add_child(row)
	hud.add_child(_context)


func _close_context() -> void:
	if _context != null and is_instance_valid(_context):
		_context.queue_free()
	_context = null


func open_panel(panel_id: String, panel_options: Dictionary = {}) -> void:
	_close_context()
	if panel_id == "trainers" and not Game.is_flag_set("met_first_trainer"):
		select_station("trainers")
		return
	if panel_id == "champion":
		Game.set_flag("inspected_champion")
	panels.open(panel_id, panel_options)


func play_dialogue(event_id: String, on_done: Callable = Callable()) -> void:
	_close_context()
	if on_done.is_valid():
		_dialogue.finished.connect(on_done, CONNECT_ONE_SHOT)
	_dialogue.play(StoryEvents.get_event(event_id))


# --- World ---------------------------------------------------------------------------

func _spawn_champion() -> void:
	var champion := Game.champion()
	champion_visual = CharacterFactory.for_champion(champion)
	champion_visual.position = Vector3(0.6, 0.0, -0.5)
	add_child(champion_visual)
	_dog_target = champion_visual.position
	var area := _make_area(0.9, "champion")
	area.position = Vector3(0, 1.0, 0)
	champion_visual.add_child(area)
	_apply_champion_look()


func _apply_champion_look() -> void:
	var champion := Game.champion()
	var weapon := Content.weapon(champion.weapon_id)
	champion_visual.set_weapon(weapon.weapon_type if weapon != null else "")
	var armor := Content.armor(champion.armor_id)
	champion_visual.set_armor(armor.weight_class if armor != null else -1)
	var ability := Content.ability(champion.equipped_ability)
	champion_visual.set_aura(ability.school if ability != null else "")


## Active mentors stand at the stations they teach from.
func _spawn_mentors() -> void:
	var spots := [Vector3(-5.4, 0, 1.8), Vector3(-3.0, 0, -3.6), Vector3(6.0, 0, 2.6),
			Vector3(3.4, 0, -3.0), Vector3(-8.6, 0, 1.6)]
	var maren := ProceduralDogVisual.new(StoryEvents.MAREN_PALETTE)
	maren.position = Vector3(-1.2, 0.55, -6.9)
	maren.scale = Vector3.ONE * 0.95
	add_child(maren)
	var index := 0
	for trainer in TrainerManager.active(Game.profile):
		if index >= spots.size():
			break
		var mentor := ProceduralDogVisual.new(trainer.palette)
		mentor.position = spots[index]
		mentor.rotation.y = atan2(mentor.position.x - 0.6, mentor.position.z + 0.5)
		match trainer.category:
			GameEnums.TrainerCategory.WEAPON:
				var weapon_type: String = GameEnums.target_id(trainer.primary_discipline[0])
				mentor.set_weapon(weapon_type)
			GameEnums.TrainerCategory.MAGIC:
				mentor.set_aura(GameEnums.target_id(trainer.primary_discipline[0]))
		mentor.set_armor(GameEnums.ArmorWeight.MEDIUM)
		mentor.add_to_group("mentor_visual")
		add_child(mentor)
		index += 1


func _build_station_areas() -> void:
	for station: String in STATIONS:
		if station == "champion":
			continue
		var area := _make_area(1.9, station)
		area.position = WorldBuilder.STATIONS[station] + Vector3(0, 1.0, 0)
		add_child(area)
		var label := Label3D.new()
		label.text = STATIONS[station][0]
		label.font_size = 44
		label.outline_size = 12
		label.modulate = UiTheme.TEXT
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = WorldBuilder.STATIONS[station] + Vector3(0, 2.5, 0)
		label.pixel_size = 0.009
		add_child(label)


func _make_area(radius: float, station: String) -> Area3D:
	var area := Area3D.new()
	area.set_meta("station", station)
	area.monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	area.add_child(shape)
	return area


## Idle life: the champion wanders around the yard between stations.
func _update_dog(delta: float) -> void:
	if champion_visual == null:
		return
	var to_target := _dog_target - champion_visual.position
	to_target.y = 0.0
	if to_target.length() > 0.15:
		var step := minf(1.4 * delta, to_target.length())
		champion_visual.position += to_target.normalized() * step
		var desired := atan2(-to_target.x, -to_target.z)
		champion_visual.rotation.y = lerp_angle(champion_visual.rotation.y, desired, clampf(delta * 6.0, 0, 1))
		champion_visual.set_locomotion(0.4)
	else:
		champion_visual.set_locomotion(0.0)
		_dog_wait -= delta
		if _dog_wait <= 0.0:
			_dog_wait = _rng.randf_range(3.0, 7.0)
			_dog_target = Vector3(_rng.randf_range(-2.5, 3.0), 0.0, _rng.randf_range(-2.0, 2.5))


# --- UI ------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = LodgeHud.new()
	hud.panel_requested.connect(open_panel)
	hud.objective_requested.connect(func(station: String) -> void:
		focus_on(station)
		if station in STATIONS:
			select_station(station))
	layer.add_child(hud)
	panels = PanelHost.new()
	panels.lodge = self
	panels.closed.connect(_refresh)
	layer.add_child(panels)
	_dialogue = DialogueBox.new()
	_dialogue.visible = false
	layer.add_child(_dialogue)


func _refresh() -> void:
	if not is_inside_tree() or not Game.is_active():
		return
	hud.refresh()
	_apply_champion_look()
	_update_markers()


func _update_markers() -> void:
	var objective := QuestLog.current()
	var station: String = objective.get("station", "")
	for key: String in _markers.keys():
		if key != station:
			(_markers[key] as Node).queue_free()
			_markers.erase(key)
	if station.is_empty() or _markers.has(station) or station == "champion":
		return
	var marker := Label3D.new()
	marker.text = "!"
	marker.font_size = 120
	marker.outline_size = 18
	marker.modulate = UiTheme.ACCENT
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.pixel_size = 0.006
	marker.position = WorldBuilder.STATIONS[station] + Vector3(0, 3.0, 0)
	add_child(marker)
	_markers[station] = marker
