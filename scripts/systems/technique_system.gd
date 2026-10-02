class_name TechniqueSystem
extends RefCounted
## Advanced techniques: Skill Matrix prerequisites + a mentor who teaches them
## (mechanics §30, prompt 15). Fully data-driven via TechniqueData.


## {"met": bool, "requirements": [{"target", "need", "have", "met"}]}
static func status(champion: Champion, technique: TechniqueData) -> Dictionary:
	var requirements: Array[Dictionary] = []
	var met := true
	var targets := technique.prerequisites.keys()
	targets.sort()
	for target: String in targets:
		var need := int(technique.prerequisites[target])
		var have := champion.rank_of(target)
		requirements.append({"target": target, "need": need, "have": have, "met": have >= need})
		met = met and have >= need
	return {"met": met, "requirements": requirements}


static func knows(champion: Champion, technique_id: String) -> bool:
	return champion.techniques.has(technique_id)


## Active mentors able to teach this technique.
static func teachers(profile: OwnerProfile, technique: TechniqueData) -> Array[TrainerData]:
	var result: Array[TrainerData] = []
	for trainer in TrainerManager.active(profile):
		if TrainerManager.teachable_techniques(trainer).has(technique):
			result.append(trainer)
	return result


## Any mentor in the world who could teach it (for "Trainer Requirement" hints).
static func known_teachers(technique: TechniqueData) -> Array[TrainerData]:
	var result: Array[TrainerData] = []
	for trainer: TrainerData in Content.list("trainers"):
		if TrainerManager.teachable_techniques(trainer).has(technique):
			result.append(trainer)
	return result


## Empty string when learnable, otherwise the reason.
static func learn_blocker(champion: Champion, technique: TechniqueData, profile: OwnerProfile) -> String:
	if knows(champion, technique.id):
		return "Already learned."
	if not status(champion, technique)["met"]:
		return "Prerequisites not met."
	if teachers(profile, technique).is_empty():
		return "No active mentor teaches %s." % technique.display_name
	if profile.coins < technique.coin_cost:
		return "You need %d coins." % technique.coin_cost
	return ""


static func learn(champion: Champion, technique: TechniqueData, profile: OwnerProfile) -> String:
	var blocker := learn_blocker(champion, technique, profile)
	if not blocker.is_empty():
		return blocker
	profile.spend(technique.coin_cost)
	champion.techniques.append(technique.id)
	champion.changed.emit()
	return ""
