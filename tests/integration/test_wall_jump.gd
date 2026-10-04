extends GutTest
## Wall jump com física real: regra "só após pulo", reflexão, encadeamento, bloqueio de
## mesma parede e técnicas (reverse, back-coming, cancel).

const Driver = preload("res://tests/helpers/player_driver.gd")
const FWD := Vector2(0, 1)

var d: Driver


func _world(spawn: Vector3, overrides: Dictionary = {}) -> void:
	d = Driver.new()
	d.setup(self, spawn, overrides)
	d.add_block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))


## Parede alta e lisa com a face em z = face_z (o jogador vem de +Z correndo para -Z).
func _tall_wall(face_z: float, height: float = 12.0) -> GreyboxBlock:
	return d.add_block(Vector3(0, height * 0.5, face_z - 0.5), Vector3(20, height, 1))


func test_falling_off_ledge_into_wall_does_not_allow_wall_jump() -> void:
	_world(Vector3(0, 6.0, 1.0))
	d.add_block(Vector3(0, 3, 0), Vector3(4, 6, 4))  # plataforma, borda em z = -2
	var wall := _tall_wall(-4.5)
	await d.ready_physics(self)
	d.step(10)
	assert_true(d.player.is_on_floor(), "começa em cima da plataforma")
	var touched := d.step_until_wall(wall, 120, FWD)
	assert_gt(touched, 0, "tocou a parede caindo")
	assert_false(d.player.is_on_floor())
	assert_eq(d.state(), &"Fall")
	assert_eq(d.player.air_origin, MovementRules.AirOrigin.FALL)
	var sp_before := d.player.sp.current
	d.press_jump()
	d.step(1, FWD)
	assert_ne(d.state(), &"WallJump", "queda livre não pode virar wall jump")
	assert_lte(d.player.velocity.y, 0.0, "nenhum impulso vertical")
	assert_eq(d.player.sp.current, sp_before, "não gastou SP")
	assert_eq(d.player.get_wall_jump_block_reason(), "não veio de pulo")
	assert_eq(d.wall_jumps.size(), 0)


func test_jump_into_wall_allows_wall_jump_and_costs_18_sp() -> void:
	_world(Vector3(0, 0, 0))
	var wall := _tall_wall(-3.0)
	await d.ready_physics(self)
	d.step(10)
	d.step(5, FWD)
	d.press_jump()
	d.step(1, FWD)
	assert_gt(d.step_until_wall(wall, 90, FWD), 0)
	var sp_before := d.player.sp.current
	d.press_jump()
	d.step(1)
	assert_eq(d.state(), &"WallJump")
	assert_almost_eq(d.player.sp.current, sp_before - 18.0, 0.01)
	assert_gt(d.player.velocity.y, 0.0)
	assert_gt(d.player.velocity.z, 0.0, "refletiu para longe da parede")
	assert_eq(d.wall_jumps.size(), 1)


func test_wall_jump_reflects_diagonal_entry() -> void:
	_world(Vector3(0, 0, 0), {"wall_jump_camera_weight": 0.0, "wall_jump_forward_boost": 0.0,
		"wall_jump_horizontal_multiplier": 1.0})
	var wall := _tall_wall(-3.0)
	await d.ready_physics(self)
	d.step(10)
	var diagonal := Vector2(1, 1).normalized()  # frente-direita
	d.step(8, diagonal)
	d.press_jump()
	d.step(1, diagonal)
	assert_gt(d.step_until_wall(wall, 90, diagonal), 0)
	d.press_jump()
	d.step(1)
	var data: Dictionary = d.wall_jumps[0]
	var v_in: Vector3 = data.velocity_in
	var v_out: Vector3 = WallJumpMath.horizontal(data.velocity_out)
	var n: Vector3 = data.normal
	assert_almost_eq(WallJumpMath.exit_angle_deg(v_out, n), WallJumpMath.incidence_angle_deg(v_in, n), 0.5)
	assert_gt(v_out.x, 0.0, "continua para o lado (side jump)")
	assert_eq(data.technique, MovementRules.TECH_SIDE_JUMP)
	assert_has(d.techniques, MovementRules.TECH_SIDE_JUMP)


func test_wall_jump_blocked_after_window_expires() -> void:
	_world(Vector3(0, 0, 0), {"wall_jump_window_after_jump": 0.3})
	var wall := _tall_wall(-4.5)
	await d.ready_physics(self)
	d.step(10)
	d.step(5, FWD)
	d.press_jump()
	d.step(1, FWD)
	assert_gt(d.step_until_wall(wall, 120, FWD), 0)
	assert_gt(d.player.ticks_since(d.player.last_jump_tick), 18)
	assert_eq(d.state(), &"Fall")
	d.press_jump()
	d.step(1)
	assert_ne(d.state(), &"WallJump")
	assert_eq(d.player.get_wall_jump_block_reason(), "janela pós-pulo expirou")


func test_same_wall_twice_in_a_row_is_blocked() -> void:
	# Saída lenta para conseguir voltar à mesma parede ainda no ar.
	_world(Vector3(0, 0, -2.4), {"wall_jump_min_horizontal_speed": 1.5, "wall_jump_min_away_speed": 1.5})
	var wall := _tall_wall(-3.0)
	await d.ready_physics(self)
	d.step(10)
	d.press_jump()
	d.step(1, FWD)
	d.step(10, FWD)  # passa da janela justa da base: wall jump normal
	d.press_jump()
	d.step(1)
	assert_eq(d.state(), &"WallJump")
	assert_eq(d.wall_jumps[0].technique, MovementRules.TECH_NORMAL)
	d.step(10, FWD)  # volta para a mesma parede com o controle aéreo
	d.step_until_wall(wall, 60, FWD)
	d.press_jump()
	d.step(1, FWD)
	assert_eq(d.wall_jumps.size(), 1, "segundo wall jump na mesma parede bloqueado")
	assert_eq(d.player.get_wall_jump_block_reason(), "mesma parede")


func test_chained_wall_jumps_between_parallel_walls_climb() -> void:
	_world(Vector3(0, 0, 1.0))
	var wall_a := d.add_block(Vector3(0, 10, -2.0), Vector3(20, 20, 1))  # face em z = -1.5
	var wall_b := d.add_block(Vector3(0, 10, 2.0), Vector3(20, 20, 1))   # face em z = +1.5
	await d.ready_physics(self)
	d.step(10)
	d.step(5, FWD)
	d.press_jump()
	d.step(1, FWD)
	var heights: Array[float] = []
	var walls := [wall_a, wall_b, wall_a, wall_b]
	for wall: GreyboxBlock in walls:
		assert_gt(d.step_until_wall(wall, 90), 0, "chegou na parede %s" % wall.name)
		heights.append(d.player.global_position.y)
		d.press_jump()
		d.step(1)
		assert_eq(d.state(), &"WallJump")
	assert_eq(d.wall_jumps.size(), 4)
	assert_gt(heights[3] - heights[0], 3.0, "subiu encadeando wall jumps: %s" % [heights])


func test_reverse_wall_jump_near_top_goes_over_the_ledge() -> void:
	_world(Vector3(0, 0, 0.3))
	var ledge := d.add_block(Vector3(0, 1.8, -6.0), Vector3(20, 3.6, 6))  # face z=-3, topo 3,6 m
	await d.ready_physics(self)
	d.step(10)
	d.step(8, FWD)  # embalo: chega na parede perto do ápice do pulo
	d.press_jump()
	d.step(1, FWD)
	assert_gt(d.step_until_wall(ledge, 90, FWD), 0)
	assert_true(d.player.wall_sensor.is_near_top(), "pés altos o bastante: raio acima da cabeça livre")
	d.press_jump()
	d.step(1)  # solta o direcional: o próprio lançamento leva por cima
	assert_eq(d.wall_jumps[0].technique, MovementRules.TECH_REVERSE)
	assert_has(d.techniques, MovementRules.TECH_REVERSE)
	assert_lt(d.wall_jumps[0].velocity_out.z, 0.0, "lançado para frente, por cima")
	d.step(60)
	assert_true(d.player.is_on_floor())
	assert_almost_eq(d.player.global_position.y, 3.6, 0.05, "terminou em cima da borda")
	assert_lt(d.player.global_position.z, -3.0)


func test_late_press_near_top_is_normal_wall_jump() -> void:
	_world(Vector3(0, 0, 0.3))
	var ledge := d.add_block(Vector3(0, 1.8, -6.0), Vector3(20, 3.6, 6))
	await d.ready_physics(self)
	d.step(10)
	d.step(8, FWD)
	d.press_jump()
	d.step(1, FWD)
	assert_gt(d.step_until_wall(ledge, 90, FWD), 0)
	d.step(d.player.config.technique_window_ticks + 2, FWD)
	d.press_jump()
	d.step(1)
	assert_eq(d.wall_jumps.size(), 1)
	assert_eq(d.wall_jumps[0].technique, MovementRules.TECH_NORMAL, "fora da janela justa")
	assert_gt(d.player.velocity.z, 0.0, "refletiu para trás")


func test_back_coming_allows_second_wall_jump_on_same_wall() -> void:
	_world(Vector3(0, 0, -2.45))
	var wall := _tall_wall(-3.0)
	await d.ready_physics(self)
	d.step(10, FWD)
	d.press_jump()
	d.step(2, FWD)
	d.press_jump()
	d.step(1, FWD)
	assert_eq(d.wall_jumps.size(), 1)
	assert_eq(d.wall_jumps[0].technique, MovementRules.TECH_BACK_COMING)
	assert_has(d.techniques, MovementRules.TECH_BACK_COMING)
	var start_y := d.player.global_position.y
	d.step(12)  # sobe colado na parede, sem input
	assert_true(d.player.wall_sensor.has_contact, "continua encostado na parede")
	assert_gt(d.player.global_position.y, start_y + 1.0)
	d.press_jump()
	d.step(1)
	assert_eq(d.wall_jumps.size(), 2, "segundo wall jump na MESMA parede liberado pelo back-coming")
	assert_eq(d.state(), &"WallJump")
	assert_eq(d.wall_jumps[1].normal, d.wall_jumps[0].normal)
	assert_eq(d.wall_jumps[1].technique, MovementRules.TECH_NORMAL, "parede alta: sem topo perto")
	assert_gt(d.player.velocity.z, 0.0, "segundo salto se afasta da parede")


func test_cancel_on_wall_jump_preserves_part_of_speed() -> void:
	_world(Vector3(0, 0, 0))
	var wall := _tall_wall(-3.0)
	await d.ready_physics(self)
	d.step(10)
	d.step(5, FWD)
	d.press_jump()
	d.step(1, FWD)
	assert_gt(d.step_until_wall(wall, 90, FWD), 0)
	d.press_jump()
	d.press_weapon_swap(1)
	d.step(1)
	assert_has(d.techniques, MovementRules.TECH_CANCEL)
	assert_ne(d.state(), &"WallJump")
	var entry: Vector3 = d.wall_jumps[0].velocity_in
	var h := d.player.get_horizontal_velocity()
	assert_lt(h.z, 0.1, "lançamento desfeito: não foi refletido para trás")
	assert_almost_eq(h.length(), entry.length() * d.player.config.cancel_speed_retained, 0.6)


func test_cancel_shortly_after_wall_jump_and_not_after_window() -> void:
	_world(Vector3(0, 0, 0))
	var wall := _tall_wall(-3.0)
	await d.ready_physics(self)
	d.step(10)
	d.step(5, FWD)
	d.press_jump()
	d.step(1, FWD)
	assert_gt(d.step_until_wall(wall, 90, FWD), 0)
	d.press_jump()
	d.step(1)
	d.step(d.player.config.cancel_window_ticks + 2)
	d.press_weapon_swap(2)
	d.step(1)
	assert_does_not_have(d.techniques, MovementRules.TECH_CANCEL, "tarde demais")


func test_back_coming_then_reverse_climbs_wall_too_tall_for_a_single_jump() -> void:
	_world(Vector3(0, 0, -2.45))
	d.add_block(Vector3(0, 2.2, -6.0), Vector3(20, 4.4, 6))  # bloco de 4,4 m, face em z = -3
	await d.ready_physics(self)
	d.step(10, FWD)
	d.press_jump()
	d.step(3, FWD)
	d.press_jump()
	d.step(1)
	assert_eq(d.wall_jumps[0].technique, MovementRules.TECH_BACK_COMING)
	var near_top := d.step_until(func() -> bool: return d.player.wall_sensor.is_near_top(), 40)
	assert_gt(near_top, 0, "back-coming leva os pés alto o bastante")
	d.press_jump()
	d.step(1)
	assert_eq(d.wall_jumps[1].technique, MovementRules.TECH_REVERSE)
	d.step(60)
	assert_true(d.player.is_on_floor())
	assert_almost_eq(d.player.global_position.y, 4.4, 0.05, "em cima da parede de 4,4 m")


func test_single_jump_cannot_reverse_over_4_4_m_wall() -> void:
	_world(Vector3(0, 0, 0.3))
	var wall := _tall_wall(-3.0, 4.4)
	await d.ready_physics(self)
	d.step(10)
	d.step(8, FWD)
	d.press_jump()
	d.step(1, FWD)
	var max_near_top := false
	for i in 40:
		d.step(1, FWD)
		max_near_top = max_near_top or d.player.wall_sensor.is_near_top()
	assert_false(max_near_top, "pulo simples nunca chega perto do topo de 4,4 m")
