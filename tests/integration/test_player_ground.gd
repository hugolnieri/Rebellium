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
	assert_eq(d.player.get_state_name(), &"Run", "exausto: Shift não volta a dar sprint")
	assert_almost_eq(d.player.get_horizontal_speed(), 6.0, 0.1)


func test_jump_height_is_2_2_m() -> void:
	var start_y := d.player.global_position.y
	d.press_jump()
	d.step()
	assert_eq(d.player.get_state_name(), &"Jump")
	var max_y := start_y
	for i in 60:
		d.step()
		max_y = maxf(max_y, d.player.global_position.y)
	assert_almost_eq(max_y - start_y, 2.2, 0.03)
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
	d.step(d.player.config.land_recovery_ticks + 1)
	assert_eq(d.player.get_state_name(), &"Idle")


func test_walking_off_ledge_enters_fall_with_fall_origin() -> void:
	d.add_block(Vector3(0, 2.5, -20), Vector3(4, 1, 4))  # plataforma elevada
	await d.ready_physics(self)
	d.player.respawn(Transform3D(Basis(), Vector3(0, 3.05, -20)))
	d.step(5)
	assert_true(d.player.is_on_floor())
	var ticks := d.step_until(func() -> bool: return d.player.get_state_name() == &"Fall", 120, FWD)
	assert_gt(ticks, 0)
	assert_eq(d.player.air_origin, MovementRules.AirOrigin.FALL)
