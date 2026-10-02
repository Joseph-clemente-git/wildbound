# WILDBOUND: Chronicles of the Aether

A mobile-first 3D animal fantasy adventure built with **Godot 4.7** (GL Compatibility, Jolt).
You are the Keeper of a small training lodge, inherited from its old owner, Old Marten.
Raise a young humanoid dog into a champion: train it with human mentors who can teach any
champion, equip it, teach it the Aether Arts and enter the trials of
the Home Valley. Champions grow from what they actually live — *"this animal became good at
this because of the way I raised and fought with it."*

This repository contains the complete **Chapter 1 MVP** described in `mechanics.md` and
`story.md`, now with a simulation-based battle system (see `docs/BATTLE_SIMULATION.md`): a humanoid dog
plus a shark and an eagle who can join your lodge, ground movement, 1v1, one arena, Sword/Hammer, Fire/Wind,
six mentors, armor, energy, happiness, experience, Skill Matrix, training, techniques,
results, recovery, world map and versioned saves.

## Play

Open the folder in Godot 4.7+ and press Play, or:

```bash
godot --path .
```

| Action | Touch (landscape) | Keyboard | Gamepad |
| --- | --- | --- | --- |
| Move | Left-side floating joystick (push to the rim to sprint) | WASD / arrows (+Shift sprint) | Left stick (+LB) |
| Attack / Heavy | Right buttons | J / K | X / Y |
| Dodge | Right button (direction = joystick) | Space | A |
| Block (hold) | Right button | L | RB |
| Aether Art | Right button (cooldown ring) | U | B |
| Pause / back | II button, Android back | Esc | Start |

In the lodge, tap the champion or a station; drag to pan; pinch or wheel to zoom.

## The loop

`Title → New Journey → Opening story → Lodge (inspect, Skill Matrix, meet a mentor, train,
equip, Aether) → Journey (region → fight) → Opponent Preview → Champion → Battle Preparation → Arena → Battle Result → Rest → develop
again → … → Home Valley Regional Trial → World Map`.

## Project layout

```
data/            Content resources (.tres): animals, weapons, armor, accessories, magic,
                 trainers, techniques, opponents, arenas, trials, regions, config
scripts/core/    Autoloads: Settings, Content, Game, Saves, Router, Sfx
scripts/data/    Resource classes and catalogs (GameConfig, AnimalData, SkillCatalog, …)
scripts/model/   Runtime state: OwnerProfile, Champion, SkillMatrix, ExperienceTracks
scripts/systems/ Rules: experience/growth, training, mentors, techniques, equipment,
                 trials, condition/recovery, quests, story, codex
scripts/combat/  Combatant, BattleManager, AiController, BattleRecorder, CombatStats,
                 PlayerController, BattleCamera
scripts/ui/      Screens, lodge panels and components (theme, HUDs, touch controls)
scripts/presentation/  Procedural world, humanoid rig + animation library, glTF adapter
scenes/          One thin scene per context: boot, title, story, lodge, world map,
                 battle prep, arena, result
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
tools/run_tests.sh combat       # only files whose name contains "combat"
godot --headless --path . res://tools/balance_sim.tscn   # win rates vs every opponent
# Screenshots of any state (needs a display or xvfb-run):
godot --path . --write-movie out.png --fixed-fps 10 --quit-after 60 \
      res://tests/visual/scenario.tscn -- --scenario=arena --trial=valley_regional
```

Scenarios: `story`, `lodge`, `lodge_context`, `lodge_mid`, `panel --panel=<id>`, `arena`,
`result`, `prep --trial=<id>`, `journey`, `preview --trial=<id>`, `champions`, `map`; `tests/visual/dog_preview.tscn` renders every animation clip.

## Art

All visuals are procedural placeholders built from primitives so the game runs with no
external assets. Champions are animals (`ProceduralDogVisual`); mentors, Old Marten and
other Keepers are people (`ProceduralHumanVisual`). Both share one humanoid rig, so they
play the same animation clips. The rig follows the reusable skeleton from the design, so the
Blender master character can replace it without touching gameplay — see
[`docs/ASSET_PIPELINE.md`](docs/ASSET_PIPELINE.md). Sounds are synthesized placeholders
behind named hooks (`Sfx.play("heavy_hit")`).

See [`docs/UX_REVIEW.md`](docs/UX_REVIEW.md) for the UI/UX and accessibility review, and
[`docs/IMPLEMENTATION_MAP.md`](docs/IMPLEMENTATION_MAP.md) for how each part of the
design maps to code, and what is deliberately left for Phase 2.
