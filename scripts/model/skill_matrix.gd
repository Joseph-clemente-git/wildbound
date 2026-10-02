class_name SkillMatrix
extends RefCounted
## What a champion has actually learned (mechanics §24).
##
## Stores a rank and in-rank progress for every skill / weapon / magic target.
## Stat "ranks" are not stored: they are descriptors derived from stat values.

signal rank_changed(target: String, rank: int)

var ranks: Dictionary = {}     # target -> int (GameEnums.Rank)
var progress: Dictionary = {}  # target -> float progress inside the current rank


func get_rank(target: String) -> int:
	return int(ranks.get(target, GameEnums.Rank.NONE))


func get_progress(target: String) -> float:
	return float(progress.get(target, 0.0))


func set_rank(target: String, rank: int) -> void:
	ranks[target] = clampi(rank, GameEnums.Rank.NONE, GameEnums.Rank.MASTER)
	progress[target] = 0.0


## Progress needed to advance from `rank` to the next one.
static func progress_needed(rank: int) -> float:
	return Content.config.skill_progress_per_rank * float(maxi(rank, 1))


## Lowest rank a target starts at when first learned.
static func first_rank(target: String) -> int:
	match GameEnums.target_kind(target):
		"weapon":
			return SkillCatalog.WEAPON_FIRST_RANK
		"magic":
			return SkillCatalog.MAGIC_FIRST_RANK
	return GameEnums.Rank.FOUNDATION


func is_learned(target: String) -> bool:
	return get_rank(target) > GameEnums.Rank.NONE


## Adds progress, ranking up as many times as earned without passing `cap`.
## Returns the list of ranks reached.
func add_progress(target: String, amount: float, cap: int = GameEnums.Rank.MASTER) -> Array[int]:
	var reached: Array[int] = []
	if amount <= 0.0:
		return reached
	var rank := get_rank(target)
	if rank == GameEnums.Rank.NONE:
		# Learning a skill for the first time: jump to its starting rank.
		rank = mini(first_rank(target), cap)
		if rank <= GameEnums.Rank.NONE:
			return reached
		ranks[target] = rank
		progress[target] = 0.0
		reached.append(rank)
		rank_changed.emit(target, rank)
		return reached
	var value := get_progress(target) + amount
	while rank < cap and value >= progress_needed(rank):
		value -= progress_needed(rank)
		rank += 1
		reached.append(rank)
		rank_changed.emit(target, rank)
	if rank >= cap:
		value = minf(value, progress_needed(rank) - 0.01) if rank < GameEnums.Rank.MASTER else 0.0
	ranks[target] = rank
	progress[target] = value
	return reached


## 0..1 fill of the current rank, for progress bars.
func progress_ratio(target: String) -> float:
	var rank := get_rank(target)
	if rank >= GameEnums.Rank.MASTER:
		return 1.0
	return clampf(get_progress(target) / progress_needed(rank), 0.0, 1.0)


func learned_targets(kind: String = "") -> Array[String]:
	var result: Array[String] = []
	for target: String in ranks:
		if get_rank(target) > GameEnums.Rank.NONE and (kind.is_empty() or GameEnums.target_kind(target) == kind):
			result.append(target)
	result.sort()
	return result


func to_dict() -> Dictionary:
	return {"ranks": ranks.duplicate(), "progress": progress.duplicate()}


static func from_dict(data: Dictionary) -> SkillMatrix:
	var matrix := SkillMatrix.new()
	for target: String in data.get("ranks", {}):
		if SkillCatalog.is_valid_target(target):
			matrix.ranks[target] = int(data["ranks"][target])
	for target: String in data.get("progress", {}):
		if matrix.ranks.has(target):
			matrix.progress[target] = float(data["progress"][target])
	return matrix
