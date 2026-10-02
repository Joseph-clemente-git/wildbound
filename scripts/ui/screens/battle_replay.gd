extends Node3D
## Battle Replay: the 3D presentation of a simulated battle. The result is
## already decided and applied (BattleSession); this screen plays the log
## back — every move, swing, guard, dodge, Art and knockout exactly as the
## simulation produced them — at 1×, 2× or 4×, with pause, replay and skip.
## Params: {"session": BattleSession}

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
## Clip to play for each simulated action.
const CLIPS := {
	"attack": "attack", "heavy": "heavy_attack", "block": "block", "dodge": "dodge", "cast": "cast",
	"stagger": "stagger", "flinch": "hit", "knockdown": "knocked_out", "recover": "recover", "ko": "knocked_out",
}
const ARROW_COLOR := Color("6a4a2a")

var session: BattleSession
var timeline: ReplayTimeline
var time := 0.0
var speed := 1.0
var paused := false
var finished := false
var visuals: Array[CharacterVisual] = []
var camera: BattleCamera

var _spans: Array[Dictionary] = []
var _shots: Dictionary = {}  # projectile id -> Node3D
var _bars: Array[Dictionary] = []
var _ticker: Label
var _messages: Array[String] = []
var _speed_buttons: Array[Button] = []
var _pause_button: Button
var _banner: Control
var _root: Control


func _ready() -> void:
	session = Router.params.get("session", null)
	if session == null or not Game.is_active():
		Router.go.call_deferred("lodge" if Game.is_active() else "title")
		return
	timeline = ReplayTimeline.new(session.battle_log)
	var arena := Content.arena(session.trial.arena_id)
	ArenaBuilder.build(self, arena)
	Sfx.play_ambient()
	for spec_data: Dictionary in session.battle_log.header["combatants"]:
		var visual := _body(spec_data)
		add_child(visual)
		visuals.append(visual)
		_spans.append({})
	camera = BattleCamera.new()
	camera.player = visuals[0]
	camera.opponent = visuals[1] if visuals.size() > 1 else visuals[0]
	camera.limit = arena.camera_limit
	add_child(camera)
	_build_ui()
	Router.back_requested.connect(skip)
	_apply(0.0)
	camera.snap()


func _body(spec_data: Dictionary) -> CharacterVisual:
	var visual := CharacterFactory.create(Content.animal(spec_data.get("animal", "")), spec_data.get("palette", {}))
	var weapon := Content.weapon(spec_data.get("weapon", ""))
	visual.set_weapon(weapon.weapon_type if weapon != null else "")
	var armor := Content.armor(spec_data.get("armor", ""))
	visual.set_armor(armor.weight_class if armor != null else -1)
	var ability := Content.ability(spec_data.get("ability", ""))
	visual.set_aura(ability.school if ability != null else "")
	visual.play("combat_idle", -1.0, false)
	return visual


# --- Playback ------------------------------------------------------------------

func _process(delta: float) -> void:
	if timeline == null or paused or finished:
		return
	advance(delta * speed)


## Moves the replay forward by `seconds` of battle time.
func advance(seconds: float) -> void:
	var before := time
	time = minf(time + seconds, timeline.duration)
	for event in timeline.events_between(before, time):
		_on_event(event)
	_apply(time)
	if time >= timeline.duration and not finished:
		_finish()


func set_speed(value: float) -> void:
	speed = value
	for i in _speed_buttons.size():
		_speed_buttons[i].theme_type_variation = "TabButtonSelected" if SPEEDS[i] == value else "TabButton"


func toggle_pause() -> void:
	paused = not paused
	_pause_button.text = "▶" if paused else "❚❚"
	for visual in visuals:
		visual.animation_player.speed_scale = 0.0 if paused else 1.0


## Watches the battle again from the start.
func restart() -> void:
	time = 0.0
	finished = false
	paused = false
	_pause_button.text = "❚❚"
	_banner.visible = false
	_messages.clear()
	_ticker.text = ""
	for shot: Node3D in _shots.values():
		shot.queue_free()
	_shots.clear()
	for i in visuals.size():
		_spans[i] = {}
		visuals[i].release()
	_apply(0.0)
	camera.snap()


## Leaves for the result (already applied).
func skip() -> void:
	Router.go("result", {"outcome": session.result, "session": session})


func _apply(t: float) -> void:
	var states := timeline.sample(t)
	for i in visuals.size():
		var data: Dictionary = states[i]
		var visual := visuals[i]
		var planar: Vector2 = data["position"]
		var previous := visual.position
		visual.position = Vector3(planar.x, float(data["elevation"]), planar.y)
		var facing: Vector2 = data["facing"]
		visual.rotation.y = atan2(-facing.x, -facing.y)
		if visual is ProceduralEagleVisual:
			(visual as ProceduralEagleVisual).set_spread(clampf(float(data["elevation"]) / 1.6, 0.0, 1.0))
		_animate(i, t, previous)
		_update_bar(i, data)
	_update_shots(t)


func _animate(i: int, t: float, previous: Vector3) -> void:
	var visual := visuals[i]
	var span := timeline.span_at(i, t)
	if span != _spans[i]:
		_spans[i] = span
		if span.is_empty():
			visual.release()
		elif CLIPS.has(span["action"]):
			var length := maxf(float(span["end"]) - float(span["start"]), 0.1)
			var clip: String = CLIPS[span["action"]]
			visual.play(clip, length / maxf(speed, 0.01) if span["action"] != "block" else -1.0, true)
	if span.is_empty():
		var moved := Vector2(visual.position.x - previous.x, visual.position.z - previous.z).length()
		var per_second := moved / maxf(get_process_delta_time() * speed, 0.001) if not paused else 0.0
		visual.set_locomotion(clampf(per_second / 5.5, 0.0, 1.0), true)


func _update_shots(t: float) -> void:
	var alive := {}
	for shot: Dictionary in timeline.projectiles(t):
		alive[shot["id"]] = true
		var node: Node3D = _shots.get(shot["id"])
		if node == null:
			node = _shot_body(shot)
			add_child(node)
			_shots[shot["id"]] = node
		var at: Vector2 = shot["position"]
		node.position = Vector3(at.x, 1.1, at.y)
	for id in _shots.keys():
		if not alive.has(id):
			(_shots[id] as Node3D).queue_free()
			_shots.erase(id)


func _shot_body(shot: Dictionary) -> Node3D:
	var ability := Content.ability(shot.get("ability", ""))
	if ability != null:
		var bolt := AetherBolt.new()
		bolt.color = MagicVisuals.school_color(ability.school)
		bolt.school = ability.school
		bolt.size = ability.radius
		return bolt
	var arrow := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.6
	arrow.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = ARROW_COLOR
	arrow.material_override = material
	arrow.rotation.x = PI * 0.5
	return arrow


# --- Events ----------------------------------------------------------------------

func _on_event(event: Dictionary) -> void:
	var actor: int = event.get("actor", -1)
	var target: int = event.get("target", -1)
	match event["type"]:
		"damage":
			if target >= 0:
				var heavy: bool = event.get("kind", "") == "heavy"
				_float_text(target, str(roundi(float(event["amount"]))), UiTheme.BAD if event.get("opening", false) else UiTheme.TEXT)
				if event.get("kind", "") != "burn":
					visuals[target].flash(Color(1.0, 0.85, 0.7), 0.12)
					Sfx.play("heavy_hit" if heavy else "hit")
					if heavy:
						camera.shake(0.25)
		"evade":
			_say("%s %s!" % [_name(actor), "dodges perfectly" if event.get("perfect", false) else "dodges"])
			Sfx.play("perfect_dodge" if event.get("perfect", false) else "dodge")
		"block":
			visuals[actor].flash(Color(0.6, 0.8, 1.0), 0.1)
			Sfx.play("block")
		"parry":
			_float_text(actor, "Parry!", UiTheme.ACCENT)
			_say("%s parries %s!" % [_name(actor), _name(target)])
			Sfx.play("perfect_block")
		"staggered":
			if event.get("reason", "") == "guard_break":
				_float_text(actor, "Guard broken!", UiTheme.WARN)
			_say("%s is staggered." % _name(actor))
			Sfx.play("stagger")
		"knockdown":
			_float_text(actor, "Down!", UiTheme.WARN)
			_say("%s is knocked down!" % _name(actor))
			camera.shake(0.35)
		"technique":
			var technique := Content.technique(event.get("technique", ""))
			if technique != null:
				_float_text(actor, technique.display_name + "!", UiTheme.ACCENT)
		"cast_release":
			var ability := Content.ability(event.get("ability", ""))
			if ability != null and ability.effect != MagicAbilityData.Effect.PROJECTILE:
				MagicVisuals.spawn_effect(self, ability, visuals[actor], {})
			if ability != null:
				_say("%s calls %s." % [_name(actor), ability.display_name])
		"exhausted":
			_float_text(actor, "Exhausted", UiTheme.TEXT_DIM)
		"knockout":
			_say("%s is knocked out!" % _name(actor))
			camera.shake(0.4)


func _float_text(index: int, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_size = 10
	label.font_size = 64
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = visuals[index].position + Vector3(0, 2.1, 0)
	add_child(label)
	var tween := label.create_tween()
	tween.set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 0.8, 0.9 / maxf(speed, 1.0))
	tween.tween_property(label, "modulate:a", 0.0, 0.9 / maxf(speed, 1.0))
	tween.chain().tween_callback(label.queue_free)


func _say(text: String) -> void:
	_messages.append(text)
	while _messages.size() > 3:
		_messages.pop_front()
	_ticker.text = "\n".join(_messages)


func _name(index: int) -> String:
	if index < 0:
		return ""
	return session.battle_log.header["combatants"][index].get("name", "?")


func _finish() -> void:
	finished = true
	var won := session.outcome.player_won()
	var draw := session.outcome.winner_team < 0
	for i in visuals.size():
		var team: int = session.state.combatants[i].team
		if team == session.outcome.winner_team:
			visuals[i].play("victory", 1.6, true)
	_banner.visible = true
	var title: Label = _banner.find_child("Title", true, false)
	title.text = "Draw" if draw else ("Victory" if won else "Defeat")
	title.add_theme_color_override("font_color", UiTheme.GOOD if won else (UiTheme.TEXT if draw else UiTheme.BAD))
	var how: Label = _banner.find_child("How", true, false)
	how.text = {"knockout": "by knockout", "decision": "on the judges' decision", "draw": "too close to call"}.get(session.outcome.reason, "")
	Sfx.play("victory" if won else "defeat")


# --- HUD -------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)
	var safe := UiKit.safe_area(16)
	_root.add_child(safe)
	var column := UiKit.vbox(10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	var top := UiKit.hbox(16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	for i in visuals.size():
		top.add_child(_fighter_bars(i))
		if i == 0:
			var middle := UiKit.vbox(2)
			middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var title := UiKit.label(session.trial.display_name.to_upper(), "DimLabel")
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			middle.add_child(title)
			top.add_child(middle)
	_ticker = UiKit.label("", "", true)
	_ticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_ticker)
	column.add_child(UiKit.spacer())
	var controls := UiKit.hbox(10)
	controls.alignment = BoxContainer.ALIGNMENT_END
	_pause_button = UiKit.button("❚❚", toggle_pause, "", 72)
	_pause_button.name = "Pause"
	controls.add_child(_pause_button)
	for value in SPEEDS:
		var button := UiKit.button("%d×" % int(value), set_speed.bind(value), "TabButton", 72)
		button.name = "Speed%d" % int(value)
		_speed_buttons.append(button)
		controls.add_child(button)
	controls.add_child(UiKit.button("⟲ Replay", restart, "", 140))
	var skip_button := UiKit.button("Skip ▶▶", skip, "", 140)
	skip_button.name = "Skip"
	controls.add_child(skip_button)
	column.add_child(controls)
	set_speed(1.0)
	_banner = _build_banner()
	_root.add_child(_banner)


func _fighter_bars(i: int) -> Control:
	var box := UiKit.panel("ChipPanel")
	box.custom_minimum_size.x = 330
	var column := UiKit.vbox(4)
	box.add_child(column)
	var name_label := UiKit.label(_name(i))
	column.add_child(name_label)
	var health := UiKit.bar(1.0, 1.0, UiTheme.HEALTH, 16.0)
	column.add_child(health)
	var stamina := UiKit.bar(1.0, 1.0, UiTheme.STAMINA, 8.0)
	column.add_child(stamina)
	_bars.append({"health": health, "stamina": stamina})
	return box


func _update_bar(i: int, data: Dictionary) -> void:
	if i >= _bars.size():
		return
	(_bars[i]["health"] as ProgressBar).value = float(data["health"]) / maxf(float(data["max_health"]), 1.0)
	(_bars[i]["stamina"] as ProgressBar).value = float(data["stamina"]) / maxf(float(data["max_stamina"]), 1.0)


func _build_banner() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	var panel := UiKit.panel("SheetPanel")
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var column := UiKit.vbox(10)
	panel.add_child(column)
	var title := UiKit.label("", "TitleLabel")
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var how := UiKit.label("", "DimLabel")
	how.name = "How"
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(how)
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button("⟲ Watch again", restart, "", 200))
	var result := UiKit.primary_button("See the result", skip, 220)
	result.name = "SeeResult"
	row.add_child(result)
	column.add_child(row)
	return center
