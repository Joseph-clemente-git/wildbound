class_name SkillNetwork
extends RefCounted
## The Skill Matrix as a network: every development target and advanced
## technique is a node, and every prerequisite is an edge from what is needed
## to what it opens. Built from data only (SkillCatalog.PREREQUISITES and
## TechniqueData.prerequisites), so new skills, weapons, schools and
## techniques join the network without UI changes.
##
## Columns read left to right as the matrix's layers: fundamentals (with the
## natural foundation and the attributes techniques ask for), discipline,
## weapons with the Aether Arts below them, techniques. Parts of the matrix the story has not
## revealed yet stay out, as on the Skill Matrix screen.

## What a node means for the champion right now.
enum State {
	LOCKED,    ## prerequisites missing
	OPEN,      ## could start, but no active mentor teaches it (or coins are short)
	READY,     ## can be trained or learned right now
	LEARNED,   ## has a rank / is known
	MASTERED,  ## at the highest rank this champion can reach
}

const STATE_NAMES := ["Locked", "Needs a mentor", "Ready", "Learned", "Mastered"]

const GROUP_NATURAL := "natural"
const GROUP_ATTRIBUTES := "attributes"
const GROUP_FUNDAMENTALS := "fundamentals"
const GROUP_DISCIPLINE := "discipline"
const GROUP_WEAPONS := "weapons"
const GROUP_MAGIC := "magic"
const GROUP_TECHNIQUES := "techniques"

const GROUP_NAMES := {
	GROUP_NATURAL: "Natural Foundation",
	GROUP_ATTRIBUTES: "Attributes",
	GROUP_FUNDAMENTALS: "Combat Fundamentals",
	GROUP_DISCIPLINE: "Combat Discipline",
	GROUP_WEAPONS: "Weapon Proficiency",
	GROUP_MAGIC: "Aether Arts",
	GROUP_TECHNIQUES: "Advanced Techniques",
}

## Column headings, left to right.
const COLUMNS := ["Foundation", "Discipline", "Weapons & Aether", "Techniques"]

## Node id -> node. A node is a Dictionary:
## id ("skill:dodge", "weapon:sword", "stat:strength", "technique:riposte"),
## kind (stat/skill/weapon/magic/technique), group, name, description,
## column, row, rank, cap, progress (0-1 within the rank), state,
## needs [{id, need, have, met}], opens [ids], teachers [TrainerData],
## active_teachers [TrainerData].
var nodes: Dictionary = {}
## [{from, to, need, met}] — `from` is required by `to`.
var edges: Array[Dictionary] = []
## Order nodes were added (stable for tests and keyboard order).
var order: Array[String] = []
## Whether some part of the matrix is still hidden by the story.
var has_hidden := false

var _champion: Champion
var _profile: OwnerProfile


static func build(champion: Champion, profile: OwnerProfile, revealed: Callable = Callable()) -> SkillNetwork:
	var network := SkillNetwork.new()
	network._champion = champion
	network._profile = profile
	var is_revealed := revealed if revealed.is_valid() else \
			func(stage: String) -> bool: return Game.is_flag_set(SkillCatalog.REVEAL_FLAGS.get(stage, ""))
	network._build(is_revealed)
	return network


static func technique_id(technique: TechniqueData) -> String:
	return "technique:" + technique.id


func node(id: String) -> Dictionary:
	return nodes.get(id, {})


func edges_into(id: String) -> Array[Dictionary]:
	return edges.filter(func(edge: Dictionary) -> bool: return edge["to"] == id)


func edges_from(id: String) -> Array[Dictionary]:
	return edges.filter(func(edge: Dictionary) -> bool: return edge["from"] == id)


## The node to show first: something ready to train or learn, else the most
## advanced thing learned, else the first node.
func suggested() -> String:
	for state in [State.READY, State.LEARNED, State.MASTERED]:
		var best := ""
		for id in order:
			if nodes[id]["state"] != state:
				continue
			# Prefer what opens the most; techniques first among the ready.
			if best.is_empty() or _weight(id) > _weight(best):
				best = id
		if not best.is_empty():
			return best
	return order[0] if not order.is_empty() else ""


func _weight(id: String) -> float:
	var entry: Dictionary = nodes[id]
	return (10.0 if entry["kind"] == "technique" else 0.0) + entry["opens"].size() + entry["rank"] * 0.1


# --- Building ----------------------------------------------------------------------

func _build(is_revealed: Callable) -> void:
	var champion := _champion
	# Column 0: natural foundation actually learned, then the fundamentals.
	var row := 0.0
	for skill: String in SkillCatalog.NATURAL_ORDER:
		if champion.skills.get_rank("skill:" + skill) > 0:
			_add_target("skill:" + skill, GROUP_NATURAL, 0, row)
			row += 1.0
	if row > 0.0:
		row += 0.5

	# Discipline rows sit beside the fundamental they build on, so the tree
	# reads straight across.
	var parents := {}
	for target: String in SkillCatalog.PREREQUISITES:
		for need: String in SkillCatalog.PREREQUISITES[target]:
			if GameEnums.target_kind(need) == "skill":
				parents[target] = need
	var discipline_shown: bool = is_revealed.call("discipline")
	var fundamental_rows := {}
	for skill: String in SkillCatalog.FUNDAMENTAL_ORDER:
		var target := "skill:" + skill
		if not is_revealed.call(SkillCatalog.reveal_stage(target)):
			has_hidden = true
			continue
		var children: Array[String] = []
		if discipline_shown:
			for discipline: String in SkillCatalog.DISCIPLINE_ORDER:
				if parents.get("skill:" + discipline, "") == target:
					children.append("skill:" + discipline)
		var span := maxf(children.size(), 1.0)
		var center := row + (span - 1.0) * 0.5
		_add_target(target, GROUP_FUNDAMENTALS, 0, center)
		fundamental_rows[target] = center
		for i in children.size():
			_add_target(children[i], GROUP_DISCIPLINE, 1, row + i)
		row += span
	if discipline_shown:
		# Any discipline whose fundamental is hidden or missing goes at the end.
		for discipline: String in SkillCatalog.DISCIPLINE_ORDER:
			if not nodes.has("skill:" + discipline):
				_add_target("skill:" + discipline, GROUP_DISCIPLINE, 1, row)
				row += 1.0
	else:
		has_hidden = true

	var arms_row := 0.0
	if is_revealed.call("weapons"):
		for weapon_type: String in GameEnums.WEAPON_TYPES:
			_add_target("weapon:" + weapon_type, GROUP_WEAPONS, 2, arms_row)
			arms_row += 1.0
		arms_row += 0.5
	else:
		has_hidden = true
	if is_revealed.call("magic"):
		for school: String in GameEnums.MAGIC_SCHOOLS:
			_add_target("magic:" + school, GROUP_MAGIC, 2, arms_row)
			arms_row += 1.0
	else:
		has_hidden = true

	if is_revealed.call("techniques"):
		var attribute_row := row + 0.5
		for technique: TechniqueData in Content.list("techniques"):
			for need: String in technique.prerequisites:
				if GameEnums.target_kind(need) == "stat" and not nodes.has(need):
					_add_target(need, GROUP_ATTRIBUTES, 0, attribute_row)
					attribute_row += 1.0
			_add_technique(technique, 3, 0.0)
		_place_techniques()
	else:
		has_hidden = true

	for target: String in SkillCatalog.PREREQUISITES:
		var needs: Dictionary = SkillCatalog.PREREQUISITES[target]
		for need: String in needs:
			_link(need, target, int(needs[need]))
	for id in order:
		_finish(id)


func _add(entry: Dictionary) -> void:
	entry.merge({"rank": 0, "cap": GameEnums.Rank.MASTER, "progress": 0.0, "state": State.LOCKED,
			"needs": [], "opens": [], "teachers": [], "active_teachers": []})
	nodes[entry["id"]] = entry
	order.append(entry["id"])


func _add_target(target: String, group: String, column: int, row: float) -> void:
	var kind := GameEnums.target_kind(target)
	var description := SkillCatalog.description(target)
	_add({"id": target, "kind": kind, "group": group, "name": SkillCatalog.target_name(target),
			"description": description, "column": column, "row": row})


func _add_technique(technique: TechniqueData, column: int, row: float) -> void:
	_add({"id": technique_id(technique), "kind": "technique", "group": GROUP_TECHNIQUES,
			"name": technique.display_name, "description": technique.description,
			"column": column, "row": row, "technique": technique})
	for need: String in technique.prerequisites:
		_link(need, technique_id(technique), int(technique.prerequisites[need]))


## Techniques sit level with the average of what they need, in order and
## at least a row apart.
func _place_techniques() -> void:
	var placed: Array[Dictionary] = []
	for id in order:
		var entry: Dictionary = nodes[id]
		if entry["kind"] != "technique":
			continue
		var rows: Array[float] = []
		var technique: TechniqueData = entry["technique"]
		for need: String in technique.prerequisites:
			if nodes.has(need):
				rows.append(float(nodes[need]["row"]))
		var total := 0.0
		for value in rows:
			total += value
		entry["row"] = total / rows.size() if not rows.is_empty() else 0.0
		placed.append(entry)
	placed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["row"] < b["row"])
	var next := -INF
	for entry in placed:
		entry["row"] = maxf(float(entry["row"]), next)
		next = float(entry["row"]) + 1.25


func _link(need: String, target: String, rank: int) -> void:
	if not nodes.has(need) or not nodes.has(target):
		return
	var have := _champion.rank_of(need)
	var edge := {"from": need, "to": target, "need": rank, "met": have >= rank}
	edges.append(edge)
	nodes[target]["needs"].append({"id": need, "need": rank, "have": have, "met": have >= rank})
	nodes[need]["opens"].append(target)


func _finish(id: String) -> void:
	var entry: Dictionary = nodes[id]
	var champion := _champion
	var profile := _profile
	var all_met := true
	for need: Dictionary in entry["needs"]:
		all_met = all_met and need["met"]
	if entry["kind"] == "technique":
		var technique: TechniqueData = entry["technique"]
		entry["teachers"] = TechniqueSystem.known_teachers(technique)
		entry["active_teachers"] = TechniqueSystem.teachers(profile, technique) if profile != null else []
		if TechniqueSystem.knows(champion, technique.id):
			entry["state"] = State.LEARNED
			entry["rank"] = 1
		elif not all_met:
			entry["state"] = State.LOCKED
		elif profile != null and TechniqueSystem.learn_blocker(champion, technique, profile).is_empty():
			entry["state"] = State.READY
		else:
			entry["state"] = State.OPEN
		return
	if entry["kind"] == "stat":
		var stat := GameEnums.target_id(id)
		entry["rank"] = champion.stat_rank(stat)
		entry["cap"] = GameEnums.Rank.MASTER
		entry["state"] = State.LEARNED if entry["rank"] > 0 else State.OPEN
		entry["description"] = "Natural attribute: %s %d of %d potential." % [GameEnums.stat_name(stat),
				roundi(champion.developed_stat(stat)), roundi(champion.potential(stat))]
	else:
		entry["rank"] = champion.skills.get_rank(id)
		entry["cap"] = champion.rank_cap(id)
		entry["progress"] = champion.skills.progress_ratio(id) if entry["rank"] > 0 else 0.0
	var teachers: Array[TrainerData] = []
	var active: Array[TrainerData] = []
	if profile != null:
		for trainer in TrainerManager.owned(profile):
			if TrainerManager.coverage(trainer).has(id):
				teachers.append(trainer)
				if TrainerManager.is_active(profile, trainer.id):
					active.append(trainer)
	entry["teachers"] = teachers
	entry["active_teachers"] = active
	if entry["kind"] == "stat":
		return
	if entry["rank"] > 0 and (entry["rank"] >= entry["cap"] or entry["rank"] >= GameEnums.Rank.MASTER):
		entry["state"] = State.MASTERED
	elif entry["rank"] > 0:
		entry["state"] = State.LEARNED
	elif not all_met:
		entry["state"] = State.LOCKED
	elif not active.is_empty():
		entry["state"] = State.READY
	else:
		entry["state"] = State.OPEN
