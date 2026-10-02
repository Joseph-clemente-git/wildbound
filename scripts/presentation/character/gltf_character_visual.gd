class_name GltfCharacterVisual
extends CharacterVisual
## A champion body imported from Blender (glTF/.blend) — see
## docs/ASSET_PIPELINE.md. Clip names are matched loosely ("HeavyAttack",
## "heavy-attack" and "heavy_attack" all resolve), weapons attach to the hand
## bone, and optional armor meshes are toggled by name.

const HAND_BONES: Array[String] = ["RightHand", "hand.R", "Hand.R", "mixamorig:RightHand"]
const ARMOR_MESHES: Array[String] = ["Armor_Light", "Armor_Medium", "Armor_Heavy"]
## Fallbacks when a rig lacks an optional clip.
const FALLBACKS := {"combat_idle": "idle", "exhausted": "idle", "cast": "attack", "victory": "idle"}

var model: Node3D
var skeleton: Skeleton3D
var _aliases: Dictionary = {}  # normalized name -> actual animation name
var _hand: Node3D
var _aura: OmniLight3D


## `face_minus_z`: glTF characters face +Z; combat expects -Z forward.
func _init(imported: Node3D, face_minus_z: bool = true) -> void:
	model = imported
	if face_minus_z:
		model.rotation.y = PI
	add_child(model)
	animation_player = _find(model, "AnimationPlayer") as AnimationPlayer
	skeleton = _find(model, "Skeleton3D") as Skeleton3D
	if animation_player != null:
		for clip_name in animation_player.get_animation_list():
			_aliases[_normalize(clip_name)] = clip_name
		animation_player.animation_finished.connect(_on_animation_finished)
	_collect_materials(model)
	_hand = _make_hand_attachment()
	_aura = OmniLight3D.new()
	_aura.position = Vector3(0, 1.1, -0.2)
	_aura.omni_range = 2.2
	_aura.visible = false
	add_child(_aura)
	if has_clip("idle"):
		play("idle", -1.0, false)


func resolve_clip(clip: String) -> String:
	var key := _normalize(clip)
	if _aliases.has(key):
		return _aliases[key]
	if FALLBACKS.has(clip):
		return resolve_clip(FALLBACKS[clip])
	return ""


func set_weapon(new_weapon_type: String) -> void:
	weapon_type = new_weapon_type
	if _hand == null:
		return
	for child in _hand.get_children():
		child.queue_free()
	if not new_weapon_type.is_empty():
		_hand.add_child(WeaponVisuals.build(new_weapon_type))


func set_armor(weight: int) -> void:
	armor_weight = weight
	for i in ARMOR_MESHES.size():
		var mesh := model.find_child(ARMOR_MESHES[i], true, false) as Node3D
		if mesh != null:
			mesh.visible = i == weight


func set_aura(school: String) -> void:
	aura_school = school
	_aura.visible = not school.is_empty()
	if _aura.visible:
		_aura.light_color = MagicVisuals.school_color(school)


static func _normalize(clip_name: String) -> String:
	var text := clip_name.get_slice("/", clip_name.get_slice_count("/") - 1)  # drop library prefix
	return text.to_snake_case().replace("-", "_").replace(" ", "_").to_lower()


func _make_hand_attachment() -> Node3D:
	if skeleton == null:
		return null
	for bone_name in HAND_BONES:
		if skeleton.find_bone(bone_name) != -1:
			var attachment := BoneAttachment3D.new()
			attachment.bone_name = bone_name
			skeleton.add_child(attachment)
			return attachment
	return null


func _collect_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.get_surface_override_material_count():
			var material := mesh_instance.get_active_material(i)
			if material is StandardMaterial3D:
				var unique := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
				mesh_instance.set_surface_override_material(i, unique)
				_flash_materials.append(unique)
	for child in node.get_children():
		_collect_materials(child)


static func _find(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find(child, type_name)
		if found != null:
			return found
	return null
