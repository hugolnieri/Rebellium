extends PlayerState
## Parado no chão. Desacelera até zero.


func physics_update(input: PlayerInput, delta: float) -> void:
	if player.try_ground_actions(input):
		return
	var next := player.ground_target_state(input)
	player.apply_ground_movement(input, cfg().walk_speed, delta)
	if next != &"Idle":
		machine.transition_to(next, "input de movimento")


func post_move(_input: PlayerInput) -> void:
	player.check_left_ground()
