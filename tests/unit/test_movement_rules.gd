extends GutTest
## Regras puras: wall jump só após pulo, janela do bunny hop, classificação e dodge em 8 direções.

const JUMP := MovementRules.AirOrigin.JUMP
const FALL := MovementRules.AirOrigin.FALL
const NONE := MovementRules.AirOrigin.NONE


func test_wall_jump_allowed_while_rising_from_jump() -> void:
	assert_true(MovementRules.can_wall_jump(JUMP, true, 200, 36))


func test_wall_jump_allowed_falling_inside_window_after_jump() -> void:
	assert_true(MovementRules.can_wall_jump(JUMP, false, 36, 36))


func test_wall_jump_blocked_falling_after_window() -> void:
	assert_false(MovementRules.can_wall_jump(JUMP, false, 37, 36))


func test_wall_jump_never_allowed_after_falling_off_ledge() -> void:
	for ticks: int in [0, 1, 10, 36, 1000]:
		assert_false(MovementRules.can_wall_jump(FALL, false, ticks, 36), "queda livre, %d ticks" % ticks)
		assert_false(MovementRules.can_wall_jump(FALL, true, ticks, 36))
	assert_false(MovementRules.can_wall_jump(NONE, false, 0, 36))


func test_bunny_hop_window_is_three_ticks_after_landing() -> void:
	var land := 100
	assert_true(MovementRules.is_bunny_hop(100, land, 3), "mesmo tick")
	assert_true(MovementRules.is_bunny_hop(101, land, 3))
	assert_true(MovementRules.is_bunny_hop(102, land, 3))
	assert_false(MovementRules.is_bunny_hop(103, land, 3), "4º tick já perdeu")
	assert_false(MovementRules.is_bunny_hop(99, land, 3), "aperto antes de aterrissar não conta")


func test_bunny_hop_window_is_configurable() -> void:
	assert_true(MovementRules.is_bunny_hop(104, 100, 5))
	assert_false(MovementRules.is_bunny_hop(100, 100, 0))


func test_technique_window_is_symmetric() -> void:
	assert_true(MovementRules.is_within_window(46, 50, 4))
	assert_true(MovementRules.is_within_window(54, 50, 4))
	assert_false(MovementRules.is_within_window(55, 50, 4))


func test_classification_priorities() -> void:
	var side := 30.0
	assert_eq(MovementRules.classify_wall_jump(true, true, true, 0.0, side), MovementRules.TECH_REVERSE)
	assert_eq(MovementRules.classify_wall_jump(true, false, true, 0.0, side), MovementRules.TECH_BACK_COMING)
	assert_eq(MovementRules.classify_wall_jump(false, true, true, 0.0, side), MovementRules.TECH_NORMAL,
		"fora da janela justa não há técnica de topo/base")
	assert_eq(MovementRules.classify_wall_jump(false, false, false, 45.0, side), MovementRules.TECH_SIDE_JUMP)
	assert_eq(MovementRules.classify_wall_jump(false, false, false, 10.0, side), MovementRules.TECH_NORMAL)


func test_dodge_snaps_to_8_camera_relative_directions() -> void:
	var cases := {
		Vector2(0, 1): Vector3(0, 0, -1),
		Vector2(0, -1): Vector3(0, 0, 1),
		Vector2(1, 0): Vector3(1, 0, 0),
		Vector2(-1, 0): Vector3(-1, 0, 0),
		Vector2(1, 1).normalized(): Vector3(1, 0, -1).normalized(),
		Vector2(0.3, 0.9): Vector3(0, 0, -1),
		Vector2(0.6, 0.8): Vector3(1, 0, -1).normalized(),
	}
	for move: Vector2 in cases:
		var dir := MovementRules.dodge_direction(move, 0.0, true)
		assert_almost_eq(dir.distance_to(cases[move]), 0.0, 0.0001, str(move))


func test_dodge_follows_camera_yaw_and_neutral_direction() -> void:
	var dir := MovementRules.dodge_direction(Vector2(0, 1), PI * 0.5, true)
	assert_almost_eq(dir.distance_to(Vector3(-1, 0, 0)), 0.0, 0.0001)
	var neutral_back := MovementRules.dodge_direction(Vector2.ZERO, 0.0, true)
	assert_almost_eq(neutral_back.distance_to(Vector3(0, 0, 1)), 0.0, 0.0001)
	var neutral_forward := MovementRules.dodge_direction(Vector2.ZERO, 0.0, false)
	assert_almost_eq(neutral_forward.distance_to(Vector3(0, 0, -1)), 0.0, 0.0001)


func test_seconds_to_ticks_at_60hz() -> void:
	assert_eq(MovementRules.seconds_to_ticks(0.15), 9)
	assert_eq(MovementRules.seconds_to_ticks(0.6), 36)


func test_double_tap_window() -> void:
	assert_true(MovementRules.is_double_tap(110, 100, 15))
	assert_true(MovementRules.is_double_tap(115, 100, 15))
	assert_false(MovementRules.is_double_tap(116, 100, 15), "intervalo longo demais")
	assert_false(MovementRules.is_double_tap(100, 100, 15), "mesmo toque")
	assert_false(MovementRules.is_double_tap(100, PlayerInput.NEVER, 15), "primeiro toque")


func test_side_dash_direction_and_speed_curve() -> void:
	assert_almost_eq(MovementRules.side_dash_direction(1.0, 0.0).distance_to(Vector3(1, 0, 0)), 0.0, 0.0001)
	assert_almost_eq(MovementRules.side_dash_direction(-1.0, 0.0).distance_to(Vector3(-1, 0, 0)), 0.0, 0.0001)
	assert_almost_eq(MovementRules.dash_speed(0.0, 24.0, 4.0, 1.8), 24.0, 0.001)
	assert_almost_eq(MovementRules.dash_speed(1.0, 24.0, 4.0, 1.8), 4.0, 0.001)
	assert_lt(MovementRules.dash_speed(0.5, 24.0, 4.0, 1.8), 14.0, "freia mais no começo")
