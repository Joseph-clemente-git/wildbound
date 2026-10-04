# 3D combat system expansion plan

A plan for the full "3D Combat System" feature list (movement, attacks, defense, weapons,
animation, hit detection, AI, attributes, status effects and feedback): what the game
already has, what each missing feature means in Wildbound, and the order to build it in.

It continues the staged approach of [`BATTLE_SIMULATION.md`](BATTLE_SIMULATION.md):
Stages 1–25 are done, so this plan starts at **Stage 26**. Each stage is small enough to
verify on its own, keeps the game shippable and ends with tests.

## 0. The key decision: watched simulation or player control

The feature list reads like a player-controlled action game (sprint, target lock, light
and heavy buttons). Wildbound deliberately **retired** that in Stage 25: battles are a
deterministic, tick-based simulation that the Keeper **watches** as a 3D replay, and the
result comes from how the champion was raised.

**Recommendation: build every feature into the simulation, not as player input.** Each
feature becomes something the champion *does* because of its build, skills, experience
and AI, and the replay *shows* it. This keeps:

- the core promise: *"this animal became good at this because of the way I raised it"*;
- determinism (saved battles are inputs + seed, re-simulated on rewatch);
- mobile-friendliness (no twitch input on a phone).

Player control could still come back later as an optional **Spar** mode without
rewriting anything. Intents are already the seam: a `PlayerDecisionPhase` that turns
touch input into the same `{"action", "move", "dodge_dir"}` intents can be plugged in
with `BattleSimulator.use_phase("decision", …)`. That is out of scope here; see §6.

Every row below assumes the recommendation. If you want player control as the main
mode, sections 3 (Movement), 7 (Combat AI) and 10 (Feedback) change; ask before
starting Stage 26.

### Design decisions to confirm before building

| # | Question | Recommendation |
| --- | --- | --- |
| D1 | Watched simulation or player control? | Simulation (above). |
| D2 | Are critical hits a seeded random chance or a condition? | **Conditional crits**: weak-point, back, punished-opening and perfect-counter hits crit. Stats widen the windows. The design forbids hidden chance ("never a roll"). A small *seeded* chance is the fallback if you want the slot-machine feel. |
| D3 | Add new trainable stats (Dexterity, Accuracy, Crit Chance/Damage, Reaction)? | Add **one** stat, **Dexterity** (precision). Show Accuracy, Crit, Reaction and Move Speed as **derived** numbers from existing stats + skills. Each new trainable stat touches growth, experience tracks, trainers, training, UI, saves and balance. |
| D4 | Blood and bleeding in an animal-fantasy game? | A **"Wounded"** damage-over-time effect with stylised sparks and dust, no gore by default. Blood is a Settings toggle (off). |
| D5 | Weapon durability? | **Defer.** It is an economy feature (repairs, coins), not combat. If wanted, wear only between battles and never break mid-fight. |
| D6 | Death animation? | The design says *knockouts, not deaths* (mechanics §74). "Death" becomes a dramatic **knockout collapse**; nothing dies. |
| D7 | Dual-wield / one-hand / two-hand loadouts? | Yes, but late (Stage 41): it needs an off-hand slot, equipment UI and a save migration. |
| D8 | Friendly fire? | Only with 2v2/3v3, which the design defers. Add the rule as an arena/trial flag, default **off**. |

## 1. Rules every stage follows

These come from the existing architecture; breaking them breaks saves, replays or balance.

1. **Deterministic.** All variation comes from `BattleState.rng` (seeded). No `randf()`,
   no wall clock, no physics engine in the simulation. Hit detection stays analytic
   geometry (arcs, lines, cones, height bands). Jolt is for presentation only.
2. **Data, not code.** Moves, effects and weapon behaviour live in resources
   (`WeaponData`, `MagicAbilityData`, new `AttackMove`, `StatusEffectData`). Every
   number goes in `GameConfig`. A new weapon or effect needs no engine change.
3. **No species branching.** Behaviour keys off movement type, stats, skills and gear.
   The existing "no species in `scripts/simulation/`" test keeps passing.
4. **Append-only enums.** `CombatantState.Action`, `GameEnums.*` values appear in saved
   replays; only add new values at the end.
5. **Everything visible is an event.** The simulation emits events and snapshots into
   `BattleLog`. The replay, results, experience, mentor review and moments read only
   that log, so each new mechanic must log what it did.
6. **Previews never show digits.** Scouting and matchup text stays in bands and words
   (tests enforce this). New threats and openings get words, not numbers.
7. **Replay versioning (new, Stage 26).** Rule changes alter how saved battles re-simulate.
   Every stage that changes rules bumps `simulation_version`.
8. **Balance is measured.** Each stage that changes outcomes re-runs
   `tools/balance_sim.tscn` and records the before/after table in the stage notes.

## 2. Coverage audit

Status key:
**Have** = already in the simulation and replay ·
**Extend** = exists in part, needs work ·
**New** = not there yet ·
**Adapt** = means something different in a watched simulation ·
**Defer** = recommend not now (see §0).

### 2.1 Movement mechanics

| Feature | Status | Today | Plan |
| --- | --- | --- | --- |
| Walking | Have | `MovementPhase`; `walk` clip | Gait bands (S28) |
| Running | Have | `run` clip, speed from Agility | Gait bands (S28) |
| Sprinting | Extend | `GameConfig.sprint_factor`, `sprint_stamina` exist but are unused | S28: gait chosen by the AI, costs stamina |
| Strafing | Extend | Circling by `mobility` in `DecisionPhase._movement` | S28: strafe speed factor; S36: strafe clips |
| Forward / backward movement | Extend | Movement is free in any direction at one speed | S28: backpedal slower than forward |
| Side stepping | Extend | One generic dodge | S29: `sidestep` dodge kind |
| Dodging | Have | `DODGE` action, protected window, Evasion distance | S29 variants |
| Rolling | New | — | S29: `roll` (long, more protection, long recovery, armour-sensitive) |
| Backstep | New | — | S29: `backstep` (fast, short, breaks reach, no protection) |
| Dashing | Extend | Wind Step Art, Wind Dash technique | S29: `dash` (forward gap-closer) |
| Jumping | New | Elevation exists (fliers) | S30: short jump arc for ground animals; avoids low sweeps, enables jump attacks |
| Crouching | New | — | S30: duck under high horizontal swings |
| Combat positioning | Have | Preferred range by build, ring edge, obstacles, water | S38 extends to teams |
| Circling / orbit | Have | Strafe direction and `strafe_until` in the mind | — |
| Target lock movement | Adapt | `target_index`, facing turns to target | S38: threat-based retargeting; S43: camera lock framing |
| Root motion | Adapt | Clips are in place, the simulation moves bodies | S31: moves carry an authored `lunge` curve the simulation applies ("simulation root motion") |

### 2.2 Attack mechanics

| Feature | Status | Today | Plan |
| --- | --- | --- | --- |
| Light attack | Have | `ATTACK` | Becomes the default move in a moveset (S27) |
| Heavy attack | Have | `HEAVY` | Same (S27) |
| Quick attack | New | — | S32: fast, low-damage opener (jab) |
| Charged attack | New | — | S33: heavy held 0–N s, damage and stagger scale with charge |
| Overhead attack | New | — | S31: high, narrow arc, strong stagger |
| Horizontal slash | New | — | S31: wide arc at torso height; crouch ducks it |
| Vertical slash | New | — | S31: narrow arc, beats sidesteps less, good against crouch |
| Thrust attack | New | — | S31: line hitbox, long reach |
| Piercing attack | New | — | S31 + S39: thrust/arrow that ignores part of armour |
| Jump attack | New | Flier swoop exists | S34: from a jump (S30) |
| Running attack | New | — | S34: from a sprint (S28) |
| Aerial attack | Extend | Fliers swoop to strike | S34: named aerial move for fliers |
| Combo attack | Have | Light chain up to `combo_max` | S32: combo graph per weapon |
| Chain attack | Extend | Chain in recovery | S32: cancel windows into the next move |
| Counterattack | Have | AI counter, Riposte technique | S35: perfect-dodge counter window |
| Finishing attack | New | — | S35: punisher on a knocked-down, guard-broken or exhausted foe (a knockout blow, never an execution) |
| Special attack | Extend | Techniques (Riposte, Guard Break, Flame Slash, Wind Dash) | S35: techniques can own a move |
| Critical attack | New | — | S39 (decision D2) |

### 2.3 Defensive mechanics

| Feature | Status | Today | Plan |
| --- | --- | --- | --- |
| Blocking | Have | Guard ±70°, block factor, guard drain | S37: block stun |
| Perfect blocking | Extend | A guard raised in the perfect window counts as a parry | S37: split *perfect block* (no chip, no drain) from *parry* |
| Parrying | Extend | As above | S37: `PARRY` as its own active action, punishable on a whiff |
| Perfect parry | New | — | S37: first half of the parry window: longer stagger, guaranteed riposte |
| Dodging / Rolling / Evasion | Have / New | Dodge with protected window | S29 |
| Counter defense | Have | Riposte, guard-into-strike | S35 |
| Shield defense | Have | Shield `block_bonus` | S41: off-hand shield |
| Damage reduction | Have | `mitigation` (Defense, armour, skill), wards | S39: damage types |
| Guard break | Have | Guard runs dry; Guard Break technique | — |
| Stamina-based defense | Have | Guard drain, exhaustion | — |

### 2.4 Weapon mechanics

| Feature | Status | Today | Plan |
| --- | --- | --- | --- |
| Weapon switching | New | One weapon slot | S42: secondary weapon, switch action chosen by the AI on a range mismatch |
| Weapon drawing / sheathing | New | Weapon always in hand | S42: draw at fight start, sheathe on victory and switch; lodge shows it sheathed |
| Weapon handling | Have | `weight` slows movement and actions | — |
| Weapon reach | Have | `attack_range`, `arc_degrees` | S31: per-move shapes |
| Weapon collision | Extend | Line-of-sight to obstacles | S40: weapon **clash** when two active swings meet |
| Weapon durability | Defer | — | D5 |
| Weapon proficiency | Have | Skill Matrix weapon ranks, mastery | S32: mastery unlocks moves |
| Weapon-specific combos | New | Same chain for all | S32 |
| Dual-wielding | New | — | S41 |
| Two-handed combat | Extend | Hammer and axe behave heavy | S41: `grip` field |
| One-handed combat | Extend | Sword, dagger | S41 |

### 2.5 Combat animations

Clips today (`character_animations.gd`): idle, combat_idle, walk, run, attack,
heavy_attack, dodge, block, hit, stagger, knocked_out, recover, cast, victory, exhausted.

| Feature | Status | Plan |
| --- | --- | --- |
| Idle, walking, running | Have | S36: locomotion blend space |
| Sprint | New | S36 |
| Attack, heavy attack | Have | S36: one clip per move (overhead, horizontal, thrust, charge hold/release…) |
| Combo | Extend | S36: `attack_1/2/3` per weapon combo step |
| Blocking | Have | S36: block-hit reaction |
| Parry | New | S36 |
| Dodge | Have | S36: roll, sidestep L/R, backstep, dash |
| Hit reaction | Extend | S36: directional (front/back/left/right) |
| Stagger | Have | — |
| Knockback | New | S36: slide-back pose while `push_velocity` is high |
| Knockdown | Extend | S36: fall + lie + get-up (today stagger and KO clips) |
| Recovery | Have | — |
| Death | Adapt | KO collapse (D6) |
| Victory | Have | S36: per-weapon flourish + sheathe |

### 2.6 Hit detection and damage

| Feature | Status | Today | Plan |
| --- | --- | --- | --- |
| Weapon hit detection | Have | Reach + arc around facing, each swing hits each target once | S31: per-move hitbox shapes |
| Collision detection | Have | Bodies, ring edge, obstacles, projectiles sweep | — |
| Hitboxes | Extend | One arc per weapon | S31: arc / line / cone / circle per move, with height band |
| Hurtboxes | Extend | One body circle (0.45 m) + elevation | S27: head / torso / legs height bands, front / side / back |
| Directional damage | Extend | Dagger flank bonus | S39: back and side multipliers for all; guards only cover the front |
| Critical hit detection | New | — | S39 (D2) |
| Damage calculation | Have | `DamagePhase.raw_damage`, openings, mastery variation | — |
| Armor mitigation | Have | `mitigation` | S39: slash / pierce / blunt vs armour weight |
| Penetration | New | — | S39: ignores a share of mitigation |
| Knockback calculation | Have | `ForcePhase` | — |
| Hit registration | Have | `struck` per swing | — |
| Friendly fire | New | Teammates never struck | S38 flag (D8) |

### 2.7 Combat AI

`DecisionPhase` already has reaction time, threat reading, dodge, block or counter
answers with timing error, initiative, punishing, stamina and health caution, preferred
range, circling, flanking for agile builds, terrain awareness and `CombatStyle`.

| Feature | Status | Plan |
| --- | --- | --- |
| Target detection, selection, tracking | Have (nearest enemy) | S38: threat-scored selection for 2v2/3v3 |
| Combat positioning, distance management | Have | — |
| Attack / defensive / dodge / counter decisions | Have | S32–S37: choose *which* move, dodge kind and parry vs block |
| Retreat, aggressive, defensive behaviour | Have (tendencies, caution) | — |
| Flanking | Have (agile style) | S38: coordinated flanks in teams |
| Surrounding | New | S38: team slots around a target |
| Threat assessment | Extend | S38: score enemies by damage, reach, health, who is attacking an ally |
| Combat awareness | Extend | S38: field of view; threats from behind are noticed later. In-fight **adaptation**: a mind remembers what the foe keeps doing (always dodges left, always blocks the first hit) and counters it, more with battle experience |

### 2.8 Character attributes and stats

Core stats today: Health, Attack, Strength, Attack Speed, Defense, Agility, Evasion,
Endurance (+ Magic potential). Derived numbers live in `CombatStats`.

| Feature | Status | Plan |
| --- | --- | --- |
| Strength, Agility, Endurance, Health, Defense, Attack Speed | Have | — |
| Stamina | Have (derived from Endurance + skills) | — |
| Movement speed | Have (derived from Agility, armour, weight) | Show as a derived band |
| Armor | Have (equipment) | — |
| Weapon skill | Have (Skill Matrix) | — |
| Combat experience | Have (`battle_experience`) | — |
| Reaction speed | Have (derived `reaction_time`) | Show as a derived band |
| Dexterity | New | S44 (D3): precision stat |
| Accuracy | New (derived) | S44: from Dexterity + weapon mastery; aim error on shots, leading moving targets |
| Critical chance / damage | New (derived) | S44: from Dexterity + Strength; widens crit windows / crit multiplier |

### 2.9 Combat status effects

Today: stagger, knockdown, knockback, flinch (interrupt), exhaustion, recover, and the
lasting effects burn, slow and ward in `EffectRules`.

| Feature | Status | Plan |
| --- | --- | --- |
| Stagger, knockdown, knockback | Have | — |
| Interrupt | Have (flinch, cast interruption) | — |
| Exhaustion, recovery | Have | — |
| Stun | New | S40: no actions, longer than a stagger; Lightning (Spark Lance) |
| Bleeding | New | S40: "Wounded" DoT (D4) from slash crits and dagger; stops sooner when the target rests |
| Poison | New | S40: slow DoT that also cuts stamina regeneration; Nature |
| Burning | Have | Migrates to the new effect framework in S27 |
| Slow | Have | Same |
| Immobilization | New | S40: root (can act, can't move); Thornbind becomes a short root + slow |
| Fear | New | S40: an AI state: aggression down, keeps distance; from intimidating finishers or a technique |
| Disarm | New | S42: perfect parry by an Expert knocks the weapon away; fight unarmed until it is picked up |

### 2.10 Combat feedback and effects

Today (`battle_replay.gd`, `Sfx`): hit flashes, guard flashes, camera shake on heavies,
knockdowns and KOs, floating damage numbers (red on openings), call-outs, commentary
ticker, synthesized sound hooks (`swing`, `hit`, `heavy_hit`, `block`, `perfect_block`,
`guard_break`, `dodge`, `stagger`, `step`…).

| Feature | Status | Plan |
| --- | --- | --- |
| Hit effects, impact effects | Extend | S43: particle impacts by damage type and weight; dust ring on knockdown; ground crack for hammer heavies |
| Weapon sparks | New | S43: on block, parry and clash |
| Blood effects | New | S43: stylised, off by default (D4) |
| Camera shake | Have | S43: scaled per event, Settings slider |
| Hit pause | New | S43: replay clock slows ~60–100 ms on heavies, crits, parries; the simulation is untouched |
| Screen feedback | New | S43: crit flash, low-health vignette on the champion's side; respects reduced-flashing setting |
| Combat / weapon sound effects | Extend | S43: hooks per weapon weight and material (`swing_light`, `clash_metal`, `block_wood`…) |
| Footstep sounds | Extend | S43: `step` hook fired from the locomotion cycle; splash in water |
| Damage indicators | Extend | S43: colour and icon per kind: crit, chip through guard, DoT, pierce |
| Floating damage numbers | Have | S43: Settings toggle |

## 3. Foundations (Stages 26–27)

These change no outcomes. They make the later stages cheap and safe.

### Stage 26 — Simulation versioning for replays

**Problem.** A saved battle is its inputs + seed (`BattleRecord`), re-simulated on
rewatch with the *current* rules. Any rule change in this plan silently changes old
replays, and the rewatch could even show a different winner than the recorded result.

- Add `GameConfig.simulation_version` (int) and write it into the `BattleLog` header.
- `BattleRecord.has_replay` returns false when the version differs. The Journey's
  *Recent battles* shows "Recorded under older rules" with no ▶ button. The summary
  stays.
- Save migration v3 → v4 stamps existing replays with version 1.
- Test: a record with an older version is not replayable; a current one is identical
  event for event.

### Stage 27 — Moves, hurt zones and effects as data

1. **`AttackMove` resource** (`scripts/data/attack_move.gd`):
   `id`, `kind` (light / heavy / quick / charged / special), `direction`
   (horizontal / vertical / overhead / thrust), `shape` (arc / line / cone / circle) +
   `range`, `arc_degrees`, `width`, `height_band` (low / mid / high), `windup`, `active`,
   `recovery`, `damage_factor`, `stagger_factor`, `knockback_factor`, `stamina_factor`,
   `damage_type` (slash / pierce / blunt), `penetration`, `lunge` (metres over the
   wind-up and active phases), `hyper_armor`, `requires` (none / sprinting / airborne /
   after_dodge / after_parry / foe_down / mastery ≥ rank), `chains_to` (move ids) and
   `cancel_from` (seconds into recovery).
2. **`WeaponData.moveset: Array[AttackMove]`.** When empty, `WeaponRules.default_moveset()`
   builds the two moves the weapon's current light and heavy fields describe, so every
   existing weapon fights **exactly** as today.
3. **Hurt zones.** `ContactPhase` tags each hit with `zone` (head / torso / legs, from the
   move's height band and the target's elevation or crouch) and `side` (front / flank /
   back, generalising the dagger's flank test). No damage change yet.
4. **`StatusEffectData` resource**: `kind`, `stacking` (refresh / strongest / stack ≤ n),
   `tick`, `damage_per_second`, `armor_factor`, modifiers (`move`, `action_speed`,
   `regen`, `damage_taken`), flags (`can_move`, `can_act`, `ai_fear`), `cleansed_by`.
   `EffectRules` reads it; burn, slow and ward become three `.tres` files.
5. `CombatantState` gains `move_id` and a snapshot field; action spans in
   `ReplayTimeline` carry it.

**Gate:** `balance_sim` and a golden-log test (fixed seeds × every opponent) produce
**identical** logs before and after. This is the safety net for everything that follows.

## 4. Build stages (28–44)

Each stage: rules + data + AI use + log events + replay presentation (placeholder clip or
tint is fine) + experience hooks + tests + `BATTLE_SIMULATION.md` notes. Stages that
change outcomes bump `simulation_version` and record the balance table.

### Milestone A — Movement

**Stage 28 — Gaits.** `walk` / `run` / `sprint` speed bands. Sprint uses the existing
`sprint_factor` and `sprint_stamina`, delays stamina regeneration, and is chosen by the
mind to close distance (heavy and agile styles), escape when cornered, or chase a
retreating ranged build. Backpedal ×0.75 and strafe ×0.88 of forward speed (`GameConfig`)
make facing matter. State gets a `gait` field. Experience: sustained sprinting → Agility;
running out of breath sprinting → Endurance lesson in the mentor review.

**Stage 29 — Evasion repertoire.** `dodge_kind` on the DODGE action (no new enum value):

| Kind | Distance | Protection | Recovery | Best against |
| --- | --- | --- | --- | --- |
| sidestep | short | short | short | thrusts, shots, narrow overheads |
| roll | long | long | long; much worse in heavy armour | wide slashes, bursts, heavies |
| backstep | short, backwards | none | very short | getting out of reach of a wind-up |
| dash | forward | short | short | closing on a ranged foe |

The mind picks by threat shape (S31) and its own build. Dodge skill, Evasion and armour
shape all four. Experience: as today, plus `roll` vs heavy → Evasion.

**Stage 30 — Jump and crouch (ground animals).** A short jump arc on `elevation`
(fliers keep their flight). Jumping clears **low** moves, crouching ducks **high**
horizontal moves (hurt-zone bands from S27). Both have a commitment cost, so a vertical
or overhead move punishes a jump and a low move punishes a crouch. Keep it rare in the
AI (Agility, Timing and experience raise its use) so fights don't turn into hopping.
*This stage is optional: skip it if it reads poorly on mobile.*

### Milestone B — Attacks

**Stage 31 — Directional moves and hitbox shapes.** Contact geometry per move: arc
(horizontal), narrow arc with high band (overhead / vertical), line with width (thrust),
cone and circle (sweeps). Apply `lunge` during wind-up and active phases ("simulation
root motion"). Author movesets for all seven weapons:

| Weapon | Moves (light chain → heavy) |
| --- | --- |
| Sword | horizontal → vertical → thrust; overhead heavy |
| Hammer | horizontal sweep; overhead slam heavy (ground crack) |
| Dagger | quick thrusts ×3; backstab lunge heavy |
| Spear | thrust → thrust → horizontal sweep; charging thrust heavy |
| Axe | diagonal → horizontal; overhead heavy |
| Shield | bash (blunt, high stagger); shield charge heavy |
| Bow | shot; charged shot heavy (S33) |

The mind chooses moves against the foe's habits (a crouching foe gets an overhead, a
side-stepper gets a horizontal).

**Stage 32 — Combo graph, quick attacks and mastery unlocks.** Moves chain through
`chains_to` and `cancel_from` instead of a flat `combo_max`. Each weapon has a quick
opener and a finisher. Weapon mastery unlocks graph branches: Novice two-hit, Apprentice
full string, Skilled finisher, Expert charged and cancel branches. This replaces today's
"Skilled adds a step". Scouting gains openings such as *"Long recovery after the third
cut"*.

**Stage 33 — Charged attacks.** A heavy (or bow shot) can be held: the mind picks a
charge time from the foe's state (longer against a staggered or exhausted foe), damage
and stagger scale up to `max_charge_factor`, and the visible hold is a readable tell
that experienced foes answer. Optional hyper armour while charging (per move).

**Stage 34 — Context attacks.** Moves with `requires`: running attack (from a sprint,
lunge plus knockback), jump attack (from S30), aerial attack (a flier's named swoop),
dodge attack (out of a roll or dash). The decision layer offers them only when their
condition holds.

**Stage 35 — Counters, finishers and special moves.** A perfect dodge opens a short
counter window (a dodge-counter move). A finishing move is used on a knocked-down,
guard-broken or exhausted foe and has a bonus that can end the bout (knockout only). A
technique may own a move (`TechniqueData.move`), so new specials are data. Moments and
call-outs: *"Counter!"*, *"Finisher!"*.

### Milestone C — Defense and presentation

**Stage 36 — Animation pass (presentation only).**
- An `AnimationTree` per body: a locomotion `BlendSpace2D` (velocity relative to facing:
  forward, backpedal, strafe L/R; walk, run, sprint) plus one-shots for actions.
- New procedural clips in `character_animations.gd` for every new move, dodge kind,
  parry, directional hit, knockback slide, knockdown fall / lie / get-up and victory
  flourish. Clip names become `<move_id>` with a fallback chain
  (`sword_overhead` → `overhead` → `heavy_attack`), so Blender clips can replace them one
  at a time.
- Update the clip table in `ASSET_PIPELINE.md`; `dog_preview.tscn` renders the new clips;
  `missing_clips()` tests cover the fallback chain.

**Stage 37 — Parry, perfect block and block stun.**
- `PARRY` becomes its own action (appended to the enum): a short active window, then a
  punishable recovery if nothing arrives. The perfect half staggers the attacker longer
  and guarantees a riposte window.
- A guard that meets a blow inside the perfect window is a **perfect block**: no chip, no
  drain, no stagger for either side. A normal block applies **block stun** by attack
  weight, so heavy weapons win frame advantage on a guard.
- The mind chooses parry or block from Timing, block skill, experience and the threat.
  Experience: `parry` / `perfect_parry` → Defense and Timing.

### Milestone D — AI and teams

**Stage 38 — Awareness, threat assessment and team tactics.** A field of view: threats
outside the front 200° are noticed later. In-fight memory: the mind tracks the foe's
habits and adapts, faster with battle experience. Threat-scored target selection.
For 2v2/3v3 (already supported by `BattleState`): flank and surround slots around a
target, no ally stands in another's line, and an optional `friendly_fire` flag on the
arena or trial. Ship the rules now; team selection in the flow stays deferred per the
design.

### Milestone E — Damage depth

**Stage 39 — Damage types, penetration, directional damage, crits.**
- `damage_type` vs armour: slash is weak against heavy armour, blunt is strong, pierce
  ignores `penetration` × mitigation. Light armour takes more slash; heavy takes more
  blunt stagger but less slash.
- Back hits ×1.25 and side hits ×1.1 for every weapon (the dagger's flank bonus stacks on
  top); guards cover the front only.
- **Critical hits (D2, conditional):** a hit crits when it lands on the back, on the
  head zone with an overhead, on a punished opening, or on a perfect counter. A crit
  multiplies damage and stagger. Dexterity (S44) and weapon mastery widen these windows;
  they never add a hidden roll.
- Events carry `crit`, `zone`, `side`, `damage_type`. Scouting threats such as *"Pierces
  armour"* and *"Punishes your back"*.

**Stage 40 — Status effects.** Built on `StatusEffectData` (S27):

| Effect | Source | Rule |
| --- | --- | --- |
| Stun | Lightning (Spark Lance), crit overheads on the head zone | can't act or move; diminishing returns per bout |
| Wounded (bleed) | slash crits, dagger | DoT; ends sooner while the target isn't moving |
| Poison | Nature, dagger technique | slow DoT; stamina regeneration −30% |
| Immobilize | Thornbind (short root, then slow) | can act, can't move |
| Fear | finishers, an intimidation technique | the mind's aggression drops and it keeps distance; Happiness (composure) shortens it |

Every effect has an icon above the bar, a commentary line, a counter (cleanse by dodge
roll for burn, a Stone Ward cleanse, rest for bleed) and anti-stacking rules. Mentor
review lesson: *"Kept getting stunned"* → a Timing/Defense mentor.

**Stage 41 — Grip and loadouts (D7).** `WeaponData.grip` = `one_hand` / `two_hand` /
`off_hand` (shield). Champion gains `offhand_id`: a shield with a one-hand weapon, or a
second one-hand weapon (dual wield: alternating-hand combos, faster chains, no guard
bonus). Two-handed weapons block the off-hand slot and gain damage and stagger. The
visual uses the rig's `LeftHand` bone. Covers equipment UI, `CombatantSpec`, save
migration v5 and matchup analysis lines.

**Stage 42 — Draw, sheathe, switch, disarm, clash.**
- Fighters start sheathed and draw (short action) as the bout opens; the victor
  sheathes.
- A `secondary_weapon_id`: the mind switches when its range is wrong (a bow at point-blank
  range switches to a dagger). The switch takes time and is an opening.
- **Disarm:** an Expert's perfect parry knocks the weapon to the floor (a log entry with
  its position). The disarmed fighter fights unarmed until it walks over and picks it up.
- **Clash:** two active swings whose shapes meet on the same tick both recoil
  (deterministic); heavier weapon wins ties. Sparks in S43.

### Milestone F — Feedback and stats

**Stage 43 — Feedback director (presentation only).** A `CombatFeedback` table (event →
VFX, SFX hook, shake, hit-pause, call-out) replaces the `match` in
`battle_replay.gd::_on_event`, so new events are data:

- Pooled `GPUParticles3D` / `CPUParticles3D` (GL Compatibility-safe) for impacts,
  sparks, dust, ground cracks, water splashes and optional blood.
- **Hit pause** on the replay clock only. `ReplayTimeline` time slows to ~10% for
  60–100 ms; the simulation is not touched.
- Crit flash, a low-health vignette, damage indicator colours and icons, and a camera
  target-lock framing mode.
- Sound hooks per weapon weight and material; footsteps fired from the locomotion cycle
  phase; surface-aware splash.
- **Settings → Replay:** screen shake strength, hit pause on/off, reduced flashing,
  damage numbers on/off, blood off/on. Accessibility tests extended.

**Stage 44 — Dexterity and derived stats (D3).**
- New stat `dexterity` appended to `GameEnums.STATS`. This touches `AnimalData` base and
  potential, `CombatStats`, experience tracks (`precision`: crits, perfect parries,
  accurate shots), `GrowthSystem`, trainers (a precision mentor), training, the Skill
  Matrix UI and a save migration.
- Derived and shown as bands: Accuracy (aim error on shots; leading a moving target at
  Skilled+ ranged mastery), Crit window, Crit power, Reaction, Move speed.
- Retune with `balance_sim`; the champion card shows the new derived bands.

## 5. Order, dependencies and size

```
26 versioning ─► 27 data foundations ─┬─► 28 gaits ─► 29 evasion ─► 30 jump/crouch (opt.)
                                      ├─► 31 moves ─► 32 combos ─► 33 charge ─► 34 context ─► 35 counters
                                      │                └──────────► 36 animation pass (after 31–35)
                                      ├─► 37 parry/perfect block
                                      ├─► 39 damage depth ─► 40 status effects
                                      └─► 41 grip ─► 42 draw/switch/disarm/clash
38 AI awareness/teams (after 31, 37)   43 feedback (any time after 27; best after 39)   44 Dexterity (after 39)
```

| Milestone | Stages | Size | Visible result |
| --- | --- | --- | --- |
| Foundations | 26–27 | M | None (by design): safe replays, data-driven moves |
| A Movement | 28–30 | M | Sprints, rolls, backsteps, jumps in replays |
| B Attacks | 31–35 | L | Every weapon fights with its own move list |
| C Defense + animation | 36–37 | L | Parries, perfect blocks, new clips |
| D AI | 38 | M | Smarter, adapting opponents; team tactics ready |
| E Damage depth | 39–42 | L | Armour types, crits, status effects, loadouts, disarm |
| F Feedback + stats | 43–44 | M | Juice, settings, Dexterity |

Suggested first slice: **26 → 27 → 28 → 31 → 36 (sword only) → 43 (impacts + hit pause)**.
That gives a visibly richer sword fight end to end before every weapon is authored.

## 6. Out of scope here

- A player-controlled mode (§0). If wanted later: a `PlayerDecisionPhase` for intents,
  a touch control layer, and a separate "Spar" route that never applies results.
- Real Blender clips and recorded audio (the pipeline from Stage 36 is ready for them).
- Weapon durability (D5), permanent death (design §74), 2v2/3v3 in the flow (design
  Phase 2).

## 7. Testing each stage

- **Unit:** each rule in isolation with `ScriptedDecisionPhase` (e.g. a roll clears a
  horizontal slash but not a burst; a crouch ducks a high move; a perfect parry staggers
  longer).
- **Determinism:** the same seed gives an identical log; `simulation_version` is bumped
  when outcomes change.
- **Golden logs:** fixed seeds × every opponent. Identical in Stage 27; updated on
  purpose afterwards with the balance table.
- **Architecture:** no species names in `scripts/simulation/`; previews contain no
  digits; enums are append-only (a test compares against the saved order).
- **Performance:** a full 180 s 1v1 simulates headless in < 0.25 s; 3v3 in < 1 s.
- **Playthrough:** `test_playthrough.gd` still completes Chapter 1 in a similar number of
  battles.
- **Visual:** `tests/visual/scenario.tscn --scenario=replay` screenshots per weapon;
  `dog_preview.tscn` for new clips.
