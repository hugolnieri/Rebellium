class_name Player
extends CharacterBody3D
## Corpo do jogador: cápsula + "motor" de movimento (helpers usados pelos estados).
## Fluxo por tick: input → SP.update → estado.physics_update → move_and_slide → estado.post_move.
## A lógica só consome PlayerInput; `step()` pode ser chamado por testes/replay.

enum AirOrigin { NONE, JUMP, FALL }

@export var config: MovementConfig
@export var camera_config: CameraConfig
@export var feedback_config: FeedbackConfig
## Se true, `_physics_process` não amostra input sozinho: quem controla chama `step()`.
@export var external_control: bool = false

@onready var input_reader: InputReader = $InputReader
@onready var state_machine: StateMachine = $StateMachine
@onready var visual: Node3D = $Visual
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $Visual/Body

var sp: SPPool
## Tick de simulação deste jogador (incrementa a cada `step`).
var tick: int = 0
var current_input: PlayerInput = PlayerInput.new()
## Como o jogador entrou no ar. Wall jump exige JUMP (nunca FALL).
var air_origin: AirOrigin = AirOrigin.NONE
var last_jump_tick: int = PlayerInput.NEVER
var left_floor_tick: int = PlayerInput.NEVER
var land_tick: int = PlayerInput.NEVER
## Velocidade vertical (positiva) no último impacto com o chão.
var land_impact_speed: float = 0.0
## Velocidade antes do move_and_slide deste tick (a colisão "come" a componente contra a parede).
var pre_slide_velocity: Vector3 = Vector3.ZERO
## Flag de invencibilidade (dodge). Consultada pelo combate futuro.
var is_invulnerable: bool = false
var spawn_transform: Transform3D

var _consumed_jump_press_tick: int = PlayerInput.NEVER


func _ready() -> void:
	add_to_group(&"local_player")
	if config == null:
		push_warning("Player sem MovementConfig; usando valores padrão.")
		config = MovementConfig.new()
	if feedback_config == null:
		feedback_config = FeedbackConfig.new()
	apply_body_config()
	sp = SPPool.new(config)
	sp.depleted.connect(func() -> void: GameEvents.sp_depleted.emit(self))
	sp.recovered.connect(func() -> void: GameEvents.sp_recovered.emit(self))
	spawn_transform = global_transform
	state_machine.setup(self)


## Aplica dimensões da cápsula e parâmetros de chão da config (chamar após editar a config).
func apply_body_config() -> void:
	var capsule := body_shape.shape as CapsuleShape3D
	capsule.radius = config.body_radius
	capsule.height = config.body_height
	body_shape.position = Vector3(0.0, config.body_height * 0.5, 0.0)
	var mesh := body_mesh.mesh as CapsuleMesh
	if mesh != null:
		mesh.radius = config.body_radius
		mesh.height = config.body_height
		body_mesh.position = body_shape.position
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
	sp.update(delta)
	state_machine.physics_update(input, delta)
	pre_slide_velocity = velocity
	move_and_slide()
	state_machine.post_move(input)
	_update_visual(delta)


# --- Consultas -----------------------------------------------------------------

func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func get_horizontal_speed() -> float:
	return get_horizontal_velocity().length()


func get_wall_debug_text() -> String:
	return "sim" if is_on_wall() else "não"


func ticks_since(past_tick: int) -> int:
	return tick - past_tick


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


func can_sprint(input: PlayerInput) -> bool:
	return input.sprint_held and input.has_move() and sp.can_drain()


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
	if consume_jump_press(input, config.jump_buffer_ticks):
		do_jump("pulo do chão")
		return true
	return false


## Pulo do chão (também usado pelo coyote time): entra no ar como PULO.
func do_jump(reason: String) -> void:
	velocity.y = config.get_jump_velocity()
	mark_jump_origin()
	GameEvents.jumped.emit(self)
	state_machine.transition_to(&"Jump", reason)


## Marca que o jogador está no ar por um PULO (habilita wall jump dentro da janela).
func mark_jump_origin() -> void:
	air_origin = AirOrigin.JUMP
	last_jump_tick = tick


## Para estados de chão: se perdeu o chão sem pular, vira queda (origem FALL). Retorna true se saiu.
func check_left_ground() -> bool:
	if is_on_floor():
		return false
	air_origin = AirOrigin.FALL
	left_floor_tick = tick
	state_machine.transition_to(&"Fall", "saiu da borda")
	return true


## Teleporta para um ponto (reset/checkpoint), zerando velocidade e restaurando SP.
func respawn(at: Transform3D) -> void:
	global_transform = at
	velocity = Vector3.ZERO
	air_origin = AirOrigin.NONE
	is_invulnerable = false
	sp.refill()
	reset_physics_interpolation()
	state_machine.transition_to(&"Idle", "respawn")


# --- Visual --------------------------------------------------------------------

func _update_visual(delta: float) -> void:
	var horizontal := get_horizontal_velocity()
	if horizontal.length() < 0.5:
		return
	var target_yaw := atan2(-horizontal.x, -horizontal.z)
	var weight := clampf(feedback_config.model_turn_speed * delta, 0.0, 1.0)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, weight)
