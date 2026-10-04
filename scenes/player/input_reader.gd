class_name InputReader
extends Node
## ÚNICO ponto que lê `Input` para o jogador. Produz um PlayerInput por tick de física.
## O look (yaw/pitch) é acumulado aqui a partir do mouse e entra no PlayerInput,
## para a lógica nunca depender do nó da câmera.

@export var camera_config: CameraConfig

var look_yaw: float = 0.0
var look_pitch: float = 0.0
## Quando false, o reader devolve input neutro (ex.: menu de debug aberto).
var enabled: bool = true

var _jump_pressed_tick: int = PlayerInput.NEVER
var _dodge_pressed_tick: int = PlayerInput.NEVER
var _weapon_swap_pressed_tick: int = PlayerInput.NEVER
var _weapon_swap_slot: int = 0
var _forward_pressed_tick: int = PlayerInput.NEVER
var _attack_light_pressed_tick: int = PlayerInput.NEVER
var _attack_heavy_pressed_tick: int = PlayerInput.NEVER
var _forward_prev_pressed_tick: int = PlayerInput.NEVER


func _ready() -> void:
	look_pitch = deg_to_rad(camera_config.initial_pitch_deg)
	capture_mouse(true)


func capture_mouse(capture: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"release_mouse"):
		capture_mouse(false)
	elif event is InputEventMouseButton and event.pressed and enabled and not is_mouse_captured():
		capture_mouse(true)
	elif event is InputEventMouseMotion and is_mouse_captured() and enabled:
		var motion := event as InputEventMouseMotion
		var sens := camera_config.mouse_sensitivity
		var y_sign := 1.0 if camera_config.invert_y else -1.0
		look_yaw = wrapf(look_yaw - motion.relative.x * sens, -PI, PI)
		look_pitch = clampf(look_pitch + y_sign * motion.relative.y * sens,
			deg_to_rad(camera_config.pitch_min_deg), deg_to_rad(camera_config.pitch_max_deg))


## Amostra o input do tick atual. Chamar dentro de `_physics_process`.
func sample(tick: int) -> PlayerInput:
	var input := PlayerInput.new()
	input.tick = tick
	input.look_yaw = look_yaw
	input.look_pitch = look_pitch
	if enabled:
		if Input.is_action_just_pressed(&"jump"):
			_jump_pressed_tick = tick
		if Input.is_action_just_pressed(&"move_forward"):
			_forward_prev_pressed_tick = _forward_pressed_tick
			_forward_pressed_tick = tick
		if Input.is_action_just_pressed(&"weapon_slot_1"):
			_weapon_swap_pressed_tick = tick
			_weapon_swap_slot = 1
		elif Input.is_action_just_pressed(&"weapon_slot_2"):
			_weapon_swap_pressed_tick = tick
			_weapon_swap_slot = 2
		elif Input.is_action_just_pressed(&"weapon_toggle"):
			_weapon_swap_pressed_tick = tick
			_weapon_swap_slot = 0
		# O clique que só captura o mouse não ataca.
		if is_mouse_captured() or DisplayServer.get_name() == "headless":
			if Input.is_action_just_pressed(&"attack_light"):
				_attack_light_pressed_tick = tick
			if Input.is_action_just_pressed(&"attack_heavy"):
				_attack_heavy_pressed_tick = tick
		input.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
		input.jump_held = Input.is_action_pressed(&"jump")
		input.shoulder_swap_pressed = Input.is_action_just_pressed(&"shoulder_swap")
	input.jump_pressed_tick = _jump_pressed_tick
	input.dodge_pressed_tick = _dodge_pressed_tick
	input.weapon_swap_pressed_tick = _weapon_swap_pressed_tick
	input.weapon_swap_slot = _weapon_swap_slot
	input.attack_light_pressed_tick = _attack_light_pressed_tick
	input.attack_heavy_pressed_tick = _attack_heavy_pressed_tick
	input.forward_pressed_tick = _forward_pressed_tick
	input.forward_prev_pressed_tick = _forward_prev_pressed_tick
	return input

