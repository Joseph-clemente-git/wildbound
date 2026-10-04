extends TestCase
## The Skill Network: the Skill Matrix drawn as prerequisites between nodes.

const S := SkillNetwork.State


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")


func _everything(_stage: String) -> bool:
	return true


func _full() -> SkillNetwork:
	return SkillNetwork.build(Game.champion(), Game.profile, _everything)


func test_early_game_shows_only_what_the_story_revealed() -> void:
	var network := SkillNetwork.build(Game.champion(), Game.profile)
	check(network.nodes.has("skill:attack"), "basic fundamentals are shown")
	check(not network.nodes.has("skill:block"), "block waits for the first training")
	check(not network.nodes.has("weapon:sword"), "weapons wait for the first training")
	check(not network.nodes.has("skill:timing"), "discipline waits for the first trial")
	check(not network.nodes.has("technique:riposte"), "techniques wait for the first trial")
	check(network.has_hidden, "the screen says more is to come")
	for edge: Dictionary in network.edges:
		check(network.nodes.has(edge["from"]) and network.nodes.has(edge["to"]), "no links to hidden nodes")


func test_every_prerequisite_is_a_link() -> void:
	var network := _full()
	check(not network.has_hidden)
	var links := {}
	for edge: Dictionary in network.edges:
		links["%s>%s" % [edge["from"], edge["to"]]] = int(edge["need"])
	for target: String in SkillCatalog.PREREQUISITES:
		var needs: Dictionary = SkillCatalog.PREREQUISITES[target]
		for need: String in needs:
			check_eq(links.get("%s>%s" % [need, target], -1), int(needs[need]), "%s needs %s" % [target, need])
	for technique: TechniqueData in Content.list("techniques"):
		var id := SkillNetwork.technique_id(technique)
		check(network.nodes.has(id), "technique shown: " + technique.id)
		for need: String in technique.prerequisites:
			check(network.nodes.has(need), "%s's prerequisite %s is a node" % [technique.id, need])
			check_eq(links.get("%s>%s" % [need, id], -1), int(technique.prerequisites[need]))
	check(network.nodes["skill:attack"]["opens"].has("skill:timing"), "a node knows what it opens")


func test_states_follow_ranks_mentors_and_prerequisites() -> void:
	var champion := Game.champion()
	var profile := Game.profile
	profile.coins = 9999
	TrainerManager.recruit(profile, "swordmaster_yenbi", true)
	champion.skills.set_rank("skill:attack", GameEnums.Rank.FOUNDATION)
	var network := _full()
	check_eq(network.node("weapon:sword")["state"], S.READY, "Yenbi is active and teaches the sword")
	check_eq(network.node("weapon:hammer")["state"], S.OPEN, "nobody here teaches the hammer")
	check_eq(network.node("skill:timing")["state"], S.LOCKED, "timing needs Attack Novice")
	check(not network.node("skill:timing")["needs"][0]["met"])
	check_eq(network.node("technique:riposte")["state"], S.LOCKED)

	champion.skills.set_rank("skill:attack", GameEnums.Rank.NOVICE)
	champion.skills.set_rank("weapon:sword", GameEnums.Rank.APPRENTICE)
	champion.skills.set_rank("skill:block", GameEnums.Rank.APPRENTICE)
	network = _full()
	check_eq(network.node("skill:timing")["state"], S.READY, "prerequisite met and Yenbi teaches timing")
	check_eq(network.node("weapon:sword")["state"], S.LEARNED)
	check_eq(network.node("weapon:sword")["rank"], GameEnums.Rank.APPRENTICE)
	check_eq(network.node("technique:riposte")["state"], S.READY, "Yenbi teaches Riposte")
	check(network.node("technique:riposte")["active_teachers"].size() == 1)

	champion.techniques.append("riposte")
	champion.skills.set_rank("skill:attack", GameEnums.Rank.MASTER)
	network = _full()
	check_eq(network.node("technique:riposte")["state"], S.LEARNED)
	check_eq(network.node("skill:attack")["state"], S.MASTERED)


func test_magic_mastered_at_the_animals_potential() -> void:
	var champion := Game.champion()
	var cap := champion.rank_cap("magic:fire")
	champion.skills.set_rank("magic:fire", cap)
	var entry := _full().node("magic:fire")
	check_eq(entry["cap"], cap)
	check_eq(entry["state"], S.MASTERED if cap > 0 else S.OPEN)


func test_layout_keeps_stones_and_names_apart() -> void:
	var network := _full()
	var font_width := 10.5  # generous average glyph width at the stone-name size
	var shapes: Array[Dictionary] = []
	for id: String in network.order:
		var entry: Dictionary = network.nodes[id]
		var center := SkillNetworkView.node_center(entry)
		var width := str(entry["name"]).length() * font_width
		var label := Rect2(center + Vector2(-width * 0.5, SkillNetworkView.ORB_RADIUS + 18.0), Vector2(width, 22))
		var orb := Rect2(center - Vector2.ONE * (SkillNetworkView.ORB_RADIUS + 8.0), Vector2.ONE * (SkillNetworkView.ORB_RADIUS + 8.0) * 2.0)
		for other: Dictionary in shapes:
			check(center.distance_to(other["center"]) >= SkillNetworkView.ORB_RADIUS * 2.0 + 24.0, "%s crowds %s" % [id, other["id"]])
			check(not label.intersects(other["label"]), "%s's name overlaps %s's" % [id, other["id"]])
			check(not label.intersects(other["orb"]) and not orb.intersects(other["label"]),
					"%s and %s overlap name and stone" % [id, other["id"]])
		shapes.append({"id": id, "center": center, "label": label, "orb": orb})


func test_veins_grow_outward_and_sectors_cover_the_foundation() -> void:
	var network := _full()
	for edge: Dictionary in network.edges:
		check(int(network.nodes[edge["from"]]["ring"]) < int(network.nodes[edge["to"]]["ring"]),
				"%s → %s grows outward" % [edge["from"], edge["to"]])
	var names := network.sectors.map(func(sector: Dictionary) -> String: return sector["name"])
	check_eq(names, ["Offense", "Guard", "Endurance", "Mobility"])
	check_eq(network.nodes["skill:attack"]["ring"], SkillNetwork.RING_FOUNDATION)
	check_eq(network.nodes["skill:timing"]["ring"], SkillNetwork.RING_DISCIPLINE)
	check_eq(network.nodes["weapon:sword"]["ring"], SkillNetwork.RING_ARMS)
	check_eq(network.nodes["technique:riposte"]["ring"], SkillNetwork.RING_TECHNIQUES)
	# A discipline sits close to the fundamental it refines.
	var gap := absf(angle_difference(float(network.nodes["skill:block"]["angle"]),
			float(network.nodes["skill:block_control"]["angle"])))
	check(gap < 0.01, "Block Control sits beside Block")


func test_suggests_something_to_do() -> void:
	TrainerManager.recruit(Game.profile, "swordmaster_yenbi", true)
	var network := _full()
	check_eq(network.node(network.suggested())["state"], S.READY)


# --- Panel ---------------------------------------------------------------------------

func _open(options: Dictionary = {}) -> PanelHost:
	var host := PanelHost.new()
	root.add_child(host)
	host.open("skill_network", options)
	return host


func test_panel_shows_the_network_and_details() -> void:
	for flag in ["trained_once", "first_trial_done"]:
		Game.set_flag(flag)
	TrainerManager.recruit(Game.profile, "swordmaster_yenbi", true)
	var host := _open({"select": "weapon:sword"})
	var panel: LodgePanel = host._current
	var view: SkillNetworkView = panel.get("view")
	check(view != null, "the network view is built")
	check(view.button_for("weapon:sword") != null, "nodes are buttons")
	check(view.button_for("technique:riposte") != null)
	check_eq(view.selected, "weapon:sword")
	check(Game.is_flag_set("viewed_skill_matrix"))
	var act := panel.find_child("Act", true, false) as Button
	check(act != null and act.text.contains("Yenbi"), "offers training with the active mentor")
	act.pressed.emit()
	check_eq(host._current.panel_id, "training", "Train opens the Training Yard")
	check_eq(host._current.get("_target"), "weapon:sword")
	host.free()


func test_selecting_a_node_updates_the_card() -> void:
	for flag in ["trained_once", "first_trial_done"]:
		Game.set_flag(flag)
	var host := _open()
	var panel: LodgePanel = host._current
	var view: SkillNetworkView = panel.get("view")
	view.select("technique:guard_break")
	panel.call("_show_details")  # normally deferred to the next idle frame
	var texts := PackedStringArray()
	for label in panel.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	for button in panel.find_child("Details", true, false).find_children("*", "Button", true, false):
		texts.append((button as Button).text)
	var all := "\n".join(texts)
	check((panel.find_child("Inscription", true, false).find_children("*", "Label", true, false)[0] as Label).text == "Guard Break",
			"the inscription names the technique")
	check(all.contains("Strength"), "and lists what it needs")
	check(all.contains("Bram") or all.contains("Aldous"), "and who teaches it")
	host.free()


func test_champion_tabs_lead_to_and_from_the_network() -> void:
	var host := _open()
	check(host._current.find_child("Portrait", true, false) != null, "the champion's portrait is shown")
	(host._current.find_child("MatrixButton", true, false) as Button).pressed.emit()
	check_eq(host._current.panel_id, "champion")
	check_eq(host._current.get("_tab"), "skills")
	host._current.call("_select_tab", "network")
	check_eq(host._current.panel_id, "skill_network")
	host.free()


func test_camera_survives_a_rebuild() -> void:
	var host := _open()
	var panel: LodgePanel = host._current
	var view: SkillNetworkView = panel.get("view")
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(800, 500)
	view.set_zoom(0.6)
	var zoom := view.zoom
	var position: Vector2 = view.camera()["position"]
	panel.rebuild()
	var rebuilt: SkillNetworkView = panel.get("view")
	check(rebuilt != view, "the view was rebuilt")
	check_near(rebuilt.zoom, zoom, 0.001, "zoom kept")
	check_eq(rebuilt.camera()["position"], position, "position kept")
	host.free()


func _touch(view: SkillNetworkView, index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	view._gui_input(event)


func _drag(view: SkillNetworkView, index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	view._gui_input(event)


func test_touch_pans_pinches_and_taps() -> void:
	var host := _open({"select": "skill:attack"})
	var view: SkillNetworkView = host._current.get("view")
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(800, 500)
	view.set_zoom(0.8)
	var start: Vector2 = view.camera()["position"]
	_touch(view, 0, Vector2(400, 250), true)
	_drag(view, 0, Vector2(360, 250), Vector2(-40, 0))
	check_near((view.camera()["position"] as Vector2).x, start.x - 40.0, 0.01, "one finger pans")
	view._on_node_pressed("skill:dodge")
	check_eq(view.selected, "skill:attack", "letting go after a pan is not a tap")
	_touch(view, 0, Vector2(360, 250), false)
	_touch(view, 0, Vector2(300, 250), true)
	view._on_node_pressed("skill:dodge")
	check_eq(view.selected, "skill:dodge", "a still tap selects")
	_touch(view, 1, Vector2(500, 250), true)
	var zoom := view.zoom
	_drag(view, 1, Vector2(600, 250), Vector2(100, 0))
	check(view.zoom > zoom, "spreading two fingers zooms in")
	host.free()
