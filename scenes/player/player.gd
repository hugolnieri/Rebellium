class_name Player
extends CharacterBody3D
## Corpo do jogador: cápsula + "motor" de movimento (helpers usados pelos estados).
## Fluxo por tick: input → SP.update → estado.physics_update → move_and_slide → estado.post_move.
## A lógica só consome PlayerInput; `step()` pode ser chamado por testes/replay.

@export var config: MovementConfig
@export var camera_config: CameraConfig
@export var feedback_config: FeedbackConfig
## Se true, `_physics_process` não amostra input sozinho: quem controla chama `step()`.
@export var external_control: bool = false

@onready var input_reader: InputReader = $InputReader
@onready var state_machine: StateMachine = $StateMachine
@onready var visual: Node3D = $Visual
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var model: CharacterModel = $Visual/Model
@onready var wall_sensor: WallSensor = $WallSensor

var sp: SPPool
## Tick de simulação deste jogador (incrementa a cada `step`).
var tick: int = 0
var current_input: PlayerInput = PlayerInput.new()
## Como o jogador entrou no ar. Wall jump exige JUMP (nunca FALL).
var air_origin: MovementRules.AirOrigin = MovementRules.AirOrigin.NONE
var last_jump_tick: int = PlayerInput.NEVER
var left_floor_tick: int = PlayerInput.NEVER
var land_tick: int = PlayerInput.NEVER
## Velocidade vertical (positiva) no último impacto com o chão.
var land_impact_speed: float = 0.0
## Velocidade antes do move_and_slide deste tick (a colisão "come" a componente contra a parede).
var pre_slide_velocity: Vector3 = Vector3.ZERO
## Sprint ativado por toque duplo em W; dura enquanto W estiver pressionado.
var sprint_latched: bool = false
## Flag de invencibilidade (dodge). Consultada pelo combate futuro.
var is_invulnerable: bool = false
var spawn_transform: Transform3D
## Parede (collider id) do último wall jump, para o bloqueio de mesma parede.
var last_wall_jump_collider: int = 0
## Back-coming libera UM wall jump extra nesta parede.
var back_coming_wall: int = 0
var last_wall_jump_tick: int = PlayerInput.NEVER
## Velocidade antes do último wall jump (usada pelo cancel).
var wall_jump_entry_velocity: Vector3 = Vector3.ZERO

var _consumed_jump_press_tick: int = PlayerInput.NEVER
var _consumed_dodge_press_tick: int = PlayerInput.NEVER
var _consumed_weapon_press_tick: int = PlayerInput.NEVER


func _ready() -> void:
	add_to_group(&"local_player")
	if config == null:
		push_warning("Player sem MovementConfig; usando valores padrão.")
		config = MovementConfig.new()
	if feedback_config == null:
		feedback_config = FeedbackConfig.new()
	apply_body_config()
	config.changed.connect(apply_body_config)
	sp = SPPool.new(config)
	sp.depleted.connect(func() -> void: GameEvents.sp_depleted.emit(self))
	sp.recovered.connect(func() -> void: GameEvents.sp_recovered.emit(self))
	spawn_transform = global_transform
	wall_sensor.setup(self)
	state_machine.setup(self)


## Aplica dimensões da cápsula e parâmetros de chão da config (chamar após editar a config).
func apply_body_config() -> void:
	var capsule := body_shape.shape as CapsuleShape3D
	capsule.radius = config.body_radius
	capsule.height = config.body_height
	body_shape.position = Vector3(0.0, config.body_height * 0.5, 0.0)
	model.apply_body_height(config.body_height)
	floor_max_angle = deg_to_rad(config.floor_max_angle_deg)
	floor_snap_length = config.floor_snap_length


func _physics_process(delta: float) -> void:
	if external_control:
		return
	step(input_reader.sample(tick + 1), delta)


## Avança um tick de simulação com o input dado.
func step(input: PlayerInput, delta: float) -> void:
	tick += 1
	input.tick = tick
	current_input = input
	if input.is_pressed_this_tick(input.weapon_swap_pressed_tick):
		GameEvents.weapon_swap_pressed.emit(self, input.weapon_swap_slot)
	sp.update(delta)
	_update_sprint_latch(input)
	state_machine.physics_update(input, delta)
	pre_slide_velocity = velocity
	move_and_slide()
	wall_sensor.update(pre_slide_velocity)
	state_machine.post_move(input)
	_update_visual(delta)


# --- Consultas -----------------------------------------------------------------

func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func get_horizontal_speed() -> float:
	return get_horizontal_velocity().length()


func get_wall_debug_text() -> String:
	if not wall_sensor.has_contact:
		return "não"
	var since_entry := str(ticks_since(wall_sensor.entry_tick)) \
		if wall_sensor.entry_tick > PlayerInput.NEVER else "-"
	return "sim  n=(%.2f, %.2f)  entrada há %s ticks  topo:%s base:%s" % [
		wall_sensor.normal.x, wall_sensor.normal.z, since_entry,
		"perto" if wall_sensor.is_near_top() else "longe",
		"perto" if wall_sensor.is_near_base() else "longe"]


## "" se um wall jump seria aceito agora (ignorando o botão); senão, o motivo do bloqueio.
func get_wall_jump_block_reason() -> String:
	if not wall_sensor.has_contact:
		return "sem parede"
	if air_origin != MovementRules.AirOrigin.JUMP:
		return "não veio de pulo" if air_origin == MovementRules.AirOrigin.FALL else "no chão"
	if not MovementRules.can_wall_jump(air_origin, _is_rising_jump_state(), ticks_since(last_jump_tick),
			MovementRules.seconds_to_ticks(config.wall_jump_window_after_jump)):
		return "janela pós-pulo expirou"
	if config.wall_jump_same_wall_lockout and wall_sensor.collider_id == last_wall_jump_collider \
			and wall_sensor.collider_id != back_coming_wall:
		return "mesma parede"
	if not sp.can_spend(config.wall_jump_sp_cost):
		return "SP insuficiente" if not sp.exhausted else "SP exausto"
	return ""


func _is_rising_jump_state() -> bool:
	return state_machine.is_in(&"Jump") or state_machine.is_in(&"WallJump")


## O estado atual é uma recuperação (interrompível por dodge cancel)?
func is_in_recovery() -> bool:
	return state_machine.current.is_recovery()


func ticks_since(past_tick: int) -> int:
	return tick - past_tick


func secs_to_ticks(seconds: float) -> int:
	return MovementRules.seconds_to_ticks(seconds)


func get_state_name() -> StringName:
	return state_machine.current_name


## Existe um aperto de pulo não consumido dentro dos últimos `window` ticks?
func has_buffered_jump(input: PlayerInput, window: int) -> bool:
	return input.jump_pressed_tick > _consumed_jump_press_tick \
		and tick - input.jump_pressed_tick <= window


## Consome o aperto de pulo (cada aperto só gera UMA ação).
func consume_jump_press(input: PlayerInput, window: int) -> bool:
	if not has_buffered_jump(input, window):
		return false
	_consumed_jump_press_tick = input.jump_pressed_tick
	return true


func has_buffered_dodge(input: PlayerInput) -> bool:
	return input.dodge_pressed_tick > _consumed_dodge_press_tick \
		and tick - input.dodge_pressed_tick <= config.dodge_buffer_ticks


## Troca de arma (cancel) apertada dentro de ±janela do tick do wall jump e não consumida.
func consume_cancel_press(input: PlayerInput) -> bool:
	var press := input.weapon_swap_pressed_tick
	if press <= _consumed_weapon_press_tick or press > tick:
		return false
	if not MovementRules.is_within_window(press, last_wall_jump_tick, config.cancel_window_ticks):
		return false
	_consumed_weapon_press_tick = press
	return true


func can_sprint(input: PlayerInput) -> bool:
	return sprint_latched and input.has_move() and sp.can_drain()


func _update_sprint_latch(input: PlayerInput) -> void:
	if input.is_pressed_this_tick(input.forward_pressed_tick) and MovementRules.is_double_tap(
			input.forward_pressed_tick, input.forward_prev_pressed_tick, config.sprint_double_tap_ticks):
		sprint_latched = true
	if input.move.y <= config.sprint_forward_threshold or sp.exhausted:
		sprint_latched = false


## Estado de chão desejado pelo input atual.
func ground_target_state(input: PlayerInput) -> StringName:
	if not input.has_move():
		return &"Idle"
	if can_sprint(input):
		return &"Sprint"
	return &"Run"


# --- Motor ---------------------------------------------------------------------

func apply_gravity(delta: float) -> void:
	var gravity := config.get_jump_gravity() if velocity.y > 0.0 else config.get_fall_gravity()
	velocity.y = maxf(velocity.y - gravity * delta, -config.terminal_fall_speed)


## Acelera/desacelera no chão em direção a `wish * target_speed`.
func apply_ground_movement(input: PlayerInput, target_speed: float, delta: float) -> void:
	var horizontal := get_horizontal_velocity()
	var target := input.get_wish_direction() * target_speed
	var accelerating := input.has_move() and horizontal.length() <= target_speed + 0.01 \
		and horizontal.dot(target) >= 0.0
	var rate := config.ground_acceleration if accelerating else config.ground_deceleration
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	apply_gravity(delta)


## Controle no ar: direciona, mas não acelera além de max(velocidade atual, andar).
func apply_air_movement(input: PlayerInput, delta: float) -> void:
	if input.has_move():
		var horizontal := get_horizontal_velocity()
		var target_speed := maxf(config.walk_speed, horizontal.length())
		var target := input.get_wish_direction() * target_speed
		horizontal = horizontal.move_toward(target, config.air_acceleration * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	apply_gravity(delta)


## Ações disponíveis em qualquer estado de chão. Retorna true se transicionou.
func try_ground_actions(input: PlayerInput) -> bool:
	if try_dodge(input):
		return true
	if consume_jump_press(input, config.jump_buffer_ticks):
		do_jump("pulo do chão")
		return true
	return false


## Pulo do chão (também usado pelo coyote time e bunny hop): entra no ar como PULO.
func do_jump(reason: String) -> void:
	velocity.y = config.get_jump_velocity()
	mark_jump_origin()
	wall_sensor.reset_entry()
	GameEvents.jumped.emit(self)
	state_machine.transition_to(&"Jump", reason)


## Dodge se houver aperto e SP. Em estado de recuperação vira dodge cancel.
func try_dodge(input: PlayerInput) -> bool:
	if not has_buffered_dodge(input):
		return false
	if config.dodge_requires_direction and not input.has_move():
		return false
	var cancelling := is_in_recovery()
	if cancelling and not config.dodge_cancel_enabled:
		return false
	if not sp.try_spend(config.dodge_sp_cost):
		return false
	_consumed_dodge_press_tick = input.dodge_pressed_tick
	var direction := MovementRules.dodge_direction(input.move, input.look_yaw,
		config.dodge_neutral_backward)
	if cancelling:
		GameEvents.technique_executed.emit(self, MovementRules.TECH_DODGE_CANCEL,
			{"from_state": get_state_name(), "position": global_position})
	state_machine.transition_to(&"Dodge", "dodge cancel" if cancelling else "dodge",
		{"direction": direction})
	return true


## Tenta um wall jump (estados aéreos). Retorna true se executou.
func try_wall_jump(input: PlayerInput) -> bool:
	if not has_buffered_jump(input, config.jump_buffer_ticks):
		return false
	if get_wall_jump_block_reason() != "":
		return false
	consume_jump_press(input, config.jump_buffer_ticks)
	sp.try_spend(config.wall_jump_sp_cost)
	var sensor := wall_sensor
	var n := sensor.normal
	var has_entry := sensor.entry_tick > PlayerInput.NEVER
	var v_in := sensor.entry_velocity if has_entry else WallJumpMath.horizontal(pre_slide_velocity)
	# O segundo wall jump liberado pelo back-coming dispensa a janela justa (contato contínuo).
	var in_window := (has_entry and MovementRules.is_within_window(
		input.jump_pressed_tick, sensor.entry_tick, config.technique_window_ticks)) \
		or sensor.collider_id == back_coming_wall
	var technique := MovementRules.classify_wall_jump(in_window, sensor.is_near_top(),
		sensor.is_near_base(), WallJumpMath.incidence_angle_deg(v_in, n),
		config.side_jump_min_incidence_deg)
	var horizontal: Vector3
	var height: float
	match technique:
		MovementRules.TECH_REVERSE:
			horizontal = -n * config.reverse_forward_speed
			height = config.reverse_jump_height
		MovementRules.TECH_BACK_COMING:
			horizontal = -n * config.back_coming_wall_push_speed
			height = config.back_coming_height
		_:
			horizontal = WallJumpMath.compute_exit_horizontal(v_in, n, input.get_camera_forward(), config)
			height = config.wall_jump_height
	wall_jump_entry_velocity = Vector3(v_in.x, velocity.y, v_in.z)
	velocity = horizontal + Vector3.UP * config.velocity_for_height(height)
	back_coming_wall = sensor.collider_id if technique == MovementRules.TECH_BACK_COMING else 0
	last_wall_jump_collider = sensor.collider_id
	last_wall_jump_tick = tick
	mark_jump_origin()
	sensor.reset_entry()
	var data := {
		"technique": technique, "position": sensor.contact_point, "normal": n,
		"velocity_in": v_in, "velocity_out": velocity,
	}
	GameEvents.wall_jump_executed.emit(self, data)
	if technique != MovementRules.TECH_NORMAL:
		GameEvents.technique_executed.emit(self, technique, data)
	if consume_cancel_press(input):
		# Troca de arma apertada um pouco ANTES do wall jump: cancela já neste tick.
		apply_wall_jump_cancel()
		return true
	state_machine.transition_to(&"WallJump", String(technique), data)
	return true


## Cancel: desfaz o lançamento do wall jump mantendo parte da velocidade de entrada.
func apply_wall_jump_cancel() -> void:
	velocity = wall_jump_entry_velocity * config.cancel_speed_retained
	# O lançamento não aconteceu: a mesma parede volta a valer.
	last_wall_jump_collider = 0
	GameEvents.technique_executed.emit(self, MovementRules.TECH_CANCEL,
		{"position": global_position, "velocity_out": velocity})
	state_machine.transition_to(&"Jump" if velocity.y > 0.0 else &"Fall", "cancel")


## Limpa memória de paredes ao tocar o chão.
func on_landed() -> void:
	last_wall_jump_collider = 0
	back_coming_wall = 0
	air_origin = MovementRules.AirOrigin.NONE


## Marca que o jogador está no ar por um PULO (habilita wall jump dentro da janela).
func mark_jump_origin() -> void:
	air_origin = MovementRules.AirOrigin.JUMP
	last_jump_tick = tick


## Para estados de chão: se perdeu o chão sem pular, vira queda (origem FALL). Retorna true se saiu.
func check_left_ground() -> bool:
	if is_on_floor():
		return false
	air_origin = MovementRules.AirOrigin.FALL
	left_floor_tick = tick
	state_machine.transition_to(&"Fall", "saiu da borda")
	return true


## Teleporta para um ponto (reset/checkpoint), zerando velocidade e restaurando SP.
func respawn(at: Transform3D) -> void:
	global_transform = at
	velocity = Vector3.ZERO
	air_origin = MovementRules.AirOrigin.NONE
	is_invulnerable = false
	sprint_latched = false
	last_wall_jump_collider = 0
	back_coming_wall = 0
	wall_sensor.clear()
	sp.refill()
	reset_physics_interpolation()
	state_machine.transition_to(&"Idle", "respawn")


# --- Visual --------------------------------------------------------------------

func _update_visual(delta: float) -> void:
	var horizontal := get_horizontal_velocity()
	var target_yaw: float
	if state_machine.is_in(&"Dodge"):
		# Dash lateral: o corpo continua de frente para a câmera e só se inclina.
		target_yaw = current_input.look_yaw
	elif horizontal.length() < 0.5:
		return
	else:
		target_yaw = atan2(-horizontal.x, -horizontal.z)
	var weight := clampf(feedback_config.model_turn_speed * delta, 0.0, 1.0)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, weight)
