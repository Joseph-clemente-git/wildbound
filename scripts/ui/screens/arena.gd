extends Node3D
## The trial ground: a 1v1 battle between the Keeper's champion and a rival.
## Params: {"trial": trial id}. On the end of the battle the outcome is
## handed to the Battle Result screen.

const INTRO_SECONDS := 2.4
const OUTRO_SECONDS := 2.6

var trial: TrialData
var opponent_data: OpponentData
var battle: BattleManager
var hero: Combatant
var foe: Combatant
var hud: BattleHud
var camera: BattleCamera
var controller: PlayerController
var recorder: BattleRecorder

var _paused_modal: Control
var _telegraph: Label3D
var _obstacles: Array[GeometryInstance3D] = []
var _hit_stop := 0.0


func _ready() -> void:
	if not Game.is_active():
		Router.go("title")
		return
	trial = Content.trial(Router.params.get("trial", "first_steps"))
	opponent_data = Content.opponent(trial.opponent_id)
	if not Router.params.get("entered", false):
		TrialSystem.enter(Game.champion(), trial)  # direct entry (debug/scenarios)
	var arena_data := Content.arena(trial.arena_id)
	_obstacles.assign(ArenaBuilder.build(self, arena_data).get_meta("obstacles", []))
	Sfx.stop_ambient()

	battle = BattleManager.new()
	add_child(battle)
	var champion := Game.champion()
	hero = _make_fighter(CharacterFactory.for_champion(champion))
	hero.setup_from_champion(champion)
	foe = _make_fighter(CharacterFactory.for_opponent(opponent_data))
	foe.setup_from_opponent(opponent_data)
	battle.add_child(hero)
	battle.add_child(foe)
	battle.setup(arena_data, hero, foe)
	_dress(hero, hero.weapon, hero.armor, hero.ability)
	_dress(foe, foe.weapon, foe.armor, foe.ability)
	battle.effect_spawner = func(ability: MagicAbilityData, caster: Combatant, data: Dictionary) -> Node3D:
		return MagicVisuals.spawn_effect(battle, ability, caster, data)
	battle.ai = AiController.new(foe, opponent_data)

	camera = BattleCamera.new()
	camera.player = hero
	camera.opponent = foe
	camera.limit = arena_data.camera_limit
	add_child(camera)
	camera.snap()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = BattleHud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(hud)
	hud.bind(hero, foe, opponent_data.title)
	hud.pause_requested.connect(_pause)
	controller = PlayerController.new(hero, camera, hud.joystick)
	controller.enabled = false
	battle.player_controller = controller
	recorder = BattleRecorder.new(battle, champion, opponent_data, trial)

	battle.hint.connect(hud.show_hint)
	battle.floating_text.connect(_floating_text)
	battle.combat_event.connect(_feedback)
	battle.ended.connect(_on_ended)
	Router.back_requested.connect(_pause)
	_intro()


func _make_fighter(visual: CharacterVisual) -> Combatant:
	var fighter := Combatant.new()
	fighter.add_child(visual)
	fighter.visual = visual
	return fighter


func _dress(fighter: Combatant, weapon: WeaponData, armor: ArmorData, ability: MagicAbilityData) -> void:
	var visual := fighter.visual
	visual.set_weapon(weapon.weapon_type if weapon != null else "")
	visual.set_armor(armor.weight_class if armor != null else -1)
	visual.set_aura(ability.school if ability != null else "")
	visual.set_locomotion(0.0, true)


func _intro() -> void:
	hud.set_controls_visible(false)
	hud.show_banner(trial.display_name, UiTheme.ACCENT, 1.0)
	hud.show_hint(opponent_data.intro_line, 3.5)
	await get_tree().create_timer(INTRO_SECONDS).timeout
	if not is_inside_tree():
		return
	hud.set_controls_visible(true)
	hud.show_banner("Begin!", UiTheme.TEXT, 0.6)
	controller.enabled = true
	battle.start()
	recorder.start()


func _process(delta: float) -> void:
	if _hit_stop > 0.0:
		_hit_stop -= delta / maxf(Engine.time_scale, 0.01)
		if _hit_stop <= 0.0:
			Engine.time_scale = 1.0
	_update_telegraph()
	_teach_by_doing()
	_fade_obstructions(delta)


## Limited obstruction (mechanics §69): rocks between the camera and the
## fighters turn see-through.
func _fade_obstructions(delta: float) -> void:
	if camera == null or hero == null:
		return
	var from := Vector2(camera.global_position.x, camera.global_position.z)
	var focus := hero.planar_position().lerp(foe.planar_position(), 0.3)
	var to := Vector2(focus.x, focus.z)
	for node in _obstacles:
		var spot := Vector2(node.global_position.x, node.global_position.z)
		var closest := Geometry2D.get_closest_point_to_segment(spot, from, to)
		var blocking := closest.distance_to(spot) < 1.4 and closest.distance_to(to) > 0.6
		# Per-material alpha (GeometryInstance3D.transparency is not available
		# in the Compatibility renderer).
		var material := node.material_override as StandardMaterial3D
		var alpha := move_toward(material.albedo_color.a, 0.3 if blocking else 1.0, delta * 3.0)
		material.albedo_color.a = alpha
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if alpha > 0.6 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## In-world warning while the opponent winds up: shape and colour differ by
## threat (! light, !! heavy, ◆ Aether) so it never relies on colour alone.
func _update_telegraph() -> void:
	if _telegraph == null:
		_telegraph = Label3D.new()
		_telegraph.font_size = 96
		_telegraph.outline_size = 18
		_telegraph.pixel_size = 0.006
		_telegraph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_telegraph.no_depth_test = true
		add_child(_telegraph)
	var active := foe != null and foe.is_alive() and foe.is_winding_up()
	_telegraph.visible = active
	if not active:
		return
	match foe.state:
		Combatant.State.HEAVY:
			_telegraph.text = "!!"
			_telegraph.modulate = UiTheme.BAD
		Combatant.State.CAST:
			_telegraph.text = "◆"
			_telegraph.modulate = UiTheme.AETHER
		_:
			_telegraph.text = "!"
			_telegraph.modulate = UiTheme.WARN
	var progress := clampf(foe.phase_time / maxf(float(foe.current_attack.get("windup", 0.3)), 0.01), 0.0, 1.0)
	_telegraph.global_position = foe.global_position + Vector3(0, 2.25 + 0.15 * progress, 0)
	_telegraph.scale = Vector3.ONE * (0.8 + 0.4 * progress)


## Teach by doing (ui-ux-game onboarding): in the tutorial trial, or with
## hints on, the button that fits the moment pulses — no text needed.
func _teach_by_doing() -> void:
	if not battle.running or not (trial.tutorial or Settings.get_value("combat_assist")) \
			or not Settings.get_value("show_hints"):
		return
	var distance := hero.planar_position().distance_to(foe.planar_position())
	if foe.is_winding_up() and distance < foe.stats.attack_range + 1.5:
		hud.pad.pulse("dodge")
	elif foe.is_recovering() and distance < hero.stats.attack_range + 0.8:
		hud.pad.pulse("attack")
	elif foe.is_blocking() and foe.state_time > 0.6 and distance < hero.stats.attack_range + 0.8:
		hud.pad.pulse("heavy")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_pause()


# --- Feedback --------------------------------------------------------------------

func _feedback(who: Combatant, kind: String, data: Dictionary) -> void:
	match kind:
		"attack_result":
			var outcome: String = data.get("outcome", "")
			if outcome in ["stagger", "guard_break", "ko"] or (outcome == "hit" and data.get("heavy", false)):
				camera.shake(0.8 if data.get("heavy", false) else 0.5)
				_hit_pause(0.07)
			elif outcome == "hit":
				_hit_pause(0.035)
			if who == hero and outcome == "hit":
				_vibrate(25)
		"damaged":
			if who == hero:
				_vibrate(50)
		"exhausted":
			if who == hero:
				Sfx.play("exhausted")
				hud.show_hint("%s is exhausted! Stamina will return — keep your distance." % who.display_name, 2.5)
		"too_tired":
			if who == hero:
				_floating_text(hero.global_position + Vector3(0, 2.1, 0), "Too tired", UiTheme.WARN)
		"not_ready":
			if who == hero:
				_floating_text(hero.global_position + Vector3(0, 2.1, 0), "Not ready", UiTheme.TEXT_DIM)
		"interrupted":
			_floating_text(who.global_position + Vector3(0, 2.3, 0), "Interrupted!", UiTheme.WARN)


func _hit_pause(seconds: float) -> void:
	if Settings.get_value("reduce_motion"):
		return
	Engine.time_scale = 0.15
	_hit_stop = seconds


func _vibrate(milliseconds: int) -> void:
	if Settings.get_value("vibration") and OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)


func _floating_text(world_position: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.global_position = world_position
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 0.8, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


# --- Pause / end ---------------------------------------------------------------------

func _pause() -> void:
	if battle.finished or _paused_modal != null:
		return
	get_tree().paused = true
	_paused_modal = UiKit.modal(hud, "Paused", 520)
	var column := UiKit.vbox(12)
	_paused_modal.add_child(column)
	column.add_child(UiKit.label(trial.display_name, "DimLabel"))
	column.add_child(UiKit.primary_button("Resume", _resume))
	column.add_child(UiKit.button("Settings", func() -> void: SettingsPanel.open(hud, false)))
	column.add_child(UiKit.button("Forfeit the trial", func() -> void:
		_resume()
		recorder.forfeited = true
		battle._finish(foe)))


func _resume() -> void:
	get_tree().paused = false
	if _paused_modal != null:
		UiKit.close_modal(_paused_modal)
		_paused_modal = null


func _on_ended(winner: Combatant) -> void:
	controller.enabled = false
	hud.set_controls_visible(false)
	Engine.time_scale = 0.4
	var won := winner == hero
	hud.show_banner("Victory!" if won else "Knocked out", UiTheme.GOOD if won else UiTheme.BAD, 1.4)
	Sfx.play("victory" if won else "defeat")
	winner.visual.play("victory", -1.0, true)
	var outcome := TrialSystem.apply_result(recorder.finish(won))
	await get_tree().create_timer(OUTRO_SECONDS * Engine.time_scale).timeout
	Engine.time_scale = 1.0
	Router.go("result", {"outcome": outcome})
