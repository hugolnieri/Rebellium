extends GutTest
## Personagem: modelo com esqueleto carregado, ossos movidos pelas molas, arma na mão e piscar.

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


func test_skeleton_has_all_joints() -> void:
	var skeleton := _skeleton()
	for joint in CharacterModel.JOINTS:
		if joint != &"lean":
			assert_true(skeleton.find_bone(CharacterModel.BONE_MAP[joint]) >= 0, "osso %s" % joint)


func test_weapon_socket_follows_right_hand() -> void:
	_animate(10)
	# O esqueleto e os BoneAttachment3D atualizam no quadro seguinte.
	await get_tree().process_frame
	await get_tree().process_frame
	var skeleton := _skeleton()
	var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(CharacterModel.BONE_MAP[&"wrist_r"]))
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
	_animate(40, FWD)
	var skeleton := _skeleton()
	var thigh_l := skeleton.get_bone_pose_rotation(skeleton.find_bone(CharacterModel.BONE_MAP[&"thigh_l"]))
	var thigh_r := skeleton.get_bone_pose_rotation(skeleton.find_bone(CharacterModel.BONE_MAP[&"thigh_r"]))
	assert_gt(thigh_l.angle_to(thigh_r), 0.2, "pernas em fases opostas")
