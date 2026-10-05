extends GutTest
## Dodge: custo, invencibilidade, 8 direções, bloqueio com SP zerado e dodge cancel.

const Driver = preload("res://tests/helpers/player_driver.gd")

var d: Driver


func before_each() -> void:
	d = Driver.new()
	d.setup(self, Vector3(0, 0, 0))
	d.add_block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	await d.ready_physics(self)
	d.step(10)


func test_dodge_costs_20_sp_and_moves_in_input_direction() -> void:
	var start := d.player.global_position
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_almost_eq(d.player.sp.current, 80.0, 0.01)
	d.step(20)
	var moved := d.player.global_position - start
	assert_gt(moved.x, 2.5, "passo rápido para a direita")
	assert_almost_eq(moved.z, 0.0, 0.01)


func test_invulnerability_lasts_0_15_s() -> void:
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	var invulnerable_ticks := 1 if d.player.is_invulnerable else 0
	for i in 30:
		d.step(1)
		if d.player.is_invulnerable:
			invulnerable_ticks += 1
	assert_eq(invulnerable_ticks, 9, "0,15 s a 60 ticks")
	assert_false(d.player.is_invulnerable)


func test_dash_without_direction_does_nothing_by_default() -> void:
	d.press_dodge()
	d.step(5)
	assert_ne(d.state(), &"Dodge", "Shift sozinho não dá dash")
	assert_eq(d.player.sp.current, 100.0)


func test_shift_then_direction_inside_buffer_dashes() -> void:
	d.press_dodge()
	d.step(2)
	d.step(1, Vector2(-1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_lt(d.player.velocity.x, -10.0, "dash para a esquerda (Shift + A)")


func test_neutral_dodge_goes_backward_relative_to_camera() -> void:
	d.player.config.dodge_requires_direction = false
	d.player.config.dodge_side_only = false
	d.press_dodge()
	d.step(5)
	assert_gt(d.player.velocity.z, 10.0, "sem direção: passo para trás (+Z com câmera olhando -Z)")


func test_no_dodge_when_exhausted() -> void:
	d.player.sp.current = 1.0
	d.player.sp.drain(1.0)
	assert_true(d.player.sp.exhausted)
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_ne(d.state(), &"Dodge")


func test_dodge_cancels_land_recovery() -> void:
	d.press_jump()
	d.step(1)
	d.step_until(func() -> bool: return d.state() == &"Land", 120)
	d.press_dodge()
	d.step(1, Vector2(-1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_has(d.techniques, MovementRules.TECH_DODGE_CANCEL)


func test_dodge_cancels_its_own_recovery_but_not_the_dash() -> void:
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	d.press_dodge()
	d.step(1, Vector2(-1, 0))
	assert_almost_eq(d.player.sp.current, 80.0, 0.01, "durante o deslocamento não cancela")
	d.step(d.player.secs_to_ticks(d.player.config.dodge_duration) + 1)
	assert_true(d.player.state_machine.current.is_recovery())
	var sp_before := d.player.sp.current
	d.press_dodge()
	d.step(1, Vector2(-1, 0))
	assert_has(d.techniques, MovementRules.TECH_DODGE_CANCEL)
	assert_almost_eq(d.player.sp.current, sp_before - 20.0, 0.6)
	assert_lt(d.player.velocity.x, -10.0, "novo dodge para a esquerda")


func test_dodge_returns_to_ground_state() -> void:
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	d.step(d.player.secs_to_ticks(d.player.config.dodge_duration + d.player.config.dodge_recovery) + 5)
	assert_eq(d.state(), &"Idle")


func test_air_dash_once_per_jump_flat_and_refilled_on_landing() -> void:
	d.player.config.air_dodge_suspends_gravity = true
	d.press_jump()
	d.step(8)
	var y_before := d.player.global_position.y
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_almost_eq(d.player.velocity.y, 0.0, 0.001, "dash no ar é reto")
	assert_almost_eq(d.player.sp.current, 80.0, 0.01)
	d.step(5, Vector2(1, 0))
	assert_almost_eq(d.player.global_position.y, y_before, 0.05, "não caiu durante o dash")
	d.step(d.player.secs_to_ticks(d.player.config.dodge_duration) - 4)
	assert_ne(d.state(), &"Dodge")
	assert_false(d.player.is_on_floor())
	d.press_dodge()
	d.step(1, Vector2(-1, 0))
	assert_ne(d.state(), &"Dodge", "só um dash por pulo")
	d.step_until(func() -> bool: return d.player.is_on_floor(), 120)
	d.step(10)
	d.press_jump()
	d.step(6)
	d.press_dodge()
	d.step(1, Vector2(-1, 0))
	assert_eq(d.state(), &"Dodge", "recarregou ao aterrissar")


func test_air_dash_accelerates_fall() -> void:
	d.press_jump()
	d.step(10)
	assert_gt(d.player.velocity.y, 0.0, "ainda subindo")
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_lte(d.player.velocity.y, -d.player.config.air_dodge_fall_speed, "mergulha no dash")
	var vy := d.player.velocity.y
	d.step(3, Vector2(1, 0))
	assert_lt(d.player.velocity.y, vy, "cai cada vez mais rápido")
	assert_gt(d.player.get_horizontal_speed(), 10.0, "continua indo para o lado")


func test_air_dash_cancels_accumulated_fall() -> void:
	d.player.respawn(Transform3D(Basis(), Vector3(0, 30, 0)))
	d.step_until(func() -> bool: return d.player.velocity.y < -12.0, 120)
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_gt(d.player.velocity.y, -d.player.config.air_dodge_fall_speed - 0.5, "o dash corta a queda")


func test_landing_after_air_dash_has_no_roll() -> void:
	d.player.respawn(Transform3D(Basis(), Vector3(0, 12, 0)))
	d.step(20)
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	var rolled := false
	for i in 200:
		d.step(1)
		if d.state() == &"Land" and d.player.state_machine.current.rolling:
			rolled = true
		if d.player.is_on_floor() and d.state() != &"Dodge":
			break
	assert_true(d.player.is_on_floor())
	assert_false(rolled, "dash no ar cancela a cambalhota")
	assert_true(d.player.last_landing_soft)


func test_landing_after_air_attack_has_no_roll() -> void:
	d.player.respawn(Transform3D(Basis(), Vector3(0, 12, 0)))
	d.step(20)
	d.press_attack()
	d.step(1)
	assert_eq(d.state(), &"Attack")
	d.step_until(func() -> bool: return d.state() == &"Land", 200)
	assert_eq(d.state(), &"Land")
	assert_false(d.player.state_machine.current.rolling, "golpe no ar cancela a cambalhota")
	d.step(30)
	d.player.respawn(Transform3D(Basis(), Vector3(0, 12, 0)))
	d.step_until(func() -> bool: return d.state() == &"Land", 200)
	assert_true(d.player.state_machine.current.rolling, "queda normal ainda rola")


func test_air_dash_continues_after_touching_ground() -> void:
	d.press_jump()
	d.step(4)
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge")
	d.step_until(func() -> bool: return d.player.is_on_floor(), 60, Vector2(1, 0))
	d.step(1, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge", "o dash continua no chão")
	assert_gt(d.player.get_horizontal_speed(), 4.0)
	d.press_jump()
	d.step(1)
	assert_eq(d.state(), &"Jump", "pular interrompe o dash")


func test_air_dash_keeps_momentum_and_returns_to_fall() -> void:
	d.player.config.air_dodge_suspends_gravity = true
	d.press_jump()
	d.step(20)
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	d.step(d.player.secs_to_ticks(d.player.config.dodge_duration) + 1)
	assert_true(d.state() == &"Fall" or d.state() == &"Jump")
	assert_almost_eq(d.player.get_horizontal_speed(), d.player.config.air_dodge_exit_speed, 0.5)


func test_air_dash_can_be_disabled() -> void:
	d.player.config.dodge_allow_in_air = false
	d.press_jump()
	d.step(8)
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_ne(d.state(), &"Dodge")


func test_space_plus_side_key_dashes_instead_of_jumping() -> void:
	d.press_jump()
	d.step(1, Vector2(1, 0))  # Espaço + D
	assert_eq(d.state(), &"Dodge")
	assert_gt(d.player.velocity.x, 15.0, "dash para a direita")
	assert_lte(d.player.velocity.y, 0.0, "não pulou")


func test_space_with_forward_diagonal_still_jumps() -> void:
	d.press_jump()
	d.step(1, Vector2(0.707, 0.707))  # W + D + Espaço
	assert_eq(d.state(), &"Jump")


func test_dash_only_goes_sideways() -> void:
	d.press_dodge()
	d.step(1, Vector2(0, 1))
	assert_ne(d.state(), &"Dodge", "dash não vai para frente")


func test_dash_decelerates_and_goes_farther() -> void:
	var start := d.player.global_position
	d.press_jump()
	d.step(1, Vector2(1, 0))
	var first := d.player.get_horizontal_speed()
	d.step(10)
	var middle := d.player.get_horizontal_speed()
	d.step(10)
	var late := d.player.get_horizontal_speed()
	assert_gt(first, middle, "desacelera")
	assert_gt(middle, late)
	d.step(30)
	assert_gt(d.player.global_position.x - start.x, 4.0, "distância maior que o passo antigo")


func test_space_during_dash_cancels_and_jumps() -> void:
	d.press_jump()
	d.step(1, Vector2(1, 0))
	d.step(5)
	var dash_speed := d.player.get_horizontal_speed()
	d.press_jump()
	d.step(1)
	assert_eq(d.state(), &"Jump", "cancelou o dash com pulo")
	assert_gt(d.player.velocity.y, 5.0)
	assert_lt(d.player.get_horizontal_speed(), dash_speed, "parte do embalo mantida")
	assert_gt(d.player.get_horizontal_speed(), 3.0)
	assert_has(d.techniques, MovementRules.TECH_DASH_JUMP)


func test_air_dash_with_space_and_side_key() -> void:
	d.press_jump()
	d.step(8)
	d.press_jump()
	d.step(1, Vector2(-1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_lt(d.player.velocity.x, -15.0)
