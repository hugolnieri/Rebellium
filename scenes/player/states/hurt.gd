extends PlayerState
## Levou um golpe: recuo + atordoamento curto. Com vida zerada fica caído e reaparece no spawn.

var _t: int = 0
var _stun_ticks: int = 1


func enter(_from: StringName, data: Dictionary) -> void:
	_t = 0
	var knockback: Vector3 = data.get("knockback", Vector3.ZERO)
	player.velocity = knockback * player.combat_config.received_knockback_multiplier
	player.sprint_latched = false
	player.air_sprinting = false
	_stun_ticks = player.secs_to_ticks(player.combat_config.respawn_delay) if player.health.is_dead() \
		else maxi(player.secs_to_ticks(player.combat_config.hitstun), 1)


func physics_update(input: PlayerInput, delta: float) -> void:
	_t += 1
	if player.is_on_floor():
		var horizontal := player.get_horizontal_velocity().move_toward(Vector3.ZERO,
			cfg().ground_deceleration * delta)
		player.velocity.x = horizontal.x
		player.velocity.z = horizontal.z
	player.apply_gravity(delta)
	if _t < _stun_ticks:
		return
	if player.health.is_dead():
		player.respawn(player.spawn_transform)
		GameEvents.player_respawned.emit(player)
	elif player.is_on_floor():
		machine.transition_to(player.ground_target_state(input), "fim do atordoamento")
	else:
		player.air_origin = MovementRules.AirOrigin.FALL
		player.left_floor_tick = player.tick
		machine.transition_to(&"Fall", "fim do atordoamento no ar")
