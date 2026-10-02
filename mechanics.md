# ANIMAL CHAMPION

## Complete Game Mechanics, Progression & Step-by-Step Implementation Plan

---

# 1. GAME VISION

A mobile 3D game where the player manages animal champions, prepares their builds, trains them, equips them, teaches them magic, and battles opponents.

Technology:

* Godot 4.x
* Blender for 3D assets
* Mobile-first
* Landscape orientation
* Touch controls
* 3D gameplay

Initial foundation:

```text
1 humanoid dog
1 movement type: Ground
1 battle format: 1v1
1 arena
```

Future:

```text
Multiple animals
Flying
Swimming
Amphibious
More weapons
More magic
2v2
3v3
More arenas
```

The first dog is the **reference implementation**, not the definition of the architecture.

---

# 2. CORE GAME LOOP

The overall player loop is:

```text
MAIN MENU
    ↓
HOME
    ↓
ANIMAL MANAGEMENT
    ↓
VIEW SKILL MATRIX
    ↓
TRAIN / DEVELOP
    ↓
EQUIP
    ↓
MAGIC
    ↓
BATTLE PREPARATION
    ↓
BATTLE
    ↓
RESULT
    ↓
REWARDS
    ↓
RECOVERY
    ↓
DEVELOP AGAIN
```

The core philosophy:

```text
Build
↓
Fight
↓
Gain Experience
↓
Develop
↓
Unlock Capability
↓
Fight Again
```

---

# 3. PLAYER / OWNER SYSTEM

The player is the owner/trainer of the animal champions.

Player progression:

```text
Owner Level
Owner XP
Coins
Trainer Roster
Trainer Slots
Owned Animals
Owned Equipment
Unlocked Content
```

Coins are used for:

* Training
* Equipment
* Recovery
* Trainer services
* Future systems

---

# 4. OWNER LEVEL

Owner Level is separate from animal combat capability.

Owner Level can control:

* Trainer slots
* Access to additional systems
* Future arenas
* Future battle formats
* Future shops/content

Recommended trainer slot progression:

```text
Owner Level 1   → 1 active trainer
Owner Level 5   → 2 active trainers
Owner Level 10  → 3 active trainers
Owner Level 15  → 4 active trainers
Owner Level 20  → 5 active trainers
```

Maximum:

# 5 active trainers

The exact level thresholds should remain configurable.

---

# 5. ANIMAL SYSTEM

Every animal has:

```text
Animal ID
Name
Model
Movement Type
Base Attributes
Training Potential
Strengths
Weaknesses
Experience
Skill Matrix
Equipment
Magic
Energy
Happiness
```

The first animal:

```text
Humanoid Dog
MovementType.Ground
```

The system must be data-driven.

Never build the combat architecture around:

```text
if dog
if bird
if fish
```

Use:

```text
AnimalData
+
MovementType
+
Stats
+
Skills
```

---

# 6. NATURAL ATTRIBUTES

Animals begin with different natural tendencies.

Example:

```text
DOG

Strength       Medium
Attack         Medium
Attack Speed   Medium
Defense        Medium
Agility        High
Evasion        High
Endurance      High
```

Another future animal might have:

```text
BEAR

Strength       Very High
Attack         High
Defense        Very High
Agility        Low
Evasion        Low
Endurance      High
```

Natural attributes establish identity.

They do not determine the final build.

---

# 7. ANIMAL BALANCE RULE

Every animal MUST have:

```text
Strengths
Weaknesses
Counterplay
```

No animal should be universally superior.

A powerful strength must create a corresponding weakness.

Examples:

```text
High Strength
→ slower / higher stamina cost

High Defense
→ lower mobility

High Agility
→ lower durability

High Attack Speed
→ lower individual attack impact

Long Range
→ weaker at close range

Flying
→ stamina / anti-air / knockdown vulnerability

Swimming
→ land limitations
```

The goal is:

> **Every animal should be interesting to play, but every animal must have a way to be countered.**

---

# 8. CORE COMBAT STATS

Use:

```text
Health
Attack
Strength
Attack Speed
Defense
Agility
Evasion
Endurance
```

## Health

How much damage the animal can survive.

## Attack

Base offensive damage capability.

## Strength

Physical force:

* Knockback
* Stagger
* Heavy attack effectiveness
* Guard pressure

Strength does not simply equal damage.

## Attack Speed

Determines:

* Attack interval
* Combo speed
* Recovery between attacks

## Defense

Determines:

* Damage reduction
* Block efficiency
* Stagger resistance
* Knockback resistance

## Agility

Determines:

* Movement responsiveness
* Turning
* Repositioning
* Movement recovery

## Evasion

Improves active dodging:

* Dodge distance
* Dodge recovery
* Responsiveness
* Stamina efficiency

It should not primarily be a random miss chance.

## Endurance

Determines:

* Maximum stamina
* Stamina recovery
* Long-fight performance

---

# 9. THREE SOURCES OF ANIMAL DEVELOPMENT

Animal growth comes from three layers:

```text
NATURAL ATTRIBUTES
        +
BATTLE EXPERIENCE
        +
TRAINER DEVELOPMENT
        =
FINAL CAPABILITY
```

This replaces the simplistic system of either:

```text
Level → stat points
```

or:

```text
Trainer → all progression
```

Instead:

> **Experience shapes the animal. Trainers guide the animal.**

---

# 10. BATTLE EXPERIENCE

Animals naturally learn from what they actually do.

Experience should be tracked by category instead of giving a raw stat point after every action.

Example:

```text
Offensive Experience
Defense Experience
Mobility Experience
Evasion Experience
Endurance Experience
Resilience Experience
Weapon Experience
Magic Experience
```

Experience accumulates toward growth thresholds.

Example:

```text
Offensive Experience
85 / 100

→ 15 more meaningful experience
→ Growth event
```

---

# 11. OFFENSIVE EXPERIENCE

Can be gained from:

* Meaningful successful attacks
* Successful combinations
* Punishing an opening
* Guard breaks
* Effective pressure

Can contribute toward:

```text
Attack
Attack Speed
Weapon development
Combat skills
```

Do not reward mindless attack spam.

---

# 12. STRENGTH EXPERIENCE

Strength experience comes from physical force.

Examples:

```text
Successful Heavy Attack
→ Strength XP

Strong Knockback
→ Strength XP

Strong Stagger
→ Strength XP

Guard Break
→ Strength XP
```

This keeps:

```text
Attack ≠ Strength
```

---

# 13. ATTACK-SPEED EXPERIENCE

Do not increase attack speed just because the player presses attack repeatedly.

Reward:

* Successful combos
* Proper timing
* Fast punish windows
* Efficient attack chains

This creates skill-based development rather than button-spam development.

---

# 14. AGILITY EXPERIENCE

Earned from meaningful movement:

* Repositioning
* Rapid directional changes
* Avoiding attacks through movement
* Close combat repositioning
* Successful movement decisions

Do not award unlimited XP simply for holding the joystick.

---

# 15. EVASION EXPERIENCE

Earned from successful avoidance:

```text
Successful Dodge
Perfect Dodge
Avoiding Heavy Attack
Avoiding Magic
```

A well-timed dodge provides more experience than a random movement away from danger.

---

# 16. DEFENSE EXPERIENCE

Earned from successful defensive actions:

```text
Successful Block
Heavy Attack Block
Damage Mitigation
Defensive Counter
```

This naturally develops animals that actually play defensively.

---

# 17. ENDURANCE EXPERIENCE

Earned from sustained combat and stamina management:

```text
Long meaningful battles
Efficient stamina usage
Sustained physical activity
Good stamina recovery decisions
```

Avoid simply rewarding waiting.

---

# 18. RESILIENCE EXPERIENCE

This handles your idea that losses can make the animal stronger.

Do not implement:

```text
Loss
→ +10 Health
```

because players can intentionally lose to farm Health.

Instead:

```text
Heavy Damage Survived
→ Resilience XP

Survived Below 25% Health
→ Large Resilience XP

Recovered From Knockout
→ Small Resilience XP

Difficult Prolonged Defeat
→ Small Resilience XP
```

Resilience can contribute toward:

```text
Maximum Health
Endurance
Recovery
Defensive development
```

So:

> **Victory teaches technique. Defeat teaches survival.**

---

# 19. WEAPON EXPERIENCE

Each weapon can have its own familiarity experience.

Example:

```text
Sword Experience
245 / 500

Hammer Experience
110 / 500
```

Using a weapon effectively develops familiarity.

But distinguish:

```text
Weapon Experience
→ Familiarity

Weapon Trainer
→ Mastery
```

Therefore an animal can naturally become comfortable with a sword while still needing a Swordmaster for advanced mastery.

---

# 20. MAGIC EXPERIENCE

Magic can also naturally accumulate experience.

Examples:

```text
Successful Fire Spell
→ Fire Experience

Successful Wind Spell
→ Wind Experience
```

The player should not be able to spam harmless magic against passive targets to farm progression.

Experience must consider:

* Successful use
* Difficulty
* Combat relevance
* Opponent strength
* Repetition limits

---

# 21. EXPERIENCE THRESHOLDS

Do not instantly convert every action into a permanent stat increase.

Instead:

```text
Battle
↓
Experience
↓
Experience Threshold
↓
Growth Event
↓
Natural Development
```

Example:

```text
Evasion Experience
100 / 100
↓
Evasion Growth
↓
Evasion progression increases
```

This makes progression feel meaningful.

---

# 22. DIFFICULTY-WEIGHTED EXPERIENCE

Experience should depend on encounter difficulty.

Example conceptual multipliers:

```text
Much weaker opponent → 0.75x
Similar opponent     → 1.00x
Stronger opponent    → 1.25x
Very difficult       → 1.50x
```

Values should be configurable.

This prevents:

```text
Weak enemy farming
→ infinite growth
```

---

# 23. ANTI-FARMING

Repeated identical actions should have diminishing returns.

Example:

```text
First meaningful dodge
→ full XP

Repeated similar dodge
→ reduced XP

Artificial repetitive behavior
→ very low XP
```

The goal is to reward:

> **meaningful combat behavior**

rather than repetitive exploitation.

---

# 24. SKILL MATRIX

The Skill Matrix represents what the animal has actually learned.

Hierarchy:

```text
NATURAL FOUNDATION
        ↓
COMBAT FUNDAMENTALS
        ↓
COMBAT DISCIPLINE
        ↓
WEAPON PROFICIENCY
        ↓
MAGIC PROFICIENCY
        ↓
ADVANCED TECHNIQUES
```

---

# 25. NATURAL FOUNDATION

Defines:

* Natural attributes
* Movement type
* Training potential
* Strengths
* Weaknesses

This cannot simply be copied between all animals.

---

# 26. COMBAT FUNDAMENTALS

Skills:

```text
Movement
Attack
Defense
Dodge
Block
Stamina Management
Recovery
```

Example:

```text
Movement     Skilled
Attack       Apprentice
Defense      Apprentice
Dodge        Skilled
Block        Foundation
Stamina      Apprentice
Recovery     Apprentice
```

---

# 27. COMBAT DISCIPLINE

Skills:

```text
Timing
Positioning
Attack Control
Defense Control
Dodge Control
Block Control
Stamina Discipline
Recovery Control
```

These improve combat capability without simply adding raw damage.

---

# 28. WEAPON PROFICIENCY

Weapons:

```text
Sword
Axe
Hammer
Spear
Dagger
Shield
Bow
```

Ranks:

```text
Novice
Apprentice
Skilled
Expert
Master
```

Every animal can use every weapon.

Weapon mastery unlocks:

* Better handling
* More efficient actions
* New attack patterns
* Combos
* Advanced techniques

---

# 29. MAGIC PROFICIENCY

Magic schools:

```text
Fire
Frost
Wind
Earth
Lightning
Nature
```

Every animal can learn every magic school.

Ranks:

```text
Foundation
Apprentice
Skilled
Expert
Master
```

Magic is universal rather than species locked.

---

# 30. ADVANCED TECHNIQUES

Advanced techniques require skill combinations.

Example:

```text
Hammer Skilled
+
Strength Skilled
+
Defense Skilled
=
Guard Break
```

```text
Dagger Skilled
+
Agility Skilled
+
Wind Skilled
=
Wind Dash
```

```text
Sword Expert
+
Fire Skilled
=
Flame Slash
```

Techniques are learned through trainers.

---

# 31. COMBAT CAPABILITY RANK

The Skill Matrix can generate a descriptive capability:

```text
Untrained
Trainee
Fighter
Specialist
Veteran
Master
```

This should summarize development, not replace the detailed Skill Matrix.

Example:

```text
Combat Capability: Specialist

Sword: Expert
Fire: Skilled
Defense: Skilled
Dodge: Apprentice
```

---

# 32. TRAINERS

Trainers are universal specialists.

A trainer can train any animal.

Do not create:

```text
Dog Trainer
Bird Trainer
Fish Trainer
```

Instead create:

```text
Swordmaster
Agility Trainer
Fire Mage
Defense Trainer
Hammermaster
```

All can train any owned animal where applicable.

---

# 33. TRAINER TYPES

## Attribute Trainers

```text
Strength Trainer
Attack Trainer
Agility Trainer
Defense Trainer
Evasion Trainer
Endurance Trainer
```

## Weapon Trainers

```text
Swordmaster
Axemaster
Hammermaster
Spearmaster
Duelist
Guardian
Ranger
```

## Magic Trainers

```text
Fire Mage
Frost Mage
Wind Mage
Earth Mage
Lightning Mage
Nature Mage
```

---

# 34. TRAINER RARITY

Use:

```text
Common
Uncommon
Rare
Epic
Legendary
```

Rarity affects:

* Training efficiency
* Skill coverage
* Supported skill tier
* Technique access
* Trainer traits

Do not turn rarity into direct combat power.

---

# 35. TRAINER DISCIPLINES

A trainer can have:

```text
Primary Discipline
Secondary Discipline
Special Trait
```

Example:

```text
Epic Duelist

Primary:
Sword

Secondary:
Dodge

Special:
Counter training
```

Another:

```text
Rare Battle Master

Primary:
Combat Fundamentals

Secondary:
Defense

Special:
Improved defensive training
```

This makes trainers strategically distinct.

---

# 36. TRAINER LIMIT

Maximum active trainers:

# 5

The player chooses which trainers are currently active.

Example:

```text
1. Rare Swordmaster
2. Epic Fire Mage
3. Uncommon Agility Trainer
4. Rare Hammermaster
5. Common Endurance Trainer
```

Trainer selection is part of the player's strategic build.

---

# 37. TRAINER + EXPERIENCE RELATIONSHIP

Battle experience is natural growth.

Trainers provide deliberate development.

Example:

```text
Battle
→ Gain Strength Experience
```

Then:

```text
Strength Trainer
→ Converts/guides development more efficiently
```

Trainer benefits may include:

* Better conversion of experience
* Higher training progress
* Higher mastery ceiling
* Skill unlocks
* Technique unlocks
* Better efficiency
* Special training traits

---

# 38. TRAINING

Training requires:

```text
Trainer
+
Animal
+
Skill
+
Coins
+
Energy
```

Flow:

```text
Trainer
↓
Animal
↓
Skill
↓
Cost
↓
Energy
↓
Confirm
↓
Training
```

Training can improve:

* Stats
* Combat Fundamentals
* Combat Discipline
* Weapon Mastery
* Magic Mastery

Training is deliberate development.

---

# 39. TRAINING POTENTIAL

Each animal has a potential limit.

Example:

```text
Strength      80 / 100
Agility      100 / 100
Defense       70 / 100
Endurance     90 / 100
Magic         60 / 100
```

Approaching the potential causes slower training progression.

Natural experience can also slow as the animal approaches its developmental potential.

This prevents infinite scaling.

---

# 40. LEVELING

Animal Level exists but does not automatically give stat points.

Animal Level represents general progression.

Owner Level controls things such as:

* Trainer slots
* Content access
* Future systems

Therefore:

```text
Animal XP
→ Animal Level
```

while:

```text
Battle behavior
→ Experience Tracks
→ Natural development
```

and:

```text
Trainer
→ Deliberate development
→ Mastery
→ Techniques
```

This keeps the systems separate.

---

# 41. WEAPONS

Every animal can use every weapon.

Initial weapons:

```text
Sword
Axe
Hammer
Spear
Dagger
Shield
Bow
```

Weapon data:

```text
Damage
Attack Speed
Range
Stamina Cost
Weight
Strength Scaling
Stagger
Recovery
Techniques
```

---

# 42. WEAPON IDENTITIES

## Sword

Balanced.

## Hammer

* High stagger
* High strength interaction
* Slow
* High stamina
* Long recovery

## Dagger

* Fast
* Short range
* Low stagger
* Low stamina

## Spear

* Long range
* Strong spacing

## Bow

* Strong at range
* Weak at close range

## Axe

* Strong offensive pressure
* Moderate/slow attacks

## Shield

* Strong defensive control
* Strong block interaction

---

# 43. ARMOR

Armor changes playstyle.

## Light

Advantages:

* Mobility
* Dodge
* Stamina efficiency

Weakness:

* Lower defense

## Medium

Balanced.

## Heavy

Advantages:

* Defense
* Stagger resistance
* Knockback resistance

Weakness:

* Lower movement
* Worse dodge
* Higher stamina pressure

---

# 44. MAGIC

Every animal can learn every magic school.

Initial:

```text
Fire
Frost
Wind
Earth
Lightning
Nature
```

Magic should have:

```text
Cost
Range
Cast Time
Recovery
Effect
Prerequisites
Mastery
```

Magic must have counterplay.

---

# 45. MAGIC + WEAPON SYNERGY

Examples:

```text
Hammer + Earth
→ Heavy defensive control
```

```text
Dagger + Wind
→ Fast mobility
```

```text
Sword + Fire
→ Offensive pressure
```

```text
Bow + Frost
→ Ranged control
```

These are build possibilities, not fixed classes.

---

# 46. BUILD SYSTEM

There are no fixed classes.

A build is:

```text
Animal
+
Natural Attributes
+
Battle Experience
+
Skill Matrix
+
Weapon
+
Weapon Mastery
+
Armor
+
Magic
+
Magic Mastery
+
Trainer Roster
```

This creates unique animals without hard-locking their choices.

---

# 47. STAMINA

Stamina is a major combat resource.

Consumes stamina:

```text
Attack
Heavy Attack
Dodge
Block
Sprint
Magic
Special Technique
```

Endurance determines:

```text
Maximum Stamina
Stamina Recovery
```

At zero:

```text
EXHAUSTED
```

Effects can include:

* Lower movement
* Slower actions
* Reduced defensive capability
* Reduced dodge capability
* Longer recovery

---

# 48. ACTIVE DODGE

Dodge is player-controlled.

Evasion affects:

* Dodge distance
* Responsiveness
* Recovery
* Efficiency

Do not make dodge a random chance.

Player timing must matter.

---

# 49. ACTIVE BLOCK

Block is player-controlled.

Defense affects:

* Damage reduction
* Stagger resistance
* Knockback resistance
* Block efficiency

Block consumes stamina.

---

# 50. COMBAT LOOP

```text
Observe opponent
↓
Position
↓
Attack / Block / Dodge
↓
Manage stamina
↓
Create opening
↓
Attack
↓
Recover
↓
Reposition
```

Combat should reward timing and decisions rather than button mashing.

---

# 51. BATTLE FORMATS

## 1v1

Small arena.

Focus:

* Timing
* Stamina
* Positioning
* Dodge
* Block
* Weapon matchup

## 2v2

Medium arena.

Adds:

* Target switching
* Ally protection
* Team positioning
* Combos

## 3v3

Large arena.

Adds:

* Team composition
* Target priority
* Coordinated abilities
* Area control

---

# 52. MOVEMENT TYPES

Use:

```text
Ground
Flying
Swimming
Amphibious
```

Movement must be reusable.

Architecture:

```text
Animal
↓
MovementType
↓
MovementController
```

---

# 53. FLYING

Flying provides mobility, not immunity.

Flying animals:

* Use stamina while airborne
* Can be knocked down
* Can be affected by wind
* Have recovery windows
* Can be threatened by ranged attacks
* Need landing opportunities

---

# 54. SWIMMING

Swimming provides environmental advantages.

Swimming animals:

* Move effectively in water
* Can fight in water
* May have limitations on land

Water should create opportunities and disadvantages rather than automatic victory.

---

# 55. ARENA SCALING

Arena size should depend on:

```text
Battle Format
+
Movement Types
+
Weapon Range
+
Magic Range
+
Terrain
```

### 1v1

Small.

### 2v2

Medium.

### 3v3

Large.

---

# 56. ARENA TYPES

Possible arenas:

```text
Meadow
Forest
Lake
Coast
Cliff
Mountain
Ruins
```

Examples:

```text
Meadow
→ Ground focused

Lake
→ Ground + Water + Air

Cliff
→ Ground + Elevation + Air

Forest
→ Obstacles + Line of Sight

Coast
→ Ground + Water + Air
```

---

# 57. TERRAIN

Arena components:

```text
GroundZone
WaterZone
AirZone
Obstacle
SpawnPoint
Boundary
NavigationArea
```

Future magic interactions:

```text
Fire
→ Burn terrain

Frost
→ Freeze water

Wind
→ Push / reposition

Earth
→ Temporary walls

Lightning
→ Water interaction
```

These should not all be part of MVP.

---

# 58. MAIN SCENE FLOW

Recommended flow:

```text
BOOT
 ↓
MAIN MENU
 ↓
HOME
 ├── ANIMAL
 ├── SKILL MATRIX
 ├── TRAINING
 ├── TRAINERS
 ├── EQUIPMENT
 ├── MAGIC
 ├── RECOVERY
 └── BATTLE
       ↓
BATTLE PREPARATION
       ↓
ARENA
       ↓
RESULT
       ↓
HOME
```

---

# 59. MAIN MENU

Initial:

```text
Play
Settings
Exit
```

Play:

```text
Main Menu
→ Home
```

Keep this simple.

---

# 60. HOME

Display:

```text
Owner Level
Coins
XP
Trainer Slots
Active Trainers
Selected Animal
Energy
Happiness
```

Navigation:

```text
Animal
Skill Matrix
Training
Trainers
Equipment
Magic
Battle
Recovery
```

---

# 61. ANIMAL MANAGEMENT SCREEN

Show:

```text
3D Animal Model
Name
Animal Level
Combat Capability
Energy
Happiness
```

Stats:

```text
Health
Attack
Strength
Attack Speed
Defense
Agility
Evasion
Endurance
```

Also:

```text
Weapon
Armor
Magic
Skill Matrix
Mastery
Training Potential
```

---

# 62. SKILL MATRIX SCREEN

Structure:

```text
COMBAT FUNDAMENTALS
├── Movement
├── Attack
├── Defense
├── Dodge
├── Block
├── Stamina
└── Recovery

COMBAT DISCIPLINE
├── Timing
├── Positioning
├── Attack Control
├── Defense Control
├── Dodge Control
├── Block Control
├── Stamina Discipline
└── Recovery Control

WEAPONS
├── Sword
├── Hammer
├── Dagger
├── Spear
├── Axe
├── Shield
└── Bow

MAGIC
├── Fire
├── Frost
├── Wind
├── Earth
├── Lightning
└── Nature

TECHNIQUES
├── Available
└── Locked
```

Each branch can show:

```text
Rank
Experience
Potential
Trainer Requirement
Prerequisites
```

---

# 63. TRAINER SCREEN

Show:

```text
Active Trainers
Available Trainers
Rarity
Primary Discipline
Secondary Discipline
Efficiency
Supported Skill Tier
Traits
```

Actions:

```text
Activate
Deactivate
Replace
Inspect
```

Maximum active trainers:

```text
5
```

---

# 64. TRAINING SCREEN

Flow:

```text
Animal
↓
Trainer
↓
Skill
↓
Current Progress
↓
Training Cost
↓
Energy Cost
↓
Expected Development
↓
Confirm
```

The system should clearly distinguish:

```text
Experience Growth
```

from:

```text
Trainer Development
```

---

# 65. EQUIPMENT SCREEN

Categories:

```text
Weapons
Armor
Accessories
```

Preview:

```text
Attack
Strength
Attack Speed
Defense
Mobility
Stamina
Range
Stagger
```

---

# 66. MAGIC SCREEN

Show:

```text
Magic School
Mastery
Experience
Known Abilities
Locked Abilities
Trainer Requirement
Skill Requirements
```

---

# 67. BATTLE PREPARATION

Before entering battle:

```text
Animal
Weapon
Armor
Magic
Skill Matrix
Energy
```

Flow:

```text
Review
↓
Confirm
↓
Enter Arena
```

---

# 68. MOBILE COMBAT UI

Landscape.

Suggested control arrangement:

```text
LEFT
Virtual Joystick
```

```text
RIGHT
Attack
Heavy Attack
Dodge
Block
Magic
```

HUD:

```text
Player Health
Enemy Health
Player Stamina
Enemy Stamina
Current Ability
```

The world should remain the visual priority.

---

# 69. MOBILE CAMERA

Requirements:

* Clear combat visibility
* Target awareness
* Camera boundaries
* Limited obstruction
* Mobile-friendly camera input
* Focus on both combatants

Avoid making the UI cover the arena.

---

# 70. ENERGY

Energy is the outside-of-battle management resource.

Consumed by:

```text
Training
Battles
Future activities
```

Recovered through:

```text
Rest
Recovery
Future systems
```

---

# 71. HAPPINESS

Happiness changes through:

Positive:

```text
Winning
Rest
Successful training
Care
```

Negative:

```text
Overtraining
Repeated losses
Insufficient recovery
```

It can lightly influence:

* Training efficiency
* Morale
* Recovery

It should never become a hard punishment.

---

# 72. BATTLE RESULT

After battle:

```text
Victory / Defeat
Coins
XP
Experience Gains
Energy Change
Happiness Change
New Growth
New Mastery
Unlocked Skills
```

The player should be able to understand:

> **What did my animal learn from this battle?**

---

# 73. LOSS DESIGN

Loss should not feel like pure failure.

A defeat can produce:

```text
Resilience Experience
Defense Experience
Endurance Experience
Weapon Experience
```

depending on the fight.

This gives players a reason to analyze and improve rather than simply feeling punished.

---

# 74. KNOCKOUT

Normal battle defeat should use:

```text
Knocked Out
```

rather than permanent death.

Recovery returns the animal to usable condition.

Permanent death should not be part of the initial combat loop.

---

# 75. SAVE SYSTEM

Save:

```text
Owner
Owner XP
Owner Level
Coins
Trainer Slots
Active Trainers

Animals
Animal XP
Animal Level
Stats
Experience Tracks
Skill Matrix
Training Potential
Energy
Happiness

Weapons
Armor
Accessories

Magic
Magic Experience
Magic Mastery

Weapon Experience
Weapon Mastery

Trainers
Trainer Rarity
Trainer Progression
Trainer Traits

Unlocked Techniques
Battle History
```

Use versioned save data.

---

# 76. BLENDER PIPELINE

First production character:

```text
Humanoid Dog
```

Characteristics:

* Upright
* Human-inspired anatomy
* Two arms
* Two hands
* Two legs
* Dog head
* Dog ears
* Dog snout
* Tail
* Fur details

Use the dog as the master visual reference.

---

# 77. REUSABLE CHARACTER SKELETON

Concept:

```text
Root
 ├── Hips
 ├── Spine
 ├── Chest
 ├── Neck
 ├── Head
 ├── LeftArm
 ├── RightArm
 ├── LeftLeg
 ├── RightLeg
 └── Tail
```

Future animals should reuse the controller/animation architecture whenever practical.

---

# 78. INITIAL ANIMATIONS

MVP:

```text
Idle
Walk
Run
Attack
Heavy Attack
Dodge
Block
Hit
Stagger
Knocked Out
Recover
```

Future:

```text
Jump
Fly
Swim
Magic Cast
Magic Hit
Weapon-specific attacks
```

---

# 79. ARCHITECTURE

Separate:

```text
DATA
GAMEPLAY
UI
PRESENTATION
```

Data:

```text
AnimalData
WeaponData
ArmorData
MagicData
TrainerData
SkillData
TechniqueData
ArenaData
```

Gameplay:

```text
AnimalController
MovementController
CombatController
WeaponController
MagicController
TrainingController
TrainerManager
SkillMatrixManager
ExperienceManager
BattleManager
SaveManager
```

UI:

```text
MainMenuUI
HomeUI
AnimalUI
SkillMatrixUI
TrainerUI
TrainingUI
EquipmentUI
MagicUI
BattlePreparationUI
BattleUI
ResultUI
```

---

# 80. MOST IMPORTANT DESIGN RELATIONSHIP

The final progression model is:

```text
NATURAL ABILITY
        ↓
BATTLE EXPERIENCE
        ↓
NATURAL DEVELOPMENT
        ↓
TRAINER
        ↓
DELIBERATE DEVELOPMENT
        ↓
MASTERY
        ↓
TECHNIQUE
        ↓
BUILD
        ↓
BATTLE
```

This is the central identity of the game.

---

# 81. MVP CONTENT

Keep the first playable version small:

```text
1 Animal
1 Movement Type
1v1
1 Arena
2 Weapons
2 Magic Schools
3–5 Trainers
Basic Armor
Energy
Happiness
Experience
Skill Matrix
Training
Save System
```

Recommended:

```text
Animal:
Humanoid Dog

Weapons:
Sword
Hammer

Magic:
Fire
Wind

Trainers:
Swordmaster
Hammermaster
Agility Trainer
Fire Mage
Endurance Trainer
```

---

# 82. MVP COMPLETE LOOP

The first playable build should achieve:

```text
Launch
↓
Main Menu
↓
Home
↓
View Dog
↓
View Skill Matrix
↓
Select Trainer
↓
Train
↓
Equip Sword / Hammer
↓
Learn Fire / Wind
↓
Battle Preparation
↓
1v1 Arena
↓
Move
↓
Attack
↓
Heavy Attack
↓
Dodge
↓
Block
↓
Manage Stamina
↓
Use Magic
↓
Win / Lose
↓
Gain Coins + XP
↓
Gain Battle Experience
↓
Possible Natural Growth
↓
Energy / Happiness Update
↓
Recovery
↓
Save
↓
Return Home
```

---

# 83. AI AGENT DEVELOPMENT RULE

For every task:

```text
1. Inspect the existing project first.
2. Understand what already exists.
3. Implement ONLY the requested task.
4. Reuse existing architecture.
5. Do not rewrite unrelated systems.
6. Do not implement future features early.
7. Avoid unnecessary dependencies.
8. Run the project.
9. Verify the requested functionality.
10. Fix errors caused by the current task.
11. Stop when the requested milestone is complete.
```

The agent should never treat the complete document as one coding task.

---

# STEP-BY-STEP IMPLEMENTATION PROMPTS

## PROMPT 01 — PROJECT FOUNDATION

```text
You are building a mobile 3D game using Godot and Blender.

Implement ONLY the project foundation.

Create clean architecture for:

- Main Menu
- Home
- Animal Management
- Skill Matrix
- Trainers
- Training
- Equipment
- Magic
- Battle Preparation
- Battle Arena
- Battle Result
- Save System

Separate:

- Data
- Gameplay
- UI
- Presentation

The MVP starts with one humanoid dog and 1v1.

Do not implement gameplay yet.

Verify that the project opens and runs correctly.
```

---

## PROMPT 02 — BOOT + MAIN MENU

```text
Implement ONLY:

Boot
→ Main Menu

Main Menu contains:

- Play
- Settings
- Exit

Play transitions to Home.

Do not implement training, combat, equipment, magic, or economy.
```

---

## PROMPT 03 — OWNER + HOME

```text
Implement ONLY the Owner Profile and Home scene.

Owner data:

- Coins
- XP
- Level
- Trainer Slots

Home displays:

- Owner Level
- Coins
- XP
- Active Trainer Count
- Animal
- Training
- Equipment
- Magic
- Battle

Use placeholder navigation for systems not implemented yet.
```

---

## PROMPT 04 — ANIMAL DATA

```text
Implement ONLY the reusable AnimalData system.

Support:

- ID
- Name
- Model
- Movement Type
- Base Stats
- Training Potential
- Strengths
- Weaknesses

Stats:

- Health
- Attack
- Strength
- Attack Speed
- Defense
- Agility
- Evasion
- Endurance

Movement Types:

- Ground
- Flying
- Swimming
- Amphibious

Create the first animal:

Humanoid Dog.

Do not implement combat.
```

---

## PROMPT 05 — SKILL MATRIX DATA

```text
Implement ONLY the Skill Matrix data model.

Hierarchy:

Natural Foundation
→ Combat Fundamentals
→ Combat Discipline
→ Weapon Proficiency
→ Magic Proficiency
→ Advanced Techniques

Combat Fundamentals:

- Movement
- Attack
- Defense
- Dodge
- Block
- Stamina
- Recovery

Combat Discipline:

- Timing
- Positioning
- Attack Control
- Defense Control
- Dodge Control
- Block Control
- Stamina Discipline
- Recovery Control

Weapons:

- Sword
- Hammer
- Dagger
- Spear
- Axe
- Shield
- Bow

Magic:

- Fire
- Frost
- Wind
- Earth
- Lightning
- Nature

Ranks:

- None
- Foundation
- Novice
- Apprentice
- Skilled
- Expert
- Master

Do not implement training or combat.
```

---

## PROMPT 06 — ANIMAL MANAGEMENT

```text
Implement ONLY Animal Management.

Player owns one humanoid dog.

Display:

- 3D model
- Name
- Animal Level
- Combat Capability
- Energy
- Happiness
- Stats
- Skill Matrix

Prepare for multiple animals later.

Do not implement battle or training.
```

---

## PROMPT 07 — OWNER LEVEL + TRAINER SLOTS

```text
Implement ONLY Owner Level and Trainer Slot capacity.

Use configurable slot progression.

Example:

Level 1 = 1 trainer
Level 5 = 2
Level 10 = 3
Level 15 = 4
Level 20 = 5

Maximum active trainers = 5.

Do not implement trainer functionality yet.
```

---

## PROMPT 08 — EXPERIENCE SYSTEM

```text
Implement ONLY the reusable Animal Experience system.

Create experience tracks for:

- Offensive
- Strength
- Agility
- Evasion
- Defense
- Endurance
- Resilience
- Weapon familiarity
- Magic familiarity

Experience must accumulate through meaningful gameplay events.

Do not yet connect it to combat actions.

Create configurable thresholds and development rules.

Do not implement trainer development yet.
```

---

## PROMPT 09 — NATURAL GROWTH

```text
Implement ONLY Natural Growth from Experience.

When experience thresholds are reached, the animal can naturally develop related attributes.

Examples:

Offensive Experience
→ Attack progression

Strength Experience
→ Strength progression

Agility Experience
→ Agility progression

Evasion Experience
→ Evasion progression

Defense Experience
→ Defense progression

Endurance Experience
→ Endurance progression

Resilience Experience
→ Health / Endurance / Recovery progression

Weapon Experience
→ Weapon Familiarity

Magic Experience
→ Magic Familiarity

Do NOT provide manual stat-point allocation.

Respect animal training potential.

Do not implement combat yet.
```

---

## PROMPT 10 — TRAINER DATA

```text
Implement ONLY the Trainer data system.

Trainers are universal and can train ANY animal.

Categories:

Attribute
Weapon
Magic

Create definitions for:

Strength Trainer
Attack Trainer
Agility Trainer
Defense Trainer
Evasion Trainer
Endurance Trainer

Swordmaster
Axemaster
Hammermaster
Spearmaster
Duelist
Guardian
Ranger

Fire Mage
Frost Mage
Wind Mage
Earth Mage
Lightning Mage
Nature Mage

Trainer data:

- ID
- Name
- Rarity
- Primary Discipline
- Secondary Discipline
- Efficiency
- Supported Skill Tier
- Special Trait

Do not implement training yet.
```

---

## PROMPT 11 — TRAINER RARITY

```text
Implement ONLY Trainer Rarity.

Rarities:

Common
Uncommon
Rare
Epic
Legendary

Rarity should affect:

- Training efficiency
- Skill coverage
- Supported skill tier
- Technique access
- Trainer traits

Do not make rarity directly increase battle stats.
```

---

## PROMPT 12 — ACTIVE TRAINER MANAGEMENT

```text
Implement ONLY Active Trainer Management.

Player can:

- View trainers
- Activate trainers
- Deactivate trainers
- Replace trainers

Active trainer limit depends on Owner Level.

Maximum = 5.

Trainers are shared across all owned animals.

The same trainer can train any owned animal.

Do not implement actual training actions.
```

---

## PROMPT 13 — ENERGY + HAPPINESS

```text
Implement ONLY animal Energy and Happiness.

Energy:

- Current
- Maximum
- Consumption
- Recovery

Happiness:

- Current
- Maximum
- Positive changes
- Negative changes

Create reusable APIs/hooks for future systems.

Do not implement combat yet.
```

---

## PROMPT 14 — TRAINING SYSTEM

```text
Implement ONLY trainer-based development.

Training flow:

Trainer
→ Animal
→ Skill
→ Cost
→ Energy
→ Confirm
→ Development

Training can improve:

- Stats
- Combat Fundamentals
- Combat Discipline
- Weapon Mastery
- Magic Mastery

Training requires Coins + Animal Energy.

Training must respect:

- Trainer capability
- Trainer rarity
- Animal training potential
- Skill prerequisites

Do NOT provide manual stat-point allocation.
```

---

## PROMPT 15 — TECHNIQUE PREREQUISITES

```text
Implement ONLY the Skill Matrix prerequisite system.

Advanced techniques require combinations of skills.

Examples:

Hammer Skilled
+
Strength Skilled
+
Defense Skilled
=
Guard Break

Dagger Skilled
+
Agility Skilled
+
Wind Skilled
=
Wind Dash

Sword Expert
+
Fire Skilled
=
Flame Slash

Techniques require a trainer to be learned.

Use a data-driven prerequisite system.

Only create a few test techniques.
```

---

## PROMPT 16 — EQUIPMENT DATA

```text
Implement ONLY EquipmentData.

Weapons:

- Sword
- Hammer
- Dagger
- Spear
- Axe
- Shield
- Bow

Armor:

- Light
- Medium
- Heavy

Every animal can use every weapon.

Do not implement combat behavior yet.
```

---

## PROMPT 17 — EQUIPMENT UI

```text
Implement ONLY Equipment Management UI.

Allow:

- View weapons
- Equip weapon
- Unequip weapon
- View armor
- Equip armor
- Unequip armor

Show projected combat effects.

Do not add new gameplay features.
```

---

## PROMPT 18 — WEAPON EXPERIENCE + MASTERY

```text
Implement ONLY weapon familiarity and mastery.

Weapon Experience:
→ gained from meaningful weapon usage.

Weapon Mastery:
→ developed through weapon trainers.

Ranks:

Novice
Apprentice
Skilled
Expert
Master

Do not add large numerical combat bonuses yet.

Prepare the system for advanced techniques.
```

---

## PROMPT 19 — MAGIC EXPERIENCE + MASTERY

```text
Implement ONLY magic familiarity and mastery.

Schools:

- Fire
- Frost
- Wind
- Earth
- Lightning
- Nature

Magic Experience:
→ gained from meaningful magic usage.

Magic Mastery:
→ developed through magic trainers.

Every animal can learn every school.

Do not implement environmental magic effects yet.
```

---

## PROMPT 20 — COMBAT FOUNDATION

```text
Implement ONLY the core 1v1 combat framework.

Use:

- One humanoid dog
- One opponent
- Ground movement
- One arena

Implement:

- Health
- Damage
- Attack
- Strength
- Attack Speed
- Defense
- Agility
- Evasion
- Endurance
- Stamina
- Stagger
- Knockback
- Recovery

Do not implement flying, swimming, 2v2, or 3v3.
```

---

## PROMPT 21 — COMBAT EXPERIENCE EVENTS

```text
Connect the Experience System to the combat system.

Meaningful combat events should award experience:

Successful attack
→ Offensive XP

Heavy attack
→ Strength XP

Successful dodge
→ Evasion XP

Successful block
→ Defense XP

Good movement/repositioning
→ Agility XP

Sustained stamina management
→ Endurance XP

Surviving heavy damage
→ Resilience XP

Weapon usage
→ Weapon XP

Magic usage
→ Magic XP

Use difficulty weighting and anti-farming logic.

Do not directly grant random stat points.
```

---

## PROMPT 22 — MOBILE COMBAT CONTROLS

```text
Implement ONLY mobile combat controls.

Landscape layout.

Left:

- Virtual Joystick

Right:

- Attack
- Heavy Attack
- Dodge
- Block
- Magic

Dodge is active.

Block is active.

Evasion is not RNG.

Keep the battlefield visible.
```

---

## PROMPT 23 — STAMINA

```text
Implement ONLY stamina combat behavior.

Consume stamina for:

- Attack
- Heavy Attack
- Dodge
- Block
- Sprint
- Magic
- Special Technique

Endurance controls:

- Maximum stamina
- Recovery

At zero stamina:

Exhausted

Exhaustion temporarily reduces combat effectiveness.

Tune for mobile combat and avoid button-mashing dominance.
```

---

## PROMPT 24 — SWORD + HAMMER

```text
Implement ONLY Sword and Hammer combat.

Sword:

- Balanced
- Medium range
- Medium speed
- Moderate stamina

Hammer:

- High stagger
- High strength interaction
- Slow
- High stamina cost
- Long recovery

The two weapons must feel distinctly different.

Do not add additional weapons yet.
```

---

## PROMPT 25 — FIRE + WIND

```text
Implement ONLY Fire and Wind combat abilities.

Magic must:

- Consume stamina
- Have casting time
- Have recovery
- Have counterplay
- Be dodgeable or interruptible where appropriate

Do not implement all magic schools yet.
```

---

## PROMPT 26 — BALANCE / COUNTERPLAY

```text
Implement the reusable animal balance profile.

Every animal must define:

- Strengths
- Weaknesses
- Counterplay

No animal should be universally superior.

Use soft counters.

The current dog should have meaningful trade-offs.

Do not add additional species yet.
```

---

## PROMPT 27 — FIRST ARENA

```text
Implement ONLY the first 1v1 arena.

Requirements:

- Small arena
- Ground navigation
- Spawn points
- Combat boundary
- Simple obstacles
- Camera limits

Do not implement water or flying.
```

---

## PROMPT 28 — BATTLE PREPARATION

```text
Implement ONLY Battle Preparation.

Review:

- Animal
- Weapon
- Armor
- Magic
- Skill Matrix
- Energy
- Build summary

Flow:

Preparation
→ Confirm
→ Arena
```

Keep the UI simple and mobile friendly.

````

---

## PROMPT 29 — BATTLE RESULTS

```text
Implement ONLY Battle Result.

Display:

- Victory / Defeat
- Coins
- XP
- Experience gained by category
- Natural growth
- Skill progress
- Energy change
- Happiness change

XP must not directly provide arbitrary stat points.

The result screen should explain what the animal learned.
````

---

## PROMPT 30 — RECOVERY

```text
Implement ONLY recovery.

Allow the animal to recover:

- Energy
- Happiness where appropriate
- Knockout state

Use a simple cost/time model.

Do not add new combat mechanics.
```

---

## PROMPT 31 — SAVE / LOAD

```text
Implement ONLY persistent save/load.

Save:

Owner
Owner Level
Owner XP
Coins
Trainer Slots
Active Trainers

Animals
Animal XP
Animal Level
Stats
Experience Tracks
Skill Matrix
Training Potential
Energy
Happiness

Weapons
Armor
Magic

Weapon Experience
Weapon Mastery
Magic Experience
Magic Mastery

Trainers
Rarity
Progression
Traits

Techniques

Use versioned save data.

Test save, restart, load, and verify consistency.
```

---

## PROMPT 32 — BLENDER / GODOT CHARACTER PIPELINE

```text
Implement and verify ONLY the production asset pipeline.

Use the humanoid dog as the master character.

Verify:

- Blender import
- Scale
- Orientation
- Skeleton
- Materials
- Collision
- Animation player
- Animation states

Animations:

Idle
Walk
Run
Attack
Heavy Attack
Dodge
Block
Hit
Stagger
Knocked Out
Recover

Do not add other animal species.
```

---

## PROMPT 33 — MOBILE UX PASS

```text
Review ONLY existing mobile UI and interaction.

Improve:

- Touch targets
- Readability
- Landscape layout
- Safe areas
- Navigation
- HUD
- Camera visibility
- Button placement
- Screen hierarchy

Do not add gameplay features.
```

---

## PROMPT 34 — COMBAT POLISH

```text
Polish ONLY the existing 1v1 combat.

Improve:

- Attack timing
- Hit feedback
- Stagger
- Knockback
- Dodge responsiveness
- Block response
- Animation synchronization
- Camera response
- Audio hooks
- Mobile input response

Do not add major new systems.
```

---

# PHASE 2 — EXPANSION

Only begin these after the first dog 1v1 version is fun and stable.

---

## PROMPT 35 — SECOND ANIMAL

```text
Add ONE additional animal using AnimalData.

Do NOT rewrite combat.

The new animal must have:

- Natural strengths
- Natural weaknesses
- Counterplay
- Training potential
- Existing weapon compatibility
- Existing magic compatibility

Verify all existing systems still work.
```

---

## PROMPT 36 — FLYING PROTOTYPE

```text
Add Flying as a reusable MovementType.

Implement:

- Vertical movement
- Air stamina
- Flying attacks
- Landing
- Knockdown
- Anti-air interaction
- Camera support
- Targeting
- Arena boundaries

Use one prototype animal.

Do not build a complete flying roster.
```

---

## PROMPT 37 — SWIMMING PROTOTYPE

```text
Add Swimming as a reusable MovementType.

Implement:

- Water movement
- Water navigation
- Land transition
- Water combat interaction
- Camera
- Targeting

Use one prototype animal.

Do not build multiple swimming species yet.
```

---

## PROMPT 38 — 2v2

```text
Add ONLY 2v2.

Support:

- Two allied animals
- Two enemy animals
- Target selection
- Ally targeting
- Team positioning
- Team combat state
- Medium arena

Do not implement 3v3 yet.
```

---

## PROMPT 39 — 3v3

```text
Add ONLY 3v3.

Support:

- Three allied animals
- Three enemy animals
- Target priority
- Team positioning
- Area abilities
- Coordinated combat
- Large arena

Reuse the existing architecture.

Do not rewrite 1v1 or 2v2.
```

---

# 83. FINAL SYSTEM ARCHITECTURE

The completed game should conceptually work like this:

```text
                         OWNER
                           │
                     OWNER LEVEL
                           │
                    TRAINER SLOTS
                           │
                      MAX 5
                           │
              ┌────────────┴────────────┐
              ↓                         ↓
          TRAINERS                   ANIMALS
              │                         │
              │                  NATURAL ATTRIBUTES
              │                         │
              │                       BATTLE
              │                         │
              │                  EXPERIENCE TRACKS
              │                         │
              │                 NATURAL DEVELOPMENT
              │                         │
              └──────────────→ TRAINING
                                        │
                               SKILL DEVELOPMENT
                                        │
                                    MASTERY
                                        │
                                   TECHNIQUES
                                        │
                                     BUILD
                                        │
                                     BATTLE
                                        │
                                      RESULT
                                        │
                          EXPERIENCE + REWARDS
                                        │
                                        └──→ DEVELOPMENT
```

---

# 84. NON-NEGOTIABLE DESIGN RULES

```text
1. Every animal has strengths and weaknesses.

2. Every strength must have counterplay.

3. Every animal can use every weapon.

4. Every animal can learn every magic school.

5. Trainers are universal and can train any animal.

6. Maximum active trainers = 5.

7. Owner Level determines trainer slots and progression access.

8. Trainers have rarity.

9. Trainer rarity improves training capability, not direct battle power.

10. Animals naturally develop from meaningful battle experience.

11. Experience does not directly produce arbitrary manual stat points.

12. Repeated actions cannot be exploited for unlimited experience.

13. Defeat can provide resilience-related growth.

14. Trainers provide deliberate development and advanced mastery.

15. Advanced techniques require Skill Matrix prerequisites.

16. Dodge is an active action.

17. Block is an active action.

18. Stamina is a major combat resource.

19. Higher stats should never guarantee victory.

20. Combat rewards timing, positioning and stamina management.

21. Flying provides mobility, not immunity.

22. Swimming provides environmental advantage, not automatic superiority.

23. Battle arena size scales with battle format and movement requirements.

24. Species-specific logic should be minimized.

25. The first dog is a content prototype, not a hard-coded special case.

26. Mobile usability is part of the core design, not a later afterthought.

27. Blender assets must fit a reusable Godot character architecture.

28. Each AI implementation task must remain small and focused.
```

# 85. FINAL DESIGN PHILOSOPHY

The animal's development should tell a story.

A dog that spends its career:

```text
Dodging
+
Repositioning
+
Fast attacks
```

should naturally develop differently from a dog that:

```text
Blocks
+
Uses heavy weapons
+
Endures long battles
```

But the owner can redirect that development using trainers.

Therefore:

```text
Natural Ability
    ↓
What the Animal Experiences
    ↓
How the Animal Develops
    ↓
Which Trainers the Owner Has
    ↓
How the Owner Trains It
    ↓
What Weapon / Armor / Magic It Uses
    ↓
How the Player Fights
    ↓
Final Result
```

The result should feel less like:

```text
"I leveled up and received +10."
```

and more like:

```text
"This animal became good at this because of the way I raised and fought with it."
```

That should be the identity of the entire progression system.

# 86. MVP DEFINITION

Do not start with 20 animals.

The first milestone is:

```text
ONE HUMANOID DOG
        ↓
ONE SKILL MATRIX
        ↓
UP TO 5 UNIVERSAL TRAINERS
        ↓
EXPERIENCE FROM BATTLE
        ↓
NATURAL GROWTH
        ↓
TRAINER DEVELOPMENT
        ↓
SWORD / HAMMER
        ↓
FIRE / WIND
        ↓
ARMOR
        ↓
ONE 1v1 ARENA
        ↓
MOBILE COMBAT
        ↓
BATTLE RESULT
        ↓
RECOVERY
        ↓
SAVE
```

Once this is fun, stable, and mobile-friendly, the game can expand primarily through:

```text
New Animal
+
New Model
+
New Movement Profile
+
New Strengths / Weaknesses
+
New Weapons
+
New Magic
+
New Trainers
+
New Arenas
+
New Battle Formats
```

rather than rewriting the core systems.
