extends PlayerState
## Sprint (segurando Shift): mais rápido e drena SP continuamente.


func physics_update(input: PlayerInput, delta: float) -> void:
	if player.try_ground_actions(input):
		return
	var next := player.ground_target_state(input)
	if next != &"Sprint":
		player.apply_ground_movement(input, cfg().walk_speed, delta)
		machine.transition_to(next, "SP esgotado" if player.sp.exhausted else "soltou sprint")
		return
	player.apply_ground_movement(input, cfg().sprint_speed, delta)
	player.sp.drain(cfg().sprint_sp_cost_per_second * delta)
	if player.sp.exhausted:
		machine.transition_to(&"Run", "SP zerado")


func post_move(_input: PlayerInput) -> void:
	player.check_left_ground()
