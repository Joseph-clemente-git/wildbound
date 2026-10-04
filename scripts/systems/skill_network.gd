class_name SkillNetwork
extends RefCounted
## The Skill Matrix as a network: every development target and advanced
## technique is a node, and every prerequisite is an edge from what is needed
## to what it opens. Built from data only (SkillCatalog.PREREQUISITES and
## TechniqueData.prerequisites), so new skills, weapons, schools and
## techniques join the network without UI changes.
##
## The layout is radial — the Aether Weave. The champion sits at the hub and
## the matrix's layers are rings growing outward: Foundation (fundamentals,
## natural foundation and the attributes techniques ask for), Discipline
## (each beside the fundamental it refines), Arms & Aether, and Techniques
## (drawn toward what they combine). The foundation ring is split into
## sectors — Offense, Guard, Endurance, Mobility — so a champion's growth
## visibly leans one way or another. Parts of the matrix the story has not
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

## Rings, from the hub outward.
const RINGS := ["Foundation", "Discipline", "Arms & Aether", "Techniques"]
const RING_FOUNDATION := 0
const RING_DISCIPLINE := 1
const RING_ARMS := 2
const RING_TECHNIQUES := 3

## Sectors of the foundation ring, clockwise from the top. A foundation node
## not listed joins the last sector.
const SECTORS := [
	["Offense", ["skill:attack", "stat:strength", "stat:attack", "stat:attack_speed"]],
	["Guard", ["skill:defense", "skill:block", "stat:defense"]],
	["Endurance", ["skill:stamina", "skill:recovery", "stat:endurance", "stat:health"]],
	["Mobility", ["skill:movement", "skill:dodge", "stat:agility", "stat:evasion", "skill:swimming", "skill:flight"]],
]
## Angular spread between disciplines that refine the same fundamental.
const SIBLING_SPREAD := 0.36
## Closest two techniques may sit on their ring, in radians.
const TECHNIQUE_GAP := 0.21

## Node id -> node. A node is a Dictionary:
## id ("skill:dodge", "weapon:sword", "stat:strength", "technique:riposte"),
## kind (stat/skill/weapon/magic/technique), group, name, description,
## ring, angle (radians, 0 = right, clockwise on screen), rank, cap,
## progress (0-1 within the rank), state, needs [{id, need, have, met}],
## opens [ids], teachers [TrainerData], active_teachers [TrainerData].
var nodes: Dictionary = {}
## [{from, to, need, met}] — `from` is required by `to`.
var edges: Array[Dictionary] = []
## Order nodes were added (stable for tests and keyboard order).
var order: Array[String] = []
## [{name, start, end}] — angular extent of each sector on the foundation ring.
var sectors: Array[Dictionary] = []
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


func count_in(state: State) -> int:
	return order.filter(func(id: String) -> bool: return nodes[id]["state"] == state).size()


## The node to show first: something ready to train or learn, else the most
## advanced thing learned, else the first node.
func suggested() -> String:
	for state in [State.READY, State.LEARNED, State.MASTERED]:
		var best := ""
		for id in order:
			if nodes[id]["state"] != state:
				continue
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
	var techniques_shown: bool = is_revealed.call("techniques")
	var techniques: Array = Content.list("techniques") if techniques_shown else []

	# Foundation ring: natural skills actually learned, revealed fundamentals
	# and the attributes techniques ask for, grouped by sector.
	var foundation: Array[Array] = []
	for target: String in _foundation_targets(is_revealed, techniques):
		var kind := GameEnums.target_kind(target)
		var group := GROUP_ATTRIBUTES if kind == "stat" else \
				(GROUP_NATURAL if SkillCatalog.NATURAL_ORDER.has(GameEnums.target_id(target)) else GROUP_FUNDAMENTALS)
		foundation.append([target, group])
	var by_sector: Array[Array] = []
	for sector: Array in SECTORS:
		by_sector.append([])
	for entry: Array in foundation:
		by_sector[_sector_of(entry[0])].append(entry)
	var flat: Array[Array] = []
	for list: Array in by_sector:
		flat.append_array(list)
	var step := TAU / maxf(flat.size(), 1.0)
	var start := -PI * 0.5 - step * (by_sector[0].size() - 1) * 0.5
	var index := 0
	for s in by_sector.size():
		var list: Array = by_sector[s]
		if list.is_empty():
			continue
		var first := start + index * step
		for entry: Array in list:
			_add_target(entry[0], entry[1], RING_FOUNDATION, start + index * step)
			index += 1
		sectors.append({"name": SECTORS[s][0], "start": first - step * 0.5, "end": start + (index - 1) * step + step * 0.5})

	# Discipline ring: beside the fundamental each one refines.
	if is_revealed.call("discipline"):
		var children := {}
		for target: String in SkillCatalog.PREREQUISITES:
			for need: String in SkillCatalog.PREREQUISITES[target]:
				if GameEnums.target_kind(need) == "skill" and nodes.has(need):
					if not children.has(need):
						children[need] = []
					children[need].append(target)
		var orphan := 0
		for discipline: String in SkillCatalog.DISCIPLINE_ORDER:
			var target := "skill:" + discipline
			var parent := ""
			for need: String in children:
				if (children[need] as Array).has(target):
					parent = need
			if parent.is_empty():
				_add_target(target, GROUP_DISCIPLINE, RING_DISCIPLINE, PI * 0.5 + orphan * 0.3)
				orphan += 1
				continue
			var siblings: Array = children[parent]
			var offset := (siblings.find(target) - (siblings.size() - 1) * 0.5) * SIBLING_SPREAD
			_add_target(target, GROUP_DISCIPLINE, RING_DISCIPLINE, float(nodes[parent]["angle"]) + offset)
	else:
		has_hidden = true

	# Arms & Aether: weapons arc around Offense and Guard, schools fill the rest.
	var arms: Array[Array] = []
	if is_revealed.call("weapons"):
		for weapon_type: String in GameEnums.WEAPON_TYPES:
			arms.append(["weapon:" + weapon_type, GROUP_WEAPONS])
	else:
		has_hidden = true
	var weapon_count := arms.size()
	if is_revealed.call("magic"):
		for school: String in GameEnums.MAGIC_SCHOOLS:
			arms.append(["magic:" + school, GROUP_MAGIC])
	else:
		has_hidden = true
	if not arms.is_empty():
		var arms_step := TAU / arms.size()
		var center := _mean_angle(nodes.keys().filter(func(id: String) -> bool:
			return nodes[id]["ring"] == RING_FOUNDATION and _sector_of(id) <= 1), -PI * 0.5)
		var arms_start := center - (maxf(weapon_count, 1.0) - 1.0) * 0.5 * arms_step
		for i in arms.size():
			_add_target(arms[i][0], arms[i][1], RING_ARMS, arms_start + i * arms_step)

	# Techniques: drawn toward the average of what they combine.
	if techniques_shown:
		for technique: TechniqueData in techniques:
			_add_technique(technique)
		_spread_techniques()
	else:
		has_hidden = true

	for target: String in SkillCatalog.PREREQUISITES:
		var needs: Dictionary = SkillCatalog.PREREQUISITES[target]
		for need: String in needs:
			_link(need, target, int(needs[need]))
	for technique: TechniqueData in techniques:
		for need: String in technique.prerequisites:
			_link(need, technique_id(technique), int(technique.prerequisites[need]))
	for id in order:
		_finish(id)


func _foundation_targets(is_revealed: Callable, techniques: Array) -> Array[String]:
	var targets: Array[String] = []
	for skill: String in SkillCatalog.NATURAL_ORDER:
		if _champion.skills.get_rank("skill:" + skill) > 0:
			targets.append("skill:" + skill)
	for skill: String in SkillCatalog.FUNDAMENTAL_ORDER:
		var target := "skill:" + skill
		if is_revealed.call(SkillCatalog.reveal_stage(target)):
			targets.append(target)
		else:
			has_hidden = true
	for technique: TechniqueData in techniques:
		for need: String in technique.prerequisites:
			if GameEnums.target_kind(need) == "stat" and not targets.has(need):
				targets.append(need)
	return targets


static func _sector_of(target: String) -> int:
	for i in SECTORS.size():
		if (SECTORS[i][1] as Array).has(target):
			return i
	return SECTORS.size() - 1


## Circular mean of the given nodes' angles.
func _mean_angle(ids: Array, fallback: float) -> float:
	var sum := Vector2.ZERO
	for id: String in ids:
		sum += Vector2.from_angle(float(nodes[id]["angle"]))
	return sum.angle() if sum.length() > 0.001 else fallback


func _add(entry: Dictionary) -> void:
	entry.merge({"rank": 0, "cap": GameEnums.Rank.MASTER, "progress": 0.0, "state": State.LOCKED,
			"needs": [], "opens": [], "teachers": [], "active_teachers": []})
	entry["angle"] = wrapf(float(entry["angle"]), -PI, PI)
	nodes[entry["id"]] = entry
	order.append(entry["id"])


func _add_target(target: String, group: String, ring: int, angle: float) -> void:
	_add({"id": target, "kind": GameEnums.target_kind(target), "group": group, "name": SkillCatalog.target_name(target),
			"description": SkillCatalog.description(target), "ring": ring, "angle": angle})


func _add_technique(technique: TechniqueData) -> void:
	var needs := technique.prerequisites.keys().filter(func(need: String) -> bool: return nodes.has(need))
	_add({"id": technique_id(technique), "kind": "technique", "group": GROUP_TECHNIQUES,
			"name": technique.display_name, "description": technique.description,
			"ring": RING_TECHNIQUES, "angle": _mean_angle(needs, 0.0), "technique": technique})


## Pushes techniques apart until no two sit closer than TECHNIQUE_GAP.
func _spread_techniques() -> void:
	var placed: Array = order.filter(func(id: String) -> bool: return nodes[id]["ring"] == RING_TECHNIQUES)
	for _pass in 24:
		placed.sort_custom(func(a: String, b: String) -> bool: return nodes[a]["angle"] < nodes[b]["angle"])
		var moved := false
		for i in placed.size():
			if placed.size() < 2:
				break
			var a: Dictionary = nodes[placed[i]]
			var b: Dictionary = nodes[placed[(i + 1) % placed.size()]]
			var gap := wrapf(float(b["angle"]) - float(a["angle"]), 0.0, TAU)
			if gap < TECHNIQUE_GAP:
				var push := (TECHNIQUE_GAP - gap) * 0.5 + 0.001
				a["angle"] = wrapf(float(a["angle"]) - push, -PI, PI)
				b["angle"] = wrapf(float(b["angle"]) + push, -PI, PI)
				moved = true
		if not moved:
			return


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
