# ANIMAL CHAMPION

## Story, World, Menu & Scene Flow

---

# 1. STORY DIRECTION

The game should be presented as an **animal fantasy adventure**, not a gladiator simulator.

The animals are:

* Champions
* Companions
* Protectors
* Travelers
* Students
* Guardians

They are not slaves and should never feel like disposable units.

The player is their **Keeper / Warden / Champion Trainer**, responsible for guiding them.

Battles are organized competitions and trials used to:

* Prove skill
* Protect territories
* Earn resources
* Build reputation
* Discover new areas
* Meet other champions
* Prepare for greater threats

Animals can be defeated or knocked out, but normal battles do not revolve around killing them.

---

# 2. STORY PREMISE

A suitable foundation story:

## The Age of the Wildbound

Long ago, the lands were connected by ancient paths where animals lived alongside the forces of nature.

Certain animals discovered that they could channel ancient energy called **Aether**.

Aether allowed them to:

* Strengthen their bodies
* Master weapons
* Learn magic
* Communicate through bonds
* Protect their territories

Over time, communities created the **Grand Trials**.

The Trials began as peaceful contests between champions.

But something changed.

Ancient Aether sites are beginning to fail.

Wild creatures are becoming unstable.

Old territories are becoming dangerous.

And strange creatures have started appearing beyond the known borders.

The player inherits a small training lodge from an aging mentor and receives their first companion:

**a young humanoid dog with potential but little experience.**

The player's journey begins with something simple:

> Train one companion. Enter the local trial. Earn enough reputation to keep the lodge open.

Eventually, the player discovers that the competitions are connected to the disturbances affecting the world.

This gives the game a reason to expand.

---

# 3. PLAYER ROLE

The player is not the fighter themselves.

The player is the:

## Keeper

The Keeper:

* Manages champions
* Builds relationships with trainers
* Selects equipment
* Studies opponents
* Guides development
* Chooses where to travel
* Enters trials
* Uncovers the story

The animals are the ones who fight.

This also makes the trainer system logical.

---

# 4. TRAINER ROLE IN THE STORY

Trainers are not simply menu entries.

They are people/animal characters who have dedicated their lives to a discipline.

Examples:

```text id="kz4o7h"
Swordmaster
A veteran duelist who teaches discipline and timing.

Hammermaster
A powerful but patient trainer specializing in force and control.

Agility Trainer
A traveler who teaches movement and evasive techniques.

Fire Mage
A scholar of destructive Aether.

Wind Mage
A wandering mage who teaches movement and positioning.
```

The player can eventually recruit or work with trainers.

The important rule remains:

> **One trainer can train any champion.**

A Swordmaster does not belong to one dog.

---

# 5. TRAINER RARITY IN THE STORY

Trainer rarity should feel like reputation and expertise.

```text id="h51xkt"
Common
→ Local instructor

Uncommon
→ Experienced specialist

Rare
→ Recognized master

Epic
→ Renowned expert

Legendary
→ Historical-level master
```

This is much more believable than simply giving an NPC a glowing rarity color.

A Legendary trainer could be someone whose techniques are known throughout the world.

---

# 6. WHY ONLY 5 TRAINERS?

The story can explain the five-trainer limit.

The Keeper has a limited number of **active mentorship contracts** because:

* Trainers require time
* Trainers have personal commitments
* Training requires direct attention
* Maintaining too many disciplines reduces effectiveness

Therefore the player's lodge can maintain only a limited active circle of mentors.

Owner progression expands that capability:

```text id="c3v4ow"
Beginning
→ 1 mentor

Growing Lodge
→ 2

Established Lodge
→ 3

Recognized Lodge
→ 4

Renowned Lodge
→ 5
```

This feels much more natural than:

> "Level 20 gives you five slots."

The level can still control it internally, but the story presents it as the growth of the player's lodge.

---

# 7. WORLD STRUCTURE

The world should be divided into regions.

Example:

```text id="4r6t0u"
Home Valley
    ↓
Greenwood
    ↓
Stonepass
    ↓
Lakeward
    ↓
High Cliffs
    ↓
Ancient Wilds
```

Each region introduces:

* New animals
* Trainers
* Weapons
* Magic
* Arenas
* NPCs
* Story events
* New environmental challenges

The player doesn't need access to everything at the beginning.

---

# 8. MAIN GAME STRUCTURE

The overall experience should be:

```text id="m1j1yg"
STORY
 ↓
EXPLORE
 ↓
MEET / RECRUIT
 ↓
TRAIN
 ↓
PREPARE
 ↓
TRIAL
 ↓
REWARD
 ↓
DISCOVER
 ↓
UNLOCK NEXT REGION
 ↓
REPEAT
```

This makes the systems serve the story.

---

# 9. BOOT / OPENING

When the game launches:

```text id="q7zq2k"
Godot Logo
↓
Studio Logo
↓
Short atmospheric world shot
↓
Title
```

Avoid immediately showing a complex interface.

Give the game a sense of place.

For example:

* Wind through grass
* Distant mountains
* A small training lodge
* The dog walking toward the lodge
* Soft environmental audio

Then:

```text id="rv8pr9"
ANIMAL CHAMPION
```

---

# 10. TITLE SCREEN

The first menu should be extremely simple.

```text id="f9v2t2"
CONTINUE
NEW JOURNEY
SETTINGS
CREDITS
```

On a first launch:

```text id="qtx8kq"
NEW JOURNEY
SETTINGS
CREDITS
```

Do not show:

* Inventory
* Skill Matrix
* Trainers
* Battle
* Shop
* Magic

Those belong inside the journey.

---

# 11. NEW JOURNEY

Selecting New Journey starts the opening scene.

Do not immediately throw the player into a menu.

Instead:

```text id="g7jwe6"
New Journey
↓
Opening Cinematic
↓
Story Scene
↓
First Dog
↓
Home
```

---

# 12. OPENING CINEMATIC

Introduce the world through a short scene.

Example:

The player approaches an old training lodge.

Inside is an aging mentor.

The mentor explains that the local Champion Trial is approaching.

The mentor has one young dog who has not yet found their path.

The mentor gives the player responsibility for the lodge.

The story begins.

Keep the first cinematic short.

The player should reach gameplay quickly.

---

# 13. FIRST PLAYABLE SCENE — THE LODGE

The player begins inside the first home environment.

This is not a dashboard.

It is a small 3D location.

Possible areas:

```text id="dzqj61"
Training Yard
Lodge
Rest Area
Equipment Bench
Trainer Board
Battle Map
```

The player can navigate this location or interact with contextual buttons depending on how much free exploration you want.

---

# 14. HOME / LODGE

The Lodge becomes the player's primary hub.

Instead of a generic screen:

```text
Animal
Training
Equipment
Magic
Battle
```

the world presents those systems naturally.

Example:

```text id="z7xqvj"
Dog
→ interact with dog

Training Yard
→ training

Equipment Bench
→ weapons / armor

Magic Circle
→ magic

Trainer Board
→ trainers

Map / Notice Board
→ battles / story
```

This is much more immersive.

---

# 15. OPTIONAL MOBILE HOME UI

Because this is a mobile game, you can combine:

```text id="0bh13d"
3D Lodge
+
Contextual UI
```

The player doesn't need to physically walk everywhere.

When they select the dog:

```text
[Inspect]
[Train]
[Equip]
[Magic]
```

appear contextually.

This preserves mobile usability without becoming a dashboard.

---

# 16. FIRST STORY QUEST

The mentor gives the player the first objective:

> Prepare the young dog for the local trial.

The quest teaches:

```text id="2k7c7x"
Inspect Animal
↓
Learn about Stats
↓
Learn about Skill Matrix
↓
Meet First Trainer
↓
Train
↓
Equip Weapon
↓
Enter Trial
```

This naturally teaches the mechanics.

---

# 17. FIRST TRAINER

The first trainer should appear as a real character.

For example:

## Local Swordmaster

The trainer explains:

* The dog already has natural strengths.
* Experience comes from fighting.
* Training helps direct that growth.
* Mastery unlocks better techniques.

The player performs their first training session.

This teaches the core progression philosophy through story.

---

# 18. FIRST SKILL MATRIX PRESENTATION

Do not overwhelm the player with the entire Skill Matrix at the start.

Initially reveal:

```text id="j9bn87"
Combat Fundamentals
├── Attack
├── Movement
├── Dodge
└── Stamina
```

Later reveal:

```text id="dgo4mb"
Defense
Block
Weapon Mastery
Magic
Advanced Techniques
```

Eventually the entire matrix becomes available.

This is much better than presenting 50 progression nodes on the first screen.

---

# 19. FIRST EQUIPMENT

The player receives their first weapon.

Recommended:

## Sword

It is easier to understand than a highly specialized weapon.

Then the Hammer can become the first alternate weapon.

The player learns:

```text id="d2c5s5"
Every animal can use weapons.
Mastery determines proficiency.
```

---

# 20. FIRST BATTLE

The first battle is a local trial.

The opponent should deliberately teach one mechanic.

For example:

```text id="5j13oa"
Opponent attacks slowly
→ teaches Dodge
```

Then:

```text id="w9y1ht"
Opponent guards
→ teaches timing
```

Then:

```text id="0grv9v"
Opponent becomes aggressive
→ teaches stamina
```

The first battle should feel like a tutorial embedded inside the story.

---

# 21. FIRST BATTLE RESULT

After victory/defeat:

```text id="ic74ra"
Battle Result
↓
Coins
XP
Experience
Skill Development
Energy
Happiness
```

But present it as the animal's growth.

Example:

```text
Bruno learned from the trial.

Evasion Experience +12
Sword Experience +18
Endurance Experience +7
```

This makes the experience system meaningful.

---

# 22. POST-BATTLE STORY

After the first trial, the mentor explains:

The dog has potential.

But the local trial was only the beginning.

The player receives a map showing nearby regions.

Now the game opens up.

---

# 23. WORLD MAP

The World Map becomes the main progression navigation.

Example:

```text id="hkz8r4"
HOME VALLEY
     │
     ├── Greenwood
     │
     ├── Stonepass
     │
     ├── Lakeward
     │
     └── Unknown
```

Regions can show:

* Story progress
* Available trials
* Trainers
* Animals
* Resources
* Difficulty
* Unexplored locations

---

# 24. STORY CHAPTER STRUCTURE

The game can be divided into chapters.

### Chapter 1 — First Steps

Learn:

* Animal management
* Training
* Equipment
* 1v1
* Experience

### Chapter 2 — The Road Beyond

Introduce:

* New regions
* Additional trainers
* More equipment
* Second animal

### Chapter 3 — The Broken Aether

Introduce:

* Magic expansion
* Environmental effects
* Stronger enemies

### Chapter 4 — Wings and Waters

Introduce:

* Flying animals
* Swimming animals
* New arena types

### Chapter 5 — The Grand Trials

Introduce:

* 2v2
* More advanced team mechanics

### Chapter 6 — The Final Path

Introduce:

* 3v3
* Ancient arenas
* Major story conflict

---

# 25. MAIN MENU AFTER PROGRESSION

Once the player has progressed, Continue remains the primary action.

The player can enter:

```text id="3tj36d"
CONTINUE
JOURNEY
CHAMPIONS
TRAINERS
EQUIPMENT
CODEX
SETTINGS
```

However, these should only appear as they become relevant.

Do not expose everything immediately.

---

# 26. JOURNEY

"Journey" should contain the larger world progression.

```text id="ne2c63"
World Map
Story
Trials
Regions
Objectives
```

This becomes the player's adventure navigation.

---

# 27. CHAMPIONS

This replaces the generic "Animals" label.

Show:

```text id="l3n4dl"
Owned Champions
```

Selecting a champion:

```text
3D Model
Name
Level
Energy
Happiness
Capability
Stats
Skill Matrix
Weapon
Armor
Magic
Experience
```

---

# 28. TRAINING

Training remains a separate screen accessible through the champion and the Lodge.

Flow:

```text id="oj3z4r"
Champion
↓
Trainer
↓
Skill
↓
Cost
↓
Energy
↓
Training
```

---

# 29. TRAINERS

Trainer screen:

```text id="yq5fdb"
Active Mentors
Available Mentors
Trainer Details
Discipline
Rarity
Traits
Training Efficiency
```

The player can activate up to five.

---

# 30. EQUIPMENT

Rather than simply calling it Inventory:

```text id="i2bmcz"
Equipment Hall
```

Show:

```text Weapons
Armor
Accessories
```

This feels more in-world.

---

# 31. MAGIC

Magic can be represented as:

## Aether

The world can call magic "Aether Arts."

Schools:

```text id="bklwoa"
Fire
Frost
Wind
Earth
Lightning
Nature
```

Now magic is part of the world's lore rather than a generic RPG menu.

---

# 32. CODEX

A Codex adds story value.

It can contain:

```text id="g9xw6p"
Animals
Trainers
Weapons
Magic
Regions
Aether
Enemies
Stories
Battle Records
```

The Codex should unlock gradually.

This gives players a reason to explore the world.

---

# 33. BATTLE MENU

Instead of a giant generic "Battle" screen:

```text id="0j2a2n"
TRIALS
```

The player sees:

```text Local Trials
Regional Trials
Special Trials
Story Battles
```

Later:

```text 1v1
2v2
3v3
```

can appear as formats within the appropriate progression.

---

# 34. BATTLE PREPARATION

Battle Preparation should feel like preparing for a real trial.

Show:

```text id="9z4sfz"
Champion
Weapon
Armor
Aether Art
Skill Matrix
Energy
Opponent Information
Arena
```

Then:

```text
ENTER TRIAL
```

---

# 35. ARENA

The player enters the actual 3D battlefield.

Keep the UI minimal.

Combat HUD:

```text id="7yqu7v"
Health
Stamina
Magic
Target
```

The arena itself should dominate the screen.

---

# 36. BATTLE END

When the animal is defeated:

```text id="bk6qxu"
Knocked Out
```

The match ends.

Do not make normal battles about killing.

This keeps the game's tone consistent with animal champions.

---

# 37. BATTLE RESULT

Use a narrative presentation rather than only numbers.

Example:

```text id="xg0q7d"
TRIAL COMPLETE

Victory

Bruno gained experience.

Sword Experience     +18
Offensive Experience +11
Evasion Experience    +6
Resilience Experience +3
```

Then:

```text
Coins +120
Owner XP +85
```

This gives the animal's development a sense of continuity.

---

# 38. EXPERIENCE EVENTS

The battle system should track meaningful events.

Examples:

```text id="m8x2up"
Successful Attack
→ Offensive Experience

Heavy Impact
→ Strength Experience

Successful Dodge
→ Evasion Experience

Successful Block
→ Defense Experience

Good Reposition
→ Agility Experience

Long Stamina Management
→ Endurance Experience

Survived Critical Damage
→ Resilience Experience

Weapon Usage
→ Weapon Experience

Magic Usage
→ Magic Experience
```

Loss can contribute to resilience but should not become an easy farming method.

---

# 39. TRAINER INTERACTION AFTER BATTLE

This is where the game's management loop becomes interesting.

After a battle:

```text id="o1i76l"
New Experience
↓
Review Growth
↓
Choose Trainer
↓
Develop
```

For example:

```text
Bruno gained significant Evasion Experience.

Agility Trainer is currently available.

Train Evasion?
```

The player makes the decision.

---

# 40. STORY AND SYSTEMS SHOULD FEED EACH OTHER

Each system should have a narrative reason.

```text id="5h7kwp"
Animal
→ Your champion

Trainer
→ Mentor

Skill Matrix
→ Learned disciplines

Experience
→ Life experience

Weapons
→ Chosen fighting style

Magic
→ Aether Arts

Battle
→ Trial

Arena
→ Region's challenge ground

Coins
→ Lodge economy

Energy
→ Physical condition

Happiness
→ Bond / morale

Owner Level
→ Reputation of your Lodge

5 Trainers
→ Active mentorship circle

World Map
→ Journey
```

This is what will make the game feel like a real game world instead of a collection of menus.

---

# 41. RECOMMENDED COMPLETE MENU STRUCTURE

## First Launch

```text
BOOT
 ↓
TITLE
 ↓
NEW JOURNEY
 ↓
OPENING STORY
 ↓
LODGE
 ↓
TUTORIAL
 ↓
FIRST TRIAL
```

## Normal Game

```text
TITLE
 ↓
CONTINUE
 ↓
LODGE / HOME
```

From the Lodge:

```text
CHAMPION
TRAINING
TRAINERS
EQUIPMENT
AETHER ARTS
JOURNEY
CODEX
```

Journey:

```text
WORLD MAP
 ↓
REGION
 ↓
TRIAL
 ↓
BATTLE PREPARATION
 ↓
ARENA
 ↓
RESULT
 ↓
STORY / REWARD
 ↓
WORLD MAP
```

---

# 42. CONTEXTUAL MENU DESIGN

Do not make the player navigate ten menus for simple actions.

From Champion:

```text
Inspect
Train
Equip
Aether
```

From Trainer:

```text
Talk
Train Champion
View Discipline
```

From World Map:

```text
Travel
View Region
View Trial
```

From Trial:

```text
Prepare
```

Use contextual interaction wherever possible.

---

# 43. MOBILE UX PRINCIPLE

The game should feel like a mobile game, not a desktop game squeezed onto a phone.

Use:

* Large touch targets
* Short menus
* Contextual actions
* Clear navigation
* Minimal HUD
* Readable typography
* Large 3D character presentation
* Bottom sheets where appropriate
* Simple confirmation dialogs

Avoid:

* Dense tables
* Tiny icons
* Multi-panel desktop dashboards
* Excessive stat columns
* Too many buttons on one screen

---

# 44. SCENE ARCHITECTURE

Conceptually:

```text id="d43d43"
Boot
│
├── TitleScreen
│
├── MainMenu
│
├── StoryIntro
│
├── Lodge
│   ├── Champion
│   ├── Training
│   ├── Trainers
│   ├── Equipment
│   └── Aether
│
├── WorldMap
│
├── Region
│
├── TrialSelect
│
├── BattlePreparation
│
├── Arena
│
├── BattleResult
│
├── StoryEvent
│
├── Codex
│
└── Settings
```

Not every menu has to be a completely separate Godot scene.

Some can be UI states over a shared scene.

---

# 45. IMPORTANT GODOT PRINCIPLE

Do not make every button load a completely new world scene.

For example:

```text
Lodge
→ Champion Panel
→ Training Panel
→ Equipment Panel
```

can potentially remain inside the Lodge scene.

This gives the game smoother transitions and makes the mobile experience feel faster.

Use dedicated scenes when the gameplay context truly changes:

```text
Lodge
→ World Map
→ Arena
→ Story
```

---

# 46. STORY-FIRST DEVELOPMENT ORDER

The implementation should now be reorganized around the player's actual journey.

### STEP 01

Project foundation.

### STEP 02

Boot and title.

### STEP 03

Main menu.

### STEP 04

Opening cinematic/story scene.

### STEP 05

Lodge/home hub.

### STEP 06

First dog presentation.

### STEP 07

Champion data.

### STEP 08

Basic Skill Matrix.

### STEP 09

First trainer interaction.

### STEP 10

Experience system.

### STEP 11

Natural growth.

### STEP 12

Trainer system.

### STEP 13

Training.

### STEP 14

Equipment.

### STEP 15

Aether/magic.

### STEP 16

Battle preparation.

### STEP 17

1v1 arena.

### STEP 18

Mobile combat.

### STEP 19

Battle experience events.

### STEP 20

Battle result.

### STEP 21

Recovery.

### STEP 22

World map.

### STEP 23

First story progression.

### STEP 24

Save/load.

### STEP 25

Mobile polish.

---

# 47. IMPORTANT: DON'T BUILD THE WHOLE STORY SYSTEM AT ONCE

The AI agent should initially implement only:

```text
Title
→ Opening
→ Lodge
→ First Dog
→ First Trainer
→ First Trial
→ First Result
```

That is enough to validate whether the game actually feels like a game.

After that:

```text
Lodge
→ Map
→ Region
→ New Trial
```

Then:

```text
New Region
→ New Trainer
→ New Animal
→ New Mechanics
```

The world grows along with the player.

---

# 48. FIRST CHAPTER SHOULD FEEL LIKE A COMPLETE MINI-GAME

The first chapter should allow the player to:

```text
Meet Dog
↓
Learn its personality
↓
Meet Mentor
↓
Train
↓
Choose Weapon
↓
Enter First Trial
↓
Fight
↓
Learn From Battle
↓
Recover
↓
Prepare Again
↓
Win Regional Trial
↓
Unlock World Map
```

At the end of Chapter 1, the player should understand the entire basic game loop.

---

# 49. THE MOST IMPORTANT STORY PRINCIPLE

Every system should answer one question:

> **Why does this exist in the world?**

For example:

Why are there trainers?

→ Specialists who pass down knowledge.

Why are there battles?

→ Trials, competitions and tests of skill.

Why do animals gain experience?

→ They learn through real experiences.

Why can animals use weapons?

→ Champions study different combat disciplines.

Why can every animal learn magic?

→ Aether is a learnable discipline, not a species-exclusive ability.

Why are there five trainers?

→ The Lodge can maintain only a limited active mentorship circle.

Why do arenas have different environments?

→ Trials take place across different regions and natural grounds.

Why does the player need coins?

→ To maintain the Lodge, equipment and professional training.

Why does Owner Level matter?

→ The Lodge gains reputation and access as the player's journey grows.

---

# 50. FINAL PLAYER JOURNEY

The complete game should feel like:

```text id="g4gaj7"
A SMALL LODGE
       ↓
ONE YOUNG CHAMPION
       ↓
FIRST MENTOR
       ↓
FIRST TRAINING
       ↓
FIRST TRIAL
       ↓
FIRST VICTORY / DEFEAT
       ↓
LEARN FROM EXPERIENCE
       ↓
IMPROVE THE CHAMPION
       ↓
GROW THE LODGE
       ↓
RECRUIT MORE MENTORS
       ↓
MEET MORE CHAMPIONS
       ↓
TRAVEL TO NEW REGIONS
       ↓
DISCOVER MAGIC
       ↓
FACE NEW MOVEMENT TYPES
       ↓
ENTER GREATER TRIALS
       ↓
2v2
       ↓
3v3
       ↓
DISCOVER THE TRUTH ABOUT THE AETHER
       ↓
FINAL JOURNEY
```

The game therefore has a reason to progress from:

**one dog → more animals → more trainers → more regions → flying/swimming → team battles → larger story.**

That gives you a proper game structure rather than a menu-driven RPG prototype.

# 51. MASTER TONE

The visual and narrative tone should be:

**Warm, adventurous, mysterious, and respectful toward the animals.**

Not:

* Grim slave arena
* Human gladiator aesthetic
* Generic fantasy RPG menu
* Pet simulator
* Childish cartoon UI

The ideal feeling is:

> **A quiet animal fantasy world that gradually opens into a larger adventure.**

The player starts with a small lodge and one dog.

By the end, they have built a circle of champions, mentors, and companions and traveled across a world shaped by the ancient Aether.
