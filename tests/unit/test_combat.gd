extends TestCase
## Core 1v1 combat: timing, stamina, dodge, block, stagger, knockback, magic.

const DT := 1.0 / 60.0

var battle: BattleManager
var hero: Combatant
var foe: Combatant
var events: Array = []


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	var champion := Game.champion()
	Game.profile.add_item("sword_training")
	champion.weapon_id = "sword_training"
	battle = BattleManager.new()
	battle.auto_step = false
	root.add_child(battle)
	hero = Combatant.new()
	hero.setup_from_champion(champion)
	foe = Combatant.new()
	foe.setup_from_opponent(Content.opponent("pip"))
	battle.add_child(hero)
	battle.add_child(foe)
	battle.setup(Content.arena("meadow_ring"), hero, foe)
	hero.position = Vector3(0, 0, 1)
	foe.position = Vector3(0, 0, -0.6)
	battle._face_each_other()
	events.clear()
	battle.combat_event.connect(func(who: Combatant, kind: String, data: Dictionary) -> void:
		events.append([who, kind, data]))
	battle.start()


func _run(seconds: float) -> void:
	for i in int(seconds / DT):
		battle.step(DT)


func _has_event(who: Combatant, kind: String, key: String = "", value: Variant = null) -> bool:
	for entry: Array in events:
		if entry[0] == who and entry[1] == kind and (key.is_empty() or entry[2].get(key) == value):
			return true
	return false


func after() -> void:
	battle.queue_free()


func test_attack_lands_after_windup() -> void:
	var before := foe.health
	hero.request("attack")
	battle.step(DT)
	check_eq(hero.state, Combatant.State.ATTACK)
	check_eq(foe.health, before, "no damage during wind-up")
	_run(0.5)
	check(foe.health < before, "damage after wind-up")
	check(_has_event(hero, "attack_result", "outcome", "hit"))
	check(hero.stamina < hero.stats.max_stamina, "attacks cost stamina")
	after()


func test_dodge_iframes_evade() -> void:
	foe.request("attack")
	battle.step(DT)
	hero.move_input = Vector2(0, -1)  # dodge through the opponent's swing
	_run(foe.current_attack["windup"] - 0.05)
	hero.request("dodge")
	var hp := hero.health
	_run(0.3)
	check_eq(hero.health, hp, "dodged attack deals no damage")
	check(_has_event(hero, "evaded", "perfect", true), "late dodge through the swing is perfect")


func test_sidestep_repositions_out_of_reach() -> void:
	foe.request("attack")
	battle.step(DT)
	hero.move_input = Vector2(0.3, 1)  # step back and aside during the wind-up
	var hp := hero.health
	_run(foe.current_attack["windup"] + 0.2)
	check_eq(hero.health, hp)
	check(_has_event(hero, "repositioned"), "moving out of a committed attack is repositioning")
	after()


func test_block_reduces_damage_and_drains_stamina() -> void:
	hero.block_held = true
	_run(0.5)  # not a perfect block
	check_eq(hero.state, Combatant.State.BLOCK)
	var hp := hero.health
	var stamina := hero.stamina
	foe.request("attack")
	_run(1.0)
	var blocked_damage := hp - hero.health
	check(_has_event(hero, "blocked", "perfect", false))
	check(blocked_damage > 0.0 and blocked_damage < foe.stats.damage * 0.5, "chip damage only: %s" % blocked_damage)
	check(hero.stamina < stamina, "guard costs stamina")
	after()


func test_perfect_block_parries() -> void:
	foe.request("attack")
	battle.step(DT)
	_run(foe.current_attack["windup"] - 0.08)
	hero.block_held = true
	var hp := hero.health
	_run(0.2)
	check_eq(hero.health, hp, "perfect block takes nothing")
	check(_has_event(hero, "blocked", "perfect", true))
	check_eq(foe.state, Combatant.State.STAGGER, "attacker is parried")
	after()


func test_stamina_exhaustion() -> void:
	for i in 40:
		hero.request("attack")
		_run(0.25)
	check(_has_event(hero, "exhausted"), "spamming attacks exhausts")
	check(hero.is_exhausted())
	hero.request("dodge")
	battle.step(DT)
	check(hero.state != Combatant.State.DODGE, "cannot dodge while exhausted")
	_run(6.0)
	check(not hero.is_exhausted(), "breath recovers")
	after()


func test_hammer_staggers_and_knocks_back() -> void:
	Game.profile.add_item("hammer_iron")
	Game.champion().weapon_id = "hammer_iron"
	hero.setup_from_champion(Game.champion())
	var start := foe.planar_position()
	hero.request("heavy")
	_run(1.6)
	check(_has_event(hero, "attack_result", "outcome", "stagger"), "heavy hammer staggers")
	check(foe.planar_position().distance_to(start) > 0.6, "knockback moves the target")
	after()


func test_sword_and_hammer_feel_different() -> void:
	var sword := CombatStats.for_champion(Game.champion(), {"weapon_id": "sword_training"})
	var hammer := CombatStats.for_champion(Game.champion(), {"weapon_id": "hammer_iron"})
	check(hammer.windup > sword.windup * 1.5, "hammer is slow")
	check(hammer.recovery > sword.recovery * 1.5, "hammer has long recovery")
	check(hammer.attack_stamina > sword.attack_stamina * 1.5, "hammer is tiring")
	check(hammer.stagger_power > sword.stagger_power * 2.0, "hammer staggers")
	check(hammer.damage > sword.damage, "hammer hits harder")


func test_ko_ends_battle() -> void:
	var winners: Array = []
	battle.ended.connect(func(w: Combatant) -> void: winners.append(w))
	foe.health = 1.0
	hero.request("attack")
	_run(0.6)
	check(not foe.is_alive())
	check(battle.finished)
	check_eq(winners, [hero])
	after()


func test_arena_boundary_and_obstacles() -> void:
	hero.position = Vector3(50, 0, 0)
	battle.constrain(hero)
	check(hero.planar_position().length() <= battle.arena_radius)
	var rock: Vector4 = battle.obstacles[0]
	hero.position = Vector3(rock.x, 0, rock.y)
	battle.constrain(hero)
	check(hero.planar_position().distance_to(Vector3(rock.x, 0, rock.y)) >= rock.z, "pushed out of the rock")
	after()


func test_fire_bolt_projectile_and_interrupt() -> void:
	hero.ability = Content.ability("ember_bolt")
	hero.ability_rank = 1
	foe.position = Vector3(0, 0, -6)
	battle._face_each_other()
	var hp := foe.health
	hero.request("magic")
	_run(2.0)
	check(foe.health < hp, "ember bolt hits")
	check(foe.burn_time >= 0.0)
	check(hero.cooldown > 0.0, "ability cooldown")
	# Interrupt: hit during the cast wind-up cancels it.
	hero.cooldown = 0.0
	foe.position = Vector3(0, 0, -0.6)
	battle._face_each_other()
	hero.request("magic")
	battle.step(DT)
	foe.request("attack")
	_run(0.5)
	check(_has_event(hero, "interrupted"), "cast interrupted by a hit")
	after()


func test_gale_push_knocks_back() -> void:
	hero.ability = Content.ability("gale_push")
	hero.ability_rank = 1
	foe.position = Vector3(0, 0, -2.5)
	battle._face_each_other()
	var start := foe.planar_position()
	hero.request("magic")
	_run(1.0)
	check(foe.planar_position().distance_to(start) > 2.0, "wind pushes the opponent away")
	after()


func test_riposte_after_block() -> void:
	hero.techniques.append("riposte")
	hero.block_held = true
	_run(0.5)
	foe.request("attack")
	_run(0.9)
	hero.block_held = false
	battle.step(DT)
	hero.request("attack")
	_run(0.6)
	check(_has_event(hero, "technique_used", "technique", "riposte"))
	after()


func test_guard_break_technique() -> void:
	Game.profile.add_item("hammer_iron")
	Game.champion().weapon_id = "hammer_iron"
	hero.setup_from_champion(Game.champion())
	hero.techniques.append("guard_break")
	foe.block_held = true
	_run(0.5)
	hero.request("heavy")
	_run(1.5)
	check(_has_event(hero, "attack_result", "outcome", "guard_break"))
	after()


func test_ai_battle_reaches_a_result() -> void:
	battle.ai = AiController.new(foe, Content.opponent("pip"), 7)
	var hero_ai_profile := Content.opponent("juniper")
	var hero_ai := AiController.new(hero, hero_ai_profile, 3)
	battle.player_controller = hero_ai
	hero.position = Vector3(0, 0, 5)
	foe.position = Vector3(0, 0, -5)
	_run(150.0)
	check(battle.finished, "battle ends")
	check(_has_event(foe, "attack_result") and _has_event(hero, "attack_result"), "both fought")
	after()
