# Blender → Godot character pipeline

The humanoid dog is the master character. Today it is a procedural rig
(`ProceduralDogVisual`); a Blender model replaces it by setting
`AnimalData.model_scene` — `CharacterFactory` then wraps it in `GltfCharacterVisual`.
Gameplay only talks to the `CharacterVisual` interface, so combat, lodge and UI code do
not change.

## Modelling

- **Scale:** 1 Blender unit = 1 m. Upright humanoid dog ≈ 1.75–1.85 m to the ear tips;
  hips ≈ 0.9 m. Apply all transforms before export.
- **Orientation:** Z up, character faces **−Y** (Blender front view). The glTF exporter
  converts to Y-up/+Z-forward; `GltfCharacterVisual` turns the model 180° so it faces
  Godot's −Z, the combat forward.
- **Anatomy:** two arms, two hands, two legs, dog head with ears and snout, tail, fur
  detail in textures/normal maps (keep within mobile budgets: ~8–15k tris, one 2k
  texture set).
- **Materials:** Principled BSDF only (imports as `StandardMaterial3D`). Materials are
  duplicated per instance so hit flashes don't affect other champions.
- **Armor (optional):** meshes named `Armor_Light`, `Armor_Medium`, `Armor_Heavy`; the
  visual shows the one matching the equipped armor weight.

## Skeleton

Use the reusable humanoid skeleton (mechanics §77). Bone names:

```
Root
 └ Hips
    ├ Spine ─ Chest ─┬ Neck ─ Head (LeftEar, RightEar)
    │                ├ LeftArm ─ LeftForearm ─ LeftHand
    │                └ RightArm ─ RightForearm ─ RightHand   ← weapon attachment
    ├ LeftLeg ─ LeftShin
    ├ RightLeg ─ RightShin
    └ Tail
```

`RightHand` (or `hand.R`, `mixamorig:RightHand`) receives a `BoneAttachment3D` with the
weapon model. Future species should reuse this skeleton whenever practical so clips and
controllers carry over.

## Animations

Export as actions on the armature (no root motion — combat moves the body). Names are
matched loosely (`HeavyAttack`, `heavy-attack`, `Heavy Attack` → `heavy_attack`).

| Clip | Loop | Notes |
| --- | --- | --- |
| idle, walk, run | yes | walk/run speed is scaled to movement speed |
| attack | no | the strike should land at ~42% of the clip |
| heavy_attack | no | impact at ~56% |
| dodge, block, hit, stagger | no | time-scaled to gameplay durations |
| knocked_out, recover | no | KO holds its last frame |
| combat_idle, cast, exhausted, victory | optional | fall back to idle/attack |

Combat time-scales clips so gameplay timing (wind-up → active → recovery) always wins;
author clips at natural speed.

## Godot import

1. Export `humanoid_dog.glb` (glTF Binary, +Y up, apply modifiers, include animations).
2. Place it under `assets/characters/` and let Godot import it (Animation → Import On:
   all; loop the looping clips in the import dock).
3. Set the imported scene on `data/animals/humanoid_dog.tres → model_scene`.
4. Run the checks:
   - `tests/unit/test_character_pipeline.gd` validates clip mapping, hand attachment,
     armor toggling and orientation (add a test that loads the real `.glb` and asserts
     `missing_clips()` is empty).
   - `tests/visual/dog_preview.tscn` renders every clip for review.
5. Collision is not taken from the mesh: combatants use a 0.45 m radius
   (`Combatant.RADIUS`), so silhouettes may vary freely.

## Status

The pipeline code paths are implemented and unit-tested with a Blender-shaped scene built
in code. A real Blender export has not been produced in this repository yet.
