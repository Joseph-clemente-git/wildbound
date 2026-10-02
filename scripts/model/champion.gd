class_name Champion
extends RefCounted
## A champion the Keeper raises: one owned animal and everything it has lived.
##
## FINAL CAPABILITY = NATURAL ATTRIBUTES + BATTLE EXPERIENCE (natural growth)
##                  + TRAINER DEVELOPMENT, limited by training potential,
## then modified by equipment. Animal level is tracked separately and never
## grants stat points (mechanics §40).

signal changed

const CAPABILITY_NAMES: Array[String] = ["Untrained", "Trainee", "Fighter", "Specialist", "Veteran", "Master"]
const CAPABILITY_THRESHOLDS: Array[float] = [0.8, 1.5, 2.2, 3.0, 4.0]
const HISTORY_LIMIT := 12

var uid: String = ""
var animal_id: String = "humanoid_dog"
var name: String = "Bruno"
var palette: Dictionary = {}
var level: int = 1
var xp: int = 0

var natural_growth: Dictionary = {}  # stat -> points from experience
var trained: Dictionary = {}         # stat -> points from trainers
var experience := ExperienceTracks.new()
var skills := SkillMatrix.new()
var techniques: Array[String] = []

var weapon_id: String = ""
var armor_id: String = "armor_light"
var accessory_id: String = ""
var equipped_ability: String = ""

var energy: float = 100.0
var happiness: float = 70.0
var knocked_out: bool = false
var knocked_out_at: float = 0.0
var last_energy_tick: float = 0.0
var last_short_rest: float = -100000.0

var wins: int = 0
var losses: int = 0
var loss_streak: int = 0
var history: Array[Dictionary] = []


static func create(animal: AnimalData, champion_name: String, now: float) -> Champion:
	var champion := Champion.new()
	champion.uid = "c%d" % int(now * 1000.0 + randi() % 1000)
	champion.animal_id = animal.id
	champion.name = champion_name
	champion.palette = animal.palette.duplicate()
	for target: String in animal.starting_skills:
		champion.skills.set_rank(target, int(animal.starting_skills[target]))
	champion.energy = Content.config.max_energy
	champion.last_energy_tick = now
	return champion


func data() -> AnimalData:
	return Content.animal(animal_id)


# --- Stats ---------------------------------------------------------------------

func base_stat(stat: String) -> float:
	return data().get_base(stat)


func potential(stat: String) -> float:
	return data().get_potential(stat)


## Natural + trained development, never above the species potential.
func developed_stat(stat: String) -> float:
	var value := base_stat(stat) + float(natural_growth.get(stat, 0.0)) + float(trained.get(stat, 0.0))
	return clampf(value, 0.0, potential(stat))


## What the champion brings into battle with its current equipment.
func final_stat(stat: String) -> float:
	return clampf(developed_stat(stat) + equipment_modifier(stat), 1.0, 120.0)


func equipment_modifier(stat: String) -> float:
	var total := 0.0
	for item_id: String in [weapon_id, armor_id, accessory_id]:
		if item_id.is_empty():
			continue
		var item := Content.equipment(item_id)
		if item != null:
			total += float(item.stat_modifiers.get(stat, 0.0))
	return total


## Remaining room to develop a stat, 0..1 (1 = far from potential).
func potential_room(stat: String) -> float:
	var cap := potential(stat)
	if cap <= 0.0:
		return 0.0
	return clampf((cap - developed_stat(stat)) / cap, 0.0, 1.0)


func add_natural_growth(stat: String, amount: float) -> float:
	var before := developed_stat(stat)
	natural_growth[stat] = float(natural_growth.get(stat, 0.0)) + amount
	_clamp_development(stat)
	return developed_stat(stat) - before


func add_trained(stat: String, amount: float) -> float:
	var before := developed_stat(stat)
	trained[stat] = float(trained.get(stat, 0.0)) + amount
	_clamp_development(stat)
	return developed_stat(stat) - before


## Keeps stored development from silently exceeding potential.
func _clamp_development(stat: String) -> void:
	var excess := base_stat(stat) + float(natural_growth.get(stat, 0.0)) + float(trained.get(stat, 0.0)) - potential(stat)
	if excess > 0.0:
		if trained.has(stat) and float(trained[stat]) >= excess:
			trained[stat] = float(trained[stat]) - excess
		else:
			natural_growth[stat] = maxf(float(natural_growth.get(stat, 0.0)) - excess, 0.0)


## Stats described with the shared rank names ("Strength Skilled").
func stat_rank(stat: String) -> int:
	var thresholds := Content.config.stat_rank_thresholds
	var value := developed_stat(stat)
	var rank := GameEnums.Rank.NONE
	for i in thresholds.size():
		if value >= thresholds[i]:
			rank = i
	return rank


## Rank of any development target ("stat:", "skill:", "weapon:", "magic:").
func rank_of(target: String) -> int:
	if GameEnums.target_kind(target) == "stat":
		return stat_rank(GameEnums.target_id(target))
	return skills.get_rank(target)


## Highest rank this species can reach for a target.
func rank_cap(target: String) -> int:
	match GameEnums.target_kind(target):
		"magic":
			return SkillCatalog.rank_cap_for_potential(data().get_potential(GameEnums.MAGIC_POTENTIAL))
	return GameEnums.Rank.MASTER


# --- Capability --------------------------------------------------------------------

func capability_score() -> float:
	return score_capability(skills.get_rank, techniques.size())


func capability_rank() -> int:
	return capability_rank_for(capability_score())


## Learned capability from Skill Matrix ranks, shared by champions and
## opponents so a capability name means the same on both sides.
## `rank_of` is a Callable(target: String) -> int.
static func score_capability(rank_of: Callable, technique_count: int) -> float:
	var fundamentals := 0.0
	for skill: String in SkillCatalog.FUNDAMENTAL_ORDER:
		fundamentals += rank_of.call("skill:" + skill)
	fundamentals /= SkillCatalog.FUNDAMENTAL_ORDER.size()
	var discipline := 0.0
	for skill: String in SkillCatalog.DISCIPLINE_ORDER:
		discipline += rank_of.call("skill:" + skill)
	discipline /= SkillCatalog.DISCIPLINE_ORDER.size()
	var best_weapon := 0
	for weapon_type: String in GameEnums.WEAPON_TYPES:
		best_weapon = maxi(best_weapon, rank_of.call("weapon:" + weapon_type))
	var best_magic := 0
	for school: String in GameEnums.MAGIC_SCHOOLS:
		best_magic = maxi(best_magic, rank_of.call("magic:" + school))
	return fundamentals * 0.35 + discipline * 0.2 + best_weapon * 0.3 + best_magic * 0.1 \
			+ minf(technique_count, 3) * 0.25


static func capability_rank_for(score: float) -> int:
	for i in CAPABILITY_THRESHOLDS.size():
		if score < CAPABILITY_THRESHOLDS[i]:
			return i
	return CAPABILITY_THRESHOLDS.size()


func capability_name() -> String:
	return CAPABILITY_NAMES[capability_rank()]


## Single number used to compare champions for difficulty weighting.
func power_rating() -> float:
	return PowerRating.from_stats(_final_stats(), capability_score(), level)


func _final_stats() -> Dictionary:
	var stats := {}
	for stat: String in GameEnums.STATS:
		stats[stat] = final_stat(stat)
	return stats


# --- Level ----------------------------------------------------------------------

static func xp_to_next(for_level: int) -> int:
	var config := Content.config
	return config.animal_xp_base + config.animal_xp_per_level * (for_level - 1)


## Animal XP only raises the animal level (general progression).
func add_xp(amount: int) -> int:
	var gained := 0
	xp += maxi(amount, 0)
	while level < Content.config.animal_max_level and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	changed.emit()
	return gained


# --- Condition (energy / happiness) ----------------------------------------------

func max_energy() -> float:
	return float(Content.config.max_energy)


func max_happiness() -> float:
	return float(Content.config.max_happiness)


func has_energy(amount: float) -> bool:
	return energy >= amount


func consume_energy(amount: float) -> bool:
	if energy < amount:
		return false
	energy -= amount
	changed.emit()
	return true


func restore_energy(amount: float) -> float:
	var before := energy
	energy = clampf(energy + amount, 0.0, max_energy())
	changed.emit()
	return energy - before


func change_happiness(delta: float) -> float:
	var before := happiness
	happiness = clampf(happiness + delta, 0.0, max_happiness())
	changed.emit()
	return happiness - before


## Happiness lightly influences training (never a hard punishment).
func happiness_factor() -> float:
	var range_values := Content.config.happiness_training_range
	return lerpf(range_values.x, range_values.y, happiness / max_happiness())


func mood_name() -> String:
	if happiness >= 80.0:
		return "Joyful"
	if happiness >= 60.0:
		return "Content"
	if happiness >= 40.0:
		return "Calm"
	if happiness >= 20.0:
		return "Weary"
	return "Downcast"


func can_fight() -> bool:
	return not knocked_out and energy >= 1.0


# --- Persistence ------------------------------------------------------------------

func record_battle(entry: Dictionary) -> void:
	history.push_front(entry)
	while history.size() > HISTORY_LIMIT:
		history.pop_back()


func to_dict() -> Dictionary:
	return {
		"uid": uid, "animal_id": animal_id, "name": name, "palette": _palette_to_dict(),
		"level": level, "xp": xp,
		"natural_growth": natural_growth.duplicate(), "trained": trained.duplicate(),
		"experience": experience.to_dict(), "skills": skills.to_dict(),
		"techniques": techniques.duplicate(),
		"weapon_id": weapon_id, "armor_id": armor_id, "accessory_id": accessory_id,
		"equipped_ability": equipped_ability,
		"energy": energy, "happiness": happiness,
		"knocked_out": knocked_out, "knocked_out_at": knocked_out_at,
		"last_energy_tick": last_energy_tick, "last_short_rest": last_short_rest,
		"wins": wins, "losses": losses, "loss_streak": loss_streak,
		"history": history.duplicate(true),
	}


static func from_dict(data: Dictionary) -> Champion:
	var champion := Champion.new()
	champion.uid = str(data.get("uid", "c0"))
	champion.animal_id = str(data.get("animal_id", "humanoid_dog"))
	if Content.animal(champion.animal_id) == null:
		champion.animal_id = "humanoid_dog"
	champion.name = str(data.get("name", "Bruno"))
	champion.palette = Content.animal(champion.animal_id).palette.duplicate()
	var saved_palette: Dictionary = data.get("palette", {})
	for key: String in saved_palette:
		champion.palette[key] = Color.html(str(saved_palette[key]))
	champion.level = int(data.get("level", 1))
	champion.xp = int(data.get("xp", 0))
	champion.natural_growth = _float_dict(data.get("natural_growth", {}))
	champion.trained = _float_dict(data.get("trained", {}))
	champion.experience = ExperienceTracks.from_dict(data.get("experience", {}))
	champion.skills = SkillMatrix.from_dict(data.get("skills", {}))
	for technique_id in data.get("techniques", []):
		if Content.technique(str(technique_id)) != null:
			champion.techniques.append(str(technique_id))
	champion.weapon_id = _valid_item(str(data.get("weapon_id", "")))
	champion.armor_id = _valid_item(str(data.get("armor_id", "armor_light")))
	champion.accessory_id = _valid_item(str(data.get("accessory_id", "")))
	champion.equipped_ability = str(data.get("equipped_ability", ""))
	if Content.ability(champion.equipped_ability) == null:
		champion.equipped_ability = ""
	champion.energy = float(data.get("energy", 100.0))
	champion.happiness = float(data.get("happiness", 70.0))
	champion.knocked_out = bool(data.get("knocked_out", false))
	champion.knocked_out_at = float(data.get("knocked_out_at", 0.0))
	champion.last_energy_tick = float(data.get("last_energy_tick", 0.0))
	champion.last_short_rest = float(data.get("last_short_rest", -100000.0))
	champion.wins = int(data.get("wins", 0))
	champion.losses = int(data.get("losses", 0))
	champion.loss_streak = int(data.get("loss_streak", 0))
	for entry in data.get("history", []):
		if entry is Dictionary:
			champion.history.append(entry)
	return champion


func _palette_to_dict() -> Dictionary:
	var result := {}
	for key: String in palette:
		result[key] = (palette[key] as Color).to_html()
	return result


static func _float_dict(source: Dictionary) -> Dictionary:
	var result := {}
	for key: String in source:
		if GameEnums.STATS.has(key):
			result[key] = float(source[key])
	return result


static func _valid_item(item_id: String) -> String:
	return item_id if item_id.is_empty() or Content.equipment(item_id) != null else ""
