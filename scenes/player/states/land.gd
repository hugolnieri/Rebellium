extends PlayerState
## Aterrissagem. Com impacto suficiente vira uma CAMBALHOTA que absorve o impacto — no lugar
## (`roll_in_place`) ou rolando para frente (cancelável por dash, por corrida — toque duplo em W — por
## golpe e por pulo).
## Sem impacto (ou chegando correndo no ar) é só uma recuperação curta.
## - Bunny hop: pulo nos primeiros `bunny_hop_window_ticks` preserva a velocidade horizontal.
## - É um estado de recuperação: dash aqui = dodge cancel.

var rolling: bool = false

var _landing_velocity: Vector3 = Vector3.ZERO
var _roll_direction: Vector3 = Vector3.FORWARD
var _roll_ticks: int = 1


func enter(_from: StringName, _data: Dictionary) -> void:
	player.land_tick = player.tick
	player.land_impact_speed = maxf(-player.pre_slide_velocity.y, 0.0)
	_landing_velocity = WallJumpMath.horizontal(player.pre_slide_velocity)
	# Dash ou golpe no ar cancelam a animação de impacto: aterrissa limpo, sem cambalhota.
	player.last_landing_soft = player.air_action_used and cfg().air_action_cancels_landing
	rolling = cfg().roll_enabled and player.land_impact_speed >= cfg().roll_min_impact_speed \
		and not player.air_sprinting and not player.last_landing_soft
	_roll_ticks = maxi(player.secs_to_ticks(cfg().roll_duration), 1)
	if _landing_velocity.length() > 0.5:
		_roll_direction = _landing_velocity.normalized()
	else:
		_roll_direction = -player.visual.global_basis.z
		_roll_direction.y = 0.0
		_roll_direction = _roll_direction.normalized()
	player.on_landed()
	GameEvents.landed.emit(player, player.land_impact_speed)


func exit() -> void:
	rolling = false


func is_recovery() -> bool:
	return true


## Progresso 0–1 da cambalhota (para a animação).
func get_roll_progress() -> float:
	return clampf(float(machine.ticks_in_state()) / _roll_ticks, 0.0, 1.0)


func physics_update(input: PlayerInput, delta: float) -> void:
	if player.try_dodge(input):
		return
	if _try_bunny_hop(input):
		return
	if player.try_attack(input):
		return
	var next := player.ground_target_state(input)
	var speed := player.get_sprint_speed() if next == &"Sprint" else player.get_walk_speed()
	if player.has_buffered_jump(input, cfg().jump_buffer_ticks):
		# Pulo fora da janela do bunny hop: velocidade volta ao limite do chão.
		var horizontal := player.get_horizontal_velocity().limit_length(speed)
		player.velocity = Vector3(horizontal.x, player.velocity.y, horizontal.z)
		player.consume_jump_press(input, cfg().jump_buffer_ticks)
		player.do_jump("pulo do chão")
		return
	if rolling and input.is_pressed_this_tick(input.forward_pressed_tick) and player.sprint_latched:
		machine.transition_to(&"Sprint", "corrida cancela a cambalhota")
		return
	if player.ticks_since(player.land_tick) < cfg().bunny_hop_window_ticks:
		player.velocity.x = _landing_velocity.x
		player.velocity.z = _landing_velocity.z
		player.apply_gravity(delta)
	elif rolling and cfg().roll_in_place:
		# Sem input fica no lugar (não sai rolando sozinho); com o direcional, rola para onde se aponta.
		var horizontal := Vector3.ZERO
		if input.has_move():
			horizontal = input.get_wish_direction() * cfg().roll_steer_speed * minf(input.move.length(), 1.0)
		player.velocity.x = horizontal.x
		player.velocity.z = horizontal.z
		player.apply_gravity(delta)
	elif rolling:
		if cfg().air_instant_turn and input.has_move():
			# A cambalhota vai para onde se olha (como o pulo).
			_roll_direction = input.get_wish_direction().normalized()
		var current := maxf(player.get_horizontal_speed(), cfg().roll_min_speed)
		var roll_speed := maxf(current - cfg().roll_deceleration * delta, cfg().roll_min_speed)
		player.velocity.x = _roll_direction.x * roll_speed
		player.velocity.z = _roll_direction.z * roll_speed
		player.apply_gravity(delta)
	else:
		player.apply_ground_movement(input, speed, delta)
	var duration := _roll_ticks if rolling else maxi(cfg().land_recovery_ticks, cfg().bunny_hop_window_ticks)
	if machine.ticks_in_state() >= duration:
		machine.transition_to(next, "fim da cambalhota" if rolling else "fim da recuperação")


func _try_bunny_hop(input: PlayerInput) -> bool:
	if not player.has_buffered_jump(input, cfg().jump_buffer_ticks):
		return false
	if not MovementRules.is_bunny_hop(input.jump_pressed_tick, player.land_tick,
			cfg().bunny_hop_window_ticks):
		return false
	player.consume_jump_press(input, cfg().jump_buffer_ticks)
	var preserved := _landing_velocity.limit_length(cfg().bunny_hop_speed_cap)
	player.velocity = Vector3(preserved.x, player.velocity.y, preserved.z)
	GameEvents.technique_executed.emit(player, MovementRules.TECH_BUNNY_HOP,
		{"position": player.global_position, "speed": preserved.length()})
	player.do_jump("bunny hop", true, true)
	return true


func post_move(_input: PlayerInput) -> void:
	player.check_left_ground()
