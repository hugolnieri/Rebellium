extends PlayerState
## Passo rápido (dash) em 8 direções relativas à câmera, no chão ou no ar.
## Chão: deslocamento (`dodge_duration`) → recuperação (`dodge_recovery`, cancelável por dodge).
## Ar: deslocamento reto (gravidade suspensa, se configurado) → volta a cair mantendo
## `air_dodge_exit_speed`; dá para emendar wall jump durante o dash.
## `player.is_invulnerable` fica true durante `dodge_invulnerability` desde o início.

var _direction: Vector3 = Vector3.FORWARD
var _airborne: bool = false


func enter(_from: StringName, data: Dictionary) -> void:
	_direction = data.get("direction", -player.visual.global_basis.z)
	_airborne = data.get("airborne", false)
	player.is_invulnerable = cfg().dodge_invulnerability > 0.0
	player.velocity.x = _direction.x * cfg().dodge_speed
	player.velocity.z = _direction.z * cfg().dodge_speed
	if _airborne and cfg().air_dodge_suspends_gravity:
		player.velocity.y = 0.0
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
	var dash := _dash_ticks()
	var horizontal: Vector3
	if t < dash:
		horizontal = _direction * cfg().dodge_speed
	elif t == dash:
		horizontal = _direction * cfg().dodge_exit_speed
	else:
		horizontal = player.get_horizontal_velocity().move_toward(Vector3.ZERO,
			cfg().ground_deceleration * delta)
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


func _air_update(input: PlayerInput, delta: float, t: int) -> void:
	if player.try_wall_jump(input):
		return
	if t < _dash_ticks():
		player.velocity.x = _direction.x * cfg().dodge_speed
		player.velocity.z = _direction.z * cfg().dodge_speed
		if cfg().air_dodge_suspends_gravity:
			player.velocity.y = 0.0
		else:
			player.apply_gravity(delta)
		return
	var exit := _direction * cfg().air_dodge_exit_speed
	player.velocity.x = exit.x
	player.velocity.z = exit.z
	player.apply_gravity(delta)
	machine.transition_to(&"Jump" if player.velocity.y > 0.0 else &"Fall", "fim do dash no ar")


func post_move(_input: PlayerInput) -> void:
	if _airborne and player.is_on_floor() and machine.ticks_in_state() > 0:
		machine.transition_to(&"Land", "dash no ar tocou o chão")


func _dash_ticks() -> int:
	return maxi(player.secs_to_ticks(cfg().dodge_duration), 1)
