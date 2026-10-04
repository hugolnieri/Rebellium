extends PlayerState
## Andando/correndo normal no chão (velocidade de andar).


func physics_update(input: PlayerInput, delta: float) -> void:
	if player.try_ground_actions(input):
		return
	var next := player.ground_target_state(input)
	player.apply_ground_movement(input, cfg().walk_speed, delta)
	if next != &"Run":
		machine.transition_to(next, "sprint" if next == &"Sprint" else "sem input")


func post_move(_input: PlayerInput) -> void:
	player.check_left_ground()
