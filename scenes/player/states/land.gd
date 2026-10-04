extends PlayerState
## Recuperação curta ao aterrissar.
## - Bunny hop: pulo nos primeiros `bunny_hop_window_ticks` preserva a velocidade horizontal
##   (durante essa janela o atrito do chão não age).
## - É um estado de recuperação: dodge aqui = dodge cancel.

var _landing_velocity: Vector3 = Vector3.ZERO


func enter(_from: StringName, _data: Dictionary) -> void:
	player.land_tick = player.tick
	player.land_impact_speed = maxf(-player.pre_slide_velocity.y, 0.0)
	_landing_velocity = WallJumpMath.horizontal(player.pre_slide_velocity)
	player.on_landed()
	GameEvents.landed.emit(player, player.land_impact_speed)


func is_recovery() -> bool:
	return true


func physics_update(input: PlayerInput, delta: float) -> void:
	if _try_bunny_hop(input):
		return
	if player.try_attack(input) or player.try_dodge(input):
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
	if player.ticks_since(player.land_tick) < cfg().bunny_hop_window_ticks:
		player.velocity.x = _landing_velocity.x
		player.velocity.z = _landing_velocity.z
		player.apply_gravity(delta)
	else:
		player.apply_ground_movement(input, speed, delta)
	if machine.ticks_in_state() >= maxi(cfg().land_recovery_ticks, cfg().bunny_hop_window_ticks):
		machine.transition_to(next, "fim da recuperação")


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
	player.do_jump("bunny hop")
	return true


func post_move(_input: PlayerInput) -> void:
	player.check_left_ground()
