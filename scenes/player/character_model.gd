class_name CharacterModel
extends Node3D
## Personagem anime (traje preto com linhas roxas emissivas, cabelo branco, olhos verdes).
## Modelo pronto do VRoid Studio (licença CC0) adaptado por tools/prepare_character.py, com
## shader toon e contorno. Só apresentação: lê o estado do Player e nunca altera gameplay.
## Frente = -Z, pés em y = 0.
##
## Animação: cada articulação persegue uma pose-alvo através de uma MOLA (frequência +
## amortecimento), o que dá peso, continuidade e um leve balanço — nada de poses rígidas.
## Camadas: locomoção (corrida com quadril/tronco em contra-rotação, inclinação nas curvas,
## respiração) → ar (mistura contínua subida/queda) → golpe (poses-chave de AttackPoses).
## As poses são escritas num esqueleto de referência (repouso = identidade, braços para baixo) e
## convertidas para os ossos do modelo (repouso em T-pose: os braços ganham uma rotação fixa).

const REFERENCE_HEIGHT: float = 1.8
const JOINTS: Array[StringName] = [
	&"lean", &"hips", &"spine", &"chest", &"head", &"shoulder_l", &"shoulder_r", &"elbow_l",
	&"elbow_r", &"wrist_l", &"wrist_r", &"thigh_l", &"thigh_r", &"knee_l", &"knee_r",
	&"foot_l", &"foot_r",
]
## Canais escalares (posição): altura do quadril.
const HIPS_Y: StringName = &"hips_y"
## Canal do cabelo (movimento secundário).
const HAIR: StringName = &"hair"

const MODEL_SCENE: PackedScene = preload("res://assets/character/hero.glb")
const SUIT_EMISSION: Texture2D = preload("res://assets/character/hero_suit_emission.png")
const TOON_SHADER: Shader = preload("res://scenes/player/feedback/anime_toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://scenes/player/feedback/outline.gdshader")
## Altura do modelo original (topo do cabelo), para escalar até REFERENCE_HEIGHT.
const MODEL_HEIGHT: float = 1.92
## Canal da animação → osso do modelo (nomes do VRoid).
const BONE_MAP: Dictionary = {
	&"hips": &"J_Bip_C_Hips", &"spine": &"J_Bip_C_Spine", &"chest": &"J_Bip_C_Chest",
	&"head": &"J_Bip_C_Head",
	&"shoulder_l": &"J_Bip_L_UpperArm", &"elbow_l": &"J_Bip_L_LowerArm", &"wrist_l": &"J_Bip_L_Hand",
	&"shoulder_r": &"J_Bip_R_UpperArm", &"elbow_r": &"J_Bip_R_LowerArm", &"wrist_r": &"J_Bip_R_Hand",
	&"thigh_l": &"J_Bip_L_UpperLeg", &"knee_l": &"J_Bip_L_LowerLeg", &"foot_l": &"J_Bip_L_Foot",
	&"thigh_r": &"J_Bip_R_UpperLeg", &"knee_r": &"J_Bip_R_LowerLeg", &"foot_r": &"J_Bip_R_Foot",
}
## Cadeia do braço direito até a mão (para posicionar a arma sem esperar o esqueleto atualizar).
const RIGHT_ARM_CHAIN: Array[StringName] = [
	&"J_Bip_C_Spine", &"J_Bip_C_Chest", &"J_Bip_C_UpperChest", &"J_Bip_R_Shoulder",
	&"J_Bip_R_UpperArm", &"J_Bip_R_LowerArm", &"J_Bip_R_Hand",
]
## Distância do pulso ao centro da palma (unidades do modelo).
const PALM_OFFSET: float = 0.06
const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Little"]
## Quanto cada falange dobra em relação à base.
const PHALANX_CURL: Array[float] = [1.0, 1.1, 0.8]
## Braço da arma com a lâmina apoiada no ombro (armas com `rest_on_shoulder`).
const SHOULDER_REST: Dictionary = {
	&"shoulder_r": Vector3(0.25, 0.07, 0.1),
	&"elbow_r": Vector3(1.2, 0, 0),
	&"wrist_r": Vector3(1.1, -0.1, -0.39),
}
## Quanto o quadril sobe no meio da estrela (mãos no chão, corpo de ponta-cabeça).
const CARTWHEEL_LIFT: float = 0.2
## Balanço do cabelo aplicado às mechas presas à cabeça.
const HAIR_SWAY: float = 0.8

var player: Player
var weapon_visual: WeaponVisual
var trail: WeaponTrail

var _bones: Dictionary = {}  # canal -> índice do osso
var _skeleton: Skeleton3D
var _rig: Node3D
var _rig_scale: float = 1.0
var _hips_rest: Vector3 = Vector3.ZERO
## Rotação fixa que leva o braço da T-pose para "braço abaixado" (repouso da animação).
var _arm_ref: Dictionary = {}
var _arm_offsets: Array[Vector3] = []
var _hair_roots: PackedInt32Array = PackedInt32Array()
var _face: MeshInstance3D
var _blink_shape: int = -1
var _brow_shape: int = -1
var _blink_timer: float = 2.0
var _blink_t: float = -1.0
var _brow: float = 0.0
var _lean: Node3D
var _trick: Node3D
var _socket: Node3D
var _materials: Array[ShaderMaterial] = []
var _suit_material: ShaderMaterial

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
## Rotações globais (espaço do modelo) da animação de referência, por canal.
var _global: Dictionary = {}
var _last_step_side: int = 0
var _sprint_amount: float = 0.0


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
	_lean = Node3D.new()
	add_child(_lean)
	_trick = Node3D.new()
	_lean.add_child(_trick)
	_rig = MODEL_SCENE.instantiate() as Node3D
	_rig_scale = REFERENCE_HEIGHT / MODEL_HEIGHT
	_rig.scale = Vector3.ONE * _rig_scale
	_trick.add_child(_rig)
	_skeleton = _rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for channel: StringName in BONE_MAP:
		_bones[channel] = _skeleton.find_bone(BONE_MAP[channel])
	_hips_rest = _skeleton.get_bone_rest(_bones[&"hips"]).origin
	# O quadril fica na origem de _trick, então o mortal/cambalhota gira em torno dele.
	_trick.position = Vector3(0, _hips_rest.y * _rig_scale, 0)
	_rig.position = -_hips_rest * _rig_scale
	# T-pose → braço abaixado: esquerdo (-X) gira +90° em Z, direito (+X) gira -90°.
	_arm_ref[&"l"] = Quaternion(Vector3.BACK, PI * 0.5)
	_arm_ref[&"r"] = Quaternion(Vector3.BACK, -PI * 0.5)
	for bone_name in RIGHT_ARM_CHAIN:
		_arm_offsets.append(_skeleton.get_bone_rest(_skeleton.find_bone(bone_name)).origin)
	var head := _bones[&"head"] as int
	for i in _skeleton.get_bone_count():
		if _skeleton.get_bone_parent(i) == head and _skeleton.get_bone_name(i).begins_with("HairJoint"):
			_hair_roots.append(i)
	_pose_fingers()
	_setup_materials()
	_face = _rig.find_child("Face", true, false) as MeshInstance3D
	if _face != null:
		_blink_shape = _find_blend_shape(_face.mesh, "Fcl_EYE_Close")
		_brow_shape = _find_blend_shape(_face.mesh, "Fcl_BRW_Angry")
	# Encaixe da arma: posicionado por código a cada quadro (escala desfeita para a arma).
	_socket = Node3D.new()
	_rig.add_child(_socket)


func _pose_fingers() -> void:
	var fb := _fb()
	for side in ["L", "R"]:
		# Dedos esticados em T-pose apontam para ±X; dobrar = girar para a palma (-Y) em torno de Z.
		var curl := fb.relaxed_curl if side == "L" else -fb.grip_curl
		for finger in FINGERS:
			for i in 3:
				var bone := _skeleton.find_bone("J_Bip_%s_%s%d" % [side, finger, i + 1])
				if bone >= 0:
					_skeleton.set_bone_pose_rotation(bone, Quaternion(Vector3.BACK, curl * PHALANX_CURL[i]))
		var thumb := _skeleton.find_bone("J_Bip_%s_Thumb2" % side)
		if thumb >= 0:
			_skeleton.set_bone_pose_rotation(thumb, Quaternion(Vector3.UP, curl * 0.5))


func _find_blend_shape(mesh: Mesh, suffix: String) -> int:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		return -1
	for i in array_mesh.get_blend_shape_count():
		if String(array_mesh.get_blend_shape_name(i)).ends_with(suffix):
			return i
	return -1


## Troca os materiais importados por toon (variantes: opaco, dupla face, translúcido).
func _setup_materials() -> void:
	var fb := _fb()
	var cache := {}
	var shaders := {}
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter(&"outline_color", fb.outline_color)
	outline.set_shader_parameter(&"thickness", fb.outline_thickness / _rig_scale)
	for mesh: MeshInstance3D in _rig.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(i) as BaseMaterial3D
			if source == null:
				continue
			var key := source.resource_name
			if not cache.has(key):
				cache[key] = _make_toon(source, shaders, outline)
			mesh.set_surface_override_material(i, cache[key])


func _make_toon(source: BaseMaterial3D, shaders: Dictionary, outline: ShaderMaterial) -> ShaderMaterial:
	var fb := _fb()
	var mat_name := source.resource_name
	var blend := source.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA,
		BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]
	var double_sided := source.cull_mode == BaseMaterial3D.CULL_DISABLED
	var variant := "%s_%s" % [blend, double_sided]
	if not shaders.has(variant):
		var shader := Shader.new()
		var mode := "render_mode %s, %s, specular_disabled;" % [
			"cull_disabled" if double_sided else "cull_back",
			"blend_mix, depth_draw_never" if blend else "depth_draw_opaque"]
		var code := TOON_SHADER.code.replace("render_mode cull_back, specular_disabled;", mode)
		if blend:
			code = code.replace("\tALPHA_SCISSOR_THRESHOLD = alpha_cut;\n", "")
		shader.code = code
		shaders[variant] = shader
	var material := ShaderMaterial.new()
	material.shader = shaders[variant]
	material.render_priority = 1 if blend else 0
	material.set_shader_parameter(&"albedo_tex", source.albedo_texture)
	material.set_shader_parameter(&"shade_color", fb.shade_color)
	material.set_shader_parameter(&"shade_threshold", fb.shade_threshold)
	material.set_shader_parameter(&"shade_softness", fb.shade_softness)
	material.set_shader_parameter(&"rim_color", fb.rim_color)
	material.set_shader_parameter(&"rim_strength", fb.rim_strength)
	var is_face := mat_name.contains("FACE") or mat_name.contains("EYE") or mat_name.contains("Face_00")
	if is_face:
		material.set_shader_parameter(&"shading_strength", fb.face_shading)
		material.set_shader_parameter(&"rim_strength", 0.0)
		if mat_name.contains("Face_00_SKIN"):
			material.set_shader_parameter(&"tint", fb.face_tint)
	if mat_name.contains("HAIR"):
		material.set_shader_parameter(&"tint", fb.hair_color)
	if mat_name.contains("Body_00_SKIN"):
		_suit_material = material
		material.set_shader_parameter(&"emission_tex", SUIT_EMISSION)
		material.set_shader_parameter(&"emission_tint", fb.suit_glow_tint)
		material.set_shader_parameter(&"emission_energy", fb.suit_glow_energy)
	if not blend and not is_face:
		var pass_material := outline.duplicate() as ShaderMaterial
		pass_material.set_shader_parameter(&"albedo_tex", source.albedo_texture)
		material.next_pass = pass_material
	_materials.append(material)
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
	_flash_color = color
	_flash_duration = maxf(duration, 0.001)
	_flash_timer = duration
	_flash_energy = energy


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


## O mortal espera enquanto o personagem está colado na parede (antes do impulso).
func _is_wall_sticking() -> bool:
	return player.state_machine.is_in(&"WallJump") and player.state_machine.current.call(&"is_sticking")


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
			if player.state_machine.current.get(&"airborne") == true:
				_air_pose(pose)
			else:
				_ground_pose(pose, false, accel)
			attack_weight = _attack_pose(pose)
		&"Jump", &"Fall" when player.air_sprinting:
			_air_sprint_pose(pose)
		&"WallJump" when _trick_face_wall and (_is_wall_sticking() or _trick_timer > _fb().flip_duration * 0.75):
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
	_update_face(state, delta)


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
	var cfg := player.config
	var amount := clampf(_run_amount, 0.0, 1.0)
	var calm := 1.0 - amount
	var speed := player.get_horizontal_speed()
	var run_k := clampf((speed - cfg.walk_speed) / maxf(cfg.sprint_speed - cfg.walk_speed, 0.01), 0.0, 1.0)
	_sprint_amount = move_toward(_sprint_amount, 1.0 if sprinting else 0.0, get_process_delta_time() * 6.0)
	var arm_swing := deg_to_rad(fb.arm_swing_deg) * amount
	# Parado: respiração lenta e peso numa perna (a outra relaxada, joelho levemente dobrado).
	var breath := sin(_time * TAU / maxf(fb.breath_period, 0.1))
	var depth := deg_to_rad(fb.breath_depth_deg)
	var shift := deg_to_rad(fb.idle_weight_shift_deg) * calm
	var stance := deg_to_rad(fb.idle_stance_width_deg) * calm
	# O corpo inteiro inclina a partir do quadril; as coxas compensam quase tudo para os pés
	# continuarem embaixo do corpo (linha diagonal do pé de trás até a cabeça).
	var lean := lerpf(deg_to_rad(fb.run_lean_deg) * amount, deg_to_rad(fb.ninja_run_lean_deg), _sprint_amount)
	_legs(pose, amount, run_k, lean, stance, shift, calm)
	# Braço livre balança oposto à perna; ombros sobem de leve ao inspirar.
	var lift := breath * depth * 0.8 * calm
	pose[&"shoulder_l"] = Vector3(-sin(_phase) * arm_swing + 0.1 + lean * 0.5, 0, -0.16 - 0.1 * amount - lift)
	pose[&"elbow_l"] = Vector3(0.35 + 0.9 * amount, 0, 0)
	pose[&"shoulder_r"] = Vector3(lerpf(0.35, -0.45, amount) + sin(_phase) * arm_swing * 0.25 + lean * 0.5,
		0.05, 0.18 + 0.12 * amount + lift)
	pose[&"elbow_r"] = Vector3(lerpf(0.75, 0.35, amount), 0, 0)
	pose[&"wrist_r"] = Vector3(lerpf(-0.35, 3.3, amount), 0, 0)
	var accel_lean := clampf(accel * 0.01, -0.15, 0.2)
	pose[&"hips"] = Vector3(-lean, sin(_phase) * 0.15 * amount, -shift * 0.6)
	pose[&"spine"] = Vector3(-accel_lean - lean * 0.1 + breath * depth * 0.3 * calm, -sin(_phase) * 0.12 * amount,
		shift * 0.3)
	pose[&"chest"] = Vector3(breath * depth * calm, -sin(_phase) * 0.14 * amount, shift * 0.2)
	# Cabeça: olha para frente apesar da inclinação, compensa a respiração e olha em volta devagar.
	pose[&"head"] = Vector3(lean * 0.75 - breath * depth * 0.5 * calm,
		sin(_phase) * 0.12 * amount + sin(_time * 0.23) * 0.07 * calm, 0)
	var weapon := player.get_weapon()
	if weapon != null and weapon.rest_on_shoulder:
		# Lâmina apoiada no ombro direito (parado e andando).
		for key: StringName in SHOULDER_REST:
			pose[key] = SHOULDER_REST[key]
		pose[&"shoulder_r"] += Vector3(sin(_phase) * arm_swing * 0.1 + lift, 0, 0)
	if _sprint_amount > 0.0:
		_ninja_run(pose, _sprint_amount)


## Passada realista por perna: apoio (contato com o calcanhar → carga com o joelho um pouco
## dobrado → impulso na ponta do pé) e balanço (joelho sobe dobrado e estica antes do contato).
func _legs(pose: Dictionary, amount: float, run_k: float, lean: float, stance: float, shift: float,
		calm: float) -> void:
	var fb := _fb()
	var stance_frac := lerpf(fb.stance_fraction_walk, fb.stance_fraction_run, run_k)
	var swing_range := deg_to_rad(fb.leg_swing_deg) * amount * lerpf(1.0, 1.3, run_k)
	var front := swing_range * 0.58
	var back := swing_range * 0.42
	var knee_swing := deg_to_rad(fb.knee_bend_deg) * amount * lerpf(0.9, 1.6, run_k)
	var knee_load := deg_to_rad(lerpf(fb.stance_knee_walk_deg, fb.stance_knee_run_deg, run_k)) * amount
	var compensate := lean * 0.8
	for i in 2:
		var side := "l" if i == 0 else "r"
		var u := fposmod((_phase + PI * i) / TAU, 1.0)
		var thigh: float
		var knee: float
		var ankle: float
		if u < stance_frac:
			var t := u / stance_frac
			thigh = lerpf(front, -back, t)
			knee = -knee_load * sin(PI * t)
			# Calcanhar no contato (ponta para cima), pé plano, impulso na ponta no fim do apoio.
			ankle = 0.18 * maxf(0.0, 1.0 - t * 4.0) - 0.55 * pow(maxf(0.0, (t - 0.65) / 0.35), 2.0)
			ankle *= amount
		else:
			var t := (u - stance_frac) / (1.0 - stance_frac)
			thigh = -back + (front + back) * (0.5 - 0.5 * cos(PI * t))
			knee = -knee_swing * sin(PI * minf(t / 0.8, 1.0))
			# Saindo do impulso com a ponta para baixo, depois levanta a ponta para não arrastar.
			ankle = (-0.5 * pow(1.0 - t, 3.0) + 0.15 * sin(PI * t)) * amount
		var relaxed := 1.0 if i == 1 else 0.0  # parado: perna direita relaxada
		# Pernas abertas parado: esquerda gira -Z (para fora), direita +Z; o pé compensa.
		var out := -stance if i == 0 else stance
		thigh += compensate + 0.08 * relaxed * calm
		knee -= (0.06 + 0.14 * relaxed) * calm
		pose[StringName("thigh_" + side)] = Vector3(thigh, 0, out + shift)
		pose[StringName("knee_" + side)] = Vector3(knee, 0, 0)
		# Pé plano em relação ao chão: desfaz a inclinação acumulada (quadril + coxa + joelho).
		var flat := lean - thigh - knee
		pose[StringName("foot_" + side)] = Vector3(flat + ankle + 0.05 * relaxed * calm, 0, -out - shift)
	# Sobe-desce: andando o ponto mais alto é no meio do apoio; correndo, o mais baixo.
	var mid := cos(2.0 * (_phase - PI * stance_frac))
	var bob := _fb().run_bob_height * amount * lerpf(mid, -mid, run_k) * 0.5
	pose[HIPS_Y] = Vector3(bob - 0.02 * calm - 0.03 * amount, 0, 0)


## Corrida "ninja": corpo inteiro mergulhado (vem do quadril, em _ground_pose), cabeça erguida e
## braços esticados para trás NA HORIZONTAL — o ângulo do ombro desconta a inclinação do tronco.
func _ninja_run(pose: Dictionary, weight: float) -> void:
	var fb := _fb()
	var bounce := sin(_phase * 2.0) * 0.04
	var torso_forward := -((pose[&"hips"] as Vector3).x + (pose[&"spine"] as Vector3).x
		+ (pose[&"chest"] as Vector3).x)
	# Com o tronco inclinado para frente, o braço solto já aponta um pouco para trás; falta
	# girar (90° − inclinação) para ficar paralelo ao chão.
	var back := -(PI * 0.5 - torso_forward + deg_to_rad(fb.ninja_arm_pitch_deg))
	var target := {
		&"head": Vector3(torso_forward * 0.85, 0, 0),
		&"shoulder_l": Vector3(back + bounce, 0, -0.18),
		&"shoulder_r": Vector3(back - bounce, 0, 0.18),
		&"elbow_l": Vector3(0.05, 0, 0),
		&"elbow_r": Vector3(0.05, 0, 0),
		&"wrist_l": Vector3(-0.2, 0, 0),
		&"wrist_r": Vector3(-1.4, 0, 0),  # lâmina alinhada ao braço, arrastando atrás
	}
	for key: StringName in target:
		pose[key] = (pose[key] as Vector3).lerp(target[key], weight)


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
	pose[&"hips"] = Vector3(-0.5, 0, 0)
	pose[&"spine"] = Vector3(-0.1, 0, 0)
	pose[&"thigh_l"] = Vector3(0.3 + cycle * 0.6, 0, 0)
	pose[&"thigh_r"] = Vector3(0.3 - cycle * 0.6, 0, 0)
	pose[&"knee_l"] = Vector3(-0.9 - maxf(cycle, 0.0) * 0.6, 0, 0)
	pose[&"knee_r"] = Vector3(-0.9 - maxf(-cycle, 0.0) * 0.6, 0, 0)
	_ninja_run(pose, 1.0)


## Colado na parede: agachado de frente para ela, um pé plantado alto e o outro embaixo,
## tronco ereto, braços abrindo para o mortal.
func _wall_kick_pose(pose: Dictionary) -> void:
	# Bem encolhido: joelhos no peito, tronco curvado para a parede, braços recolhidos.
	pose[HIPS_Y] = Vector3(-0.28, 0, 0)
	pose[&"thigh_l"] = Vector3(1.75, 0, 0.1)
	pose[&"thigh_r"] = Vector3(1.35, 0, -0.1)
	pose[&"knee_l"] = Vector3(-2.3, 0, 0)
	pose[&"knee_r"] = Vector3(-2.0, 0, 0)
	pose[&"foot_l"] = Vector3(0.5, 0, 0)
	pose[&"foot_r"] = Vector3(0.4, 0, 0)
	pose[&"spine"] = Vector3(-0.35, 0, 0)
	pose[&"chest"] = Vector3(-0.2, 0, 0)
	pose[&"head"] = Vector3(0.35, 0, 0)
	pose[&"shoulder_l"] = Vector3(1.6, 0, -0.6)
	pose[&"shoulder_r"] = Vector3(1.4, 0, 0.6)
	pose[&"elbow_l"] = Vector3(0.5, 0, 0)
	pose[&"elbow_r"] = Vector3(0.5, 0, 0)


## Cambalhota: corpo encolhido (joelhos no peito, cabeça baixa, braços abraçando as pernas).
func _roll_pose(pose: Dictionary) -> void:
	# O corpo inteiro desce pelo pivô (_update_trick); aqui só a bola: costas arredondadas,
	# queixo no peito, joelhos colados no peito.
	pose[HIPS_Y] = Vector3(0, 0, 0)
	pose[&"spine"] = Vector3(-0.9, 0, 0)
	pose[&"chest"] = Vector3(-0.5, 0, 0)
	pose[&"head"] = Vector3(-0.55, 0, 0)
	pose[&"thigh_l"] = Vector3(2.1, 0, 0.12)
	pose[&"thigh_r"] = Vector3(2.1, 0, -0.12)
	pose[&"knee_l"] = Vector3(-2.4, 0, 0)
	pose[&"knee_r"] = Vector3(-2.4, 0, 0)
	pose[&"shoulder_l"] = Vector3(1.2, 0, 0.1)
	pose[&"shoulder_r"] = Vector3(1.0, 0, -0.1)
	pose[&"elbow_l"] = Vector3(1.4, 0, 0)
	pose[&"elbow_r"] = Vector3(1.2, 0, 0)


func _dodge_pose(pose: Dictionary) -> void:
	var fb := _fb()
	if fb.dash_cartwheel and _dash_progress() < 1.0:
		_cartwheel_pose(pose)
		return
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


## Estrela: braços abertos acima da cabeça e pernas afastadas (o giro vem de _update_trick).
func _cartwheel_pose(pose: Dictionary) -> void:
	pose[HIPS_Y] = Vector3.ZERO
	pose[&"spine"] = Vector3(0.05, 0, 0)
	pose[&"head"] = Vector3(0.1, 0, 0)
	pose[&"shoulder_l"] = Vector3(0.15, 0, -2.5)
	pose[&"shoulder_r"] = Vector3(0.15, 0, 2.5)
	pose[&"elbow_l"] = Vector3(0.1, 0, 0)
	pose[&"elbow_r"] = Vector3(0.1, 0, 0)
	pose[&"thigh_l"] = Vector3(0.05, 0, -0.6)
	pose[&"thigh_r"] = Vector3(0.05, 0, 0.6)
	pose[&"knee_l"] = Vector3(-0.15, 0, 0)
	pose[&"knee_r"] = Vector3(-0.15, 0, 0)


## Progresso do deslocamento do dash (1 fora do dash).
func _dash_progress() -> float:
	if not player.state_machine.is_in(&"Dodge"):
		return 1.0
	return player.state_machine.current.call(&"get_dash_progress")


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
	if player.get_state_name() != &"Attack" and weapon_visual != null:
		weapon_visual.set_boost(player.get_heavy_charge())
	for joint in JOINTS:
		var value := _spring(joint, pose[joint], frequency, damping, delta)
		if joint == &"lean":
			_lean.rotation = value
		else:
			_set_joint(joint, Quaternion.from_euler(value))
	var hips_y := _spring(HIPS_Y, pose[HIPS_Y], frequency, damping, delta)
	var hips_pos := _hips_rest + Vector3(0, hips_y.x / _rig_scale, 0)
	_skeleton.set_bone_pose_position(_bones[&"hips"], hips_pos)
	_update_socket(hips_pos)


## Escreve a rotação local de referência no osso do modelo (braços: conversão da T-pose).
func _set_joint(joint: StringName, local: Quaternion) -> void:
	var joint_name := String(joint)
	var parent: StringName = &""
	match joint_name.get_slice("_", 0):
		"spine": parent = &"hips"
		"chest": parent = &"spine"
		"head", "shoulder": parent = &"chest"
		"elbow": parent = StringName("shoulder_" + joint_name.right(1))
		"wrist": parent = StringName("elbow_" + joint_name.right(1))
		"thigh": parent = &"hips"
		"knee": parent = StringName("thigh_" + joint_name.right(1))
		"foot": parent = StringName("knee_" + joint_name.right(1))
	_global[joint] = (_global[parent] as Quaternion) * local if parent != &"" else local
	var bone_local := local
	if joint_name.begins_with("shoulder") or joint_name.begins_with("elbow") or joint_name.begins_with("wrist"):
		var ref: Quaternion = _arm_ref[StringName(joint_name.right(1))]
		bone_local = local * ref if joint_name.begins_with("shoulder") else ref.inverse() * local * ref
	_skeleton.set_bone_pose_rotation(_bones[joint], bone_local)


## Arma na palma da mão direita, calculada pela mesma cadeia de rotações dos ossos.
func _update_socket(hips_pos: Vector3) -> void:
	var ref: Quaternion = _arm_ref[&"r"]
	var chest: Quaternion = _global[&"chest"]
	var rotations: Array[Quaternion] = [
		_global[&"hips"], _global[&"spine"], chest, chest, chest,
		(_global[&"shoulder_r"] as Quaternion) * ref, (_global[&"elbow_r"] as Quaternion) * ref,
	]
	var pos := hips_pos
	for i in _arm_offsets.size():
		pos += rotations[i] * _arm_offsets[i]
	var wrist: Quaternion = _global[&"wrist_r"]
	pos += wrist * Vector3(0, -PALM_OFFSET, 0)
	_socket.transform = Transform3D(Basis(wrist) * Basis.from_scale(Vector3.ONE / _rig_scale), pos)


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
	var sway := hair.x + sin(_time * 9.0) * 0.02 * clampf(speed / 10.0, 0.0, 1.0)
	# Mechas penduradas: girar para -X em torno de X joga a ponta para trás (+Z).
	var hair_rotation := Quaternion(Vector3.RIGHT, -sway * HAIR_SWAY)
	for bone in _hair_roots:
		_skeleton.set_bone_pose_rotation(bone, hair_rotation)


func _emit_footsteps(speed: float, cfg: MovementConfig) -> void:
	if speed < 1.0:
		return
	var side := 0 if sin(_phase) >= 0.0 else 1
	if side != _last_step_side:
		_last_step_side = side
		GameEvents.footstep.emit(player, clampf(speed / cfg.sprint_speed, 0.0, 1.0))


func _update_trick(delta: float) -> void:
	var basis := Basis(Vector3.UP, _spin_angle)
	if _trick_timer > 0.0 and _is_wall_sticking():
		if _trick_face_wall:
			basis = basis * Basis(Vector3.UP, PI)
	elif _trick_timer > 0.0:
		_trick_timer = maxf(_trick_timer - delta, 0.0)
		var t := 1.0 - _trick_timer / maxf(_fb().flip_duration, 0.001)
		var eased := t * t * (3.0 - 2.0 * t)
		if _trick_face_wall:
			basis = basis * Basis(Vector3.UP, PI * (1.0 - eased))
		basis = basis * Basis(_trick_axis, _trick_angle * eased)
	var pivot_y := _hips_rest.y * _rig_scale
	if _trick_timer <= 0.0 and _is_rolling():
		# Cambalhota para frente: o centro do corpo desce até a altura da "bola" para as costas
		# rolarem no chão, e sobe de novo no fim.
		var roll: float = player.state_machine.current.call(&"get_roll_progress")
		basis = basis * Basis(Vector3.RIGHT, -TAU * _ease_in_out(roll))
		var down := clampf(minf(roll / 0.18, (1.0 - roll) / 0.25), 0.0, 1.0)
		pivot_y = lerpf(pivot_y, _fb().roll_ball_height, _ease_in_out(down))
	var dash := _dash_progress()
	if _trick_timer <= 0.0 and _fb().dash_cartwheel and dash < 1.0:
		# Cambalhota lateral: gira em torno do eixo da frente, para o lado do dash.
		var dir: Vector3 = player.state_machine.current.call(&"get_direction")
		var side := signf((player.visual.global_basis.inverse() * dir).x)
		var eased := _ease_in_out(dash)
		basis = basis * Basis(Vector3.BACK, -side * TAU * eased)
		pivot_y += CARTWHEEL_LIFT * sin(PI * eased)
	_trick.basis = basis
	_trick.position.y = pivot_y


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
	var glow := _flash_color * (_flash_energy * k * 0.25)
	for material in _materials:
		material.set_shader_parameter(&"flash_color", Color(glow.r, glow.g, glow.b))
	if _suit_material != null:
		_suit_material.set_shader_parameter(&"emission_tint", fb.suit_glow_tint.lerp(_flash_color, k))
		_suit_material.set_shader_parameter(&"emission_energy", lerpf(fb.suit_glow_energy,
			fb.suit_glow_energy * 2.0, k))


## Piscar de tempos em tempos e sobrancelhas franzidas ao golpear/apanhar.
func _update_face(state: StringName, delta: float) -> void:
	if _face == null:
		return
	var fb := _fb()
	if _blink_shape >= 0:
		if _blink_t >= 0.0:
			_blink_t += delta / maxf(fb.blink_duration, 0.01)
			if _blink_t >= 1.0:
				_blink_t = -1.0
				_blink_timer = fb.blink_interval * randf_range(0.6, 1.4)
		else:
			_blink_timer -= delta
			if _blink_timer <= 0.0:
				_blink_t = 0.0
		_face.set_blend_shape_value(_blink_shape, sin(PI * _blink_t) if _blink_t >= 0.0 else 0.0)
	if _brow_shape >= 0:
		var target := 0.8 if state in [&"Attack", &"Hurt"] or player.get_heavy_charge() > 0.0 else 0.0
		_brow = move_toward(_brow, target, delta * 5.0)
		_face.set_blend_shape_value(_brow_shape, _brow)
