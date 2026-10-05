extends GutTest
## Controller base com física real: andar, sprint + SP, pulo único e altura do pulo.

const Driver = preload("res://tests/helpers/player_driver.gd")

const FWD := Vector2(0, 1)

var d: Driver


func before_each() -> void:
	d = Driver.new()
	d.setup(self, Vector3(0, 0.05, 0))
	d.add_block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	await d.ready_physics(self)
	d.step(20)


func test_settles_on_floor_idle() -> void:
	assert_true(d.player.is_on_floor())
	assert_eq(d.player.get_state_name(), &"Idle")


func test_walk_reaches_6_mps() -> void:
	d.step(60, FWD)
	assert_eq(d.player.get_state_name(), &"Run")
	assert_almost_eq(d.player.get_horizontal_speed(), 6.0, 0.05)


func test_walk_direction_is_camera_relative() -> void:
	d.look_yaw = PI * 0.5  # câmera olhando para -X
	d.step(30, FWD)
	var v := d.player.get_horizontal_velocity().normalized()
	assert_almost_eq(v.x, -1.0, 0.01)


func test_sprint_reaches_10_mps_and_drains_sp() -> void:
	d.step(60, FWD, true)
	assert_eq(d.player.get_state_name(), &"Sprint")
	assert_almost_eq(d.player.get_horizontal_speed(), 10.0, 0.05)
	assert_almost_eq(d.player.sp.current, 88.0, 1.0)


func test_sprint_ends_when_sp_depleted() -> void:
	d.player.sp.current = 1.0
	d.step(20, FWD, true)
	assert_true(d.player.sp.exhausted)
	assert_eq(d.player.get_state_name(), &"Run")
	d.step(30, FWD, true)
	assert_eq(d.player.get_state_name(), &"Run", "exausto: toque duplo não volta a dar sprint")
	assert_almost_eq(d.player.get_horizontal_speed(), 6.0, 0.1)


func test_jump_height_matches_config() -> void:
	var start_y := d.player.global_position.y
	d.press_jump()
	d.step()
	assert_eq(d.player.get_state_name(), &"Jump")
	var max_y := start_y
	for i in 60:
		d.step()
		max_y = maxf(max_y, d.player.global_position.y)
	assert_almost_eq(max_y - start_y, d.player.config.jump_height, 0.03)
	assert_true(d.player.is_on_floor())


func test_no_double_jump_in_air() -> void:
	d.press_jump()
	d.step(10)
	var vy_before := d.player.velocity.y
	d.press_jump()
	d.step()
	assert_lt(d.player.velocity.y, vy_before, "segundo pulo no ar não pode dar impulso")


func test_full_jump_cycle_states() -> void:
	d.press_jump()
	d.step()
	assert_eq(d.player.get_state_name(), &"Jump")
	var ticks := d.step_until(func() -> bool: return d.player.get_state_name() == &"Fall", 60)
	assert_gt(ticks, 0)
	ticks = d.step_until(func() -> bool: return d.player.get_state_name() == &"Land", 60)
	assert_gt(ticks, 0)
	ticks = d.step_until(func() -> bool: return d.player.get_state_name() == &"Idle", 90)
	assert_gt(ticks, 0, "depois da cambalhota volta ao Idle")


func test_walking_off_ledge_enters_fall_with_fall_origin() -> void:
	d.add_block(Vector3(0, 2.5, -20), Vector3(4, 1, 4))  # plataforma elevada
	await d.ready_physics(self)
	d.player.respawn(Transform3D(Basis(), Vector3(0, 3.05, -20)))
	d.step(5)
	assert_true(d.player.is_on_floor())
	var ticks := d.step_until(func() -> bool: return d.player.get_state_name() == &"Fall", 120, FWD)
	assert_gt(ticks, 0)
	assert_eq(d.player.air_origin, MovementRules.AirOrigin.FALL)


func test_single_forward_press_walks_and_double_tap_sprints() -> void:
	var input_tick := d.player.tick + 1
	var walk := d.make_input(FWD, false)
	walk.forward_pressed_tick = input_tick
	d.player.step(walk, Driver.DT)
	d.step(30, FWD)
	assert_eq(d.player.get_state_name(), &"Run", "um toque só: anda")
	d.step(5)  # solta o W
	d.forward_prev_pressed_tick = d.player.tick - 10
	d.forward_pressed_tick = d.player.tick + 1
	d.step(30, FWD)
	assert_eq(d.player.get_state_name(), &"Sprint", "toque duplo em W: corre")
	d.step(3)  # soltou o W
	d.step(5, FWD)
	assert_ne(d.player.get_state_name(), &"Sprint", "soltar o W encerra o sprint")


## Pula parado, espera `ticks_before` e (opcional) faz o toque duplo em W no ar.
func _jump_and_measure_airtime(air_sprint: bool) -> Dictionary:
	d.press_jump()
	d.step(1)
	d.step(6)
	if air_sprint:
		d.forward_prev_pressed_tick = d.player.tick - 4
		d.forward_pressed_tick = d.player.tick + 1
	var sp_before := d.player.sp.current
	var max_speed := 0.0
	var ticks := 0
	while not d.player.is_on_floor() and ticks < 120:
		d.step(1, FWD)
		ticks += 1
		max_speed = maxf(max_speed, d.player.get_horizontal_speed())
	return {"ticks": ticks, "speed": max_speed, "sp_used": sp_before - d.player.sp.current}


func test_air_sprint_accelerates_but_falls_faster_and_costs_sp() -> void:
	var normal := _jump_and_measure_airtime(false)
	d.step(40)
	var sprint := _jump_and_measure_airtime(true)
	assert_gt(sprint.speed, normal.speed + 2.0, "corrida no ar acelera (%.1f vs %.1f)" % [sprint.speed, normal.speed])
	assert_lt(sprint.ticks, normal.ticks - 3, "e cai mais rápido (%d vs %d ticks)" % [sprint.ticks, normal.ticks])
	assert_gt(sprint.sp_used, 1.0, "gasta SP")
	assert_false(d.player.air_sprinting, "acaba ao aterrissar")


func test_ground_sprint_jump_does_not_speed_up_fall() -> void:
	d.step(40, FWD, true)
	assert_true(d.player.sprint_latched)
	d.press_jump()
	d.step(1, FWD)
	d.step(10, FWD)
	assert_false(d.player.air_sprinting, "sprint do chão não vira corrida no ar sozinho")


func test_sprint_turns_instantly_to_camera_direction() -> void:
	d.step(40, FWD, true)
	assert_eq(d.player.get_state_name(), &"Sprint")
	d.look_yaw = PI * 0.5  # câmera vira 90° (olhando para -X)
	d.step(1, FWD, true)
	var v := d.player.get_horizontal_velocity()
	assert_almost_eq(v.normalized().x, -1.0, 0.01, "virou na hora")
	assert_almost_eq(v.length(), 10.0, 0.1, "sem perder velocidade")


func test_air_sprint_turns_instantly_to_camera_direction() -> void:
	d.press_jump()
	d.step(4)
	d.forward_prev_pressed_tick = d.player.tick - 4
	d.forward_pressed_tick = d.player.tick + 1
	d.step(8, FWD)
	assert_true(d.player.air_sprinting)
	var speed := d.player.get_horizontal_speed()
	d.look_yaw = -PI * 0.5  # olhando para +X
	d.step(1, FWD)
	var v := d.player.get_horizontal_velocity()
	assert_almost_eq(v.normalized().x, 1.0, 0.01, "virou na hora no ar")
	assert_gte(v.length(), speed - 0.01)


func test_walking_still_turns_with_acceleration() -> void:
	d.step(40, FWD)
	d.look_yaw = PI * 0.5
	d.step(1, FWD)
	var dir := d.player.get_horizontal_velocity().normalized()
	assert_lt(dir.z, -0.9, "andando não vira instantâneo: ainda vai quase todo para a frente antiga")
	assert_lt(dir.x, -0.05, "mas já começou a virar")


func test_landing_rolls_forward_keeping_momentum() -> void:
	d.step(30, FWD)
	d.press_jump()
	d.step(1, FWD)
	d.step_until(func() -> bool: return d.player.get_state_name() == &"Land", 90, FWD)
	assert_true(d.player.state_machine.current.rolling, "cambalhota ao aterrissar")
	var z_before := d.player.global_position.z
	d.step(10)
	assert_lt(d.player.global_position.z, z_before - 0.5, "rola para frente mesmo sem input")


func test_roll_can_be_cancelled_by_dash() -> void:
	d.press_jump()
	d.step(1)
	d.step_until(func() -> bool: return d.player.get_state_name() == &"Land", 90)
	d.step(5)
	d.press_jump()
	d.step(1, Vector2(1, 0))
	assert_eq(d.player.get_state_name(), &"Dodge")
	assert_has(d.techniques, MovementRules.TECH_DODGE_CANCEL)


func test_roll_can_be_cancelled_by_sprint_double_tap() -> void:
	d.press_jump()
	d.step(1)
	d.step_until(func() -> bool: return d.player.get_state_name() == &"Land", 90)
	d.step(5)
	d.forward_prev_pressed_tick = d.player.tick - 4
	d.forward_pressed_tick = d.player.tick + 1
	d.step(1, FWD)
	assert_eq(d.player.get_state_name(), &"Sprint")


func test_landing_while_air_sprinting_does_not_roll() -> void:
	d.press_jump()
	d.step(5)
	d.forward_prev_pressed_tick = d.player.tick - 4
	d.forward_pressed_tick = d.player.tick + 1
	d.step(1, FWD)
	assert_true(d.player.air_sprinting)
	d.step_until(func() -> bool: return d.player.get_state_name() == &"Land", 90, FWD)
	assert_false(d.player.state_machine.current.rolling)


func test_sprint_start_emits_event_once() -> void:
	var count := [0]
	var handler := func(_p: Node) -> void: count[0] += 1
	GameEvents.sprint_started.connect(handler)
	d.step(40, FWD, true)
	GameEvents.sprint_started.disconnect(handler)
	assert_eq(count[0], 1, "um gritinho ao começar a correr")
