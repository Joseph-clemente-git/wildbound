extends TestCase
## Character pipeline: the procedural rig provides every required clip, and
## an imported (Blender-style) rig is adapted through GltfCharacterVisual.


func test_procedural_rig_has_all_required_clips_and_bones() -> void:
	var dog := ProceduralDogVisual.new()
	check_eq(dog.missing_clips().size(), 0, "missing: %s" % [dog.missing_clips()])
	for key: String in CharacterAnimations.BONES:
		check(dog.has_node(CharacterAnimations.BONES[key]), "bone pivot " + key)
	check(dog.right_hand != null and dog.left_hand != null)
	dog.set_weapon("hammer")
	dog.set_armor(GameEnums.ArmorWeight.HEAVY)
	dog.set_aura("fire")
	check(dog.aura_light.visible)
	dog.free()


func test_clips_cover_their_bones_every_frame() -> void:
	var library := CharacterAnimations.build_library(ProceduralDogVisual.HIP_HEIGHT)
	for clip in CharacterAnimations.REQUIRED_CLIPS:
		var animation := library.get_animation(clip)
		check(animation != null, clip)
		check_eq(animation.get_track_count(), CharacterAnimations.BONES.size() + 1, clip + " animates every bone")


## Builds what a Blender export typically looks like after import.
func _fake_import(clip_names: Array) -> Node3D:
	var scene := Node3D.new()
	scene.name = "HumanoidDog"
	var armature := Node3D.new()
	armature.name = "Armature"
	scene.add_child(armature)
	var skeleton := Skeleton3D.new()
	for bone in ["Root", "Hips", "Spine", "Chest", "Neck", "Head", "LeftArm", "RightArm", "RightHand", "LeftLeg", "RightLeg", "Tail"]:
		skeleton.add_bone(bone)
	armature.add_child(skeleton)
	var heavy := MeshInstance3D.new()
	heavy.name = "Armor_Heavy"
	armature.add_child(heavy)
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	for clip_name: String in clip_names:
		var animation := Animation.new()
		animation.length = 1.0
		library.add_animation(clip_name, animation)
	player.add_animation_library("", library)
	scene.add_child(player)
	return scene


func test_imported_rig_maps_blender_clip_names() -> void:
	var names := ["Idle", "Walk", "Run", "Attack", "HeavyAttack", "Dodge", "Block", "Hit", "Stagger", "Knocked Out", "Recover"]
	var visual := GltfCharacterVisual.new(_fake_import(names))
	root.add_child(visual)
	check_eq(visual.missing_clips().size(), 0, "missing: %s" % [visual.missing_clips()])
	check_eq(visual.resolve_clip("heavy_attack"), "HeavyAttack")
	check_eq(visual.resolve_clip("knocked_out"), "Knocked Out")
	check_eq(visual.resolve_clip("combat_idle"), "Idle", "optional clips fall back")
	visual.play("heavy_attack", 0.5)
	check_eq(visual.current_clip(), "HeavyAttack")
	visual.set_weapon("sword")
	check(visual.skeleton.get_child_count() > 0, "weapon attaches to the hand bone")
	visual.set_armor(GameEnums.ArmorWeight.HEAVY)
	check(visual.model.find_child("Armor_Heavy", true, false).visible)
	check_near(visual.model.rotation.y, PI, 0.001, "faces Godot's -Z")
	visual.free()


func test_incomplete_rig_reports_missing_clips() -> void:
	var visual := GltfCharacterVisual.new(_fake_import(["Idle", "Walk"]))
	var missing := visual.missing_clips()
	check(missing.has("attack") and missing.has("dodge"))
	visual.free()


func test_factory_uses_model_scene_when_present() -> void:
	var animal := Content.animal("humanoid_dog").duplicate() as AnimalData
	check(CharacterFactory.create(animal) is ProceduralDogVisual)
	var packed := PackedScene.new()
	var scene := _fake_import(["Idle"])
	for child in scene.get_children():
		child.owner = scene
		for grandchild in child.get_children():
			grandchild.owner = scene
	packed.pack(scene)
	animal.model_scene = packed
	var visual := CharacterFactory.create(animal)
	check(visual is GltfCharacterVisual)
	visual.free()
	scene.free()


func test_people_share_the_humanoid_rig() -> void:
	for look: Dictionary in [{}, ProceduralHumanVisual.ELDER, {"hair_style": "long", "robe": true},
			{"hair_style": "bun"}, {"hair_style": "hood"}, {"hair_style": "bald", "beard": true}]:
		var person := ProceduralHumanVisual.new(look)
		check_eq(person.missing_clips().size(), 0, "person plays every shared clip")
		for key: String in CharacterAnimations.BONES:
			check(person.has_node(CharacterAnimations.BONES[key]), "person pivot " + key)
		check(person.find_child("Snout", true, false) == null, "people have no snout")
		person.set_weapon("staff")
		person.play("cast", 0.6)
		person.free()
	var elder := ProceduralHumanVisual.new(ProceduralHumanVisual.ELDER)
	check(elder.find_child("Beard", true, false) != null, "the old owner has a beard")
	check(elder.find_child("Robe", true, false) != null)
	elder.free()


func test_every_mentor_is_a_person() -> void:
	for trainer: TrainerData in Content.list("trainers"):
		check(trainer.appearance.get("skin") is Color, trainer.id + " has a human appearance")
		check(not trainer.appearance.has("fur"), trainer.id + " is not an animal")
	check(StoryEvents.OWNER_APPEARANCE.get("beard", false), "Old Marten is bearded")
