# WILDBOUND: Chronicles of the Aether

A mobile-first 3D animal fantasy adventure built with **Godot 4.7** (GL Compatibility, Jolt).
You are the Keeper of a small training lodge, inherited from its old owner, Old Magnus.
Raise a young humanoid dog into a champion: train it with human mentors who can teach any
champion, equip it, teach it the Aether Arts and enter the trials of
the Home Valley. Champions grow from what they actually live — *"this animal became good at
this because of the way I raised and fought with it."*

This repository contains the complete **Chapter 1 MVP** described in `mechanics.md` and
`story.md`, with a **simulation-based battle system** (see
[`docs/BATTLE_SIMULATION.md`](docs/BATTLE_SIMULATION.md)). You do not pilot fights: you
choose the fight, choose and prepare the champion, then watch a 3D replay of a
deterministic, tick-based simulation. The result comes from both sides' animal, stats,
Skill Matrix, battle experience, weapon and mastery, armor, Aether Arts, trainers'
development, energy, happiness, movement type and the arena — never from a hidden win
chance, a power score or the story.

Content: a humanoid dog, plus a **shark** (swimming) and an **eagle** (flying) who join
your lodge when you beat them; three arenas (meadow ring, lakeshore with deep water, windy
ridge with open sky); seven weapon types and six Aether schools; twenty mentors; armor,
energy, happiness, experience, Skill Matrix, training, techniques, results, recovery,
world map and versioned saves with replays.

## Play

Open the folder in Godot 4.7+ and press Play, or:

```bash
godot --path .
```

Battles are watched, not piloted:

| Replay | Touch (landscape) | Keyboard | Gamepad |
| --- | --- | --- | --- |
| Pause / resume | Tap the battle, or ❚❚ | Space | A |
| Speed 1× / 2× / 4× | Speed buttons | ← / → | LB / RB |
| Watch again | ⟲ Replay | — | — |
| Leave (to the result) | Skip ▶▶, Android back | Esc | Start |

In the lodge, tap the champion or a station; drag to pan; pinch or wheel to zoom.
The champion's **Skill Network** tab opens the *Aether Weave*: the Skill Matrix as a carved
disc with the champion's crest at its hub and rings growing outward (Foundation, Discipline,
Arms & Aether, Techniques), sectors for Offense, Guard, Endurance and Mobility, and veins that
fill with Aether as requirements are met. Drag to pan, pinch or wheel to zoom, tap a stone to
see what it needs, what it opens and which mentor can train it.

## The loop

`Title → New Journey → Opening story → Lodge (inspect, Skill Matrix, meet a mentor, train,
equip, Aether) → Journey (region → fight) → Opponent Preview → Select Champion → Battle
Preparation → Start Simulation → Watch Battle → Result (what it learned, mentor's notes) →
Story / Rewards → Journey → develop again → … → Home Valley Regional Trial → World Map`.

## Project layout

```
data/            Content resources (.tres): animals, weapons, armor, accessories, magic,
                 trainers, techniques, opponents, arenas, trials, regions, config
scripts/core/    Autoloads: Settings, Content, Game, Saves, Router, Sfx
scripts/data/    Resource classes and catalogs (GameConfig, AnimalData, SkillCatalog, …)
scripts/model/   Runtime state: OwnerProfile, Champion, SkillMatrix, ExperienceTracks
scripts/systems/ Rules: experience/growth, training, mentors, techniques, equipment,
                 trials, condition/recovery, quests, story, codex
scripts/simulation/  The battle simulation: specs and state, the tick pipeline (phases/),
                 rules (defense, weapons, effects, terrain, condition, victory), outcome,
                 experience, sessions and saved records
scripts/combat/  CombatStats — the derived numbers shared by previews and the simulation
scripts/ui/      Screens, lodge panels and components (theme, HUDs)
scripts/presentation/  Procedural world and bodies (dog, human, shark, eagle), humanoid rig
                 + animation library, glTF adapter, replay timeline and camera
scenes/          One thin scene per context: boot, title, story, lodge, world map, journey,
                 fight preview, champion select, battle prep, replay, result
tests/           Headless unit/integration tests and visual scenarios
tools/           run_tests.sh, balance_sim
docs/            Asset pipeline and implementation map
```

Data, gameplay, UI and presentation are separate. Nothing branches on species: a new
animal is an `AnimalData` resource; a new weapon, mentor, trial or Aether Art is data too.
Every balance number lives in `GameConfig` (`data/config/game_config.tres`).

## Tests and tools

```bash
tools/run_tests.sh              # re-import + all headless tests (unit, UI smoke, full Chapter 1 playthrough)
tools/run_tests.sh terrain      # only files whose name contains "terrain"
godot --headless --path . res://tools/balance_sim.tscn   # win rates vs every opponent
# Screenshots of any state (needs a display or xvfb-run):
godot --path . --write-movie out.png --fixed-fps 10 --quit-after 60 \
      res://tests/visual/scenario.tscn -- --scenario=replay --trial=valley_regional
```

Scenarios: `story`, `lodge`, `lodge_context`, `lodge_mid`, `panel --panel=<id>`, `result`,
`prep --trial=<id>`, `journey`, `preview --trial=<id>`, `champions`, `replay --trial=<id>
--speed=<n> [--skip]`, `map`, `network [--select=<node id>] [--fit]`; add `--scroll=<px>` to scroll a screen's list.
`tests/visual/dog_preview.tscn -- --animal=<id>` renders every animation clip for an animal.

## Art

All visuals are procedural placeholders built from primitives so the game runs with no
external assets. Champions are animals (`ProceduralDogVisual` and the shark and eagle
bodies built on it); mentors, Old Magnus and
other Keepers are people (`ProceduralHumanVisual`). Both share one humanoid rig, so they
play the same animation clips. The rig follows the reusable skeleton from the design, so the
Blender master character can replace it without touching gameplay — see
[`docs/ASSET_PIPELINE.md`](docs/ASSET_PIPELINE.md). Sounds are synthesized placeholders
behind named hooks (`Sfx.play("heavy_hit")`).

See [`docs/UX_REVIEW.md`](docs/UX_REVIEW.md) for the UI/UX and accessibility review, and
[`docs/IMPLEMENTATION_MAP.md`](docs/IMPLEMENTATION_MAP.md) for how each part of the
design maps to code, and what is deliberately left for Phase 2.
[`docs/COMBAT_SYSTEM_PLAN.md`](docs/COMBAT_SYSTEM_PLAN.md) plans the next combat stages (26+):
movement, move sets, defense, weapons, animation, AI, status effects and feedback.
