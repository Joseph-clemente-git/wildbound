class_name CharacterAnimations
extends RefCounted
## Builds the shared humanoid AnimationLibrary from compact pose keyframes.
##
## Every humanoid champion rig (procedural or imported from Blender) exposes the
## same bone pivots, so these clips work for any species that reuses the
## reusable skeleton: Root, Hips, Spine, Chest, Neck, Head, arms, legs, Tail.
##
## Clips marked "normalized" last exactly 1 second; combat code plays them with
## `speed = 1 / action_duration` so animation timing always matches gameplay
## timing (windup → active → recovery).

## Bone key -> node path relative to the visual's root.
const BONES := {
	"hips": "Rig/Hips",
	"spine": "Rig/Hips/Spine",
	"chest": "Rig/Hips/Spine/Chest",
	"neck": "Rig/Hips/Spine/Chest/Neck",
	"head": "Rig/Hips/Spine/Chest/Neck/Head",
	"l_ear": "Rig/Hips/Spine/Chest/Neck/Head/LeftEar",
	"r_ear": "Rig/Hips/Spine/Chest/Neck/Head/RightEar",
	"l_arm": "Rig/Hips/Spine/Chest/LeftArm",
	"l_fore": "Rig/Hips/Spine/Chest/LeftArm/LeftForearm",
	"r_arm": "Rig/Hips/Spine/Chest/RightArm",
	"r_fore": "Rig/Hips/Spine/Chest/RightArm/RightForearm",
	"l_leg": "Rig/Hips/LeftLeg",
	"l_shin": "Rig/Hips/LeftLeg/LeftShin",
	"r_leg": "Rig/Hips/RightLeg",
	"r_shin": "Rig/Hips/RightLeg/RightShin",
	"tail": "Rig/Hips/Tail",
}

## Clips required by the MVP animation list (mechanics §78) plus extras.
const REQUIRED_CLIPS: Array[String] = [
	"idle", "walk", "run", "attack", "heavy_attack", "dodge", "block",
	"hit", "stagger", "knocked_out", "recover",
]

## Base pose for the arena: knees bent, arms ready.
const STANCE := {
	"hips_y": -0.04, "spine": Vector3(-0.08, 0, 0),
	"l_leg": Vector3(0.18, 0, 0), "l_shin": Vector3(-0.3, 0, 0),
	"r_leg": Vector3(-0.12, 0, 0), "r_shin": Vector3(-0.2, 0, 0),
	"r_arm": Vector3(0.45, 0, 0.15), "r_fore": Vector3(0.7, 0, 0),
	"l_arm": Vector3(0.35, 0, -0.2), "l_fore": Vector3(0.8, 0, 0),
	"tail": Vector3(-0.5, 0, 0),
}

const RELAXED := {
	"l_arm": Vector3(0, 0, -0.12), "r_arm": Vector3(0, 0, 0.12),
	"l_fore": Vector3(0.15, 0, 0), "r_fore": Vector3(0.15, 0, 0),
	"tail": Vector3(-0.6, 0, 0),
}


## `hip_height` is the rest height of the Hips pivot for the rig being animated.
static func build_library(hip_height: float) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var clips := _clips()
	for clip_name: String in clips:
		library.add_animation(clip_name, _build(clips[clip_name], hip_height))
	return library


static func _clips() -> Dictionary:
	return {
		"idle": {"length": 2.4, "loop": true, "keys": [
			[0.0, _with(RELAXED, {"chest": Vector3(-0.02, 0, 0), "tail": Vector3(-0.6, -0.3, 0)})],
			[0.6, _with(RELAXED, {"l_ear": Vector3(0, 0, -0.15)})],
			[1.2, _with(RELAXED, {"chest": Vector3(0.035, 0, 0), "hips_y": -0.012,
					"head": Vector3(0.05, 0.08, 0), "tail": Vector3(-0.6, 0.3, 0)})],
			[2.4, _with(RELAXED, {"chest": Vector3(-0.02, 0, 0), "tail": Vector3(-0.6, -0.3, 0)})],
		]},
		"combat_idle": {"length": 1.6, "loop": true, "keys": [
			[0.0, _with(STANCE, {"tail": Vector3(-0.5, -0.2, 0)})],
			[0.8, _with(STANCE, {"hips_y": -0.065, "chest": Vector3(0.04, 0, 0), "tail": Vector3(-0.5, 0.2, 0)})],
			[1.6, _with(STANCE, {"tail": Vector3(-0.5, -0.2, 0)})],
		]},
		"walk": {"length": 1.0, "loop": true, "keys": _cycle(0.45, 0.35, 0.03, 0.0, 0.2)},
		"run": {"length": 0.62, "loop": true, "keys": _cycle(0.85, 0.7, 0.06, -0.22, 1.1)},
		"attack": {"length": 1.0, "loop": false, "keys": [
			[0.0, STANCE],
			[0.3, _with(STANCE, {"r_arm": Vector3(-2.1, 0, 0.45), "r_fore": Vector3(0.5, 0, 0),
					"chest": Vector3(0, 0.55, 0), "spine": Vector3(0.05, 0, 0)})],
			[0.45, _with(STANCE, {"r_arm": Vector3(1.15, 0, 0.12), "r_fore": Vector3(0.1, 0, 0),
					"chest": Vector3(0, -0.55, 0), "spine": Vector3(-0.25, 0, 0),
					"l_leg": Vector3(0.4, 0, 0), "l_shin": Vector3(-0.4, 0, 0)})],
			[0.7, _with(STANCE, {"r_arm": Vector3(0.95, 0, 0.12), "chest": Vector3(0, -0.4, 0),
					"spine": Vector3(-0.18, 0, 0)})],
			[1.0, STANCE],
		]},
		"heavy_attack": {"length": 1.0, "loop": false, "keys": [
			[0.0, STANCE],
			[0.4, _with(STANCE, {"r_arm": Vector3(-2.8, 0, 0.1), "l_arm": Vector3(-2.7, 0, -0.1),
					"r_fore": Vector3(0.3, 0, 0), "l_fore": Vector3(0.3, 0, 0),
					"spine": Vector3(0.2, 0, 0), "hips_y": 0.02})],
			[0.56, _with(STANCE, {"r_arm": Vector3(0.9, 0, 0.05), "l_arm": Vector3(0.9, 0, -0.05),
					"r_fore": Vector3(0.1, 0, 0), "l_fore": Vector3(0.1, 0, 0),
					"spine": Vector3(-0.5, 0, 0), "hips_y": -0.14,
					"l_leg": Vector3(0.6, 0, 0), "l_shin": Vector3(-0.8, 0, 0),
					"r_leg": Vector3(-0.3, 0, 0), "r_shin": Vector3(-0.5, 0, 0)})],
			[0.8, _with(STANCE, {"r_arm": Vector3(0.8, 0, 0.05), "l_arm": Vector3(0.8, 0, -0.05),
					"spine": Vector3(-0.42, 0, 0), "hips_y": -0.12})],
			[1.0, STANCE],
		]},
		"dodge": {"length": 1.0, "loop": false, "keys": [
			[0.0, STANCE],
			[0.2, _with(STANCE, {"hips_y": -0.26, "spine": Vector3(-0.65, 0, 0),
					"l_leg": Vector3(0.95, 0, 0), "l_shin": Vector3(-1.45, 0, 0),
					"r_leg": Vector3(0.55, 0, 0), "r_shin": Vector3(-1.25, 0, 0),
					"l_arm": Vector3(0.9, 0, -0.1), "r_arm": Vector3(0.9, 0, 0.1),
					"l_fore": Vector3(1.6, 0, 0), "r_fore": Vector3(1.6, 0, 0),
					"head": Vector3(0.35, 0, 0), "l_ear": Vector3(0.6, 0, 0), "r_ear": Vector3(0.6, 0, 0)})],
			[0.7, _with(STANCE, {"hips_y": -0.2, "spine": Vector3(-0.45, 0, 0),
					"l_leg": Vector3(0.6, 0, 0), "l_shin": Vector3(-1.0, 0, 0),
					"r_leg": Vector3(0.3, 0, 0), "r_shin": Vector3(-0.9, 0, 0)})],
			[1.0, STANCE],
		]},
		"block": {"length": 0.14, "loop": false, "keys": [
			[0.0, STANCE],
			[0.14, _with(STANCE, {"hips_y": -0.08, "spine": Vector3(-0.12, 0, 0),
					"l_arm": Vector3(1.35, 0, 0.55), "l_fore": Vector3(1.25, 0, 0),
					"r_arm": Vector3(1.25, 0, -0.45), "r_fore": Vector3(1.3, 0, 0),
					"head": Vector3(0.15, 0, 0), "l_leg": Vector3(0.3, 0, 0), "l_shin": Vector3(-0.45, 0, 0)})],
		]},
		"hit": {"length": 0.36, "loop": false, "keys": [
			[0.0, STANCE],
			[0.07, _with(STANCE, {"spine": Vector3(0.35, 0, 0.1), "head": Vector3(0.35, 0, 0),
					"l_arm": Vector3(0.1, 0, -0.6), "r_arm": Vector3(0.1, 0, 0.6),
					"l_ear": Vector3(-0.4, 0, 0), "r_ear": Vector3(-0.4, 0, 0)})],
			[0.36, STANCE],
		]},
		"stagger": {"length": 1.0, "loop": false, "keys": [
			[0.0, STANCE],
			[0.15, _with(STANCE, {"spine": Vector3(0.45, 0, 0.28), "head": Vector3(0.3, 0.3, 0),
					"l_arm": Vector3(-0.4, 0, -1.0), "r_arm": Vector3(-0.3, 0, 1.1), "hips_y": -0.06})],
			[0.45, _with(STANCE, {"spine": Vector3(0.3, 0, -0.25), "head": Vector3(0.2, -0.3, 0),
					"l_arm": Vector3(0.2, 0, -0.8), "r_arm": Vector3(0.1, 0, 0.7), "hips_y": -0.1})],
			[0.75, _with(STANCE, {"spine": Vector3(0.15, 0, 0.12), "hips_y": -0.07})],
			[1.0, STANCE],
		]},
		"knocked_out": {"length": 1.2, "loop": false, "keys": [
			[0.0, STANCE],
			[0.35, _with(STANCE, {"hips_y": -0.32, "spine": Vector3(0.5, 0, 0),
					"l_shin": Vector3(-1.2, 0, 0), "r_shin": Vector3(-1.2, 0, 0),
					"l_leg": Vector3(0.9, 0, 0), "r_leg": Vector3(0.9, 0, 0)})],
			[1.0, _knocked_out_pose()],
			[1.2, _knocked_out_pose()],
		]},
		"recover": {"length": 1.2, "loop": false, "keys": [
			[0.0, _knocked_out_pose()],
			[0.6, _with(STANCE, {"hips_y": -0.4, "spine": Vector3(-0.6, 0, 0),
					"l_leg": Vector3(1.4, 0, 0), "l_shin": Vector3(-2.0, 0, 0),
					"r_leg": Vector3(1.2, 0, 0), "r_shin": Vector3(-1.8, 0, 0),
					"l_arm": Vector3(0.8, 0, 0), "r_arm": Vector3(0.8, 0, 0)})],
			[1.2, STANCE],
		]},
		"cast": {"length": 1.0, "loop": false, "keys": [
			[0.0, STANCE],
			[0.35, _with(STANCE, {"r_arm": Vector3(0.3, 0, 0.9), "l_arm": Vector3(0.3, 0, -0.9),
					"r_fore": Vector3(1.4, 0, 0), "l_fore": Vector3(1.4, 0, 0),
					"spine": Vector3(0.1, 0, 0), "head": Vector3(-0.15, 0, 0)})],
			[0.6, _with(STANCE, {"r_arm": Vector3(1.55, 0, 0.05), "r_fore": Vector3(0.05, 0, 0),
					"l_arm": Vector3(1.3, 0, -0.25), "l_fore": Vector3(0.2, 0, 0),
					"spine": Vector3(-0.15, 0, 0), "chest": Vector3(0, -0.2, 0)})],
			[0.85, _with(STANCE, {"r_arm": Vector3(1.45, 0, 0.05), "l_arm": Vector3(1.2, 0, -0.25)})],
			[1.0, STANCE],
		]},
		"victory": {"length": 1.2, "loop": true, "keys": [
			[0.0, _with(RELAXED, {"l_arm": Vector3(0, 0, -2.6), "r_arm": Vector3(0, 0, 2.6),
					"tail": Vector3(-0.8, -0.5, 0), "head": Vector3(-0.2, 0, 0)})],
			[0.3, _with(RELAXED, {"l_arm": Vector3(0, 0, -2.8), "r_arm": Vector3(0, 0, 2.8),
					"tail": Vector3(-0.8, 0.5, 0), "hips_y": 0.06, "head": Vector3(-0.25, 0, 0)})],
			[0.6, _with(RELAXED, {"l_arm": Vector3(0, 0, -2.6), "r_arm": Vector3(0, 0, 2.6),
					"tail": Vector3(-0.8, -0.5, 0), "head": Vector3(-0.2, 0, 0)})],
			[0.9, _with(RELAXED, {"l_arm": Vector3(0, 0, -2.8), "r_arm": Vector3(0, 0, 2.8),
					"tail": Vector3(-0.8, 0.5, 0), "hips_y": 0.06})],
			[1.2, _with(RELAXED, {"l_arm": Vector3(0, 0, -2.6), "r_arm": Vector3(0, 0, 2.6),
					"tail": Vector3(-0.8, -0.5, 0), "head": Vector3(-0.2, 0, 0)})],
		]},
		"exhausted": {"length": 1.4, "loop": true, "keys": [
			[0.0, _with(STANCE, {"spine": Vector3(-0.45, 0, 0), "head": Vector3(0.3, 0, 0), "hips_y": -0.1,
					"l_arm": Vector3(0.6, 0, 0), "r_arm": Vector3(0.6, 0, 0),
					"l_fore": Vector3(0.3, 0, 0), "r_fore": Vector3(0.3, 0, 0),
					"l_ear": Vector3(0.5, 0, 0), "r_ear": Vector3(0.5, 0, 0), "tail": Vector3(1.4, 0, 0)})],
			[0.7, _with(STANCE, {"spine": Vector3(-0.38, 0, 0), "head": Vector3(0.22, 0, 0), "hips_y": -0.08,
					"l_arm": Vector3(0.6, 0, 0), "r_arm": Vector3(0.6, 0, 0),
					"l_ear": Vector3(0.5, 0, 0), "r_ear": Vector3(0.5, 0, 0), "tail": Vector3(1.4, 0, 0)})],
			[1.4, _with(STANCE, {"spine": Vector3(-0.45, 0, 0), "head": Vector3(0.3, 0, 0), "hips_y": -0.1,
					"l_arm": Vector3(0.6, 0, 0), "r_arm": Vector3(0.6, 0, 0),
					"l_fore": Vector3(0.3, 0, 0), "r_fore": Vector3(0.3, 0, 0),
					"l_ear": Vector3(0.5, 0, 0), "r_ear": Vector3(0.5, 0, 0), "tail": Vector3(1.4, 0, 0)})],
		]},
	}


static func _knocked_out_pose() -> Dictionary:
	return {
		"hips": Vector3(1.45, 0, 0), "hips_y": -0.66,
		"spine": Vector3(0.1, 0, 0), "head": Vector3(0.2, 0.5, 0),
		"l_arm": Vector3(-0.3, 0, -1.2), "r_arm": Vector3(-0.2, 0, 1.3),
		"l_fore": Vector3(0.4, 0, 0), "r_fore": Vector3(0.2, 0, 0),
		"l_leg": Vector3(0.3, 0, -0.2), "r_leg": Vector3(0.5, 0, 0.15),
		"l_shin": Vector3(-0.5, 0, 0), "r_shin": Vector3(-0.3, 0, 0),
		"l_ear": Vector3(0.6, 0, 0), "r_ear": Vector3(0.6, 0, 0), "tail": Vector3(1.4, 0, 0),
	}


## Locomotion cycle: four keys per stride, mirrored halfway.
static func _cycle(leg: float, arm: float, bob: float, lean: float, fore: float) -> Array:
	var contact_a := {
		"l_leg": Vector3(leg, 0, 0), "l_shin": Vector3(-0.1, 0, 0),
		"r_leg": Vector3(-leg * 0.85, 0, 0), "r_shin": Vector3(-0.45, 0, 0),
		"l_arm": Vector3(-arm, 0, -0.12), "r_arm": Vector3(arm, 0, 0.12),
		"l_fore": Vector3(fore + 0.15, 0, 0), "r_fore": Vector3(fore + 0.15, 0, 0),
		"spine": Vector3(lean, 0, 0), "chest": Vector3(0, -0.12, 0), "hips_y": 0.0,
		"tail": Vector3(-0.6, 0.25, 0),
	}
	var pass_a := {
		"l_leg": Vector3(0.0, 0, 0), "l_shin": Vector3(-0.15, 0, 0),
		"r_leg": Vector3(0.15, 0, 0), "r_shin": Vector3(-leg * 1.6, 0, 0),
		"l_arm": Vector3(0, 0, -0.12), "r_arm": Vector3(0, 0, 0.12),
		"l_fore": Vector3(fore + 0.15, 0, 0), "r_fore": Vector3(fore + 0.15, 0, 0),
		"spine": Vector3(lean, 0, 0), "hips_y": bob, "tail": Vector3(-0.6, 0, 0),
	}
	var contact_b := _mirror(contact_a)
	var pass_b := _mirror(pass_a)
	return [[0.0, contact_a], [0.25, pass_a], [0.5, contact_b], [0.75, pass_b], [1.0, contact_a]]


static func _mirror(pose: Dictionary) -> Dictionary:
	var result := {}
	for key: String in pose:
		var target := key
		if key.begins_with("l_"):
			target = "r_" + key.substr(2)
		elif key.begins_with("r_"):
			target = "l_" + key.substr(2)
		var value: Variant = pose[key]
		if value is Vector3:
			var v: Vector3 = value
			# Sideways (z) and twist (y) components flip when mirrored.
			value = Vector3(v.x, -v.y, -v.z)
		result[target] = value
	return result


static func _with(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := base.duplicate()
	result.merge(overrides, true)
	return result


## Converts keyframes into value tracks. Every clip animates every bone so that
## switching clips never leaves a limb in the previous clip's pose; bones
## missing from a key use the rest pose.
static func _build(clip: Dictionary, hip_height: float) -> Animation:
	var animation := Animation.new()
	var length: float = clip["length"]
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if clip["loop"] else Animation.LOOP_NONE
	var keys: Array = clip["keys"]
	for bone: String in BONES:
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(BONES[bone] + ":rotation"))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
		for key: Array in keys:
			var pose: Dictionary = key[1]
			animation.track_insert_key(track, key[0], pose.get(bone, Vector3.ZERO))
	var hips_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(hips_track, NodePath(BONES["hips"] + ":position:y"))
	animation.track_set_interpolation_type(hips_track, Animation.INTERPOLATION_CUBIC)
	animation.value_track_set_update_mode(hips_track, Animation.UPDATE_CONTINUOUS)
	for key: Array in keys:
		var pose: Dictionary = key[1]
		animation.track_insert_key(hips_track, key[0], hip_height + float(pose.get("hips_y", 0.0)))
	return animation
