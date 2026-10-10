class_name Player
extends CharacterBody3D
## Corpo do jogador: cápsula + "motor" de movimento (helpers usados pelos estados).
## Fluxo por tick: input → SP.update → estado.physics_update → move_and_slide → estado.post_move.
## A lógica só consome PlayerInput; `step()` pode ser chamado por testes/replay.

@export var config: MovementConfig
@export var camera_config: CameraConfig
@export var feedback_config: FeedbackConfig
@export var combat_config: CombatConfig
## Armas nos slots 1, 2... (cada uma com seus golpes).
@export var weapons: Array[WeaponConfig] = []
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
## Corrida no ar ativa (toque duplo em W no ar). Acaba ao aterrissar, soltar W ou zerar SP.
var air_sprinting: bool = false
## Dashes usados no ar desde a última aterrissagem/wall jump.
var air_dodges_used: int = 0
## Fez dash ou golpe no ar desde que saiu do chão (aterrissa sem cambalhota/agachamento).
var air_action_used: bool = false
## A última aterrissagem foi "limpa" (sem animação de impacto).
var last_landing_soft: bool = false
## Saiu de um wall jump e ainda não pousou: o ar não vira na hora para a câmera (mantém a distância).
var wall_jump_carry: bool = false
## Velocidade horizontal "de cruzeiro" do último wall jump: o impulso sai maior e decai até ela.
var wall_jump_cruise_speed: float = 0.0
## Golpe/dash bloqueados até este tick (o mortal do wall jump vai até o fim).
var action_lock_until_tick: int = PlayerInput.NEVER
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

## Vida (HP). Zerou → estado Hurt "caído" e reaparece no spawn.
var health: HealthPool
## Índice da arma atual em `weapons`.
var weapon_slot: int = 0
var last_swap_tick: int = PlayerInput.NEVER
## Ticks restantes de congelamento por impacto (hitstop): a simulação do jogador pausa.
var hitstop_ticks: int = 0
## Direção forçada do corpo (golpe mirando um alvo). Vector3.ZERO = segue a velocidade.
var facing_override: Vector3 = Vector3.ZERO

var _consumed_jump_press_tick: int = PlayerInput.NEVER
var _consumed_light_press_tick: int = PlayerInput.NEVER
var _consumed_heavy_press_tick: int = PlayerInput.NEVER
## Clique esquerdo: carga em andamento e os "apertos" resultantes (leve ao soltar, pesado segurando).
var _attack_charge_tick: int = PlayerInput.NEVER
var _light_ready_tick: int = PlayerInput.NEVER
var _heavy_ready_tick: int = PlayerInput.NEVER
var _consumed_dodge_press_tick: int = PlayerInput.NEVER
var _consumed_weapon_press_tick: int = PlayerInput.NEVER


func _ready() -> void:
	add_to_group(&"local_player")
	add_to_group(&"hittable")
	if combat_config == null:
		combat_config = CombatConfig.new()
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
	health = HealthPool.new(combat_config.max_hp)
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
	if hitstop_ticks > 0:
		# Congelamento do impacto: nada se move; o input continua guardado no buffer.
		hitstop_ticks -= 1
		return
	if input.is_pressed_this_tick(input.weapon_swap_pressed_tick):
		GameEvents.weapon_swap_pressed.emit(self, input.weapon_swap_slot)
		_handle_weapon_swap(input.weapon_swap_slot)
	sp.update(delta)
	_update_sprint_latch(input)
	_update_attack_charge(input)
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
	return "sim  n=(%.2f, %.2f)  entrada há %s ticks  base:%s" % [
		wall_sensor.normal.x, wall_sensor.normal.z, since_entry,
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


# --- Armas e combate ---------------------------------------------------------------

func get_weapon() -> WeaponConfig:
	if weapons.is_empty():
		return null
	return weapons[clampi(weapon_slot, 0, weapons.size() - 1)]


func get_walk_speed() -> float:
	var weapon := get_weapon()
	return config.walk_speed * (weapon.move_speed_multiplier if weapon != null else 1.0)


func get_sprint_speed() -> float:
	var weapon := get_weapon()
	return config.sprint_speed * (weapon.move_speed_multiplier if weapon != null else 1.0)


func _update_attack_charge(input: PlayerInput) -> void:
	var step_result := CombatRules.attack_charge_step(_attack_charge_tick, tick,
		input.is_pressed_this_tick(input.attack_light_pressed_tick), input.attack_light_held,
		combat_config.heavy_hold_ticks, false)
	_attack_charge_tick = step_result.charge_tick
	if step_result.light:
		_light_ready_tick = tick
	if step_result.heavy:
		_heavy_ready_tick = tick


## Carga do golpe pesado (0–1) enquanto o botão esquerdo está seguro; para o visual.
func get_heavy_charge() -> float:
	if _attack_charge_tick == PlayerInput.NEVER:
		return 0.0
	return clampf(float(tick - _attack_charge_tick) / maxf(combat_config.heavy_hold_ticks, 1), 0.0, 1.0)


func _attack_press_tick(input: PlayerInput, heavy: bool) -> int:
	return maxi(input.attack_heavy_pressed_tick, _heavy_ready_tick) if heavy else _light_ready_tick


func has_buffered_attack(input: PlayerInput, heavy: bool) -> bool:
	var press := _attack_press_tick(input, heavy)
	var consumed := _consumed_heavy_press_tick if heavy else _consumed_light_press_tick
	return press > consumed and tick - press <= combat_config.attack_buffer_ticks


func _consume_attack(input: PlayerInput, heavy: bool) -> void:
	if heavy:
		_consumed_heavy_press_tick = _attack_press_tick(input, true)
	else:
		_consumed_light_press_tick = _attack_press_tick(input, false)


## Tenta iniciar (ou encadear) um golpe. O tipo sai do contexto:
## no dash → golpe de dash; no ar → golpe aéreo; no chão → leve (combo) ou pesado.
func try_attack(input: PlayerInput) -> bool:
	if tick < action_lock_until_tick:
		return false
	var heavy := has_buffered_attack(input, true)
	var light := has_buffered_attack(input, false)
	var weapon := get_weapon()
	if weapon == null or not (heavy or light):
		return false
	var current := state_machine.current
	var in_attack := state_machine.is_in(&"Attack")
	var current_kind: StringName = current.get(&"kind") if in_attack else &""
	var current_index: int = current.get(&"combo_index") if in_attack else -1
	var kind: StringName
	var attack: AttackData
	var index := 0
	var use_heavy := false
	if state_machine.is_in(&"Dodge") and light and not heavy:
		# Golpe interrompe o dash (o pesado também: segurando ou botão direito, abaixo).
		kind = CombatRules.KIND_DASH
		attack = weapon.dash
	elif not is_on_floor():
		# No ar: segurar/botão direito = pesado aéreo; toque = golpe aéreo (um de cada por vez).
		if heavy and current_kind != CombatRules.KIND_HEAVY:
			kind = CombatRules.KIND_HEAVY
			attack = weapon.heavy
			use_heavy = true
		elif light and current_kind not in [CombatRules.KIND_AIR, CombatRules.KIND_HEAVY]:
			kind = CombatRules.KIND_AIR
			attack = weapon.air
		else:
			return false
	elif heavy:
		if current_kind == CombatRules.KIND_HEAVY:
			return false
		kind = CombatRules.KIND_HEAVY
		attack = weapon.heavy
		use_heavy = true
	else:
		kind = CombatRules.KIND_LIGHT
		if current_kind == CombatRules.KIND_LIGHT:
			index = CombatRules.next_combo_index(current_index, weapon.light_combo.size())
		if index < 0 or weapon.light_combo.is_empty():
			return false
		attack = weapon.light_combo[index]
	if attack == null:
		return false
	if attack.sp_cost > 0.0 and not sp.try_spend(attack.sp_cost):
		return false
	_consume_attack(input, use_heavy)
	state_machine.transition_to(&"Attack", "%s: %s" % [kind, attack.display_name], {
		"attack": attack, "kind": kind, "combo_index": index, "direction": get_aim_direction(input),
	})
	return true


## Alvos atacáveis (grupo "hittable"), exceto o próprio jogador.
func get_hittables() -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(&"hittable"):
		if node != self and node.has_method(&"take_hit"):
			result.append(node)
	return result


## Direção do golpe: a da câmera, ou a do alvo mais alinhado (mira assistida).
func get_aim_direction(input: PlayerInput) -> Vector3:
	var forward := input.get_camera_forward()
	if not combat_config.aim_assist_enabled:
		return forward
	var targets := get_hittables()
	var centers: Array[Vector3] = []
	for target in targets:
		centers.append(target.call(&"get_hit_center"))
	var best := CombatRules.pick_aim_target(global_position, forward, centers,
		combat_config.aim_assist_range, combat_config.aim_assist_angle_deg)
	if best < 0:
		return forward
	var flat := centers[best] - global_position
	flat.y = 0.0
	return flat.normalized() if flat.length_squared() > 0.0001 else forward


## Troca de arma (slot 1, 2... ou 0 = alternar). Na recuperação de um golpe vira swap cancel.
func _handle_weapon_swap(requested_slot: int) -> void:
	if weapons.size() < 2:
		return
	var target := (weapon_slot + 1) % weapons.size() if requested_slot <= 0 else requested_slot - 1
	if target == weapon_slot or target >= weapons.size():
		return
	if ticks_since(last_swap_tick) < secs_to_ticks(combat_config.swap_cooldown):
		return
	weapon_slot = target
	last_swap_tick = tick
	GameEvents.weapon_changed.emit(self, get_weapon(), weapon_slot + 1)
	if state_machine.is_in(&"Attack") and state_machine.current.is_recovery():
		GameEvents.technique_executed.emit(self, MovementRules.TECH_SWAP_CANCEL,
			{"position": global_position})
		state_machine.transition_to(ground_target_state(current_input) if is_on_floor() else &"Fall",
			"swap cancel")


func get_hit_center() -> Vector3:
	return global_position + Vector3.UP * config.body_height * 0.5


func get_hit_radius() -> float:
	return config.body_radius


## Recebe um golpe. Retorna false se não acertou (invencível = esquiva perfeita, ou já caído).
func take_hit(info: Dictionary) -> bool:
	if health.is_dead():
		return false
	if is_invulnerable:
		GameEvents.technique_executed.emit(self, MovementRules.TECH_PERFECT_DODGE,
			{"position": global_position})
		return false
	health.damage(info.get("damage", 0.0))
	hitstop_ticks = maxi(hitstop_ticks, info.get("hitstop_ticks", 0))
	GameEvents.player_hurt.emit(self, info)
	if health.is_dead():
		GameEvents.player_died.emit(self)
	state_machine.transition_to(&"Hurt", "levou golpe", info)
	return true


func can_sprint(input: PlayerInput) -> bool:
	return sprint_latched and input.has_move() and sp.can_drain()


func _update_sprint_latch(input: PlayerInput) -> void:
	var was_running := sprint_latched or air_sprinting
	_apply_sprint_latch(input)
	if not was_running and (air_sprinting or (sprint_latched and sp.can_drain())):
		GameEvents.sprint_started.emit(self)


func _apply_sprint_latch(input: PlayerInput) -> void:
	if input.is_pressed_this_tick(input.forward_pressed_tick) and MovementRules.is_double_tap(
			input.forward_pressed_tick, input.forward_prev_pressed_tick, config.sprint_double_tap_ticks):
		sprint_latched = true
		# Toque duplo no ar = corrida no ar (sprint vindo do chão não acelera a queda).
		if config.air_sprint_enabled and not is_on_floor() and sp.can_drain():
			air_sprinting = true
	if input.move.y <= config.sprint_forward_threshold or sp.exhausted:
		sprint_latched = false
		air_sprinting = false


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
	if air_sprinting:
		gravity *= config.air_sprint_gravity_multiplier
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


## Correndo: aponta a velocidade horizontal para a direção desejada sem perder velocidade.
func redirect_to_wish(input: PlayerInput, enabled: bool = config.sprint_instant_turn) -> void:
	if not enabled or not input.has_move():
		return
	var speed := get_horizontal_speed()
	var dir := input.get_wish_direction().normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


## Controle no ar: direciona, mas não acelera além de max(velocidade atual, andar).
func apply_air_movement(input: PlayerInput, delta: float, gravity_scale: float = 1.0) -> void:
	if air_sprinting:
		sp.drain(config.air_sprint_sp_cost_per_second * delta)
		if sp.exhausted:
			air_sprinting = false
		else:
			redirect_to_wish(input)
	elif config.air_instant_turn and not wall_jump_carry:
		# Pulo vai para onde se olha: a velocidade horizontal aponta para o input relativo à câmera.
		redirect_to_wish(input, true)
	if input.has_move():
		var horizontal := get_horizontal_velocity()
		var base_speed := get_sprint_speed() if air_sprinting else get_walk_speed()
		var target_speed := maxf(base_speed, horizontal.length())
		var target := input.get_wish_direction() * target_speed
		var accel := config.air_sprint_acceleration if air_sprinting else config.air_acceleration
		horizontal = horizontal.move_toward(target, accel * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	if wall_jump_carry and wall_jump_boost_active():
		# O excesso do impulso decai; o controle aéreo normal (até a velocidade de andar) continua livre.
		var capped := get_horizontal_velocity().limit_length(maxf(wall_jump_speed_cap(), get_walk_speed()))
		velocity.x = capped.x
		velocity.z = capped.z
	apply_gravity(delta * gravity_scale)


## O impulso inicial do último wall jump ainda está decaindo.
func wall_jump_boost_active() -> bool:
	var launched := ticks_since(last_wall_jump_tick) - config.wall_jump_stick_ticks
	return wall_jump_cruise_speed > 0.0 \
		and launched < secs_to_ticks(config.wall_jump_boost_decay_time)


## Velocidade horizontal máxima agora, depois de um wall jump: começa em cruzeiro × impulso inicial e
## cai (rápido no começo, devagar no fim) até a de cruzeiro em `wall_jump_boost_decay_time`.
func wall_jump_speed_cap() -> float:
	var launched := ticks_since(last_wall_jump_tick) - config.wall_jump_stick_ticks
	var s := clampf(launched / float(Engine.physics_ticks_per_second) / config.wall_jump_boost_decay_time, 0.0, 1.0)
	var extra := wall_jump_cruise_speed * (config.wall_jump_initial_boost - 1.0)
	return wall_jump_cruise_speed + extra * (1.0 - s) * (1.0 - s)


## Ações disponíveis em qualquer estado de chão. Retorna true se transicionou.
func try_ground_actions(input: PlayerInput) -> bool:
	if try_attack(input):
		return true
	if try_dodge(input):
		return true
	if consume_jump_press(input, config.jump_buffer_ticks):
		do_jump("pulo do chão")
		return true
	return false


## Pulo do chão (também usado pelo coyote time e bunny hop): entra no ar como PULO.
func do_jump(reason: String, enter_jump_state: bool = true, keep_speed: bool = false) -> void:
	wall_jump_carry = false
	if config.jump_resets_to_walk_speed and not keep_speed:
		var horizontal := get_horizontal_velocity().limit_length(get_walk_speed())
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	velocity.y = config.get_jump_velocity()
	mark_jump_origin()
	wall_sensor.reset_entry()
	GameEvents.jumped.emit(self)
	if enter_jump_state:
		state_machine.transition_to(&"Jump", reason)


## Espaço + A/D (lateral puro) pede um dash em vez de pulo.
func wants_side_dash(input: PlayerInput) -> bool:
	return has_buffered_jump(input, config.jump_buffer_ticks) \
		and absf(input.move.x) >= config.dodge_side_input_threshold


## Dash se houver pedido (Espaço + A/D ou dash explícito) e SP. Em recuperação vira dodge cancel.
func try_dodge(input: PlayerInput) -> bool:
	var side_request := wants_side_dash(input)
	if not side_request and not has_buffered_dodge(input):
		return false
	if config.dodge_requires_direction and not input.has_move():
		return false
	if config.dodge_side_only and input.has_move() and absf(input.move.x) < 0.01:
		return false
	var cancelling := is_in_recovery()
	if cancelling and not config.dodge_cancel_enabled:
		return false
	var airborne := not is_on_floor()
	if airborne and (not config.dodge_allow_in_air or air_dodges_used >= config.air_dodge_max_per_air):
		return false
	if not sp.try_spend(config.dodge_sp_cost):
		return false
	if airborne:
		air_dodges_used += 1
		air_action_used = true
	if side_request:
		consume_jump_press(input, config.jump_buffer_ticks)
	else:
		_consumed_dodge_press_tick = input.dodge_pressed_tick
	var direction: Vector3
	if config.dodge_side_only and absf(input.move.x) >= 0.01:
		direction = MovementRules.side_dash_direction(input.move.x, input.look_yaw)
	else:
		direction = MovementRules.dodge_direction(input.move, input.look_yaw,
			config.dodge_neutral_backward)
	if cancelling:
		GameEvents.technique_executed.emit(self, MovementRules.TECH_DODGE_CANCEL,
			{"from_state": get_state_name(), "position": global_position})
	state_machine.transition_to(&"Dodge", "dodge cancel" if cancelling else "dodge",
		{"direction": direction, "airborne": airborne})
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
	# Depois de um back-coming, Space segurando na direção da parede sobe mais um lance colado nela;
	# sem segurar, o segundo salto se afasta da parede (wall jump normal).
	var chained := sensor.collider_id == back_coming_wall \
		and input.get_wish_direction().dot(-n) > config.back_coming_chain_min_dot
	var in_window := (has_entry and MovementRules.is_within_window(
		input.jump_pressed_tick, sensor.entry_tick, config.technique_window_ticks)) \
		or sensor.collider_id == back_coming_wall
	var technique := MovementRules.classify_wall_jump(in_window, sensor.is_near_base(), chained,
		WallJumpMath.incidence_angle_deg(v_in, n), config.side_jump_min_incidence_deg)
	var horizontal: Vector3
	var height: float
	match technique:
		MovementRules.TECH_BACK_COMING:
			horizontal = -n * config.back_coming_wall_push_speed
			height = config.back_coming_height
		_:
			horizontal = WallJumpMath.compute_exit_horizontal(v_in, n, input.get_camera_forward(), config)
			height = config.wall_jump_height
	# Impulso inicial forte que vai perdendo força (ver wall_jump_speed_cap).
	wall_jump_cruise_speed = 0.0
	if technique != MovementRules.TECH_BACK_COMING:
		wall_jump_cruise_speed = horizontal.length()
		horizontal *= config.wall_jump_initial_boost
	wall_jump_entry_velocity = Vector3(v_in.x, velocity.y, v_in.z)
	var launch := horizontal + Vector3.UP * config.velocity_for_height(height)
	velocity = launch
	# Só um lance extra por parede: depois do back-coming encadeado, o próximo salto se afasta.
	back_coming_wall = sensor.collider_id if technique == MovementRules.TECH_BACK_COMING and not chained else 0
	last_wall_jump_collider = sensor.collider_id
	last_wall_jump_tick = tick
	wall_jump_carry = true
	action_lock_until_tick = tick + config.wall_jump_stick_ticks + secs_to_ticks(config.wall_jump_action_lock_time)
	if config.air_dodge_refresh_on_wall_jump:
		air_dodges_used = 0
	mark_jump_origin()
	sensor.reset_entry()
	var data := {
		"technique": technique, "position": sensor.contact_point, "normal": n,
		"velocity_in": v_in, "velocity_out": launch,
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


## Tocou o chão no meio de um dash ou golpe aéreo: a ação continua (sem passar pelo Land),
## mas o pouso conta (recarrega o dash no ar, limpa paredes) e é "limpo" (sem animação de impacto).
func touch_down_during_action() -> void:
	land_tick = tick
	land_impact_speed = maxf(-pre_slide_velocity.y, 0.0)
	last_landing_soft = true
	on_landed()
	GameEvents.landed.emit(self, land_impact_speed)


## Limpa memória de paredes ao tocar o chão.
func on_landed() -> void:
	air_sprinting = false
	wall_jump_carry = false
	action_lock_until_tick = PlayerInput.NEVER
	air_action_used = false
	air_dodges_used = 0
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
	hitstop_ticks = 0
	facing_override = Vector3.ZERO
	health.refill()
	sprint_latched = false
	air_sprinting = false
	air_dodges_used = 0
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
	var instant := feedback_config.instant_facing
	if facing_override != Vector3.ZERO and state_machine.is_in(&"Attack"):
		# Golpe: o corpo encara o alvo/câmera.
		target_yaw = atan2(-facing_override.x, -facing_override.z)
		visual.rotation.y = target_yaw if instant else lerp_angle(visual.rotation.y, target_yaw,
			clampf(feedback_config.model_turn_speed * 2.0 * delta, 0.0, 1.0))
		return
	elif state_machine.is_in(&"WallJump") and state_machine.current.call(&"is_sticking"):
		# Colado na parede: o corpo já mira a saída (o mortal começa de frente para a parede).
		var launch: Vector3 = state_machine.current.call(&"get_launch_horizontal")
		if launch.length() < 0.1:
			return
		target_yaw = atan2(-launch.x, -launch.z)
	elif state_machine.is_in(&"Dodge"):
		# Dash lateral: o corpo continua de frente para a câmera e só se inclina.
		target_yaw = current_input.look_yaw
	elif instant and current_input.has_move() and not state_machine.is_in(&"WallJump"):
		# Vira na hora para a direção do input (relativa à câmera).
		var wish := current_input.get_wish_direction()
		target_yaw = atan2(-wish.x, -wish.z)
	elif horizontal.length() < 0.5:
		return
	else:
		target_yaw = atan2(-horizontal.x, -horizontal.z)
	if instant:
		visual.rotation.y = target_yaw
		return
	var weight := clampf(feedback_config.model_turn_speed * delta, 0.0, 1.0)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, weight)
