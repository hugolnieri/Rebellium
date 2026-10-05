extends PlayerState
## Dash lateral (Espaço + A/D), no chão ou no ar. A velocidade começa alta e DESACELERA
## (`dodge_speed` → `dodge_exit_speed`, curva `dodge_ease_power`) ao longo de `dodge_duration`.
## Chão: deslocamento → recuperação (`dodge_recovery`). Espaço no meio do dash cancela e pula
## (dash jump); na recuperação, Espaço + A/D emenda outro dash (dodge cancel).
## Ar: o dash acelera a queda (`air_dodge_fall_speed`, gravidade × `air_dodge_gravity_multiplier`), ou
## suspende a gravidade se `air_dodge_suspends_gravity` → segue caindo com `air_dodge_exit_speed`.
## `player.is_invulnerable` fica true durante `dodge_invulnerability` desde o início.

var _direction: Vector3 = Vector3.FORWARD
var _airborne: bool = false


func enter(_from: StringName, data: Dictionary) -> void:
	_direction = data.get("direction", -player.visual.global_basis.z)
	_airborne = data.get("airborne", false)
	player.is_invulnerable = cfg().dodge_invulnerability > 0.0
	_set_dash_velocity(0)
	if _airborne:
		if cfg().air_dodge_suspends_gravity:
			player.velocity.y = 0.0
		else:
			# O dash corta a queda acumulada: recomeça a descer devagar a partir daqui.
			player.velocity.y = -cfg().air_dodge_fall_speed
	GameEvents.dodged.emit(player, _direction)


func exit() -> void:
	player.is_invulnerable = false


func is_recovery() -> bool:
	return not _airborne and machine.ticks_in_state() >= _dash_ticks()


func physics_update(input: PlayerInput, delta: float) -> void:
	var t := machine.ticks_in_state()
	player.is_invulnerable = t < player.secs_to_ticks(cfg().dodge_invulnerability)
	# Golpe saindo do dash (estocada).
	if player.try_attack(input):
		return
	if _airborne:
		_air_update(input, delta, t)
		return
	if is_recovery() and player.try_dodge(input):
		return
	if _try_dash_jump(input):
		return
	var dash := _dash_ticks()
	if t < dash:
		_set_dash_velocity(t)
	else:
		var horizontal := player.get_horizontal_velocity().move_toward(Vector3.ZERO,
			cfg().dodge_slide_deceleration * delta)
		player.velocity.x = horizontal.x
		player.velocity.z = horizontal.z
	player.apply_gravity(delta)
	if t >= dash + player.secs_to_ticks(cfg().dodge_recovery):
		if player.is_on_floor():
			machine.transition_to(player.ground_target_state(input), "fim do dodge")
		else:
			player.air_origin = MovementRules.AirOrigin.FALL
			player.left_floor_tick = player.tick
			machine.transition_to(&"Fall", "fim do dodge no ar")


## Espaço durante o dash: cancela o movimento e pula, mantendo parte do embalo.
func _try_dash_jump(input: PlayerInput) -> bool:
	if not cfg().dash_jump_enabled or not player.is_on_floor():
		return false
	if not player.consume_jump_press(input, cfg().jump_buffer_ticks):
		return false
	var keep := player.get_horizontal_velocity() * cfg().dash_jump_speed_retained
	player.velocity.x = keep.x
	player.velocity.z = keep.z
	GameEvents.technique_executed.emit(player, MovementRules.TECH_DASH_JUMP,
		{"position": player.global_position, "speed": keep.length()})
	player.do_jump("dash jump")
	return true


func _air_update(input: PlayerInput, delta: float, t: int) -> void:
	if player.try_wall_jump(input):
		return
	if t < _dash_ticks():
		_set_dash_velocity(t)
		if cfg().air_dodge_suspends_gravity:
			player.velocity.y = 0.0
		else:
			player.apply_gravity(delta * cfg().air_dodge_gravity_multiplier)
		return
	var exit := _direction * maxf(cfg().air_dodge_exit_speed, cfg().dodge_exit_speed)
	player.velocity.x = exit.x
	player.velocity.z = exit.z
	player.apply_gravity(delta)
	machine.transition_to(&"Jump" if player.velocity.y > 0.0 else &"Fall", "fim do dash no ar")


func _set_dash_velocity(t: int) -> void:
	var speed := MovementRules.dash_speed(float(t) / _dash_ticks(), cfg().dodge_speed,
		cfg().dodge_exit_speed, cfg().dodge_ease_power)
	player.velocity.x = _direction.x * speed
	player.velocity.z = _direction.z * speed


func post_move(_input: PlayerInput) -> void:
	if _airborne and player.is_on_floor() and machine.ticks_in_state() > 0:
		# O dash continua no chão (mesma estrela, mesma curva de velocidade); pular interrompe.
		_airborne = false
		player.touch_down_during_action()


## Progresso 0–1 do deslocamento do dash (para a animação).
func get_dash_progress() -> float:
	return clampf(float(machine.ticks_in_state()) / _dash_ticks(), 0.0, 1.0)


## Direção do dash no mundo.
func get_direction() -> Vector3:
	return _direction


func _dash_ticks() -> int:
	return maxi(player.secs_to_ticks(cfg().dodge_duration), 1)
