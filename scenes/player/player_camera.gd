class_name PlayerCamera
extends Node3D
## Câmera em terceira pessoa sobre o ombro. Só apresentação: lê o look do InputReader
## e a posição interpolada do jogador. Dois SpringArm3D evitam atravessar paredes:
## um lateral (ombro) e um para trás (distância).

@export var camera_config: CameraConfig

@onready var yaw_node: Node3D = $Yaw
@onready var pitch_node: Node3D = $Yaw/Pitch
@onready var shoulder_arm: SpringArm3D = $Yaw/Pitch/ShoulderArm
@onready var back_arm: SpringArm3D = $Yaw/Pitch/ShoulderArm/BackArm
@onready var camera: Camera3D = $Yaw/Pitch/ShoulderArm/BackArm/Camera3D

var player: Player
## +1 = ombro direito, -1 = ombro esquerdo.
var shoulder_side: float = 1.0
var _shoulder_blend: float = 1.0
var _last_swap_tick: int = PlayerInput.NEVER


func _ready() -> void:
	player = get_parent() as Player
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if camera_config == null:
		camera_config = player.camera_config if player.camera_config != null else CameraConfig.new()
	shoulder_arm.add_excluded_object(player.get_rid())
	back_arm.add_excluded_object(player.get_rid())
	camera.current = true
	camera.fov = camera_config.base_fov
	# O Player (pai) termina o _ready depois dos filhos: posiciona no primeiro frame.
	_follow.call_deferred(0.0)


func _process(delta: float) -> void:
	_follow(delta)


func _follow(delta: float) -> void:
	var cfg := camera_config
	global_position = player.get_global_transform_interpolated().origin + Vector3.UP * cfg.pivot_height
	yaw_node.rotation = Vector3(0.0, player.input_reader.look_yaw, 0.0)
	pitch_node.rotation = Vector3(player.input_reader.look_pitch, 0.0, 0.0)
	var input := player.current_input
	if input.shoulder_swap_pressed and input.tick != _last_swap_tick:
		_last_swap_tick = input.tick
		shoulder_side = -shoulder_side
	_shoulder_blend = move_toward(_shoulder_blend, shoulder_side, cfg.shoulder_lerp_speed * delta) \
		if delta > 0.0 else shoulder_side
	# O braço do ombro aponta para +X (direita) ou -X (esquerda); o de trás desfaz a rotação.
	var side_angle := PI * 0.5 if _shoulder_blend >= 0.0 else -PI * 0.5
	shoulder_arm.rotation = Vector3(0.0, side_angle, 0.0)
	shoulder_arm.spring_length = absf(_shoulder_blend) * cfg.shoulder_offset
	shoulder_arm.margin = cfg.spring_margin
	back_arm.rotation = Vector3(0.0, -side_angle, 0.0)
	back_arm.spring_length = cfg.arm_length
	back_arm.margin = cfg.spring_margin
	var extra_speed := maxf(player.get_horizontal_speed() - player.config.walk_speed, 0.0)
	var target_fov := cfg.base_fov + minf(extra_speed * cfg.fov_bonus_per_speed, cfg.max_speed_fov_bonus)
	camera.fov = lerpf(camera.fov, target_fov, clampf(cfg.fov_lerp_speed * delta, 0.0, 1.0))
