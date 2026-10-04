class_name CharacterModel
extends Node3D
## Personagem greybox montado com primitivas e animado proceduralmente.
## Só apresentação: lê o estado do Player e nunca altera gameplay.
## Frente do modelo = -Z. Pés em y = 0, altura de referência 1,8 m (escala pela config).

const REFERENCE_HEIGHT: float = 1.8
const HIP_HEIGHT: float = 0.95
const THIGH_LENGTH: float = 0.44
const SHIN_LENGTH: float = 0.44
const UPPER_ARM_LENGTH: float = 0.3
const FOREARM_LENGTH: float = 0.28
const VISOR_IDLE_ENERGY: float = 0.25

var player: Player

var _hips: Node3D
var _spine: Node3D
var _head: Node3D
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _feet: Array[Node3D] = []
var _sash: Node3D
var _trick_pivot: Node3D
var _meshes: Array[MeshInstance3D] = []
var _visor_material: StandardMaterial3D
var _flash_material: StandardMaterial3D

var _phase: float = 0.0
var _time: float = 0.0
var _run_amount: float = 0.0
var _land_timer: float = 0.0
var _land_strength: float = 0.0
var _trick_timer: float = 0.0
var _trick_axis: Vector3 = Vector3.RIGHT
var _trick_angle: float = 0.0
var _flash_timer: float = 0.0
var _flash_duration: float = 0.0
var _flash_energy: float = 0.0
var _flash_color: Color = Color.WHITE
var _pose: Dictionary = {}


func _ready() -> void:
	player = get_parent().get_parent() as Player
	_build()
	GameEvents.wall_jump_executed.connect(_on_wall_jump)
	GameEvents.landed.connect(_on_landed)


func _fb() -> FeedbackConfig:
	return player.feedback_config


# --- Montagem ------------------------------------------------------------------

func _build() -> void:
	var fb := _fb()
	var suit := _material(fb.color_dark_grey, 0.85, 0.0)
	var armor := _material(fb.color_dirty_white, 0.6, 0.0)
	var metal := _material(fb.color_metal, 0.35, 0.7)
	var dark := _material(fb.color_base_black, 0.4, 0.2)
	_visor_material = _material(fb.color_base_black, 0.15, 0.4)
	_visor_material.emission_enabled = true
	_visor_material.emission = fb.color_dirty_white
	_visor_material.emission_energy_multiplier = VISOR_IDLE_ENERGY

	_trick_pivot = _joint(self, Vector3(0, HIP_HEIGHT, 0))
	_hips = _joint(_trick_pivot, Vector3.ZERO)
	_cylinder(_hips, 0.15, 0.16, 0.2, Vector3(0, -0.02, 0), 0.75, suit)
	_box(_hips, Vector3(0.36, 0.05, 0.24), Vector3(0, 0.05, 0), metal)  # cinto

	_spine = _joint(_hips, Vector3(0, 0.08, 0))
	# Tronco em V: cilindro achatado, mais largo nos ombros.
	_cylinder(_spine, 0.21, 0.14, 0.5, Vector3(0, 0.26, 0), 0.62, suit)
	_box(_spine, Vector3(0.3, 0.2, 0.07), Vector3(0, 0.36, -0.1), armor)  # peitoral
	_box(_spine, Vector3(0.24, 0.24, 0.06), Vector3(0, 0.33, 0.1), armor)  # placa das costas
	_box(_spine, Vector3(0.12, 0.06, 0.12), Vector3(0, 0.53, 0), dark)  # pescoço

	_head = _joint(_spine, Vector3(0, 0.56, 0))
	_sphere(_head, 0.135, Vector3(0, 0.14, 0), armor)  # capacete
	_box(_head, Vector3(0.04, 0.04, 0.26), Vector3(0, 0.255, 0.0), metal)  # crista
	var visor := _box(_head, Vector3(0.22, 0.06, 0.08), Vector3(0, 0.15, -0.1), dark)
	visor.material_override = _visor_material

	for side: float in [-1.0, 1.0]:
		var shoulder := _joint(_spine, Vector3(0.25 * side, 0.46, 0))
		_box(shoulder, Vector3(0.17, 0.11, 0.2), Vector3(0.03 * side, 0.03, 0), metal)
		_capsule(shoulder, 0.068, UPPER_ARM_LENGTH, Vector3(0, -UPPER_ARM_LENGTH * 0.5, 0), suit)
		var elbow := _joint(shoulder, Vector3(0, -UPPER_ARM_LENGTH, 0))
		_capsule(elbow, 0.062, FOREARM_LENGTH, Vector3(0, -FOREARM_LENGTH * 0.5, 0), armor)
		_sphere(elbow, 0.055, Vector3(0, -FOREARM_LENGTH - 0.04, 0), dark)  # punho
		_shoulders.append(shoulder)
		_elbows.append(elbow)

		var thigh := _joint(_hips, Vector3(0.11 * side, -0.04, 0))
		_capsule(thigh, 0.098, THIGH_LENGTH, Vector3(0, -THIGH_LENGTH * 0.5, 0), suit)
		var knee := _joint(thigh, Vector3(0, -THIGH_LENGTH, 0))
		_box(knee, Vector3(0.11, 0.1, 0.06), Vector3(0, 0, -0.07), metal)  # joelheira
		_capsule(knee, 0.08, SHIN_LENGTH, Vector3(0, -SHIN_LENGTH * 0.5, 0), armor)
		var foot := _joint(knee, Vector3(0, -SHIN_LENGTH, 0))
		_box(foot, Vector3(0.12, 0.08, 0.25), Vector3(0, -0.035, -0.05), dark)
		_thighs.append(thigh)
		_knees.append(knee)
		_feet.append(foot)

	# Faixa de tecido nas costas: deixa a velocidade e a direção legíveis.
	_sash = _joint(_spine, Vector3(0, 0.02, 0.13))
	_box(_sash, Vector3(0.1, 0.45, 0.02), Vector3(0, -0.22, 0.01), suit)


func _joint(parent: Node3D, offset: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = offset
	parent.add_child(node)
	return node


func _box(parent: Node3D, size: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, offset, material)


func _sphere(parent: Node3D, radius: float, offset: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _mesh(parent, mesh, offset, material)


## Cilindro (com topo/base de raios diferentes) achatado em Z por `depth_scale`.
func _cylinder(parent: Node3D, top: float, bottom: float, height: float, offset: Vector3,
		depth_scale: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	var instance := _mesh(parent, mesh, offset, material)
	instance.scale = Vector3(1.0, 1.0, depth_scale)
	return instance


func _capsule(parent: Node3D, radius: float, length: float, offset: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 4
	return _mesh(parent, mesh, offset, material)


func _mesh(parent: Node3D, mesh: Mesh, offset: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	instance.material_override = material
	parent.add_child(instance)
	_meshes.append(instance)
	return instance


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


## Ajusta a escala do modelo à altura da cápsula da config.
func apply_body_height(height: float) -> void:
	scale = Vector3.ONE * (height / REFERENCE_HEIGHT)


# --- Feedback ------------------------------------------------------------------

## Brilho na cor da técnica (visor + todo o corpo).
func flash(color: Color, duration: float, energy: float) -> void:
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.albedo_color = Color(0, 0, 0)
		_flash_material.emission_enabled = true
	_flash_color = color
	_flash_duration = maxf(duration, 0.001)
	_flash_timer = duration
	_flash_energy = energy
	for mesh in _meshes:
		mesh.material_overlay = _flash_material


func _on_wall_jump(who: Node, data: Dictionary) -> void:
	if who != player:
		return
	var technique: StringName = data.get("technique", MovementRules.TECH_NORMAL)
	match technique:
		MovementRules.TECH_BACK_COMING:
			return  # sobe colado na parede, sem acrobacia
		MovementRules.TECH_REVERSE:
			_trick_axis = Vector3.RIGHT  # mortal para frente, por cima da parede
			_trick_angle = -TAU
		_:
			_trick_axis = Vector3.UP  # giro no ar ao sair da parede
			_trick_angle = TAU * (1.0 if randf() < 0.5 else -1.0)
	_trick_timer = _fb().flip_duration


func _on_landed(who: Node, impact_speed: float) -> void:
	if who != player:
		return
	var fb := _fb()
	_land_strength = clampf(impact_speed / fb.land_crouch_full_speed, 0.15, 1.0)
	_land_timer = fb.land_crouch_time
	_trick_timer = 0.0


# --- Animação ------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	var fb := _fb()
	var cfg := player.config
	_time += delta
	var speed := player.get_horizontal_speed()
	var state := player.get_state_name()
	var grounded := state in [&"Idle", &"Run", &"Sprint", &"Land"]
	var sprinting := state == &"Sprint"

	var target_run := clampf(speed / cfg.walk_speed, 0.0, 1.0) if grounded else 0.0
	_run_amount = move_toward(_run_amount, target_run, delta * 6.0)
	var stride := lerpf(fb.stride_length_walk, fb.stride_length_sprint,
		clampf((speed - cfg.walk_speed) / maxf(cfg.sprint_speed - cfg.walk_speed, 0.01), 0.0, 1.0))
	if grounded:
		_phase = fmod(_phase + delta * speed / stride * TAU, TAU)

	var pose := _base_pose()
	match state:
		&"Jump", &"WallJump":
			_air_pose(pose, true)
		&"Fall":
			_air_pose(pose, false)
		&"Dodge":
			_dodge_pose(pose)
		_:
			_ground_pose(pose, sprinting)

	if _land_timer > 0.0:
		_land_timer = maxf(_land_timer - delta, 0.0)
		var k := _land_strength * (_land_timer / maxf(fb.land_crouch_time, 0.001))
		pose.hip_y -= fb.land_crouch_depth * k
		for i in 2:
			pose.thigh_x[i] += 0.9 * k
			pose.knee_x[i] -= 1.6 * k
		pose.spine_x -= 0.35 * k

	# Faixa: levanta com a velocidade e com a queda, tremula um pouco.
	pose.sash_x = clampf(speed * 0.09 + maxf(-player.velocity.y, 0.0) * 0.04, 0.0, 1.35) \
		+ sin(_time * 14.0) * 0.06 * clampf(speed / cfg.sprint_speed, 0.0, 1.0)

	_apply_pose(pose, clampf(fb.pose_blend_speed * delta, 0.0, 1.0))
	_update_trick(delta)
	_update_flash(delta)


func _base_pose() -> Dictionary:
	return {
		"hip_y": 0.0, "hip_z": 0.0, "spine_x": 0.0, "spine_z": 0.0, "head_x": 0.0,
		"shoulder_x": [0.0, 0.0], "shoulder_z": [0.08, -0.08], "elbow_x": [0.25, 0.25],
		"thigh_x": [0.0, 0.0], "thigh_z": [0.0, 0.0], "knee_x": [0.0, 0.0], "foot_x": [0.0, 0.0],
		"sash_x": 0.0,
	}


func _ground_pose(pose: Dictionary, sprinting: bool) -> void:
	var fb := _fb()
	var amount := _run_amount
	var swing := deg_to_rad(fb.leg_swing_deg) * amount * (1.25 if sprinting else 1.0)
	var knee := deg_to_rad(fb.knee_bend_deg) * amount
	var arm := deg_to_rad(fb.arm_swing_deg) * amount * (1.2 if sprinting else 1.0)
	for i in 2:
		var leg_phase := _phase + PI * i
		pose.thigh_x[i] = sin(leg_phase) * swing
		pose.knee_x[i] = -maxf(0.0, -cos(leg_phase)) * knee - 0.08 * amount
		pose.foot_x[i] = -pose.thigh_x[i] * 0.3
		pose.shoulder_x[i] = -sin(leg_phase) * arm
		pose.elbow_x[i] = 0.35 + 0.9 * amount
	var lean := deg_to_rad(fb.run_lean_deg) * amount
	if sprinting:
		lean += deg_to_rad(fb.sprint_extra_lean_deg)
	pose.spine_x = -lean + sin(_time * 2.2) * 0.02 * (1.0 - amount)
	pose.head_x = lean * 0.6
	pose.hip_y = -absf(cos(_phase)) * fb.run_bob_height * amount


func _air_pose(pose: Dictionary, rising: bool) -> void:
	if rising:
		pose.thigh_x = [1.1, -0.15]
		pose.knee_x = [-1.5, -0.7]
		pose.shoulder_x = [-0.6, 0.9]
		pose.shoulder_z = [0.5, -0.5]
		pose.elbow_x = [0.9, 0.6]
		pose.spine_x = -0.15
	else:
		pose.thigh_x = [0.45, 0.1]
		pose.knee_x = [-0.6, -0.35]
		pose.shoulder_z = [1.0, -1.0]
		pose.shoulder_x = [0.2, 0.2]
		pose.elbow_x = [0.4, 0.4]
		pose.spine_x = 0.05


func _dodge_pose(pose: Dictionary) -> void:
	var fb := _fb()
	# Direção do dash no espaço local do modelo (o modelo encara a câmera durante o dodge).
	var local := player.visual.global_basis.inverse() * player.get_horizontal_velocity()
	var side := clampf(local.x / maxf(player.config.dodge_speed, 0.01), -1.0, 1.0)
	var forward := clampf(-local.z / maxf(player.config.dodge_speed, 0.01), -1.0, 1.0)
	var lean := deg_to_rad(fb.dodge_lean_deg)
	pose.hip_y = -0.18
	pose.hip_z = -side * lean
	pose.spine_x = -forward * lean - 0.2
	pose.spine_z = -side * lean * 0.5
	pose.thigh_z = [0.35 * side + 0.25, 0.35 * side - 0.25]
	pose.thigh_x = [0.6, 0.6]
	pose.knee_x = [-1.1, -1.1]
	pose.shoulder_z = [0.7 - side * 0.4, -0.7 - side * 0.4]
	pose.shoulder_x = [0.4, 0.4]
	pose.elbow_x = [0.9, 0.9]


func _apply_pose(pose: Dictionary, w: float) -> void:
	_hips.position.y = lerpf(_hips.position.y, pose.hip_y, w)
	_hips.rotation.z = lerp_angle(_hips.rotation.z, pose.hip_z, w)
	_spine.rotation.x = lerp_angle(_spine.rotation.x, pose.spine_x, w)
	_spine.rotation.z = lerp_angle(_spine.rotation.z, pose.spine_z, w)
	_head.rotation.x = lerp_angle(_head.rotation.x, pose.head_x, w)
	_sash.rotation.x = lerp_angle(_sash.rotation.x, pose.sash_x, w)
	for i in 2:
		_shoulders[i].rotation.x = lerp_angle(_shoulders[i].rotation.x, pose.shoulder_x[i], w)
		_shoulders[i].rotation.z = lerp_angle(_shoulders[i].rotation.z, pose.shoulder_z[i], w)
		_elbows[i].rotation.x = lerp_angle(_elbows[i].rotation.x, pose.elbow_x[i], w)
		_thighs[i].rotation.x = lerp_angle(_thighs[i].rotation.x, pose.thigh_x[i], w)
		_thighs[i].rotation.z = lerp_angle(_thighs[i].rotation.z, pose.thigh_z[i], w)
		_knees[i].rotation.x = lerp_angle(_knees[i].rotation.x, pose.knee_x[i], w)
		_feet[i].rotation.x = lerp_angle(_feet[i].rotation.x, pose.foot_x[i], w)


func _update_trick(delta: float) -> void:
	if _trick_timer <= 0.0:
		_trick_pivot.basis = Basis()
		return
	_trick_timer = maxf(_trick_timer - delta, 0.0)
	var t := 1.0 - _trick_timer / maxf(_fb().flip_duration, 0.001)
	var eased := t * t * (3.0 - 2.0 * t)
	_trick_pivot.basis = Basis(_trick_axis, _trick_angle * eased)


func _update_flash(delta: float) -> void:
	if _flash_timer <= 0.0:
		return
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	var k := _flash_timer / _flash_duration
	_flash_material.emission = _flash_color
	_flash_material.emission_energy_multiplier = _flash_energy * k
	_visor_material.emission = _fb().color_dirty_white.lerp(_flash_color, k)
	_visor_material.emission_energy_multiplier = lerpf(VISOR_IDLE_ENERGY, 3.0, k)
	if _flash_timer == 0.0:
		for mesh in _meshes:
			mesh.material_overlay = null
