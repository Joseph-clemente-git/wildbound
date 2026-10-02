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
| 2 | Battle Selection / Challenge Scene | — | |
| 3 | Opponent Preview | — | |
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
