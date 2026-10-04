class_name PlayerCamera
extends Node3D
## Câmera em terceira pessoa sobre o ombro. Só apresentação: lê o look do InputReader
## e a posição interpolada do jogador. Dois SpringArm3D evitam atravessar paredes:
## um lateral (ombro) e um para trás (distância).

const SPEED_LINES_SHADER: Shader = preload("res://scenes/player/feedback/speed_lines.gdshader")

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
## Trauma do tremor (0–1); o deslocamento cresce com trauma².
var _trauma: float = 0.0
## 0–1: quanto da sensação de velocidade está ativa (suavizado).
var _speed_fx: float = 0.0
var _speed_lines: ColorRect
var _speed_material: ShaderMaterial
var _shake_time: float = 0.0


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
	_build_speed_lines()
	GameEvents.wall_jump_executed.connect(func(who: Node, _data: Dictionary) -> void:
		if who == player:
			add_trauma(camera_config.shake_on_wall_jump))
	GameEvents.landed.connect(func(who: Node, impact: float) -> void:
		if who == player and impact > camera_config.shake_land_min_speed:
			add_trauma((impact - camera_config.shake_land_min_speed) * camera_config.shake_land_per_speed))


func _build_speed_lines() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_speed_lines = ColorRect.new()
	_speed_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_material = ShaderMaterial.new()
	_speed_material.shader = SPEED_LINES_SHADER
	_speed_lines.material = _speed_material
	layer.add_child(_speed_lines)


func _update_speed_lines() -> void:
	var cfg := camera_config
	var size := get_viewport().get_visible_rect().size
	_speed_material.set_shader_parameter(&"intensity", _speed_fx)
	_speed_material.set_shader_parameter(&"max_alpha", cfg.speed_lines_max_alpha)
	_speed_material.set_shader_parameter(&"line_color", cfg.speed_lines_color)
	_speed_material.set_shader_parameter(&"line_count", cfg.speed_lines_count)
	_speed_material.set_shader_parameter(&"inner_radius", cfg.speed_lines_inner_radius)
	_speed_material.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))
	_speed_lines.visible = _speed_fx > 0.01


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_follow(delta)
	_update_shake(delta)
	_update_speed_lines()


func _update_shake(delta: float) -> void:
	var cfg := camera_config
	_trauma = maxf(_trauma - cfg.shake_decay * delta, 0.0)
	_shake_time += delta
	# Tremor contínuo leve em alta velocidade, somado ao trauma dos impactos.
	var trauma := maxf(_trauma, cfg.speed_shake_trauma * _speed_fx)
	var amount := trauma * trauma * cfg.shake_max_offset
	var t := _shake_time * cfg.shake_frequency
	camera.h_offset = amount * (sin(t * 1.0) + sin(t * 2.31) * 0.5)
	camera.v_offset = amount * (sin(t * 1.37 + 1.7) + sin(t * 2.89) * 0.5)


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
	var speed := player.get_horizontal_velocity().length()
	var target_fx := clampf((speed - cfg.speed_fx_start_speed)
		/ maxf(cfg.speed_fx_full_speed - cfg.speed_fx_start_speed, 0.01), 0.0, 1.0)
	_speed_fx = lerpf(_speed_fx, target_fx, clampf(cfg.fov_lerp_speed * delta, 0.0, 1.0)) \
		if delta > 0.0 else target_fx
	back_arm.spring_length = cfg.arm_length + cfg.speed_arm_bonus * _speed_fx
	back_arm.margin = cfg.spring_margin
	var extra_speed := maxf(player.get_horizontal_speed() - player.config.walk_speed, 0.0)
	var target_fov := cfg.base_fov + minf(extra_speed * cfg.fov_bonus_per_speed, cfg.max_speed_fov_bonus)
	camera.fov = lerpf(camera.fov, target_fov, clampf(cfg.fov_lerp_speed * delta, 0.0, 1.0))
