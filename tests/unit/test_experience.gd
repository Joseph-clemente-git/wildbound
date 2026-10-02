extends TestCase
## Experience tracks, anti-farming, difficulty weighting and natural growth.

var champion: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	champion = Game.champion()
	champion.weapon_id = "sword_training"


func _session(power_ratio: float = 1.0) -> ExperienceSession:
	return ExperienceSession.new(champion, champion.power_rating() * power_ratio)


func test_meaningful_events_feed_matching_tracks() -> void:
	var session := _session()
	session.report("dodge", 1.0)
	session.report("block", 2.0)
	session.report("heavy_hit", 3.0)
	session.report("hit", 4.0)
	check(session.gains.get("evasion", 0.0) > 0.0, "dodge -> evasion")
	check(session.gains.get("defense", 0.0) > 0.0, "block -> defense")
	check(session.gains.get("strength", 0.0) > 0.0, "heavy -> strength")
	check(session.gains.get("offensive", 0.0) > 0.0, "hit -> offensive")
	check(session.gains.get("weapon:sword", 0.0) > 0.0, "hit -> sword familiarity")
	check(not session.gains.has("magic:fire"), "no magic without an equipped art")


func test_repeated_actions_have_diminishing_returns() -> void:
	var session := _session()
	var first := session.report("dodge", 1.0)
	var second := session.report("dodge", 1.5)
	var third := session.report("dodge", 2.0)
	check(second < first and third < second, "%s %s %s" % [first, second, third])
	for i in 40:
		session.report("dodge", 2.0 + i * 0.3)
	var spam := session.report("dodge", 14.3)
	check(spam <= first * Content.config.repeat_floor + 0.001, "spam reaches the floor")
	# After a quiet pause the action is meaningful again.
	var rested := session.report("dodge", 200.0)
	check_near(rested, first, 0.01, "memory fades")


func test_per_battle_cap() -> void:
	var session := _session()
	for i in 500:
		session.report("block", i * 10.0)  # spaced out: no repeat penalty
	check(session.gains["defense"] <= Content.config.per_battle_track_cap + 0.001)


func test_difficulty_weighting() -> void:
	var weak := _session(0.5)
	var even := _session(1.0)
	var hard := _session(1.6)
	var a := weak.report("hit", 1.0)
	var b := even.report("hit", 1.0)
	var c := hard.report("hit", 1.0)
	check(a < b and b < c, "%s < %s < %s" % [a, b, c])
	check_near(weak.difficulty_multiplier, 0.75)
	check_near(even.difficulty_multiplier, 1.0)
	check_near(hard.difficulty_multiplier, 1.5)


func test_growth_event_at_threshold_without_manual_points() -> void:
	var before := champion.developed_stat("evasion")
	champion.experience.add("evasion", champion.experience.threshold("evasion") + 5.0)
	var events := GrowthSystem.process(champion)
	check(not events.is_empty(), "growth happened")
	check(champion.developed_stat("evasion") > before, "evasion developed")
	check_near(champion.experience.get_xp("evasion"), 5.0, 0.01, "threshold consumed")
	check_eq(champion.experience.get_growths("evasion"), 1)
	check(champion.experience.threshold("evasion") > Content.config.growth_threshold_base, "next threshold rises")


func test_resilience_develops_health_and_endurance() -> void:
	var health := champion.developed_stat("health")
	var endurance := champion.developed_stat("endurance")
	champion.experience.add("resilience", champion.experience.threshold("resilience"))
	GrowthSystem.process(champion)
	check(champion.developed_stat("health") > health)
	check(champion.developed_stat("endurance") > endurance)


func test_growth_stops_at_potential_but_keeps_experience() -> void:
	champion.natural_growth["agility"] = champion.potential("agility")
	var threshold := champion.experience.threshold("agility")
	champion.experience.add("agility", threshold * 3.0)
	var events := GrowthSystem.process(champion)
	check(events.is_empty(), "no growth past potential")
	check_near(champion.experience.get_xp("agility"), threshold, 0.01, "experience stays banked")


func test_experience_slows_near_potential() -> void:
	var session := _session()
	var fresh := session.potential_factor("agility")
	champion.natural_growth["agility"] = champion.potential("agility") - champion.base_stat("agility") - 1.0
	var near := session.potential_factor("agility")
	check_near(fresh, 1.0)
	check(near < 0.5, "near potential: %s" % near)


func test_weapon_familiarity_is_capped_without_trainer() -> void:
	for i in 30:
		champion.experience.add("weapon:sword", champion.experience.threshold("weapon:sword"))
		GrowthSystem.process(champion)
	check_eq(champion.skills.get_rank("weapon:sword"), Content.config.natural_rank_cap,
			"familiarity stops where mastery (trainers) begins")


func test_magic_familiarity_requires_learning() -> void:
	champion.experience.add("magic:fire", 500.0)
	GrowthSystem.process(champion)
	check_eq(champion.skills.get_rank("magic:fire"), GameEnums.Rank.NONE)


func test_sessions_bank_across_battles_and_grow() -> void:
	var growths: Array = []
	for battle in 2:
		var session := _session(1.6)
		for i in 30:
			session.report("perfect_dodge", i * 7.0)
		var result := session.commit()
		check(result["gains"].get("evasion", 0.0) > 0.0)
		growths.append_array(result["growths"])
		check(session.report("dodge", 999.0) == 0.0, "committed sessions ignore new events")
	check(not growths.is_empty(), "two hard fights of perfect dodges grow evasion")
