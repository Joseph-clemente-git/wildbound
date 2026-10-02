extends TestCase
## Stage 9 of the battle simulation: attack resolution. Whether an attack
## reaches anyone is geometry — reach, arc, facing, obstacles and travel —
## never a roll.

const A := CombatantState.Action

var champion: Champion
var plan: Dictionary = {}
var sim: BattleSimulator


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	for item_id in ["sword_training", "hammer_iron"]:
		Game.profile.add_item(item_id)
	champion.weapon_id = "sword_training"
	plan = {}
	sim = _make()


func _make(players: Array[CombatantSpec] = [], opponents: Array[CombatantSpec] = []) -> BattleSimulator:
	if players.is_empty():
		players = [CombatantSpec.from_champion(champion)]
	if opponents.is_empty():
		opponents = [CombatantSpec.from_opponent(Content.opponent("rook"))]
	var made := BattleSimulator.create(BattleState.create(Content.arena("meadow_ring"), players, opponents, 3))
	made.use_phase(ScriptedDecisionPhase.new(func(_s: BattleState, fighter: CombatantState, _f: SimFrame) -> Dictionary:
		return plan.get(fighter.index, {})))
	return made


func _place(index: int, position: Vector2, facing_toward: Vector2) -> void:
	var fighter := sim.state.combatants[index]
	fighter.position = position
	fighter.facing = (facing_toward - position).normalized()
	fighter.velocity = Vector2.ZERO


## Hero swings once at a target standing at `offset` from it; returns hits.
func _swing_at(offset: Vector2, heavy: bool = false, ticks: int = 40) -> Array[Dictionary]:
	_place(0, Vector2(0, 2), Vector2(0, 2) + Vector2(0, -1))
	_place(1, Vector2(0, 2) + offset, Vector2(0, 2))
	plan[0] = {"action": "heavy" if heavy else "attack"}
	var hits: Array[Dictionary] = []
	for i in ticks:
		var frame := sim.step()
		plan.erase(0)
		sim.state.combatants[0].facing = Vector2(0, -1)  # hold the aim for the test
		hits.append_array(frame.hits)
	return hits


func test_in_reach_and_in_front_connects() -> void:
	var hits := _swing_at(Vector2(0, -1.6))
	check_eq(hits.size(), 1, "one swing strikes once even across several active ticks")
	check_eq(hits[0]["attacker"], 0)
	check_eq(hits[0]["target"], 1)
	check_eq(hits[0]["via"], "melee")
	check_eq(hits[0]["kind"], "light")
	check(hits[0]["direction"].dot(Vector2(0, -1)) > 0.99, "direction of the blow")
	check(sim.battle_log.events_of("whiff").is_empty())


func test_out_of_reach_whiffs() -> void:
	var reach := sim.state.combatants[0].spec.derived.attack_range
	var hits := _swing_at(Vector2(0, -(reach + CombatantState.BODY_RADIUS + 0.4)))
	check(hits.is_empty(), "too far")
	check_eq(sim.battle_log.events_of("whiff").size(), 1, "a swing that meets air is a whiff")


func test_behind_the_arc_is_safe() -> void:
	check(_swing_at(Vector2(1.5, 0.2)).is_empty(), "beside and slightly behind the sword's arc")
	before_each()
	check_eq(_swing_at(Vector2(0.9, -1.2)).size(), 1, "inside the arc")


func test_reach_differs_by_weapon() -> void:
	var spear := CombatantSpec.from_champion(champion)
	spear.weapon = Content.weapon("spear_ash")
	spear.refresh()
	var players: Array[CombatantSpec] = [spear]
	sim = _make(players)
	check_eq(_swing_at(Vector2(0, -3.0)).size(), 1, "a spear reaches what a sword cannot")
	before_each()
	check(_swing_at(Vector2(0, -3.0)).is_empty())


func test_obstacles_block_the_line() -> void:
	var rock := sim.state.layout.obstacles[0]
	var centre := Vector2(rock.x, rock.y)
	check(not ContactPhase.line_clear(sim.state, centre + Vector2(-2, 0), centre + Vector2(2, 0)))
	check(ContactPhase.line_clear(sim.state, centre + Vector2(-2, rock.z + 0.3), centre + Vector2(2, rock.z + 0.3)))
	var hero := sim.state.combatants[0]
	var foe := sim.state.combatants[1]
	hero.position = centre + Vector2(-(rock.z + 0.5), 0)
	foe.position = centre + Vector2(rock.z + 0.5, 0)
	hero.facing = Vector2.RIGHT
	check(not ContactPhase.in_reach(sim.state, hero, foe, 10.0, 360.0), "no striking through a standing stone")


func test_a_wide_swing_can_catch_two() -> void:
	var players: Array[CombatantSpec] = [CombatantSpec.from_champion(champion)]
	var opponents: Array[CombatantSpec] = [CombatantSpec.from_opponent(Content.opponent("pip")),
			CombatantSpec.from_opponent(Content.opponent("juniper"))]
	sim = _make(players, opponents)
	_place(0, Vector2(0, 2), Vector2(0, 0))
	_place(1, Vector2(-0.6, 0.6), Vector2(0, 2))
	_place(2, Vector2(0.6, 0.6), Vector2(0, 2))
	plan[0] = {"action": "attack"}
	var targets := {}
	for i in 30:
		var frame := sim.step()
		plan.erase(0)
		sim.state.combatants[0].facing = Vector2(0, -1)
		for hit in frame.hits:
			targets[hit["target"]] = true
	check_eq(targets.size(), 2, "both enemies in the arc")


func test_teammates_are_never_struck() -> void:
	var players: Array[CombatantSpec] = [CombatantSpec.from_champion(champion), CombatantSpec.from_opponent(Content.opponent("pip"))]
	sim = _make(players)
	_place(0, Vector2(0, 2), Vector2(0, 0))
	_place(1, Vector2(0, 0.8), Vector2(0, 2))  # teammate right in front
	_place(2, Vector2(5, -5), Vector2(0, 0))
	plan[0] = {"action": "attack"}
	for i in 30:
		var frame := sim.step()
		plan.erase(0)
		sim.state.combatants[0].facing = Vector2(0, -1)
		check(frame.hits.is_empty(), "no friendly hits")


func test_projectile_art_travels_and_connects() -> void:
	champion.skills.set_rank("magic:fire", GameEnums.Rank.FOUNDATION)
	champion.equipped_ability = "ember_bolt"
	sim = _make()
	var ember := Content.ability("ember_bolt")
	_place(0, Vector2(0, 4), Vector2(0, -4))
	_place(1, Vector2(0, -4), Vector2(0, 4))
	sim.state.combatants[0].target_index = 1
	plan[0] = {"action": "cast"}
	var released := -1
	var landed := -1
	for i in 120:
		var frame := sim.step()
		plan.erase(0)
		if released < 0 and not frame.events_of("projectile").is_empty():
			released = frame.tick
		if not frame.hits.is_empty():
			landed = frame.tick
			check_eq(frame.hits[0]["via"], "projectile")
			check_eq(frame.hits[0]["ability"], "ember_bolt")
			break
	check(released > 0 and landed > released, "the bolt flies before it lands")
	var flight := (landed - released) * sim.tick_seconds
	var expected := (8.0 - CombatantState.BODY_RADIUS * 2.0 - ember.radius * 2.0) / ember.speed
	check(absf(flight - expected) < 0.15, "flight %.2fs at the bolt's speed (expected ~%.2fs)" % [flight, expected])
	check(sim.state.projectiles.is_empty())


func test_sidestepping_a_bolt() -> void:
	champion.skills.set_rank("magic:fire", GameEnums.Rank.FOUNDATION)
	champion.equipped_ability = "ember_bolt"
	sim = _make()
	_place(0, Vector2(0, 5), Vector2(0, -5))
	_place(1, Vector2(0, -5), Vector2(0, 5))
	sim.state.combatants[0].target_index = 1
	plan[0] = {"action": "cast"}
	var hits := 0
	for i in 150:
		var frame := sim.step()
		plan.erase(0)
		if not frame.events_of("projectile").is_empty():
			plan[1] = {"move": Vector2.RIGHT}  # the target steps aside once it sees the bolt
		hits += frame.hits.size()
	check_eq(hits, 0, "a slow bolt is answered by moving")
	check_eq(sim.battle_log.events_of("projectile_faded").size(), 1, "and flies on until it fades")


func test_obstacles_stop_shots() -> void:
	champion.skills.set_rank("magic:fire", GameEnums.Rank.FOUNDATION)
	champion.equipped_ability = "ember_bolt"
	sim = _make()
	var rock := sim.state.layout.obstacles[0]
	var centre := Vector2(rock.x, rock.y)
	_place(0, centre + Vector2(-3, 0), centre)
	_place(1, centre + Vector2(3, 0), centre)
	sim.state.combatants[0].target_index = 1
	plan[0] = {"action": "cast"}
	var hits := 0
	for i in 90:
		var frame := sim.step()
		plan.erase(0)
		hits += frame.hits.size()
	check_eq(hits, 0)
	check_eq(sim.battle_log.events_of("projectile_blocked").size(), 1, "the stone takes the bolt")


func test_area_arts() -> void:
	var caster := CombatantSpec.from_champion(champion)
	caster.ability = Content.ability("gale_push")
	caster.refresh()
	var players: Array[CombatantSpec] = [caster]
	sim = _make(players)
	_place(0, Vector2(0, 3), Vector2(0, 0))
	_place(1, Vector2(0, -0.5), Vector2(0, 3))
	plan[0] = {"action": "cast"}
	var via := []
	for i in 40:
		var frame := sim.step()
		plan.erase(0)
		for hit in frame.hits:
			via.append(hit["via"])
	check_eq(via, ["area"], "the gust reaches into its cone")
	var burst := CombatantSpec.from_champion(champion)
	burst.ability = Content.ability("flame_burst")
	burst.refresh()
	players = [burst]
	sim = _make(players)
	_place(0, Vector2(0, 0), Vector2(0, -1))
	_place(1, Vector2(0, 2.5), Vector2(0, 0))  # behind: a burst has no facing
	plan[0] = {"action": "cast"}
	var hits := 0
	for i in 40:
		var frame := sim.step()
		plan.erase(0)
		hits += frame.hits.size()
	check_eq(hits, 1, "a burst strikes all around")


func test_ranged_weapons_shoot() -> void:
	var archer := CombatantSpec.from_champion(champion)
	archer.weapon = Content.weapon("bow_yew")
	archer.refresh()
	var players: Array[CombatantSpec] = [archer]
	sim = _make(players)
	_place(0, Vector2(0, 5), Vector2(0, -5))
	_place(1, Vector2(0, -5), Vector2(0, 5))
	plan[0] = {"action": "attack"}
	var hits: Array[Dictionary] = []
	for i in 90:
		var frame := sim.step()
		plan.erase(0)
		hits.append_array(frame.hits)
	check_eq(sim.battle_log.events_of("projectile").size(), 1, "one arrow per shot")
	check_eq(hits.size(), 1)
	check_eq(hits[0]["via"], "projectile")
	check_eq(hits[0]["kind"], "light")
