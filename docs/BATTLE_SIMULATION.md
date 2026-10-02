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
| 4 | Champion Selection | Done | `systems/champion_selection.gd`, `ui/screens/champion_select.gd`, `tests/unit/test_champion_select.gd` |
| 5 | Battle Preparation | Done | `model/matchup_analysis.gd`, `ui/screens/battle_prep.gd`, `tests/unit/test_battle_prep.gd` |
| 6 | Combat State Model | Done | `simulation/combatant_spec.gd`, `combatant_state.gd`, `arena_layout.gd`, `battle_state.gd`, `tests/unit/test_battle_state.gd` |
| 7 | Simulation Tick System | Done | `simulation/battle_simulator.gd`, `simulation_phase.gd`, `sim_frame.gd`, `battle_log.gd`, `phases/`, `tests/unit/test_simulation_tick.gd` |
| 8 | Action System | Done | `simulation/phases/action_phase.gd`, `movement_phase.gd`, `scripted_decision_phase.gd`, `tests/unit/test_action_system.gd` |
| 9 | Attack Resolution | Done | `simulation/phases/contact_phase.gd`, `tests/unit/test_attack_resolution.gd` |
| 10 | Damage / Defense | Done | `simulation/phases/damage_phase.gd`, `tests/unit/test_damage.gd` |
| 11 | Dodge / Block | Done | `simulation/defense_rules.gd`, `phases/contact_phase.gd`, `tests/unit/test_dodge_block.gd` |
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
Champion* continues to Champion Selection; Back returns to the Journey,
and Battle Preparation's Back returns to the preview. A fight that can no longer be
chosen sends the player back to the Journey once the scene transition finishes.

`FightStage` builds the shared 3D set (arena mood, meadow, posed and dressed
combatants) for the preview and Battle Preparation.

## Stage 4 — Champion Selection

*Choose Champion* opens **Champion Selection** (`route "champion_select"`, params
`{"trial": id, "champion": uid?}`). Every champion in `Game.champions` is listed, ready
ones first, with animal, movement, current build, level, capability, an energy bar and a
mood bar. The chosen one stands in the arena on the right.

`ChampionSelection` holds the rules:

- **Readiness** comes from `TrialSystem.champion_blocker` (knockout, not enough energy
  for this fight). `entry_blocker` is now "fight open" + `champion_blocker`, so readiness
  never depends on whether the fight itself is unlocked.
- **Notes** are warnings that do not block: no weapon equipped, low mood, energy left
  after entering.
- **Default choice**: the champion the Keeper was working with if ready, else the first
  ready one.
- **Choosing** selects the champion (`Game.select_champion`), so Battle Preparation, the
  battle, its result and growth all apply to it. The uid also travels in the route
  params; Stage 6's battle state will carry it explicitly.

A champion that is not ready cannot be prepared; the screen says why and offers *Rest at
the lodge*, which selects that champion first so the Rest Area cares for the right one.
Battle Preparation's Back returns here with the same champion selected. 
## Stage 5 — Battle Preparation

Battle Preparation answers *"How should I prepare for this specific opponent?"*

**`MatchupAnalysis.analyse(champion, opponent, arena, overrides)`** is the tactical
preview. The champion is described with `ScoutingReport.for_champion` — the same bands
as the opponent — so both sides compare like for like. It returns:

- **Opponent Strength** (the opponent's force band) and the **Threat** (its top threat);
- **advantages**, most important first: a better band on Strength / Defense / Mobility /
  Range ("Reach"), *Punishing slow recoveries*, *Better weapon technique* (Skill Matrix
  weapon rank above theirs), *Outlasting them* (stamina), *Room to outmanoeuvre* (wide
  arena);
- **risks**, most important first: *Fighting without a weapon*, *Untrained with the …*,
  *Close-range pressure* (their force High+ against your Defense Medium or lower), *Being
  worn down from range*, *Being outmanoeuvred*, *Breaking through their guard*, *Less
  weapon technique*, *Tiring first in a long fight*, *Tight ring: little room to escape
  pressure*.

`main_advantage()` and `main_risk()` give the headline; nothing contains a number.
`option_effects(champion, overrides)` shows what another build would change, one arrow
per band moved ("Defense ↑↑ · Mobility ↓↓").

**The screen** (sheet on the left, champion and opponent in the arena on the right):

1. *Tactical read* — Opponent Strength, Threat, Your Advantage, Main Risk, then the full
   lists.
2. *Build for this fight* — owned weapons (with the champion's mastery rank), owned armor
   (with weight) and learned Aether Arts (plus none). Each option shows its effect on the
   matchup; tapping equips it on the champion, the read updates and the champion is
   re-dressed in 3D.
3. The champion — level, capability, the relevant Skill Matrix ranks (equipped weapon and
   school, Dodge, Block, Stamina, Timing), techniques, energy (with this fight's cost) and
   mood.
4. The opponent — capability and build, and a side-by-side table of Strength / Defense /
   Mobility / Range with the champion's better and worse bands highlighted.
5. The arena's features and the rewards.

The power-score "Difficulty" line, the old style notes based on legacy AI knobs and the
"Change build" detour to the lodge are gone. *ENTER TRIAL* still starts the real-time
arena until the simulation exists (Stages 6–18).

## Stage 6 — Combat State Model

The simulation lives in `scripts/simulation/`, apart from the legacy real-time
`scripts/combat/`. Stage 6 is data only — nothing moves yet.

```
BattleState                      the whole battle
├─ arena: ArenaData, layout: ArenaLayout
├─ combatants: [CombatantState]  any number per team (team 0 = Keeper's side)
│   ├─ spec: CombatantSpec       frozen inputs
│   └─ position, elevation, facing, velocity, health, stamina, action, phase,
│      combo_step, target, stagger_meter, exhaustion, cooldowns, effects
├─ tick, time
├─ battle_seed, rng              all controlled variation comes from here
└─ finished, winner_team
```

**`CombatantSpec`** — one combatant's inputs, built the same way for both sides
(`from_champion`, `from_opponent`): id, name, source, animal, movement type, final stats
(developed + equipment via `CombatStats.with_equipment`), the whole Skill Matrix,
techniques, battle experience (a champion's wins + losses, an opponent's
`battles_fought`), weapon, armor, accessory, the Aether Art it can actually use, weapon
and magic mastery, energy, happiness, tendencies, and `derived` combat numbers from the
same `CombatStats` formula the previews read. It is a snapshot: changing the champion
afterwards does not change a battle already set up. Champions use neutral default
tendencies (a preferred range from their weapon's reach, a magic preference when they
carry an Art); build-driven behaviour comes with the decision system (Stages 16–17).

**`CombatantState`** — the live, per-tick part: planar position (x, z) plus elevation,
facing, velocity, health and stamina pools, the current `Action` (idle, move, attack,
heavy, block, dodge, cast, stagger, knockdown, recover, KO) and `Phase` (wind-up,
active, recovery), combo step, target, stagger meter, exhaustion, cooldowns and effects.

**`ArenaLayout`** — the arena as geometry: ring radius, circular obstacles with heights,
and spawn points per team. Extra teammates line up beside the first spawn, so 2v2 and
3v3 work on any arena. Water, elevation and air zones can be added here later.

**`BattleState.create(arena, player_specs, opponent_specs, seed)`** places everyone,
faces each combatant toward its nearest enemy and fills health and stamina.
`for_fight(trial, champion)` builds the MVP 1v1 and derives the seed from the fight and
the champion's record (a new bout varies slightly; the same bout replays exactly).
`validate()` rejects empty teams, starts outside the ring, inside obstacles or on top
of each other. `snapshot()` is plain data — two states built from the same inputs and
seed produce identical snapshots, the basis for deterministic replays. A test checks
that nothing in `scripts/simulation/` refers to a species.

## Stage 7 — Simulation Tick System

`BattleSimulator.create(state)` runs a battle in fixed ticks
(`GameConfig.simulation_tick_rate`, 30 per simulated second), independent of the display
frame rate. Every tick passes through the same pipeline, in this order:

| Step | Pipeline name | Built in |
| --- | --- | --- |
| Combat Decision | `decision` | Stage 16 |
| Action Resolution | `action` | Stage 8 — `ActionPhase` |
| Hit / Dodge / Block | `contact` | Stages 9 & 11 — `ContactPhase` + `DefenseRules` |
| Damage | `damage` | Stage 10 — `DamagePhase` |
| Stagger / Knockback | `force` | Stage 13 |
| Position Update | `movement` | Stage 8 — `MovementPhase` |
| Stamina Update | `stamina` | Stage 12 |
| Cooldown / Recovery | `recovery` | Stage 7 — `CooldownPhase` |
| Knockout | `knockout` | Stage 7 — `KnockoutPhase` (Stage 17 adds the other end conditions) |

Each step is a `SimulationPhase` with `run(state, frame)`; a step not built yet is the
base class and does nothing. `use_phase()` swaps one in by name, so later stages (and
tests) plug in without touching the loop.

- **`SimFrame`** — one tick's scratch data passed along the pipeline: intents from the
  decision step, contacts from action resolution, and the tick's events
  (`emit(type, actor, target, data)`).
- **`CooldownPhase`** counts down cooldowns, exhaustion and lasting effects.
- **`KnockoutPhase`** knocks out anyone at zero health and ends the battle when only one
  team has anyone standing.
- **Time limit** — at `simulation_max_seconds` (180 s) the battle stops with no winner and a
  `battle_end` event of reason `time`; Stage 17 decides what that means.
- **`BattleLog`** — header (arena, seed, every combatant's spec), every event in order,
  a full snapshot every `simulation_keyframe_ticks` (6) ticks plus the first and final
  states. The replay (Stage 18), results (Stage 19) and experience (Stage 20) read it.

The simulator never picks a winner: with no combat phases a battle runs to the time
limit undecided. Time is derived from the tick count, so it never drifts. The same state
and seed produce an identical log; a full-length battle simulates headless well inside a
second.

## Stage 8 — Action System

**Intents** (from the decision step) look like
`{"action": "attack" | "heavy" | "block" | "dodge" | "cast" | "", "move": Vector2,
"dodge_dir": Vector2}`. Until Stage 16, `ScriptedDecisionPhase` supplies them from a
callable (tests, tools, demos).

**`ActionPhase`** (Action Resolution) commits intents into timed actions and advances
them through WINDUP → ACTIVE → RECOVERY. Lengths come from the spec's derived numbers:

| Action | Wind-up | Active | Recovery | Shaped by |
| --- | --- | --- | --- | --- |
| Light attack | weapon wind-up ÷ action speed | weapon active | weapon recovery ÷ action speed | weapon, Attack Speed, weapon mastery |
| Heavy attack | heavy wind-up ÷ action speed | active × 1.2 | heavy recovery ÷ action speed | same |
| Dodge | none | protected window (dodge skill) | dodge recovery (Evasion) | Evasion, dodge skill, armor |
| Cast | cast time | release | the Art's recovery | the Art; sets its cooldown |
| Block | raise (0.08 s) | held while wanted | — | — |

- Committed actions play out — no cancelling a heavy wind-up into a dodge. Only idle,
  moving or guarding combatants start something new; dropping a guard is immediate.
- Light attacks chain during recovery up to the derived combo length (Skilled weapon
  mastery adds a step); the chain resets afterwards.
- When an attack's ACTIVE window opens, a contact `{attacker, kind, combo, target}` goes
  into the frame for Hit / Dodge / Block (Stage 9) plus a `strike` event; a cast releases
  its Art as a contact and a `cast_release` event.
- Stagger, knockdown and recover (set by later stages) just run out their timer here.
- Events: `action_start`, `strike`, `cast_release`, `dodge`, `block_up`, `block_down`,
  `action_end`.

**`MovementPhase`** (Position Update):

- speed = derived move speed × what the combatant is doing (free 1.0, guarding 0.4,
  winding up 0.25, striking/recovering/casting 0) × terrain (ground everywhere for now —
  water, air and elevation plug in by movement type, never species);
- acceleration toward the wanted velocity grows with Agility (responsiveness);
- turning toward the target at the derived turn speed, ×0.3 while committed;
- a dodge covers its dodge distance during its protected window, then stops;
- while staggered, pushes slide out (knockback arrives in Stage 13);
- the ring edge and obstacles stop movement (sliding along them), and bodies never
  overlap.

Tuning lives in `GameConfig` (Simulation group). In a scripted exchange Bruno's sword
strikes every ~0.33 s in three-hit chains while Rook's heavy hammer takes ~1.1 s to land
and ~2.4 s per cycle.

## Stage 9 — Attack Resolution

`ContactPhase` (the `contact` step) decides whether an attack reaches anyone. It is
geometry, never a roll.

- **Melee.** `ActionPhase` now hands over a contact on *every* tick of an attack's active
  window, tagged with the swing's id. A swing reaches an enemy whose body is within the
  weapon's reach, inside the weapon's arc around the attacker's facing (the body widens
  the angle a little), with no obstacle on the line between them. Each swing strikes each
  target at most once (`CombatantState.struck`), and a wide arc can catch two enemies. A
  swing that strikes no one emits `whiff` as it ends. Reach and arc differ per weapon
  (dagger 1.3 m, sword 1.9 m / 100°, hammer 2.0 m / 80°, spear 2.9 m / 40°…).
- **Shots.** Projectile Arts (Ember Bolt) and ranged weapons (`WeaponData.projectile_speed`
  > 0; the bow is 24 m/s) loose a shot toward where the target is at release — no leading,
  so stepping aside is real counterplay. Shots live in `BattleState.projectiles`, fly at
  their speed, sweep their path for bodies, stop on obstacles (`projectile_blocked`) and
  fade at their range or the ring edge (`projectile_faded`).
- **Areas.** Cone Arts (Gale Push) strike enemies within range inside the cone; bursts
  (Flame Burst) strike everyone within their radius, facing or not. Movement Arts (Wind
  Step) strike no one — their movement is Magic Behavior (Stage 15).
- Teammates are never struck.

Every connection becomes a **hit** in `SimFrame.hits` — `{attacker, target, kind,
combo, swing, ability, direction, via: melee | projectile | area}` — plus a `hit` event.
Dodging and blocking it (Stage 11) and its damage (Stage 10) come next.

## Stage 10 — Damage / Defense

`DamagePhase` turns each hit that got through into lost health:

```
raw   = light: derived damage × (1 + 0.10 per combo step after the first)
        heavy: derived heavy damage (Strength-scaled)
        Art:   Art damage × (1 + 0.06 per magic mastery rank above its requirement)
      × opening bonus 1.12 + 0.02 per mastery rank, when the target is committed
        (winding up, recovering, casting, staggered)
      × controlled variation ±(9% − 1.2% per mastery rank, at least 2%), seeded
      × (1 − target mitigation)           Defense, armor, defense skill
      × target block factor if blocked    (Stage 11)
```

- **Attack** raises every blow; **Strength** raises heavy blows more than light ones (and
  drives force in Stage 13); **Defense** and armor reduce everything.
- **Weapon mastery** is more than a small damage bonus: an expert's damage is more
  consistent and punishes openings harder, so *High Attack + Novice Sword* and *High
  Attack + Expert Sword* fight differently.
- Health actually drops, so the Knockout step now ends battles: a scripted 1v1 reaches a
  decided knockout, and the same seed reproduces it exactly.
- Events: `damage {amount, kind, outcome, opening, health_left}`; each hit records its
  `damage` and `opening`.

## Stage 11 — Dodge / Block

Each hit is answered at the moment of contact by `DefenseRules.resolve` — timing and
position, never a roll:

| Outcome | When | Effect |
| --- | --- | --- |
| **evaded** | the target is inside a dodge's protected window (length from dodge skill) | no damage; inside the first half of the perfect window it is *perfect* |
| **parried** | a melee blow meets a guard raised within the perfect window (Timing widens it), facing the attacker | no damage; the attacker is left exposed (stagger in Stage 13) |
| **blocked** | a raised guard facing the attacker (±70°) | only the block factor gets through (block skill, Defense); the guard pays `guard_drain` stamina = raw × 0.35 × attacker's guard pressure (half if perfect) — applied in Stage 12 |
| **hit** | anything else — no guard, a guard still rising, a blow from behind, a dodge's recovery | full damage |

**Evasion** is not a miss chance: it sets how far a dodge carries and how quickly it
recovers, so a well-timed, evasive dodge gets out of reach entirely. Heavier weapons press
a guard much harder (hammer guard pressure is over twice the sword's). A dodged shot flies
on past its target (it can't hit the same target twice); a blocked shot stops.
Events: `hit {outcome, perfect}`, `evade`, `parry`, `block {guard_drain}`.
