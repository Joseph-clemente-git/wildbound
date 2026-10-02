# Implementation map

How the design documents (`mechanics.md`, `story.md`) map to this codebase.

The battle system is being revised into a combat simulation, stage by stage — see
[`BATTLE_SIMULATION.md`](BATTLE_SIMULATION.md) for the plan and what each stage changed.

## Mechanics prompts (MVP, Phase 1)

| Prompt | Where |
| --- | --- |
| 01 Foundation (data / gameplay / UI / presentation) | `project.godot`, `scripts/core/*`, folder layout |
| 02 Boot + menu | `scripts/ui/screens/boot_screen.gd`, `title_screen.gd`, `panels/settings_panel.gd` |
| 03 Owner + home | `model/owner_profile.gd`, `ui/screens/lodge.gd`, `ui/components/lodge_hud.gd` |
| 04 AnimalData | `data/animal_data.gd`, `data/animals/humanoid_dog.tres` |
| 05 Skill Matrix data | `data/skill_catalog.gd`, `model/skill_matrix.gd` |
| 06 Animal management | `ui/panels/champion_panel.gd` (multiple champions supported by `Game.champions`) |
| 07 Owner level + slots | `OwnerProfile.slots_for_level`, `GameConfig.trainer_slot_levels` |
| 08–09 Experience + natural growth | `systems/experience_session.gd`, `systems/growth_system.gd`, `model/experience_tracks.gd` |
| 10–12 Trainers, rarity, active circle | `data/trainer_data.gd`, `data/trainer_traits.gd`, `systems/trainer_manager.gd`, `ui/panels/trainers_panel.gd` |
| 13 Energy + happiness | `Champion` condition API, `systems/condition_system.gd` |
| 14 Training | `systems/training_system.gd`, `ui/panels/training_panel.gd` |
| 15 Technique prerequisites | `data/technique_data.gd`, `systems/technique_system.gd` |
| 16–17 Equipment data + UI | `data/weapon_data.gd`, `armor_data.gd`, `accessory_data.gd`, `systems/equipment_system.gd`, `ui/panels/equipment_panel.gd` |
| 18–19 Weapon / magic familiarity + mastery | experience tracks `weapon:*`/`magic:*` (familiarity capped at Apprentice) + trainer mastery |
| 20 Combat foundation | `combat/combatant.gd`, `combat/battle_manager.gd`, `combat/combat_stats.gd` |
| 21 Combat experience events | `combat/battle_recorder.gd` |
| 22 Mobile controls | `ui/components/touch_joystick.gd`, `action_pad.gd`, `combat/player_controller.gd` |
| 23 Stamina | `Combatant` stamina/exhaustion, `GameConfig` combat group |
| 24 Sword + Hammer | `data/weapons/*.tres` + heavy-weapon hyper armor |
| 25 Fire + Wind | `data/magic/fire.tres`, `wind.tres`, `BattleManager.release_ability` |
| 26 Balance / counterplay | `AnimalData` balance profile + `combat_traits`, `tools/balance_sim.gd` |
| 27 First arena | `data/arenas/meadow_ring.tres`, `presentation/world/arena_builder.gd`, `combat/battle_camera.gd` |
| 28 Battle preparation | `ui/screens/battle_prep.gd` |
| 29 Battle results | `systems/trial_system.gd`, `ui/screens/battle_result.gd` |
| 30 Recovery | `systems/condition_system.gd`, `ui/panels/recovery_panel.gd` |
| 31 Save / load | `core/save_manager.gd` (versioned JSON, migrations, backup), `Game.to_dict/load_from_dict` |
| 32 Character pipeline | `presentation/character/*`, `docs/ASSET_PIPELINE.md` |
| 33 Mobile UX | safe areas, touch sizes, side sheets, back button, pinch zoom, control scale, left-handed layout |
| 34 Combat polish | hit-stop, shake, floating text, vibration, audio hooks, perfect windows |

## Story steps

Boot/title (§9-10), New Journey + opening cinematic with naming (§11-12), the Lodge as a 3D
hub with contextual actions (§13-15), the first quest (§16, `systems/quest_log.gd`), the
Swordmaster (§17), progressive Skill Matrix (§18), first weapon (§19), the tutorial trial
whose phases teach dodge → timing → stamina (§20, `data/opponents/pip.tres`), growth-first
results (§21, §37), Marten's map (§22), world map (§23), Continue and introduced-only menu
shortcuts (§25), Champions / Mentors / Equipment Hall / Aether Circle / Codex (§27-32),
Trials (§33), mentor suggestions after battle (§39), knockouts not deaths (§36).

## Deliberately deferred (Phase 2 and later chapters)

Per the design's "do not implement future features early":

- Second animal, Flying, Swimming, Amphibious movement (data supports `MovementType`).
- 2v2 / 3v3 and larger arenas (`ArenaData.format` exists).
- Combat behaviour for Dagger, Spear, Axe, Shield, Bow and the Frost/Earth/Lightning/
  Nature schools — their data exists and is region-locked.
- Regions beyond the Home Valley (shown on the map as later chapters).
- Environmental magic interactions with terrain.
- Real Blender assets and recorded audio (pipeline + hooks are ready).
