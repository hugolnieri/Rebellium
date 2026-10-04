extends PlayerState
## Recuperação curta ao aterrissar.


func enter(_from: StringName, _data: Dictionary) -> void:
	player.land_tick = player.tick
	player.land_impact_speed = maxf(-player.pre_slide_velocity.y, 0.0)
	player.air_origin = Player.AirOrigin.NONE
	GameEvents.landed.emit(player, player.land_impact_speed)


func physics_update(input: PlayerInput, delta: float) -> void:
	if player.try_ground_actions(input):
		return
	var next := player.ground_target_state(input)
	var speed := cfg().sprint_speed if next == &"Sprint" else cfg().walk_speed
	player.apply_ground_movement(input, speed, delta)
	if machine.ticks_in_state() >= cfg().land_recovery_ticks:
		machine.transition_to(next, "fim da recuperação")


func post_move(_input: PlayerInput) -> void:
	player.check_left_ground()
