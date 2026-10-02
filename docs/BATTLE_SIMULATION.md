# Battle simulation revision

Battles are moving from a player-controlled real-time arena to a **combat simulation**:
the player chooses a fight, chooses and prepares a champion, then watches a 3D replay of a
tick-based simulation whose result emerges from both combatants' animal, stats, Skill
Matrix, battle experience, equipment, mastery, Aether Arts, condition, behaviour and the
arena. No win percentages, power-score comparisons or quest-assigned results.

```
Home / Lodge → Journey → Region → Available Fights → Select Fight → Opponent Preview
→ Select Champion → Battle Preparation → Start Simulation → Watch Battle → Result
→ Story / Reward → Return to Journey
```

The work is done one verified stage at a time. The existing real-time arena
(`Combatant`, `BattleManager`, `AiController`, `PlayerController`) keeps the game playable
until the simulation replaces it.

| # | Stage | Status | Where |
| --- | --- | --- | --- |
| 1 | Opponent Data Model | Done | `data/opponent_data.gd`, `model/scouting_report.gd`, `tests/unit/test_opponents.gd` |
| 2 | Battle Selection / Challenge Scene | Done | `systems/challenge_board.gd`, `ui/screens/journey.gd`, `tests/unit/test_challenges.gd` |
| 3 | Opponent Preview | Done | `ui/screens/fight_preview.gd`, `presentation/world/fight_stage.gd`, `tests/unit/test_fight_preview.gd` |
| 4 | Champion Selection | — | |
| 5 | Battle Preparation | — | |
| 6 | Combat State Model | — | |
| 7 | Simulation Tick System | — | |
| 8 | Action System | — | |
| 9 | Attack Resolution | — | |
| 10 | Damage / Defense | — | |
| 11 | Dodge / Block | — | |
| 12 | Stamina | — | |
| 13 | Stagger / Knockback | — | |
| 14 | Weapon Behavior | — | |
| 15 | Magic Behavior | — | |
| 16 | Combat AI Decision System | — | |
| 17 | Victory / Defeat Conditions | — | |
| 18 | Battle Replay | — | |
| 19 | Battle Result | — | |
| 20 | Experience Event Tracking | — | |
| 21 | Natural Growth | — | |
| 22 | Trainer Development Integration | — | |
| 23 | Energy / Happiness Integration | — | |
| 24 | Save/Load Integration | — | |
| 25 | Mobile UX Polish | — | |

## Stage 1 — Opponent Data Model

An opponent (`OpponentData`) is built from the same blocks as a champion, so the
simulation can treat both sides alike and never needs species code:

| Group | Fields | Notes |
| --- | --- | --- |
| Identity | `id`, `display_name`, `title`, `bio`, `animal_id`, `palette`, `level` | Movement type and soft traits come from the `AnimalData`. `level` is display only. |
| Development | `stats`, `skills`, `techniques`, `battles_fought` | `stats` are developed stats **before** equipment. `rank_of()` mirrors a champion's Skill Matrix: unlisted fundamentals/disciplines are Foundation, unlisted weapons/schools unlearned. |
| Build | `weapon_id`, `armor_id`, `accessory_id`, `magic_ability_id` | Equipment modifiers apply through `CombatStats.with_equipment`, the same rule champions use. |
| Condition | `energy`, `happiness` | Simulation inputs, as for champions. |
| Tendencies | `aggression`, `caution`, `mobility`, `heavy_chance`, `magic_chance`, `preferred_range` | Preferences that will drive the decision layer. They are habits, not capability. |
| Legacy | `block_skill`, `dodge_skill`, `reaction_time`, `telegraph`, `phases` | Read only by the real-time `AiController`; the simulation derives these from the Skill Matrix and battle experience instead, and they are removed when it takes over. |

`OpponentData.validate()` checks the opponent's own data; `test_opponents.gd` checks
references (the opponent must have learned its weapon and its Art well enough to use it).

**Capability** ("Fighter", "Veteran"…) uses one formula for champions and opponents
(`Champion.score_capability`), computed from Skill Matrix ranks and techniques.

**Scouting** (`ScoutingReport.for_opponent`) is the partial picture for the opponent
preview. It reads the same `CombatStats` the battle uses, so it never misleads, but it
only shows names and bands:

- Opponent, Animal, Movement, Capability, Weapon family, Armor weight, Magic school
- Strength (force: heavy stagger + knockback), Defense (mitigation + stagger resistance),
  Mobility (move speed + dodge distance), Range (weapon reach or a ranged Art)
- Threats (e.g. *Heavy stagger*, *Fire attacks from range*, *Relentless pressure*) and
  openings (e.g. *Long recovery after heavy swings*, *Slow to reposition*, *Tires quickly*)

Health, attack speed, evasion, endurance, exact ranks and tendencies are never shown as
numbers; tests enforce that no preview field contains a digit. `describe_build` is
species-agnostic and is reused later to describe the player's own build in preparation.

## Stage 2 — Battle Selection / Challenge Scene

A fight is a `TrialData`: opponent, arena, region, energy cost, rewards, story hooks and
now a `challenge_type` (`GameEnums.ChallengeType`: Story Battle, Local Trial, Regional
Trial, Trainer Challenge, Wild Encounter, Elite Trial, Champion Battle — append-only), a
`reason` (why the Keeper would take it) and `repeatable` (one-time story fights become
*Completed* once won). The MVP content uses Local and Regional Trials; the other types
need only data.

`ChallengeBoard` holds the rules: regions (open first), the fights a region offers,
each fight's status (Available / Cleared / Completed / Locked), plain-language
requirements for locked fights, and how many fights are still to win. Selecting a
fight never looks at the champion — readiness (energy, knockout) belongs to champion
selection.

The **Journey** scene (`route "journey"`) replaces the lodge's Journey side panel:
regions on the left, the selected region's fights on the right. Each card shows the
challenge type, status, who you would face, why the fight matters, the arena, energy
cost and rewards — no power comparison or difficulty label. The lodge Map Board, the
title shortcut and the World Map ("Choose a fight") all lead here, and Battle
Preparation's Back returns here.

## Stage 3 — Opponent Preview

*Select Fight* opens the **Opponent Preview** (`route "fight_preview"`, params
`{"trial": id}`): the opponent stands in the arena in its own gear (weapon, armor
weight, Aether aura) while a sheet answers *who*, *why* and *where*:

- the challenge type, fight name and its reason;
- the opponent's name, title, bio and intro line, and its `ScoutingReport` fields —
  Animal, Movement, Capability, Weapon, Armor, Magic, and Strength / Defense / Mobility /
  Range as bands with a five-step meter;
- *What to watch for*: threats and openings;
- the arena with `ArenaData.features()` (ring size and cover, derived from its radius and
  obstacles, so new arenas describe themselves);
- energy cost and rewards.

No level, health, evasion, endurance, attack speed, skill rank, win chance or difficulty
label is shown; tests check that the scouting sections contain no digits. *Choose
Champion* continues (to Battle Preparation until Stage 4); Back returns to the Journey,
and Battle Preparation's Back returns to the preview. A fight that can no longer be
chosen sends the player back to the Journey once the scene transition finishes.

`FightStage` builds the shared 3D set (arena mood, meadow, posed and dressed
combatants) for the preview and Battle Preparation.
