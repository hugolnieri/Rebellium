extends GutTest
## Personagem: modelo com esqueleto, clipes do Blender tocados nos ossos, arma na mão e piscar.

const Driver = preload("res://tests/helpers/player_driver.gd")

const FWD := Vector2(0, 1)

var d: Driver


func before_each() -> void:
	d = Driver.new()
	d.setup(self, Vector3(0, 0.05, 0))
	d.add_block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	await d.ready_physics(self)
	d.step(20)


func _animate(frames: int, move: Vector2 = Vector2.ZERO) -> void:
	for i in frames:
		d.step(1, move)
		d.player.model._process(1.0 / 60.0)


func _skeleton() -> Skeleton3D:
	return d.player.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D


func test_clips_animate_body_bones_but_not_root_or_hair() -> void:
	var skeleton := _skeleton()
	var names := Array(HeroClips.bones).map(func(b: int) -> String: return skeleton.get_bone_name(b))
	for bone_name in ["J_Bip_C_Hips", "J_Bip_C_Spine", "J_Bip_L_UpperLeg", "J_Bip_R_LowerLeg", "J_Bip_R_Hand",
			"J_Bip_L_ToeBase", "J_Bip_R_Index1"]:
		assert_has(names, bone_name)
	assert_does_not_have(names, "Root", "o Root é só prévia no Blender")
	assert_false(names.any(func(n: String) -> bool: return n.begins_with("HairJoint")), "cabelo fica com a mola")


func test_weapon_socket_follows_right_hand() -> void:
	_animate(10)
	# O esqueleto e os BoneAttachment3D atualizam no quadro seguinte.
	await get_tree().process_frame
	await get_tree().process_frame
	var skeleton := _skeleton()
	var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(CharacterModel.RIGHT_HAND_BONE))
	var weapon: Node3D = d.player.model.weapon_visual
	assert_not_null(weapon)
	assert_lt(weapon.global_position.distance_to(wrist.origin), 0.1)


func test_blinks_over_time() -> void:
	var model: CharacterModel = d.player.model
	var face := model.find_children("Face", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var closed := 0.0
	for i in 360:
		model._process(1.0 / 60.0)
		closed = maxf(closed, face.get_blend_shape_value(model._blink_shape))
	assert_gt(closed, 0.5, "pisca em 6 s")


func test_running_swings_the_leg_bones() -> void:
	_animate(30, FWD)
	var skeleton := _skeleton()
	var thigh_l := skeleton.find_bone("J_Bip_L_UpperLeg")
	var thigh_r := skeleton.find_bone("J_Bip_R_UpperLeg")
	var widest := 0.0
	for i in 40:
		_animate(1, FWD)
		widest = maxf(widest, skeleton.get_bone_pose_rotation(thigh_l).angle_to(
			skeleton.get_bone_pose_rotation(thigh_r)))
	assert_gt(widest, 0.4, "pernas em fases opostas ao longo da passada")


func _slot(bone_name: String) -> int:
	return HeroClips.bones.find(_skeleton().find_bone(bone_name))


func test_blender_clips_are_loaded() -> void:
	for clip in [&"idle", &"walk", &"sprint", &"air", &"air_sprint", &"jump_flip", &"wall_stick", &"wall_flip",
			&"roll", &"cartwheel", &"dash", &"land", &"hurt", &"sword_rest", &"atk_slash_r", &"atk_spin",
			&"atk_air_slam"]:
		assert_true(HeroClips.has_clip(clip), "clipe %s no hero.glb" % clip)


func test_walk_clip_alternates_legs() -> void:
	var l := _slot("J_Bip_L_UpperLeg")
	var r := _slot("J_Bip_R_UpperLeg")
	var a := HeroClips.sample(&"walk", 0.0, true)
	var b := HeroClips.sample(&"walk", 0.5, true)
	assert_gt((a[l] as Quaternion).angle_to(b[l]), 0.6, "a coxa esquerda vai da frente para trás")
	assert_almost_eq((a[l] as Quaternion).get_angle(), (b[r] as Quaternion).get_angle(), 0.05,
		"meio ciclo depois a direita repete a esquerda")


func test_walk_bobs_the_hips() -> void:
	var n := HeroClips.bones.size()
	var low := INF
	var high := -INF
	for i in 20:
		var y: float = (HeroClips.sample(&"walk", i / 20.0, true)[n] as Vector3).y
		low = minf(low, y)
		high = maxf(high, y)
	assert_gt(high - low, 0.08, "sobe e desce a cada passo (pulinho)")


func test_sword_rest_only_changes_right_arm_in_game() -> void:
	var model: CharacterModel = d.player.model
	var arm := _slot("J_Bip_R_LowerArm")
	var leg := _slot("J_Bip_L_UpperLeg")
	assert_gt(model._sword_arm_weights[arm], 0.0)
	assert_eq(model._sword_arm_weights[leg], 0.0)


func test_state_change_crossfades_instead_of_snapping() -> void:
	_animate(30)
	var skeleton := _skeleton()
	var thigh := skeleton.find_bone("J_Bip_L_UpperLeg")
	var before := skeleton.get_bone_pose_rotation(thigh)
	d.press_jump()
	_animate(1)
	var after := skeleton.get_bone_pose_rotation(thigh)
	var target: Quaternion = HeroClips.sample(&"air", 0.0)[_slot("J_Bip_L_UpperLeg")]
	assert_lt(before.angle_to(after), before.angle_to(target), "primeiro quadro do pulo ainda está misturando")
