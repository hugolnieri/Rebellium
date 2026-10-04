extends PlayerState
## Passo rápido em 8 direções relativas à câmera.
## Fases: deslocamento (`dodge_duration`) → recuperação (`dodge_recovery`, cancelável por dodge).
## `player.is_invulnerable` fica true durante `dodge_invulnerability` desde o início.

var _direction: Vector3 = Vector3.FORWARD


func enter(_from: StringName, data: Dictionary) -> void:
	_direction = data.get("direction", -player.visual.global_basis.z)
	player.is_invulnerable = cfg().dodge_invulnerability > 0.0
	player.velocity.x = _direction.x * cfg().dodge_speed
	player.velocity.z = _direction.z * cfg().dodge_speed
	GameEvents.dodged.emit(player, _direction)


func exit() -> void:
	player.is_invulnerable = false


func is_recovery() -> bool:
	return machine.ticks_in_state() >= _dash_ticks()


func physics_update(input: PlayerInput, delta: float) -> void:
	var t := machine.ticks_in_state()
	player.is_invulnerable = t < player.secs_to_ticks(cfg().dodge_invulnerability)
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


func _dash_ticks() -> int:
	return maxi(player.secs_to_ticks(cfg().dodge_duration), 1)
