extends PlayerState
## Wall jump: primeiro o personagem fica colado na parede por `wall_jump_stick_ticks` (pés
## plantados, sem cair), depois sai o impulso. Mantém a direção do lançamento sem controle aéreo por
## `wall_jump_lock_time`. No back-coming o empurrão contra a parede continua enquanto sobe colado
## nela (senão a colisão comeria a velocidade horizontal). Ao passar do topo ele NÃO leva por cima da
## parede (o reverse wall jump saiu do jogo): o corpo é empurrado para fora (`back_coming_top_pop_speed`)
## até o ápice e cai do mesmo lado.
## Cancel: troca de arma (1/2) até `cancel_window_ticks` do wall jump desfaz o lançamento.

var _launch: Vector3 = Vector3.ZERO
var _launch_horizontal: Vector3 = Vector3.ZERO
var _wall_normal: Vector3 = Vector3.ZERO
var _hold_until_clear: bool = false
## O back-coming passou do topo da parede: daqui até o ápice o corpo se afasta dela.
var _topped_out: bool = false
var _climb_contact: bool = false


func enter(_from: StringName, data: Dictionary) -> void:
	_launch = data.get("velocity_out", player.velocity)
	_launch_horizontal = WallJumpMath.horizontal(_launch)
	_wall_normal = data.get("normal", Vector3.ZERO)
	var technique: StringName = data.get("technique", &"")
	_hold_until_clear = technique == MovementRules.TECH_BACK_COMING
	_topped_out = false
	_climb_contact = false
	if is_sticking():
		_stick()


## Direção horizontal do impulso (o corpo já se orienta por ela enquanto está colado).
func get_launch_horizontal() -> Vector3:
	return _launch_horizontal


## Ainda colado na parede antes do impulso.
func is_sticking() -> bool:
	return machine.ticks_in_state() < cfg().wall_jump_stick_ticks


func _stick() -> void:
	# Encosta de leve na parede e não cai.
	player.velocity = -_wall_normal * 0.5


func physics_update(input: PlayerInput, delta: float) -> void:
	if player.consume_cancel_press(input):
		player.apply_wall_jump_cancel()
		return
	var t := machine.ticks_in_state() - cfg().wall_jump_stick_ticks
	if t < 0:
		_stick()
		return
	if t == 0:
		player.velocity = _launch
	var locked := t < player.secs_to_ticks(cfg().wall_jump_lock_time)
	var can_chain := t >= player.secs_to_ticks(cfg().wall_jump_chain_time)
	var can_act := t >= player.secs_to_ticks(cfg().wall_jump_action_lock_time)
	if can_chain and (player.try_wall_jump(input) or player.try_dodge(input)):
		return  # o dash pode cortar o mortal; o golpe espera o mortal terminar
	if can_act and player.try_attack(input):
		return
	if _hold_until_clear and t > 0 and player.wall_sensor.has_contact:
		_climb_contact = true
	elif _hold_until_clear and _climb_contact and not _topped_out:
		# Passou do topo subindo colado: nada de seguir por cima da parede; afasta-se dela.
		_topped_out = true
		_launch_horizontal = WallJumpMath.horizontal_normal(_wall_normal) * cfg().back_coming_top_pop_speed
	var climbing := _hold_until_clear and not _topped_out and player.wall_sensor.has_contact \
		and player.velocity.y > 0.0
	var popping := _topped_out and player.velocity.y > 0.0
	if locked or climbing or popping:
		var horizontal := _launch_horizontal
		if player.wall_jump_boost_active():
			horizontal = horizontal.limit_length(player.wall_jump_speed_cap())
		player.velocity.x = horizontal.x
		player.velocity.z = horizontal.z
		player.apply_gravity(delta)
		return
	player.apply_air_movement(input, delta)
	machine.transition_to(&"Jump" if player.velocity.y > 0.0 else &"Fall", "fim do lançamento")


func post_move(_input: PlayerInput) -> void:
	if not is_sticking() and player.is_on_floor() and player.velocity.y <= 0.0:
		machine.transition_to(&"Land", "tocou o chão")
