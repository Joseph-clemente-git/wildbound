class_name BattleRecorder
extends RefCounted
## Watches a battle and reports the player's meaningful actions to an
## ExperienceSession (mechanics §10-23, prompt 21): successful attacks,
## heavy impacts, dodges, blocks, repositioning, stamina discipline,
## surviving heavy damage, weapon and magic use. Also keeps the tallies
## shown on the Battle Result screen.

const STAMINA_WINDOW := 12.0
const HEAVY_DAMAGE_RATIO := 0.12
const LOW_HEALTH_SURVIVE_SECONDS := 3.0

var battle: BattleManager
var champion: Champion
var opponent: OpponentData
var trial: TrialData
var session: ExperienceSession
var forfeited := false
var tallies := {
	"hits": 0, "heavy_hits": 0, "dodges": 0, "perfect_dodges": 0, "blocks": 0,
	"perfect_blocks": 0, "staggers": 0, "spells": 0, "damage_dealt": 0.0, "damage_taken": 0.0,
	"exhaustions": 0, "techniques": 0,
}

var _window_time := 0.0
var _window_actions := 0
var _window_exhausted := false
var _low_health_at := -1.0
var _low_health_rewarded := false


func _init(battle_manager: BattleManager, owner_champion: Champion, opponent_data: OpponentData, trial_data: TrialData) -> void:
	battle = battle_manager
	champion = owner_champion
	opponent = opponent_data
	trial = trial_data
	session = ExperienceSession.new(champion, PowerRating.for_opponent(opponent))
	battle.combat_event.connect(_on_event)
	battle.stepped.connect(_on_step)


func start() -> void:
	_window_time = 0.0


func _report(event: String, variant: String = "") -> void:
	session.report(event, battle.time, variant)


func _on_step(delta: float) -> void:
	_window_time += delta
	if _window_time >= STAMINA_WINDOW:
		if not _window_exhausted and _window_actions >= 3:
			_report("stamina_discipline")
		_window_time = 0.0
		_window_actions = 0
		_window_exhausted = false
	if _low_health_at >= 0.0 and not _low_health_rewarded and battle.player.is_alive() \
			and battle.time - _low_health_at >= LOW_HEALTH_SURVIVE_SECONDS:
		_low_health_rewarded = true
		_report("survived_low_health")


func _on_event(who: Combatant, kind: String, data: Dictionary) -> void:
	if who == battle.player:
		_player_event(kind, data)
	elif kind == "attack_result" and data.get("outcome", "") in ["hit", "stagger", "ko", "guard_break"]:
		pass  # damage taken is tracked through the player's "damaged" event


func _player_event(kind: String, data: Dictionary) -> void:
	match kind:
		"attack_result":
			_window_actions += 1
			var outcome: String = data.get("outcome", "")
			if not outcome in ["hit", "stagger", "ko", "guard_break"]:
				return
			var variant := "heavy" if data.get("heavy", false) else "combo%d" % int(data.get("combo", 0))
			if data.get("kind", "melee") == "magic":
				tallies["spells"] += 1
				_report("magic_hit", str(data.get("ability", "")))
			elif data.get("heavy", false):
				tallies["heavy_hits"] += 1
				_report("heavy_hit")
			elif int(data.get("combo", 0)) > 0:
				tallies["hits"] += 1
				_report("combo_hit", variant)
			else:
				tallies["hits"] += 1
				_report("hit")
			tallies["damage_dealt"] += float(data.get("damage", 0.0))
			if data.get("punish", false):
				_report("punish", variant)
			if outcome == "stagger" or outcome == "guard_break":
				tallies["staggers"] += 1
				_report("stagger_caused")
			if outcome == "guard_break":
				_report("guard_break")
		"technique_used":
			tallies["techniques"] += 1
			_report("technique", str(data.get("technique", "")))
		"cast_released":
			_window_actions += 1
			_report("magic_cast", str(data.get("ability", "")))
		"evaded":
			_window_actions += 1
			tallies["dodges"] += 1
			if data.get("perfect", false):
				tallies["perfect_dodges"] += 1
				_report("perfect_dodge")
			else:
				_report("dodge")
			if data.get("heavy", false):
				_report("dodge_heavy")
			if data.get("magic", false):
				_report("dodge_magic")
		"blocked":
			_window_actions += 1
			tallies["blocks"] += 1
			if data.get("perfect", false):
				tallies["perfect_blocks"] += 1
				_report("perfect_block")
			else:
				_report("block")
			if data.get("heavy", false):
				_report("block_heavy")
		"repositioned":
			_report("reposition")
		"damaged":
			var amount: float = data.get("amount", 0.0)
			tallies["damage_taken"] += amount
			if amount >= battle.player.stats.max_health * HEAVY_DAMAGE_RATIO and battle.player.is_alive():
				_report("heavy_damage_survived")
		"low_health":
			_low_health_at = battle.time
		"exhausted":
			tallies["exhaustions"] += 1
			_window_exhausted = true


## Closes the session and returns everything the result screen needs.
func finish(won: bool) -> Dictionary:
	var duration := battle.time
	if duration > 60.0:
		_report("long_battle")
	var dealt_ratio := 1.0 - battle.opponent.health_ratio()
	if not won and not forfeited and duration > 50.0 and dealt_ratio >= 0.4:
		_report("prolonged_defeat")
	if forfeited:
		# Walking away early teaches little.
		for track: String in session.gains.keys():
			session.gains[track] = float(session.gains[track]) * 0.5
	var experience := session.commit()
	return {
		"trial_id": trial.id, "opponent_id": opponent.id, "won": won, "forfeited": forfeited,
		"duration": duration, "tallies": tallies.duplicate(),
		"difficulty_ratio": session.difficulty_ratio, "difficulty_multiplier": session.difficulty_multiplier,
		"experience": experience["gains"], "growths": experience["growths"],
		"player_health_ratio": battle.player.health_ratio(), "opponent_health_ratio": battle.opponent.health_ratio(),
	}
