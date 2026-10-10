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
	_animate(30, FWD)
	var skeleton := _skeleton()
	var thigh_l := skeleton.find_bone(CharacterModel.BONE_MAP[&"thigh_l"])
	var thigh_r := skeleton.find_bone(CharacterModel.BONE_MAP[&"thigh_r"])
	var widest := 0.0
	for i in 40:
		_animate(1, FWD)
		widest = maxf(widest, skeleton.get_bone_pose_rotation(thigh_l).angle_to(
			skeleton.get_bone_pose_rotation(thigh_r)))
	assert_gt(widest, 0.4, "pernas em fases opostas ao longo da passada")


func _near(a: Vector3, b: Vector3, msg: String, tolerance: float = 0.02) -> void:
	assert_lt(a.distance_to(b), tolerance, "%s: %s ≈ %s" % [msg, a, b])


func test_blender_clips_are_loaded() -> void:
	for clip in [&"idle", &"walk", &"sprint", &"air", &"air_sprint", &"jump_flip", &"wall_stick", &"wall_flip",
			&"roll", &"cartwheel", &"hurt", &"sword_rest", &"atk_slash_r", &"atk_spin", &"atk_air_slam"]:
		assert_true(HeroClips.has_clip(clip), "clipe %s no hero.glb" % clip)


## As poses escritas em tools/blender/hero_animations.py voltam iguais (ida ao Blender e volta).
func test_blender_clips_round_trip_reference_angles() -> void:
	var stick := HeroClips.sample(&"wall_stick", 0.0)
	_near(stick[&"thigh_l"], Vector3(1.75, 0, 0.1), "wall_stick coxa")
	assert_almost_eq((stick[&"hips_y"] as Vector3).x, -0.28, 0.01, "wall_stick quadril baixo")
	var rest := HeroClips.sample(&"sword_rest", 0.0)
	_near(rest[&"shoulder_r"], Vector3(0.25, 0.07, 0.1), "sword_rest ombro")
	_near(rest[&"wrist_r"], Vector3(1.1, -0.1, -0.39), "sword_rest pulso")
	# Braço acima da cabeça (x > 90°): o Euler escolhido continua o autorado, sem trocar de ramo.
	var slam := HeroClips.sample(&"atk_air_slam", CharacterModel.ATTACK_KEYS[0])
	_near(slam[&"shoulder_r"], Vector3(3.0, 0, 0.1), "air_slam ombro")


func test_walk_clip_alternates_legs() -> void:
	var a := HeroClips.sample(&"walk", 0.0, true)
	var b := HeroClips.sample(&"walk", 0.5, true)
	_near(a[&"thigh_l"], b[&"thigh_r"], "meio ciclo depois a perna direita repete a esquerda", 0.05)
