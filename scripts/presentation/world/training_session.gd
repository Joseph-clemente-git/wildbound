class_name TrainingSession
extends Node
## A training session played out in the Training Yard: the champion and the
## mentor walk to the yard, drill the chosen lesson for the session's length
## (TrainingSystem.session_seconds) with a progress bar and countdown, then
## the mentor returns to their station. Presentation only — the session's
## outcome is already decided by TrainingSystem.train before it starts.

signal finished

const GATHER_SECONDS := 1.2
const BEAT_SECONDS := 1.15
const CLOSING_SECONDS := 1.0
const RETURN_SECONDS := 1.0

## Clip pairs [champion, mentor] repeated in turn during the drill.
const ATTACK_DRILL := [["attack", "block"], ["attack", "block"], ["heavy_attack", "block"]]
const GUARD_DRILL := [["block", "attack"], ["block", "attack"], ["block", "heavy_attack"]]
const DODGE_DRILL := [["dodge", "attack"], ["dodge", "heavy_attack"]]
const FOOTWORK_DRILL := [["dodge", "attack"], ["run", "combat_idle"]]
const STAMINA_DRILL := [["run", "combat_idle"], ["run", "combat_idle"], ["exhausted", "idle"]]
const POWER_DRILL := [["heavy_attack", "block"]]
const RECOVERY_DRILL := [["hit", "attack"], ["recover", "combat_idle"]]
const CAST_DRILL := [["cast", "cast"], ["combat_idle", "cast"], ["cast", "combat_idle"]]

## Sound per champion clip.
const CLIP_SOUNDS := {
	"attack": "swing", "heavy_attack": "heavy_swing", "block": "block", "dodge": "dodge",
	"hit": "hit", "cast": "cast", "exhausted": "exhausted", "run": "step",
}

var champion: CharacterVisual
var mentor: CharacterVisual
var yard := Vector3.ZERO
var seconds := 6.0
var title := ""

var _drill: Array = []
var _phase := ""
var _phase_time := 0.0
var _elapsed := 0.0
var _beat_index := 0
var _beat_time := 0.0
var _champion_from := Vector3.ZERO
var _mentor_from := Vector3.ZERO
var _mentor_home := Vector3.ZERO
var _mentor_home_rotation := 0.0
var _overlay: Control
var _bar: ProgressBar
var _time_label: Label


## The drill for a lesson ("weapon:sword", "skill:dodge", "magic:fire"...).
static func drill_for(target: String) -> Array:
	var id := GameEnums.target_id(target)
	match GameEnums.target_kind(target):
		"weapon":
			return GUARD_DRILL if id == "shield" else ATTACK_DRILL
		"magic":
			return CAST_DRILL
		"stat":
			match id:
				"strength":
					return POWER_DRILL
				"defense", "health":
					return GUARD_DRILL
				"agility", "evasion":
					return DODGE_DRILL
				"endurance":
					return STAMINA_DRILL
			return ATTACK_DRILL
	match id:
		"block", "block_control", "defense", "defense_control":
			return GUARD_DRILL
		"dodge", "dodge_control", "timing":
			return DODGE_DRILL
		"movement", "positioning":
			return FOOTWORK_DRILL
		"stamina", "stamina_discipline":
			return STAMINA_DRILL
		"recovery", "recovery_control":
			return RECOVERY_DRILL
	return ATTACK_DRILL


## `ui_parent` hosts the progress overlay (a CanvasLayer child).
func begin(target: String, ui_parent: Node) -> void:
	_drill = drill_for(target)
	if GameEnums.target_kind(target) == "weapon":
		champion.set_weapon(GameEnums.target_id(target))
	elif GameEnums.target_kind(target) == "magic":
		champion.set_aura(GameEnums.target_id(target))
	_champion_from = champion.position
	if mentor != null:
		_mentor_from = mentor.position
		_mentor_home = mentor.position
		_mentor_home_rotation = mentor.rotation.y
	_build_overlay(ui_parent)
	_enter("gather")


func is_running() -> bool:
	return not _phase.is_empty()


## Ends the drill early (Skip button, back button).
func skip() -> void:
	if _phase == "gather" or _phase == "drill":
		_enter("closing")
	elif _phase == "closing" or _phase == "return":
		_finish()


func _process(delta: float) -> void:
	if _phase.is_empty():
		return
	_phase_time += delta
	match _phase:
		"gather":
			var t := clampf(_phase_time / GATHER_SECONDS, 0.0, 1.0)
			_walk(champion, _champion_from, _champion_spot(), t)
			if mentor != null:
				_walk(mentor, _mentor_from, _mentor_spot(), t)
			if t >= 1.0:
				_enter("drill")
		"drill":
			_elapsed += delta
			_beat_time -= delta
			if _beat_time <= 0.0:
				_play_beat()
			_update_overlay()
			if _elapsed >= seconds:
				_enter("closing")
		"closing":
			if _phase_time >= CLOSING_SECONDS:
				_enter("return")
		"return":
			var t := clampf(_phase_time / RETURN_SECONDS, 0.0, 1.0)
			if mentor != null:
				_walk(mentor, _mentor_spot(), _mentor_home, t)
			if t >= 1.0:
				_finish()


func _enter(phase: String) -> void:
	_phase = phase
	_phase_time = 0.0
	match phase:
		"drill":
			_face_each_other()
			_beat_index = 0
			_beat_time = 0.0
		"closing":
			_elapsed = seconds
			_update_overlay()
			_place(champion, _champion_spot())
			champion.play("victory", CLOSING_SECONDS)
			if mentor != null:
				_place(mentor, _mentor_spot())
				mentor.play("idle", CLOSING_SECONDS)
			_face_each_other()
			Sfx.play("ui_confirm")
		"return":
			champion.release()
			if mentor != null:
				mentor.release()


func _finish() -> void:
	_phase = ""
	champion.release()
	if mentor != null:
		_place(mentor, _mentor_home)
		mentor.rotation.y = _mentor_home_rotation
		mentor.release()
		mentor.set_locomotion(0.0)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	finished.emit()


func _play_beat() -> void:
	var pair: Array = _drill[_beat_index % _drill.size()]
	_beat_index += 1
	_beat_time = BEAT_SECONDS
	champion.play(pair[0], BEAT_SECONDS * 0.9)
	if mentor != null:
		mentor.play(pair[1], BEAT_SECONDS * 0.9)
	if CLIP_SOUNDS.has(pair[0]):
		Sfx.play(CLIP_SOUNDS[pair[0]])


func _champion_spot() -> Vector3:
	return yard + Vector3(0.85, 0.0, 0.6)


func _mentor_spot() -> Vector3:
	return yard + Vector3(-0.85, 0.0, 0.6)


func _walk(body: CharacterVisual, from: Vector3, to: Vector3, t: float) -> void:
	var step := to - from
	step.y = 0.0
	body.position = from.lerp(to, t)
	if t < 1.0 and step.length() > 0.05:
		body.rotation.y = atan2(-step.x, -step.z)
		body.set_locomotion(1.0)
	else:
		body.set_locomotion(0.0, true)


func _place(body: CharacterVisual, spot: Vector3) -> void:
	body.position = spot


func _face_each_other() -> void:
	if mentor == null:
		champion.rotation.y = atan2(-(yard.x - champion.position.x), -(yard.z - champion.position.z))
		return
	var to_mentor := mentor.position - champion.position
	champion.rotation.y = atan2(-to_mentor.x, -to_mentor.z)
	mentor.rotation.y = atan2(to_mentor.x, to_mentor.z)


func _build_overlay(ui_parent: Node) -> void:
	_overlay = MarginContainer.new()
	# Bottom centre, above the lodge's menu buttons, clear of the top bar.
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_overlay.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_overlay.position.y -= 110 + UiKit.safe_insets().w
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.theme = UiTheme.get_theme()
	var panel := UiKit.panel("SheetPanel")
	panel.custom_minimum_size = Vector2(560, 0)
	_overlay.add_child(panel)
	var column := UiKit.vbox(8)
	panel.add_child(column)
	var header := UiKit.hbox(12)
	header.add_child(UiKit.heading(title))
	header.add_child(UiKit.spacer(false))
	header.add_child(UiKit.button("Skip ▸▸", skip, "FlatButton"))
	column.add_child(header)
	_bar = UiKit.bar(0.0, seconds, UiTheme.ACCENT, 18.0)
	column.add_child(_bar)
	_time_label = UiKit.label("", "DimLabel")
	column.add_child(_time_label)
	ui_parent.add_child(_overlay)
	_update_overlay()


func _update_overlay() -> void:
	if _bar == null:
		return
	_bar.value = minf(_elapsed, seconds)
	var left := ceili(maxf(seconds - _elapsed, 0.0))
	_time_label.text = "Session complete" if left <= 0 else "%d s left" % left
