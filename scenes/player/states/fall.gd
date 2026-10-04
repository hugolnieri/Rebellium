extends PlayerState
## Caindo (após o ápice de um pulo ou saindo de uma borda).
## Wall jump aqui só se o jogador entrou no ar por um pulo e a janela pós-pulo não expirou.


func physics_update(input: PlayerInput, delta: float) -> void:
	if player.air_origin == MovementRules.AirOrigin.FALL \
			and player.ticks_since(player.left_floor_tick) <= cfg().coyote_ticks \
			and player.consume_jump_press(input, cfg().jump_buffer_ticks):
		player.do_jump("coyote")
		return
	if player.try_wall_jump(input):
		return
	if cfg().dodge_allow_in_air and player.try_dodge(input):
		return
	player.apply_air_movement(input, delta)


func post_move(_input: PlayerInput) -> void:
	if player.is_on_floor():
		machine.transition_to(&"Land", "tocou o chão")
