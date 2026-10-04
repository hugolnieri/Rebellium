class_name CharacterModel
extends Node3D
## Personagem procedural no estilo anime cyberpunk (traje preto com linhas roxas emissivas,
## cabelo branco espetado, olhos verdes, ombreiras e joelheiras). Só apresentação: lê o
## estado do Player e nunca altera gameplay. Frente = -Z, pés em y = 0, altura de referência 1,8 m.
##
## Animação: cada articulação persegue uma pose-alvo através de uma MOLA (frequência +
## amortecimento), o que dá peso, continuidade e um leve balanço — nada de poses rígidas.
## Camadas: locomoção (corrida com quadril/tronco em contra-rotação, inclinação nas curvas,
## respiração) → ar (mistura contínua subida/queda) → golpe (poses-chave de AttackPoses).

const REFERENCE_HEIGHT: float = 1.8
const HIP_HEIGHT: float = 0.97
const THIGH_LENGTH: float = 0.45
const SHIN_LENGTH: float = 0.44
const UPPER_ARM_LENGTH: float = 0.29
const FOREARM_LENGTH: float = 0.26
const JOINTS: Array[StringName] = [
	&"lean", &"hips", &"spine", &"chest", &"head", &"shoulder_l", &"shoulder_r", &"elbow_l",
	&"elbow_r", &"wrist_l", &"wrist_r", &"thigh_l", &"thigh_r", &"knee_l", &"knee_r",
	&"foot_l", &"foot_r",
]
## Canais escalares (posição): altura do quadril.
const HIPS_Y: StringName = &"hips_y"
## Canal do cabelo (movimento secundário).
const HAIR: StringName = &"hair"

var player: Player
var weapon_visual: WeaponVisual
var trail: WeaponTrail

var _nodes: Dictionary = {}  # canal -> Node3D
var _trick: Node3D
var _hair: Node3D
var _socket: Node3D
var _meshes: Array[MeshInstance3D] = []
var _line_material: StandardMaterial3D
var _flash_material: StandardMaterial3D

# Molas: posição/velocidade por canal.
var _pos: Dictionary = {}
var _vel: Dictionary = {}

var _phase: float = 0.0
var _time: float = 0.0
var _run_amount: float = 0.0
var _last_yaw: float = 0.0
var _last_speed: float = 0.0
var _bank: float = 0.0
var _land_timer: float = 0.0
var _land_strength: float = 0.0
var _trick_timer: float = 0.0
var _trick_axis: Vector3 = Vector3.RIGHT
var _trick_angle: float = 0.0
## No mortal do wall jump o corpo começa de frente para a parede e termina olhando o caminho.
var _trick_face_wall: bool = false
var _spin_angle: float = 0.0
var _flash_timer: float = 0.0
var _flash_duration: float = 0.001
var _flash_energy: float = 0.0
var _flash_color: Color = Color.WHITE
var _last_step_side: int = 0


func _ready() -> void:
	player = get_parent().get_parent() as Player
	_build()
	for joint in JOINTS:
		_pos[joint] = Vector3.ZERO
		_vel[joint] = Vector3.ZERO
	for channel in [HIPS_Y, HAIR]:
		_pos[channel] = Vector3.ZERO
		_vel[channel] = Vector3.ZERO
	GameEvents.wall_jump_executed.connect(_on_wall_jump)
	GameEvents.landed.connect(_on_landed)
	GameEvents.weapon_changed.connect(_on_weapon_changed)
	_equip.call_deferred()


func _fb() -> FeedbackConfig:
	return player.feedback_config


## Ajusta a escala do modelo à altura da cápsula da config.
func apply_body_height(height: float) -> void:
	scale = Vector3.ONE * (height / REFERENCE_HEIGHT)


# --- Montagem do corpo -----------------------------------------------------------

func _build() -> void:
	var fb := _fb()
	var suit := _material(fb.suit_color, 0.42, 0.15)
	var armor := _material(fb.armor_color, 0.18, 0.35)
	var skin := _material(fb.skin_color, 0.65, 0.0)
	var hair := _material(fb.hair_color, 0.55, 0.0)
	_line_material = _emissive(fb.suit_line_color, fb.suit_line_energy)
	var eyes := _emissive(fb.eye_color, 1.6)
	var green := _emissive(Color(0.4, 1.0, 0.35), 2.0)
	var cyan := _emissive(Color(0.3, 0.75, 1.0), 2.0)
	var line := _line_material

	var lean := _joint(&"lean", self, Vector3.ZERO)
	_trick = Node3D.new()
	_trick.position = Vector3(0, HIP_HEIGHT, 0)
	lean.add_child(_trick)
	var hips := _joint(&"hips", _trick, Vector3.ZERO)
	_capsule(hips, 0.12, 0.31, Vector3(0, -0.03, 0), Vector3(0, 0, PI * 0.5), Vector3(1, 1, 0.78), suit)
	_cylinder(hips, 0.128, 0.128, 0.02, Vector3(0, 0.07, 0), line, Vector3.ZERO, Vector3(1.12, 1, 0.82))  # cinto
	_box(hips, Vector3(0.022, 0.16, 0.012), Vector3(0.07, -0.06, -0.1), line, Vector3(0, 0, 0.5))
	_box(hips, Vector3(0.022, 0.16, 0.012), Vector3(-0.07, -0.06, -0.1), line, Vector3(0, 0, -0.5))

	var spine := _joint(&"spine", hips, Vector3(0, 0.1, 0))
	_capsule(spine, 0.11, 0.32, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1.15, 1, 0.78), suit)
	var chest := _joint(&"chest", spine, Vector3(0, 0.2, 0))
	_capsule(chest, 0.15, 0.38, Vector3(0, 0.11, 0), Vector3.ZERO, Vector3(1.2, 1, 0.7), suit)
	# Linhas do peito: V até o esterno, faixa horizontal e linha central (como no conceito).
	_box(chest, Vector3(0.02, 0.27, 0.012), Vector3(0.085, 0.13, -0.113), line, Vector3(0, 0, -0.62))
	_box(chest, Vector3(0.02, 0.27, 0.012), Vector3(-0.085, 0.13, -0.113), line, Vector3(0, 0, 0.62))
	_box(chest, Vector3(0.02, 0.2, 0.012), Vector3(0, -0.02, -0.112), line)
	_box(chest, Vector3(0.3, 0.02, 0.012), Vector3(0, -0.08, -0.1), line)
	_box(chest, Vector3(0.022, 0.32, 0.012), Vector3(0, 0.06, 0.112), line)  # coluna nas costas
	_box(chest, Vector3(0.12, 0.12, 0.012), Vector3(0, 0.15, 0.112), line, Vector3(0, 0, PI * 0.25))
	_cylinder(chest, 0.052, 0.052, 0.1, Vector3(0, 0.3, 0), suit)  # gola alta

	var head := _joint(&"head", chest, Vector3(0, 0.34, 0))
	_sphere(head, 0.102, Vector3(0, 0.1, -0.005), Vector3(0.9, 1.1, 1.0), skin)
	_sphere(head, 0.06, Vector3(0, 0.035, -0.035), Vector3(1.0, 0.8, 1.0), skin)  # queixo
	for side: float in [-1.0, 1.0]:
		_box(head, Vector3(0.034, 0.016, 0.01), Vector3(0.037 * side, 0.1, -0.096), eyes, Vector3(0, 0, -0.12 * side))
	_hair = Node3D.new()
	_hair.position = Vector3(0, 0.12, 0)
	head.add_child(_hair)
	_build_hair(hair)

	for side: float in [-1.0, 1.0]:
		var suffix := "l" if side < 0.0 else "r"
		var shoulder := _joint(StringName("shoulder_" + suffix), chest, Vector3(0.195 * side, 0.235, 0))
		_sphere(shoulder, 0.085, Vector3(0.025 * side, 0.02, 0), Vector3(1.1, 0.85, 1.05), armor)  # ombreira
		_cylinder(shoulder, 0.087, 0.087, 0.014, Vector3(0.025 * side, -0.005, 0), line, Vector3.ZERO,
			Vector3(1.1, 1, 1.05))
		_capsule(shoulder, 0.053, UPPER_ARM_LENGTH + 0.08, Vector3(0, -UPPER_ARM_LENGTH * 0.5, 0), Vector3.ZERO,
			Vector3.ONE, suit)
		_box(shoulder, Vector3(0.012, UPPER_ARM_LENGTH * 0.8, 0.018), Vector3(0.053 * side, -0.15, 0), line)
		var elbow := _joint(StringName("elbow_" + suffix), shoulder, Vector3(0, -UPPER_ARM_LENGTH, 0))
		_capsule(elbow, 0.047, FOREARM_LENGTH + 0.06, Vector3(0, -FOREARM_LENGTH * 0.5, 0), Vector3.ZERO,
			Vector3.ONE, suit)
		_box(elbow, Vector3(0.012, FOREARM_LENGTH * 0.75, 0.016), Vector3(0.047 * side, -0.12, -0.01), line,
			Vector3(0, 0, 0.12 * side))
		_cylinder(elbow, 0.05, 0.05, 0.03, Vector3(0, -FOREARM_LENGTH + 0.01, 0), armor)  # punho
		var wrist := _joint(StringName("wrist_" + suffix), elbow, Vector3(0, -FOREARM_LENGTH - 0.02, 0))
		_capsule(wrist, 0.037, 0.08, Vector3(0, -0.035, -0.005), Vector3.ZERO, Vector3(0.95, 1, 0.7), skin)
		if side < 0.0:
			# Pulseira de energia (esquerda) com tela verde.
			_box(elbow, Vector3(0.07, 0.05, 0.075), Vector3(0, -FOREARM_LENGTH + 0.06, 0), armor)
			_box(elbow, Vector3(0.045, 0.035, 0.004), Vector3(-0.038, -FOREARM_LENGTH + 0.06, 0), green,
				Vector3(0, PI * 0.5, 0))
		else:
			_socket = Node3D.new()
			_socket.position = Vector3(0, -0.045, 0)
			wrist.add_child(_socket)
			# Braçadeira com display ciano.
			_box(shoulder, Vector3(0.03, 0.045, 0.05), Vector3(0.055, -0.1, 0), armor)
			_box(shoulder, Vector3(0.004, 0.025, 0.035), Vector3(0.071, -0.1, 0), cyan)

		var thigh := _joint(StringName("thigh_" + suffix), hips, Vector3(0.095 * side, -0.03, 0))
		_cylinder(thigh, 0.085, 0.06, THIGH_LENGTH, Vector3(0, -THIGH_LENGTH * 0.5, 0), suit)
		_sphere(thigh, 0.085, Vector3(0, -0.01, 0), Vector3.ONE, suit)
		_box(thigh, Vector3(0.014, THIGH_LENGTH * 0.85, 0.014), Vector3(0, -0.22, -0.075), line,
			Vector3(0, 0, 0.18 * side))
		_box(thigh, Vector3(0.014, THIGH_LENGTH * 0.7, 0.014), Vector3(0.075 * side, -0.2, 0), line)
		var knee := _joint(StringName("knee_" + suffix), thigh, Vector3(0, -THIGH_LENGTH, 0))
		_sphere(knee, 0.072, Vector3(0, 0.01, -0.045), Vector3(0.95, 1.2, 0.6), armor)  # joelheira
		_box(knee, Vector3(0.13, 0.014, 0.014), Vector3(0, 0.065, -0.07), line)
		_cylinder(knee, 0.06, 0.042, SHIN_LENGTH, Vector3(0, -SHIN_LENGTH * 0.5, 0), suit)
		_box(knee, Vector3(0.014, SHIN_LENGTH * 0.75, 0.014), Vector3(0, -0.22, -0.055), line,
			Vector3(0, 0, -0.15 * side))
		var foot := _joint(StringName("foot_" + suffix), knee, Vector3(0, -SHIN_LENGTH, 0))
		_cylinder(foot, 0.045, 0.045, 0.03, Vector3(0, 0.0, 0), suit)  # tornozeleira
		_capsule(foot, 0.04, 0.22, Vector3(0, -0.045, -0.055), Vector3(PI * 0.5, 0, 0), Vector3(1.05, 1, 0.75),
			skin)


func _build_hair(material: Material) -> void:
	_sphere(_hair, 0.112, Vector3(0, 0.0, 0.012), Vector3(1.02, 0.92, 1.06), material)
	# Mechas espetadas: (posição, direção da ponta, comprimento, raio da base).
	var spikes: Array = [
		[Vector3(0.0, 0.07, -0.08), Vector3(0.1, -0.35, -1.0), 0.09, 0.032],
		[Vector3(-0.05, 0.065, -0.075), Vector3(-0.3, -0.45, -0.9), 0.08, 0.03],
		[Vector3(0.05, 0.065, -0.075), Vector3(0.35, -0.45, -0.9), 0.08, 0.03],
		[Vector3(-0.09, 0.03, -0.04), Vector3(-0.7, -0.9, -0.2), 0.1, 0.032],
		[Vector3(0.09, 0.03, -0.04), Vector3(0.7, -0.9, -0.2), 0.1, 0.032],
		[Vector3(0.0, 0.1, -0.01), Vector3(0.0, 1.0, 0.5), 0.14, 0.045],
		[Vector3(-0.05, 0.09, 0.02), Vector3(-0.5, 1.0, 0.6), 0.13, 0.04],
		[Vector3(0.05, 0.09, 0.02), Vector3(0.5, 1.0, 0.6), 0.13, 0.04],
		[Vector3(0.0, 0.07, 0.07), Vector3(0.0, 0.5, 1.0), 0.15, 0.045],
		[Vector3(-0.06, 0.04, 0.07), Vector3(-0.5, 0.0, 1.0), 0.13, 0.04],
		[Vector3(0.06, 0.04, 0.07), Vector3(0.5, 0.0, 1.0), 0.13, 0.04],
		[Vector3(0.0, -0.02, 0.09), Vector3(0.0, -0.7, 1.0), 0.13, 0.04],
		[Vector3(-0.095, -0.02, 0.03), Vector3(-0.7, -0.8, 0.4), 0.11, 0.035],
		[Vector3(0.095, -0.02, 0.03), Vector3(0.7, -0.8, 0.4), 0.11, 0.035],
	]
	for spike: Array in spikes:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = spike[3]
		mesh.height = spike[2]
		mesh.radial_segments = 6
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		var dir: Vector3 = (spike[1] as Vector3).normalized()
		# Alinha o eixo Y do cone com a direção da mecha.
		var basis := Basis(Quaternion(Vector3.UP, dir))
		instance.transform = Transform3D(basis, spike[0] + dir * spike[2] * 0.5)
		_hair.add_child(instance)
		_meshes.append(instance)


func _joint(channel: StringName, parent: Node3D, offset: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = offset
	parent.add_child(node)
	_nodes[channel] = node
	return node


func _box(parent: Node3D, size: Vector3, offset: Vector3, material: Material,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, offset, rot, Vector3.ONE, material)


func _sphere(parent: Node3D, radius: float, offset: Vector3, scl: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return _mesh(parent, mesh, offset, Vector3.ZERO, scl, material)


func _capsule(parent: Node3D, radius: float, length: float, offset: Vector3, rot: Vector3,
		scl: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0)  # comprimento total
	mesh.radial_segments = 16
	mesh.rings = 6
	return _mesh(parent, mesh, offset, rot, scl, material)


func _cylinder(parent: Node3D, top: float, bottom: float, height: float, offset: Vector3,
		material: Material, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	return _mesh(parent, mesh, offset, rot, scl, material)


func _mesh(parent: Node3D, mesh: Mesh, offset: Vector3, rot: Vector3, scl: Vector3,
		material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	instance.rotation = rot
	instance.scale = scl
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


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


# --- Arma ------------------------------------------------------------------------

func _equip() -> void:
	weapon_visual = WeaponVisual.new()
	_socket.add_child(weapon_visual)
	trail = WeaponTrail.new()
	add_child(trail)
	trail.source = weapon_visual
	_apply_weapon(player.get_weapon())


func _apply_weapon(weapon: WeaponConfig) -> void:
	if weapon == null or weapon_visual == null:
		return
	weapon_visual.build(weapon)
	trail.color = weapon.glow_color
	trail.clear()


func _on_weapon_changed(who: Node, weapon: Resource, _slot: int) -> void:
	if who != player:
		return
	_apply_weapon(weapon as WeaponConfig)
	# Floreio: o pulso gira a arma nova.
	_vel[&"wrist_r"] += Vector3(-30.0, 0.0, 8.0)
	flash((weapon as WeaponConfig).glow_color, 0.18, 1.5)


# --- Feedback --------------------------------------------------------------------

## Brilho na cor da técnica (corpo inteiro + linhas do traje).
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
			return
		MovementRules.TECH_REVERSE:
			_trick_axis = Vector3.RIGHT
			_trick_angle = -TAU
		_:
			# Mortal para trás: pisa na parede (de frente para ela) e gira de costas para longe.
			_trick_axis = Vector3.RIGHT
			_trick_angle = TAU
			_trick_face_wall = true
			_trick_timer = _fb().flip_duration
			return
	_trick_face_wall = false
	_trick_timer = _fb().flip_duration


func _on_landed(who: Node, impact_speed: float) -> void:
	if who != player:
		return
	var fb := _fb()
	_land_strength = clampf(impact_speed / fb.land_crouch_full_speed, 0.15, 1.0)
	_land_timer = fb.land_crouch_time
	_trick_timer = 0.0
	# Impacto empurra o quadril para baixo pela mola (amortece de forma natural).
	_vel[HIPS_Y] += Vector3(-_land_strength * 2.5, 0, 0)


# --- Animação --------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	if player.hitstop_ticks > 0:
		return  # quadro congelado do impacto
	var fb := _fb()
	var cfg := player.config
	_time += delta
	var speed := player.get_horizontal_speed()
	var state := player.get_state_name()
	var grounded := state in [&"Idle", &"Run", &"Sprint", &"Land"]
	var sprinting := state == &"Sprint"

	var target_run := clampf(speed / cfg.walk_speed, 0.0, 1.4) if grounded else 0.0
	_run_amount = move_toward(_run_amount, target_run, delta * 5.0)
	var stride := lerpf(fb.stride_length_walk, fb.stride_length_sprint,
		clampf((speed - cfg.walk_speed) / maxf(cfg.sprint_speed - cfg.walk_speed, 0.01), 0.0, 1.0))
	if grounded:
		_phase = fmod(_phase + delta * speed / stride * TAU, TAU)
		_emit_footsteps(speed, cfg)

	# Inclinação nas curvas: giro do corpo (rad/s) × velocidade.
	var yaw := player.visual.rotation.y
	var turn_rate := wrapf(yaw - _last_yaw, -PI, PI) / maxf(delta, 0.0001)
	_last_yaw = yaw
	var bank_target := clampf(-turn_rate * speed * fb.bank_strength, -deg_to_rad(fb.max_bank_deg),
		deg_to_rad(fb.max_bank_deg)) if grounded or player.air_sprinting else 0.0
	_bank = lerpf(_bank, bank_target, clampf(delta * 8.0, 0.0, 1.0))
	var accel := (speed - _last_speed) / maxf(delta, 0.0001)
	_last_speed = speed

	var pose := _rest_pose()
	var attack_weight := 0.0
	match state:
		&"Attack":
			_ground_pose(pose, false, accel)
			attack_weight = _attack_pose(pose)
		&"Jump", &"Fall" when player.air_sprinting:
			_air_sprint_pose(pose)
		&"WallJump" when _trick_face_wall and _trick_timer > _fb().flip_duration * 0.6:
			_wall_kick_pose(pose)
		&"Jump", &"Fall", &"WallJump":
			_air_pose(pose)
		&"Land" when _is_rolling():
			_roll_pose(pose)
		&"Dodge":
			_dodge_pose(pose)
		&"Hurt":
			_hurt_pose(pose)
		_:
			_ground_pose(pose, sprinting, accel)
	pose[&"lean"] = pose.get(&"lean", Vector3.ZERO) + Vector3(0, 0, _bank)

	if _is_rolling():
		_land_timer = 0.0  # a cambalhota já absorve o impacto
	if _land_timer > 0.0:
		_land_timer = maxf(_land_timer - delta, 0.0)
		var k := _land_strength * (_land_timer / maxf(fb.land_crouch_time, 0.001))
		pose[HIPS_Y] = pose[HIPS_Y] - Vector3(fb.land_crouch_depth * k, 0, 0)
		for side in ["l", "r"]:
			pose[StringName("thigh_" + side)] += Vector3(0.9 * k, 0, 0)
			pose[StringName("knee_" + side)] += Vector3(-1.6 * k, 0, 0)
		pose[&"spine"] += Vector3(-0.3 * k, 0, 0)

	var freq := lerpf(fb.anim_spring_frequency, fb.attack_spring_frequency, attack_weight)
	var damp := lerpf(fb.anim_spring_damping, fb.attack_spring_damping, attack_weight)
	_apply_springs(pose, freq, damp, delta)
	_update_hair(speed, delta)
	_update_trick(delta)
	_update_flash(delta)


func _rest_pose() -> Dictionary:
	var pose := {}
	for joint in JOINTS:
		pose[joint] = Vector3.ZERO
	pose[HIPS_Y] = Vector3.ZERO
	# Postura de prontidão: arma baixa à frente, braço livre relaxado.
	pose[&"shoulder_r"] = Vector3(0.35, 0.05, 0.18)
	pose[&"elbow_r"] = Vector3(0.75, 0, 0)
	pose[&"wrist_r"] = Vector3(-0.35, 0, 0)
	pose[&"shoulder_l"] = Vector3(0.1, 0, -0.16)
	pose[&"elbow_l"] = Vector3(0.35, 0, 0)
	return pose


func _ground_pose(pose: Dictionary, sprinting: bool, accel: float) -> void:
	var fb := _fb()
	var amount := _run_amount
	var calm := 1.0 - clampf(amount, 0.0, 1.0)
	var swing := deg_to_rad(fb.leg_swing_deg) * amount * (1.2 if sprinting else 1.0)
	var knee_bend := deg_to_rad(fb.knee_bend_deg) * amount
	var arm_swing := deg_to_rad(fb.arm_swing_deg) * amount * (1.25 if sprinting else 1.0)
	for i in 2:
		var side := "l" if i == 0 else "r"
		var leg_phase := _phase + PI * i
		var thigh := sin(leg_phase) * swing
		# Joelho dobra mais na passagem (perna vindo para frente) e estica no contato.
		var knee := -knee_bend * (0.5 + 0.5 * sin(leg_phase + PI * 0.65)) - 0.1 * amount
		pose[StringName("thigh_" + side)] = Vector3(thigh, 0, (0.04 if i == 0 else -0.04) * calm)
		pose[StringName("knee_" + side)] = Vector3(knee - 0.12 * calm, 0, 0)
		pose[StringName("foot_" + side)] = Vector3(-thigh * 0.35 - knee * 0.25, 0, 0)
	# Braço livre balança oposto à perna; o braço da arma balança menos.
	pose[&"shoulder_l"] = Vector3(-sin(_phase) * arm_swing + 0.1, 0, -0.16 - 0.1 * amount)
	pose[&"elbow_l"] = Vector3(0.35 + 0.9 * amount, 0, 0)
	# Correndo, o braço da arma vai para trás e a lâmina "arrasta" atrás do corpo.
	var run_k := clampf(amount, 0.0, 1.0)
	pose[&"shoulder_r"] = Vector3(lerpf(0.35, -0.45, run_k) + sin(_phase) * arm_swing * 0.25, 0.05,
		0.18 + 0.12 * run_k)
	pose[&"elbow_r"] = Vector3(lerpf(0.75, 0.35, run_k), 0, 0)
	pose[&"wrist_r"] = Vector3(lerpf(-0.35, 3.3, run_k), 0, 0)
	# Quadril e tronco em contra-rotação, balanço lateral e sobe-desce de dois tempos.
	var lean := deg_to_rad(fb.run_lean_deg) * amount + clampf(accel * 0.01, -0.15, 0.2)
	if sprinting:
		lean += deg_to_rad(fb.sprint_extra_lean_deg)
	pose[&"hips"] = Vector3(0, sin(_phase) * 0.22 * amount, sin(_phase * 2.0) * 0.03 * amount
		+ sin(_time * 0.9) * 0.02 * calm)
	pose[&"spine"] = Vector3(-lean, -sin(_phase) * 0.14 * amount, 0)
	pose[&"chest"] = Vector3(sin(_time * 2.1) * 0.025 * calm - lean * 0.3, -sin(_phase) * 0.16 * amount, 0)
	pose[&"head"] = Vector3(lean * 0.8, sin(_phase) * 0.18 * amount, 0)
	pose[HIPS_Y] = Vector3(-absf(cos(_phase)) * fb.run_bob_height * amount - 0.02 * calm, 0, 0)


func _air_pose(pose: Dictionary) -> void:
	# Mistura contínua: subindo (encolhido) → ápice → caindo (pernas buscando o chão).
	var k := clampf(player.velocity.y / 9.0, -1.0, 1.0)
	var rise := clampf(k, 0.0, 1.0)
	var fall := clampf(-k, 0.0, 1.0)
	pose[&"thigh_l"] = Vector3(lerpf(0.5, 1.1, rise) - 0.15 * fall, 0, 0.05)
	pose[&"thigh_r"] = Vector3(lerpf(0.1, -0.2, rise) + 0.25 * fall, 0, -0.05)
	pose[&"knee_l"] = Vector3(lerpf(-0.8, -1.6, rise) + 0.3 * fall, 0, 0)
	pose[&"knee_r"] = Vector3(lerpf(-0.6, -0.8, rise) + 0.2 * fall, 0, 0)
	pose[&"shoulder_l"] = Vector3(lerpf(0.4, 0.9, rise) - 0.2 * fall, 0, lerpf(-0.6, -0.35, rise) - 0.5 * fall)
	pose[&"elbow_l"] = Vector3(0.7, 0, 0)
	pose[&"shoulder_r"] = Vector3(lerpf(0.3, -0.3, rise) + 0.2 * fall, 0.1, 0.45 + 0.4 * fall)
	pose[&"elbow_r"] = Vector3(0.7, 0, 0)
	pose[&"wrist_r"] = Vector3(-0.6, 0, 0)
	pose[&"spine"] = Vector3(-0.15 * rise + 0.08 * fall, 0, 0)
	pose[&"head"] = Vector3(0.1 * rise - 0.1 * fall, 0, 0)


## Corrida no ar: corpo mergulhado para frente, pernas pedalando para trás.
func _air_sprint_pose(pose: Dictionary) -> void:
	var cycle := sin(_time * 14.0)
	pose[&"spine"] = Vector3(-0.55, 0, 0)
	pose[&"head"] = Vector3(0.45, 0, 0)
	pose[&"thigh_l"] = Vector3(-0.2 + cycle * 0.6, 0, 0)
	pose[&"thigh_r"] = Vector3(-0.2 - cycle * 0.6, 0, 0)
	pose[&"knee_l"] = Vector3(-0.9 - maxf(cycle, 0.0) * 0.6, 0, 0)
	pose[&"knee_r"] = Vector3(-0.9 - maxf(-cycle, 0.0) * 0.6, 0, 0)
	pose[&"shoulder_l"] = Vector3(-1.2, 0, -0.35)
	pose[&"shoulder_r"] = Vector3(-1.1, 0, 0.35)
	pose[&"elbow_l"] = Vector3(0.2, 0, 0)
	pose[&"elbow_r"] = Vector3(0.2, 0, 0)
	pose[&"wrist_r"] = Vector3(-1.4, 0, 0)


## Pés plantados na parede, joelhos dobrados empurrando, braços abrindo para o mortal.
func _wall_kick_pose(pose: Dictionary) -> void:
	pose[&"thigh_l"] = Vector3(1.3, 0, 0.1)
	pose[&"thigh_r"] = Vector3(1.1, 0, -0.1)
	pose[&"knee_l"] = Vector3(-1.7, 0, 0)
	pose[&"knee_r"] = Vector3(-1.5, 0, 0)
	pose[&"spine"] = Vector3(0.35, 0, 0)
	pose[&"head"] = Vector3(0.3, 0, 0)
	pose[&"shoulder_l"] = Vector3(1.6, 0, -0.6)
	pose[&"shoulder_r"] = Vector3(1.4, 0, 0.6)
	pose[&"elbow_l"] = Vector3(0.5, 0, 0)
	pose[&"elbow_r"] = Vector3(0.5, 0, 0)


## Cambalhota: corpo encolhido (joelhos no peito, cabeça baixa, braços abraçando as pernas).
func _roll_pose(pose: Dictionary) -> void:
	pose[HIPS_Y] = Vector3(-0.42, 0, 0)
	pose[&"spine"] = Vector3(-0.7, 0, 0)
	pose[&"chest"] = Vector3(-0.35, 0, 0)
	pose[&"head"] = Vector3(-0.4, 0, 0)
	pose[&"thigh_l"] = Vector3(1.9, 0, 0.12)
	pose[&"thigh_r"] = Vector3(1.9, 0, -0.12)
	pose[&"knee_l"] = Vector3(-2.3, 0, 0)
	pose[&"knee_r"] = Vector3(-2.3, 0, 0)
	pose[&"shoulder_l"] = Vector3(1.2, 0, 0.1)
	pose[&"shoulder_r"] = Vector3(1.0, 0, -0.1)
	pose[&"elbow_l"] = Vector3(1.4, 0, 0)
	pose[&"elbow_r"] = Vector3(1.2, 0, 0)


func _dodge_pose(pose: Dictionary) -> void:
	var fb := _fb()
	var local := player.visual.global_basis.inverse() * player.get_horizontal_velocity()
	var side := clampf(local.x / maxf(player.config.dodge_speed, 0.01), -1.0, 1.0)
	var forward := clampf(-local.z / maxf(player.config.dodge_speed, 0.01), -1.0, 1.0)
	var lean := deg_to_rad(fb.dodge_lean_deg)
	pose[HIPS_Y] = Vector3(-0.2, 0, 0)
	pose[&"lean"] = Vector3(-forward * lean * 0.6, 0, -side * lean)
	pose[&"spine"] = Vector3(-0.25 - forward * lean * 0.5, 0, -side * lean * 0.4)
	pose[&"thigh_l"] = Vector3(0.6, 0, 0.3 * side - 0.3)
	pose[&"thigh_r"] = Vector3(0.6, 0, 0.3 * side + 0.3)
	pose[&"knee_l"] = Vector3(-1.2, 0, 0)
	pose[&"knee_r"] = Vector3(-1.2, 0, 0)
	pose[&"shoulder_l"] = Vector3(0.5, 0, -0.8 - side * 0.4)
	pose[&"shoulder_r"] = Vector3(0.4, 0, 0.8 - side * 0.4)
	pose[&"elbow_l"] = Vector3(0.9, 0, 0)
	pose[&"elbow_r"] = Vector3(0.9, 0, 0)


func _hurt_pose(pose: Dictionary) -> void:
	pose[&"spine"] = Vector3(0.45, 0.15, 0)
	pose[&"chest"] = Vector3(0.2, 0, 0)
	pose[&"head"] = Vector3(0.35, 0, 0)
	pose[&"shoulder_l"] = Vector3(0.6, 0, -0.9)
	pose[&"shoulder_r"] = Vector3(0.5, 0, 0.9)
	pose[&"knee_l"] = Vector3(-0.5, 0, 0)
	pose[&"knee_r"] = Vector3(-0.3, 0, 0)
	pose[HIPS_Y] = Vector3(-0.08, 0, 0)


## Sobrepõe as poses-chave do golpe atual. Retorna o peso do golpe (0–1) para as molas.
func _attack_pose(pose: Dictionary) -> float:
	var state := player.state_machine.current
	var attack: AttackData = state.get(&"attack")
	if attack == null:
		return 0.0
	var keys := AttackPoses.get_keys(attack.anim)
	var phase: int = state.call(&"get_phase")
	var p: float = clampf(state.call(&"get_phase_progress"), 0.0, 1.0)
	var target: Dictionary
	var weight := 1.0
	_spin_angle = 0.0
	match phase:
		0:
			target = keys[0]
		1:
			target = _blend_keys(keys[0], keys[1], _ease_out(p))
			_spin_angle = keys[1].get("spin", 0.0) * _ease_out(p)
		_:
			target = _blend_keys(keys[1], keys[2], clampf(p * 2.0, 0.0, 1.0))
			_spin_angle = keys[1].get("spin", 0.0)
			# Na segunda metade da recuperação devolve o controle à locomoção.
			weight = 1.0 - clampf((p - 0.5) * 2.0, 0.0, 1.0)
	for channel: String in target:
		if channel == "spin":
			continue
		var key := StringName(channel)
		var value: Variant = target[channel]
		if channel == "hips_y":
			pose[HIPS_Y] = pose[HIPS_Y].lerp(Vector3(value, 0, 0), weight)
		elif pose.has(key):
			pose[key] = (pose[key] as Vector3).lerp(value, weight)
	if weight <= 0.0:
		_spin_angle = 0.0
	if weapon_visual != null:
		weapon_visual.set_boost(1.0 if phase == 1 else 0.3 * weight)
	if trail != null:
		trail.emitting = (phase == 0 and p > 0.6) or phase == 1 or (phase == 2 and p < 0.25)
	return weight


func _blend_keys(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var result := a.duplicate()
	for channel: String in b:
		if channel == "spin":
			continue
		if result.has(channel):
			var from: Variant = result[channel]
			if from is float:
				result[channel] = lerpf(from, b[channel], t)
			else:
				result[channel] = (from as Vector3).lerp(b[channel], t)
		else:
			result[channel] = b[channel]
	return result


func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


func _apply_springs(pose: Dictionary, frequency: float, damping: float, delta: float) -> void:
	if player.get_state_name() != &"Attack":
		if trail != null:
			trail.emitting = false
		if weapon_visual != null:
			weapon_visual.set_boost(0.0)
	for joint in JOINTS:
		var value := _spring(joint, pose[joint], frequency, damping, delta)
		(_nodes[joint] as Node3D).rotation = value
	var hips_y := _spring(HIPS_Y, pose[HIPS_Y], frequency, damping, delta)
	(_nodes[&"hips"] as Node3D).position.y = hips_y.x


## Mola implícita (estável com qualquer delta): x persegue o alvo com frequência e amortecimento.
func _spring(channel: StringName, target: Vector3, frequency: float, damping: float, dt: float) -> Vector3:
	var x: Vector3 = _pos[channel]
	var v: Vector3 = _vel[channel]
	var omega := TAU * frequency
	var f := 1.0 + 2.0 * dt * damping * omega
	var oo := omega * omega
	var hoo := dt * oo
	var hhoo := dt * hoo
	var det_inv := 1.0 / (f + hhoo)
	var new_x := (x * f + v * dt + target * hhoo) * det_inv
	var new_v := (v + (target - x) * hoo) * det_inv
	_pos[channel] = new_x
	_vel[channel] = new_v
	return new_x


func _update_hair(speed: float, delta: float) -> void:
	var fb := _fb()
	# Vento: o cabelo vai para trás com a velocidade e para cima/baixo com a queda/subida.
	var target := Vector3(clampf(speed * 0.045 - player.velocity.y * 0.025, -0.35, 0.7), 0, 0)
	var hair := _spring(HAIR, target, fb.hair_spring_frequency, fb.hair_spring_damping, delta)
	_hair.rotation = hair + Vector3(sin(_time * 9.0) * 0.02 * clampf(speed / 10.0, 0.0, 1.0), 0, 0)


func _emit_footsteps(speed: float, cfg: MovementConfig) -> void:
	if speed < 1.0:
		return
	var side := 0 if sin(_phase) >= 0.0 else 1
	if side != _last_step_side:
		_last_step_side = side
		GameEvents.footstep.emit(player, clampf(speed / cfg.sprint_speed, 0.0, 1.0))


func _update_trick(delta: float) -> void:
	var basis := Basis(Vector3.UP, _spin_angle)
	if _trick_timer > 0.0:
		_trick_timer = maxf(_trick_timer - delta, 0.0)
		var t := 1.0 - _trick_timer / maxf(_fb().flip_duration, 0.001)
		var eased := t * t * (3.0 - 2.0 * t)
		if _trick_face_wall:
			basis = basis * Basis(Vector3.UP, PI * (1.0 - eased))
		basis = basis * Basis(_trick_axis, _trick_angle * eased)
	elif _is_rolling():
		# Cambalhota para frente ao aterrissar.
		var roll: float = player.state_machine.current.call(&"get_roll_progress")
		basis = basis * Basis(Vector3.RIGHT, -TAU * _ease_in_out(roll))
	_trick.basis = basis


func _is_rolling() -> bool:
	return player.state_machine.is_in(&"Land") and player.state_machine.current.get(&"rolling") == true


func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _update_flash(delta: float) -> void:
	var fb := _fb()
	if _flash_timer <= 0.0:
		return
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	var k := _flash_timer / _flash_duration
	_flash_material.emission = _flash_color
	_flash_material.emission_energy_multiplier = _flash_energy * k * 0.5
	_line_material.emission = fb.suit_line_color.lerp(_flash_color, k)
	_line_material.emission_energy_multiplier = lerpf(fb.suit_line_energy, fb.suit_line_energy * 2.5, k)
	if _flash_timer == 0.0:
		for mesh in _meshes:
			mesh.material_overlay = null
