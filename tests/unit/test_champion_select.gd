extends TestCase
## Stage 4 of the battle simulation: choosing the champion after the fight.

var trial: TrialData
var bruno: Champion
var mika: Champion


func before_each() -> void:
	Game.autosave = false
	Game.time_override = 1000000.0
	Game.new_journey("Bruno")
	for flag in ["equipped_weapon", "trained_once", "first_trial_done", "cleared_first_steps"]:
		Game.set_flag(flag)
	trial = Content.trial("stonewall_bout")
	bruno = Game.champion()
	mika = Champion.create(Content.animal("humanoid_dog"), "Mika", Game.now())
	mika.uid = "mika"
	Game.champions.append(mika)


func test_readiness_uses_energy_and_knockouts() -> void:
	check(ChampionSelection.is_ready(bruno, trial))
	check_eq(ChampionSelection.blocker(bruno, trial), "")
	bruno.energy = trial.energy_cost - 1.0
	check(ChampionSelection.blocker(bruno, trial).contains("Needs %d energy" % trial.energy_cost))
	bruno.energy = 100.0
	ConditionSystem.knock_out(bruno, Game.now())
	check(ChampionSelection.blocker(bruno, trial).contains("knockout"))
	check(not ChampionSelection.is_ready(bruno, trial))


func test_readiness_ignores_whether_the_fight_is_open() -> void:
	var regional := Content.trial("valley_regional")
	check(not TrialSystem.is_unlocked(regional))
	check(ChampionSelection.is_ready(bruno, regional), "champion readiness is about the champion only")
	check(not TrialSystem.entry_blocker(bruno, regional).is_empty(), "entering still needs the fight open")


func test_ready_champions_come_first() -> void:
	ConditionSystem.knock_out(bruno, Game.now())
	var ordered := ChampionSelection.candidates(trial)
	check_eq(ordered.size(), 2, "every champion is listed")
	check_eq(ordered[0].uid, "mika", "ready champions first")
	check_eq(ChampionSelection.default_choice(trial).uid, "mika", "a resting champion is not preselected")
	bruno.knocked_out = false
	check_eq(ChampionSelection.default_choice(trial).uid, bruno.uid, "the champion the Keeper was working with")


func test_notes_do_not_block() -> void:
	mika.weapon_id = ""
	mika.happiness = 10.0
	var notes := " | ".join(ChampionSelection.notes(mika, trial))
	check(notes.contains("No weapon equipped"), notes)
	check(notes.contains("downcast"), notes)
	check(notes.contains("Energy after entering: %d" % roundi(mika.energy - trial.energy_cost)), notes)
	check(ChampionSelection.is_ready(mika, trial), "low mood and no weapon are warnings, not blockers")


func test_choosing_selects_the_champion_for_the_fight() -> void:
	check_eq(ChampionSelection.choose(mika, trial), "")
	check_eq(Game.champion().uid, "mika", "the battle, result and growth apply to the chosen champion")
	ConditionSystem.knock_out(bruno, Game.now())
	check(not ChampionSelection.choose(bruno, trial).is_empty())
	check_eq(Game.champion().uid, "mika", "a blocked choice changes nothing")


func test_screen_lists_and_picks_champions() -> void:
	mika.energy = 5.0
	var screen := _open({"trial": trial.id})
	check_eq(screen.chosen.uid, bruno.uid)
	check(screen.find_child("Champion_" + bruno.uid, true, false) != null)
	check(screen.find_child("Champion_mika", true, false) != null, "the roster is not limited to one champion")
	var prepare: Button = screen.find_child("Prepare", true, false)
	check(not prepare.disabled)
	check_eq(prepare.text, "Prepare Bruno")
	screen.pick("mika")
	check_eq(screen.chosen.uid, "mika")
	check(prepare.disabled, "a tired champion cannot be sent in")
	check(screen._status.text.contains("Needs"), screen._status.text)
	check(screen._rest.visible, "offers a way to recover")
	screen.free()


func test_screen_respects_a_preselection() -> void:
	var screen := _open({"trial": trial.id, "champion": "mika"})
	check_eq(screen.chosen.uid, "mika")
	screen.free()


func test_prep_uses_the_chosen_champion() -> void:
	Router.params = {"trial": trial.id, "champion": "mika"}
	var prep: Node = load(Router.ROUTES["battle_prep"]).instantiate()
	root.add_child(prep)
	Router.params = {}
	check_eq(Game.champion().uid, "mika")
	prep.free()


func _open(params: Dictionary) -> Node:
	Router.params = params
	var screen: Node = load(Router.ROUTES["champion_select"]).instantiate()
	root.add_child(screen)
	Router.params = {}
	return screen
