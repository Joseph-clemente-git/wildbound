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
| 12 | Stamina | Done | `simulation/phases/stamina_phase.gd`, `tests/unit/test_stamina.gd` |
| 13 | Stagger / Knockback | Done | `simulation/phases/force_phase.gd`, `tests/unit/test_force.gd` |
| 14 | Weapon Behavior | Done | `simulation/weapon_rules.gd`, `WeaponData` Behavior group, `tests/unit/test_weapon_behavior.gd` |
| 15 | Magic Behavior | Done | `simulation/effect_rules.gd`, `phases/action_phase.gd`, `tests/unit/test_magic_behavior.gd` |
| 16 | Combat AI Decision System | Done | `simulation/phases/decision_phase.gd`, `simulation/combat_style.gd`, `tests/unit/test_combat_ai.gd` |
| 17 | Victory / Defeat Conditions | Done | `simulation/victory_rules.gd`, `simulation/battle_outcome.gd`, `tools/balance_sim.gd`, `tests/unit/test_victory.gd` |
| — | Terrain, movement types, Shark and Eagle | Done | `simulation/terrain_rules.gd`, `data/animals/humanoid_shark.tres`, `humanoid_eagle.tres`, `tests/unit/test_terrain.gd` |
| 18 | Battle Replay | Done | `simulation/battle_session.gd`, `presentation/replay/replay_timeline.gd`, `ui/screens/battle_replay.gd`, `tests/unit/test_replay.gd` |
| 19 | Battle Result | Done | `simulation/battle_moments.gd`, `ui/screens/battle_result.gd`, `tests/unit/test_battle_result.gd` |
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
"Change build" detour to the lodge are gone. *START SIMULATION* runs the battle and opens its replay
(Stage 18).

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
| Combat Decision | `decision` | Stage 16 — `DecisionPhase` |
| Action Resolution | `action` | Stage 8 — `ActionPhase` |
| Hit / Dodge / Block | `contact` | Stages 9 & 11 — `ContactPhase` + `DefenseRules` |
| Damage | `damage` | Stage 10 — `DamagePhase` |
| Stagger / Knockback | `force` | Stage 13 — `ForcePhase` |
| Position Update | `movement` | Stage 8 — `MovementPhase` |
| Stamina Update | `stamina` | Stage 12 — `StaminaPhase` |
| Cooldown / Recovery | `recovery` | Stage 7 — `CooldownPhase` |
| Knockout | `knockout` | Stage 7 — `KnockoutPhase`; Stage 17 — `VictoryRules` |

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

## Stage 12 — Stamina

`StaminaPhase` charges this tick's effort and gives breath back:

- **Costs** (from derived numbers): light and heavy attacks by weapon × armor ×
  attack-control skill; dodges × armor × dodge-control skill; Arts their own cost; a held
  guard drains per second (block-control skill eases it); every blocked blow costs its
  guard drain (Stage 11). A hammer and plate cost well over 1.5× a sword and light garb.
- **Recovery**: after spending, a short delay (`stamina_regen_delay`), then the
  Endurance-driven regeneration (stamina-discipline skill adds to it); a third of that
  while guarding. Endurance raises both the pool and the rate.
- **Exhaustion**: at zero, the combatant is exhausted for its derived exhaustion time
  (recovery-control skill shortens it): no attacks, dodges, casts or guard, and
  `exhausted_speed_factor` feet. A guard that runs dry **breaks** (`guard_break`).
- **Overexertion**: an action may begin with too little stamina left — it plays out and
  ends in exhaustion. Managing stamina is a real decision, which the decision layer
  (Stage 16) and experience (Stage 20) build on.

## Stage 13 — Stagger / Knockback

`ForcePhase` applies the physical force of blows — this is where **Strength** matters
apart from **Attack**:

- **Stagger meter.** Each clean blow adds the attacker's stagger power (light: weapon
  stagger × Strength; heavy: ~1.9× that; Arts: their stagger) × the target's
  `stagger_taken` (armor, defense-control skill). Passing the target's **poise**
  (40 + Defense × 0.5) staggers it and its current action is lost; one blow worth 1.4×
  poise knocks it down. A blocked blow adds 30% as guard pressure. The meter drains at
  30% of poise per second.
- **Stagger time** (0.55 s, ×1.3 for heavy blows; knockdown 1.1 s) shrinks with recovery
  skill and **Agility**.
- **Parries** stagger the attacker (0.7 s); a **broken guard** staggers the defender
  (0.9 s, triggered from the stamina step).
- **Knockback** — `push_velocity`, separate from walking: attacker knockback power
  (Strength, weapon; light blows half) × the target's resistance (armor, positioning
  skill, **Defense**), 40% through a guard. Pushes slide out at 9 m/s² and stop at walls.

Repeated sword cuts break poise after a few blows; one hammer heavy staggers or floors a
lightly armored target. Events: `staggered {reason, seconds}`, `knockdown`, `knockback`.

## Stage 14 — Weapon Behavior

Beyond their numbers (damage, speed, reach, arc, stamina, weight, Strength scaling,
stagger, recovery), weapons now carry **behavior traits** as data (`WeaponData`,
"Behavior" group), applied by `WeaponRules`:

| Trait | Weapons | Effect |
| --- | --- | --- |
| `heavy_hyper_armor` | Hammer, Axe | a heavy wind-up or strike is not flinched by light blows (`armored` event); poise still builds |
| `flank_bonus` | Dagger (+35%) | extra damage from the target's side or back (outside its front 120°) |
| `block_bonus` | Shield (0.5) | half the damage through a guard and half the guard drain |
| `point_blank_factor` | Bow (×0.55 within 2.5 m) | shots up close hit weakly |

**Flinch.** A clean blow that doesn't stagger still interrupts what the target was doing
for a moment (`FLINCH`, 0.35 s scaled by recovery skill and Agility) — trading blows
matters, and fast weapons interrupt slow wind-ups unless hyper armor holds.

**Techniques** (Advanced Techniques of the Skill Matrix) now work in the simulation when
learned, triggered by context (no extra button), paying their stamina cost:

| Technique | Trigger | Effect |
| --- | --- | --- |
| Riposte | first light cut within 0.75 s of a successful guard or parry | × its power (1.6) |
| Guard Break | a heavy blow that gets blocked | the guard breaks; defender staggered |
| Flame Slash | a heavy blow with Fire attuned | × its power and the target burns |
| Wind Dash | dodging with Wind attuned | dodge distance × its power |

In an 8-second exchange the sword lands ~6× as many blows, flinching its target over and
over; each hammer blow floors the target and drives it back more than 3× as far, so the
hammer has to close in again — the build visibly changes the fight.

## Stage 15 — Magic Behavior

Every Art has a cost, a cast time, a recovery, a cooldown, a shape (Stage 9) and now
lasting behavior, all from `MagicAbilityData`:

| School | MVP Art | Role in the simulation | Counterplay |
| --- | --- | --- | --- |
| Fire | Ember Bolt | slow projectile; damage and a **burn** (damage over time) | sidestep or dodge it; interrupt the wind-up |
| Fire | Flame Burst | burst around the caster; pushes and burns | back off; punish its long recovery |
| Wind | Gale Push | cone that **shoves** the target away | stay out of the cone; it does little damage |
| Wind | Wind Step | a long **protected dash** (the Art's `speed` in metres) | wait for the predictable landing |

`EffectRules` keeps effects as plain data in `CombatantState.effects`:

- **burn** — ticks every quarter second; armor blunts only half of it; wards reduce it.
- **slow** — movement × (1 − factor) (new `slow_factor`/`slow_seconds`; Frost Shard 0.45,
  Thornbind 0.6).
- **ward** — the caster turns aside a share of damage (new `ward_factor`/`ward_seconds`;
  Stone Ward 0.5 for 3 s).

A newer effect of the same kind refreshes the old one (stronger value, longer time) —
effects never stack into something unanswerable.

**Magic mastery** raises Art damage (Stage 10) and casts faster: −8% cast time per rank
above the Art's requirement (to 60%). **Interruption** is the core counterplay: a clean
hit during a cast's wind-up cancels it — the stamina is spent, nothing is released and no
cooldown starts (`interrupted` event); uninterruptible Arts shrug off flinches.

## Stage 16 — Combat AI Decision System

`DecisionPhase` gives each combatant a **mind** that reads the battle state every tick
and produces an intent. It decides what a fighter *tries*; the pipeline decides what that
achieves. The only randomness is a small seeded spread on reactions, timing and how
eagerly a tendency acts.

**Threats → answers.** An enemy wind-up that will reach, a cast aimed its way or a shot in
flight is noticed after a **reaction time** (0.30 s − 0.03 per Timing rank − Agility ×
0.001 − battle experience × 0.0015, 0.08–0.40 s). The mind scores its answers —

- **dodge**: dodge skill, Evasion, mobility, heavy or ranged threats, light armor, agile and
  ranged builds;
- **block**: block skill, Defense, a shield, light blows; worse against heavies or when low
  on stamina;
- **counter**: when its own wind-up lands first and the attacker has no hyper armor;
- **sidestep**: for slow shots —

and times it for the perfect moment with an error of ±(0.20 − 0.022 × Timing − 0.0012 ×
experience − 0.012 × the matching skill rank). A fresh champion reads only heavies; a
drilled veteran reads sword cuts and evades, blocks and parries far more. Fighters also
**anticipate**: with an enemy in reach, careful fighters raise a guard before anything is
thrown, and strike out of it the moment the enemy opens up.

**Initiative.** Openings (wind-ups, recoveries, casts, staggers, exhaustion) are punished
at once — with a heavy when it lands in time. Guards are pressured with heavies (more with
high guard pressure). Otherwise attacks come at a pace set by **aggression** (swinging into
a ready opponent risks a dodge, parry or counter). Combos continue while they work. Arts
are cast when their shape fits: bolts from range or at openings, cones and bursts when
pressed, dashes when cornered.

**Condition and position.** Low stamina (threshold rises with **caution**) stops new
attacks and backs off to recover; low health turns defensive. Fighters hold their build's
preferred range, circle by **mobility**, steer off the ring edge and around obstacles.

**Build changes behavior** (`CombatStyle`, from gear and body, never species):

| Style | Builds | Behavior |
| --- | --- | --- |
| heavy | hyper-armored weapons (Hammer, Axe) | closes in, favours heavies (≈5× a sword's share), punishes into short windows, rarely guards |
| agile | flanking weapons (Dagger) or a very agile light build | circles to the flank while the target is committed, prefers dodging, strikes openings |
| ranged | ranged weapons (Bow) | shoots from 5 m+, never from under 3.5 m, kites on a curve |
| balanced | everything else (Sword) | a mix |

Champions' tendencies come from their build (`CombatStyle.tendencies_for`); opponents use
their profile. Probe results over 12 seeds each: a fresh Bruno beats Pip 12/12, Juniper
~7/12, Rook ~2/12, Marla 0/12; a trained Bruno (Skilled sword, block, dodge, timing;
+12 stats) wins 11–12/12 against all four. Every fight ends by knockout.

## Stage 17 — Victory / Defeat Conditions

- **Knockout** — when only one team has anyone standing it wins; if the last fighters on
  both sides fall on the same tick it is a **draw**.
- **Time limit** (180 s) — settled by a **decision on performance** (`VictoryRules`): the
  side with ≥ 3% more health left (by share of maximum) wins; otherwise damage dealt breaks
  a near tie (≥ 10% difference); otherwise a draw. Never by chance. `battle_end` carries
  `reason: knockout | decision | draw`.
- **`BattleOutcome.from(state, log)`** (also `BattleSimulator.outcome()`) sums the battle up:
  winner, reason, duration, and per combatant `damage_dealt`, `damage_taken`, `hits_landed`,
  `heavy_hits`, `blows_blocked_by_foe`, `blows_evaded_by_foe`, `whiffs`, `dodges`,
  `perfect_dodges`, `blocks`, `parries`, `staggers_caused`, `knockdowns_caused`,
  `flinches_caused`, `interruptions_caused`, `guard_breaks_caused`, `openings_punished`,
  `flank_hits`, `casts`, `techniques`, `exhaustions`, `staggered`, `knocked_down`,
  `max_combo`, `health_left`, `health_ratio`, `lowest_health_ratio`, `knocked_out`. The
  result screen (Stage 19) and experience (Stage 20) read it.

`tools/balance_sim.tscn` now runs through the simulation (24 seeds per matchup):

| Champion | Pip | Rook | Juniper | Marla |
| --- | --- | --- | --- | --- |
| fresh (no sword training) | 50% | 0% | 4% | 0% |
| trained (Apprentice sword, +5 stats) | 100% | 88% | 71% | 4% |
| veteran (Skilled sword, more training) | 100% | 100% | 96% | 63% |

Every fight ends by knockout; the regional champion asks for real development.

## Terrain, movement types, Shark and Eagle

Two new animals — the **Humanoid Shark** (Swimming) and the **Humanoid Eagle** (Flying) —
and the terrain that makes their movement types matter. Everything is keyed by
`MovementType` and the new **Natural Foundation** skills, never by species
(`TerrainRules`):

| Movement | On land | In deep water | In the air |
| --- | --- | --- | --- |
| Ground | normal | ×0.62 speed, ×0.75 dodge, ×0.8 recovery | — |
| Swimming | ×0.72 speed, ×0.8 dodge, ×0.85 recovery | ×1.25 speed, ×1.25 dodge, ×1.2 recovery, ×1.06 damage | — |
| Amphibious | ×0.95 speed | ×1.12 speed | — |
| Flying | normal when grounded | not slowed while aloft | ×1.15 speed, flies over low obstacles |

- **Natural Foundation** (new top layer of the Skill Matrix): **Swimming** and **Flight**.
  Each rank eases water penalties / flight costs and sharpens a swimmer's edge or a
  diver's swoop, for any animal (a dog with Swimming wades better). Shown in the Skill
  Matrix when learned.
- **Arenas** gain `water_zones` (deep water circles) and `air_ceiling` (open air for
  fliers; 0 = none). `features()` mentions water and open sky.
- **Fliers** cruise at 2.4 m above melee reach where the arena has air, paying stamina
  and recovering at about a third of the usual rate while aloft. They **swoop** to 0.4 m
  to strike or cast — and are within reach while they do. Shots reach them aloft; wind
  Arts reach up and **ground** them (`grounds_fliers`, Gale Push); any stagger or
  knockdown knocks them out of the air for 1.4 s; a tired flier lands to rest. Flight is
  mobility, not immunity.
- **The decision layer** knows terrain: fliers dive into reach (`can_reach`), walkers hold
  the shoreline instead of wading after a swimmer and dodge away from deep water,
  swimmers drift back to the water, and tired or resting opponents are pressed hard.
- **Bodies**: `ProceduralSharkVisual` (pointed head, jaw and teeth, gill flaps on the ear
  bones, dorsal and crescent tail fins) and `ProceduralEagleVisual` (white head, hooked
  beak, crest on the ear bones, folding wings, tail fan) share the humanoid rig and every
  animation clip with the dog.
- **Content**: arenas *Lakeshore Shallows* (half deep water) and *Windy Ridge* (tall
  stones, high open sky); visiting champions **Finn** (shark, hammer) and **Aquila**
  (eagle, sword, Gale Push); two **Elite Trials** in the Home Valley. Beating a visitor the
  first time **recruits** it: it joins the lodge (with its weapon) and can be chosen for
  any fight (`TrialData.recruit_on_first_win`, `Game.add_champion`).

Outcomes (Bruno, Apprentice sword, 10 seeds): vs Finn on its shore 2/10, on the same
arena drained 9/10, on the meadow 8/10 — swimming is a home advantage, not an automatic
win. Vs Aquila on the ridge 3/10, with no room to fly 9/10.

## Stage 18 — Battle Replay

**START SIMULATION** (Battle Preparation) pays the entry, then `BattleSession.start`
simulates the whole battle headless (~0.1 s), **applies its result at once**
(`TrialSystem.apply_result`: rewards, knockout, records, story, recruitment) and keeps the
log. The replay only *shows* what happened — skipping it, closing the app or watching it
again can never change the outcome.

**`ReplayTimeline`** reads a `BattleLog` for playback: `sample(t)` interpolates every
combatant (position, height, facing, health, stamina) between keyframes (now every 3
ticks, 0.1 s), `projectiles(t)` the shots in flight, `events_between(t0, t1)` the events
of a window (each plays exactly once), and **action spans** — each action with its real
start and end — so every clip plays exactly as long as the simulation did.

**The replay screen** (`route "replay"`, params `{"session"}`) builds the arena in 3D
(water included), gives each combatant its body in its own gear and Aether aura, and
plays the battle:

- attacks, heavies, guards, dodges, casts, flinches, staggers, knockdowns and knockouts
  as animation clips; walking and running from the movement; an eagle's wings spread
  with its height;
- damage numbers (red for punished openings), hit flashes, guard flashes, technique and
  parry call-outs, Art effects and bolts in flight, camera shake on heavy blows, sound
  hooks, and a short commentary ticker;
- health and stamina bars for both sides;
- **❚❚ / ▶**, **1× 2× 4×**, **⟲ Replay**, **Skip ▶▶**; at the end a Victory / Defeat /
  Draw banner (by knockout, on decision, too close to call) with *Watch again* and *See the
  result*. The Android back button skips to the result.

The legacy real-time arena scene is no longer on the player's path.

## Stage 19 — Battle Result

The result screen tells the simulated battle (params `{"outcome", "session"}`):

- **Victory / Defeat / Draw** and how it ended — "by knockout at 0:26", "on the judges'
  decision after 3:00", "a draw after 3:00" — and the opponent's line for that outcome
  (`win_line` when the Keeper wins; this was reversed before).
- **The fight** — a side-by-side table from `BattleOutcome`: damage dealt, damage received,
  successful attacks, dodges, blocks & parries, staggers & knockdowns, knocked out.
- **Moments** (`BattleMoments.tell`) — up to five lines from the log: the first knockdown,
  the biggest blow (and whether it punished an opening), parries, techniques used, guard
  breaks suffered, a comeback from below a quarter health, running out of breath.
- What the champion **learned** (experience and natural growth — Stage 20), **rewards**
  (coins, Keeper XP, animal XP), **condition** (energy, bond).
- A **recruited** visitor is announced.
- **Next**: *⟲ Watch again* (reopens the replay), *Lodge*, and the primary step — **Back to
  the Journey**, or **Rest & recover** for a knocked-out champion. Story events play first.
