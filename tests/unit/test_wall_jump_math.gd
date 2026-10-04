extends GutTest
## Reflexão do wall jump: ângulo de entrada = ângulo de saída, para várias normais e entradas.

const NORMAL_ANGLES_DEG: Array[float] = [0.0, 30.0, 45.0, 90.0, 135.0, 180.0, 222.0, 270.0, 333.0]
const INCIDENCE_DEG: Array[float] = [0.0, 10.0, 25.0, 45.0, 60.0, 75.0, 85.0]
const SPEEDS: Array[float] = [3.0, 6.0, 10.0, 13.5]
const EPS: float = 0.0001


func _normal_from_angle(deg: float) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(sin(a), 0.0, cos(a))


## Vetor de entrada que bate na parede com `incidence` graus a partir da normal, do lado `side`.
func _incoming(n: Vector3, incidence_deg: float, side: float, speed: float) -> Vector3:
	var tangent := Vector3.UP.cross(n).normalized() * side
	var a := deg_to_rad(incidence_deg)
	return (-n * cos(a) + tangent * sin(a)) * speed


func test_exit_angle_equals_incidence_angle_for_many_normals_and_inputs() -> void:
	var checked := 0
	for normal_deg in NORMAL_ANGLES_DEG:
		var n := _normal_from_angle(normal_deg)
		for incidence in INCIDENCE_DEG:
			for side: float in [-1.0, 1.0]:
				for speed in SPEEDS:
					var v_in := _incoming(n, incidence, side, speed)
					var v_out := WallJumpMath.reflect_horizontal(v_in, n)
					var in_angle := WallJumpMath.incidence_angle_deg(v_in, n)
					var out_angle := WallJumpMath.exit_angle_deg(v_out, n)
					assert_almost_eq(in_angle, incidence, 0.01)
					assert_almost_eq(out_angle, in_angle, 0.01,
						"n=%s° inc=%s° lado=%s" % [normal_deg, incidence, side])
					checked += 1
	assert_eq(checked, NORMAL_ANGLES_DEG.size() * INCIDENCE_DEG.size() * 2 * SPEEDS.size())


func test_reflection_matches_formula_and_preserves_speed() -> void:
	for normal_deg in NORMAL_ANGLES_DEG:
		var n := _normal_from_angle(normal_deg)
		var v_in := _incoming(n, 40.0, 1.0, 8.0)
		var v_out := WallJumpMath.reflect_horizontal(v_in, n)
		var expected := v_in - 2.0 * v_in.dot(n) * n
		assert_almost_eq(v_out.distance_to(expected), 0.0, EPS)
		assert_almost_eq(v_out.length(), v_in.length(), EPS, "reflexão conserva o módulo")
		assert_almost_eq(v_out.dot(n), -v_in.dot(n), EPS, "componente normal inverte")
		var tangent_in := v_in - n * v_in.dot(n)
		var tangent_out := v_out - n * v_out.dot(n)
		assert_almost_eq(tangent_out.distance_to(tangent_in), 0.0, EPS, "componente tangente se mantém")


func test_head_on_reflects_straight_back() -> void:
	var v_out := WallJumpMath.reflect_horizontal(Vector3(0, 0, -6), Vector3(0, 0, 1))
	assert_almost_eq(v_out.distance_to(Vector3(0, 0, 6)), 0.0, EPS)


func test_vertical_component_of_input_and_normal_is_ignored() -> void:
	var n_tilted := Vector3(0.0, 0.25, 1.0).normalized()
	var v_out := WallJumpMath.reflect_horizontal(Vector3(3, -7, -4), n_tilted)
	assert_eq(v_out.y, 0.0)
	assert_almost_eq(v_out.distance_to(Vector3(3, 0, 4)), 0.0, EPS)


func test_moving_away_from_wall_is_not_reflected() -> void:
	var v := Vector3(2, 0, 3)
	assert_eq(WallJumpMath.reflect_horizontal(v, Vector3(0, 0, 1)), v)


## Config sem multiplicador, empurrão nem câmera: isola a reflexão.
func _neutral_cfg() -> MovementConfig:
	var cfg := MovementConfig.new()
	cfg.wall_jump_camera_weight = 0.0
	cfg.wall_jump_horizontal_multiplier = 1.0
	cfg.wall_jump_forward_boost = 0.0
	cfg.wall_jump_min_horizontal_speed = 6.0
	cfg.wall_jump_max_horizontal_speed = 14.0
	cfg.wall_jump_min_away_speed = 3.0
	return cfg


func test_exit_without_camera_weight_is_pure_reflection_in_speed_range() -> void:
	var cfg := _neutral_cfg()
	var n := _normal_from_angle(45.0)
	var v_in := _incoming(n, 50.0, -1.0, 9.0)
	var out := WallJumpMath.compute_exit_horizontal(v_in, n, Vector3.FORWARD, cfg)
	assert_almost_eq(out.distance_to(WallJumpMath.reflect_horizontal(v_in, n)), 0.0, EPS)


func test_diagonal_entry_launches_forward_side_jump() -> void:
	var cfg := _neutral_cfg()
	var n := Vector3(1, 0, 0)  # parede à esquerda, jogador correndo para -Z
	var v_in := Vector3(-5, 0, -8)
	var out := WallJumpMath.compute_exit_horizontal(v_in, n, Vector3.FORWARD, cfg)
	assert_almost_eq(out.z, -8.0, EPS, "mantém o avanço para frente")
	assert_almost_eq(out.x, 5.0, EPS, "afasta da parede")


func test_camera_weight_bends_exit_toward_camera() -> void:
	var cfg := _neutral_cfg()
	cfg.wall_jump_camera_weight = 0.3
	var n := Vector3(0, 0, 1)
	var v_in := Vector3(0, 0, -8)
	var camera := Vector3(1, 0, 0)  # olhando ao longo da parede
	var out := WallJumpMath.compute_exit_horizontal(v_in, n, camera, cfg)
	assert_gt(out.x, 0.5, "puxou para o lado da câmera")
	assert_gt(out.z, 0.0, "continua se afastando da parede")
	assert_almost_eq(out.length(), 8.0, 0.001, "ajuste muda direção, não velocidade")


func test_camera_pointing_into_wall_never_sends_player_into_it() -> void:
	var cfg := MovementConfig.new()
	cfg.wall_jump_camera_weight = 1.0
	var n := Vector3(0, 0, 1)
	var out := WallJumpMath.compute_exit_horizontal(Vector3(-2, 0, -8), n, Vector3(0, 0, -1), cfg)
	assert_gte(out.dot(n), cfg.wall_jump_min_away_speed - 0.001)


func test_min_speed_and_min_away_are_enforced() -> void:
	var cfg := _neutral_cfg()
	var n := Vector3(0, 0, 1)
	var parallel := WallJumpMath.compute_exit_horizontal(Vector3(1, 0, 0), n, Vector3.ZERO, cfg)
	assert_gte(parallel.dot(n), cfg.wall_jump_min_away_speed - 0.001)
	assert_almost_eq(parallel.length(), cfg.wall_jump_min_horizontal_speed, 0.001)
	var still := WallJumpMath.compute_exit_horizontal(Vector3.ZERO, n, Vector3.ZERO, cfg)
	assert_almost_eq(still.normalized().distance_to(n), 0.0, 0.001)


func test_max_speed_is_capped() -> void:
	var cfg := _neutral_cfg()
	var out := WallJumpMath.compute_exit_horizontal(Vector3(0, 0, -40), Vector3(0, 0, 1), Vector3.ZERO, cfg)
	assert_almost_eq(out.length(), cfg.wall_jump_max_horizontal_speed, 0.001)


func test_camera_adjust_keeps_most_of_the_bounce() -> void:
	var cfg := _neutral_cfg()
	cfg.wall_jump_camera_weight = 0.3
	var n := Vector3(1, 0, 0)
	var v_in := Vector3(-5, 0, -8.66)
	var out := WallJumpMath.compute_exit_horizontal(v_in, n, Vector3(0, 0, -1), cfg)
	assert_gte(out.dot(n), 0.7 * 5.0 - 0.001, "câmera para frente tira no máximo 30% do afastamento")
	assert_lt(out.dot(n), 5.0, "mas ainda puxa para a câmera")


func test_forward_boost_and_multiplier_launch_further_along_the_wall() -> void:
	var cfg := _neutral_cfg()
	var v_in := Vector3(-5, 0, -8.66)  # parede à esquerda (n = +X), correndo para -Z
	var n := Vector3(1, 0, 0)
	var base := WallJumpMath.compute_exit_horizontal(v_in, n, Vector3.ZERO, cfg)
	cfg.wall_jump_horizontal_multiplier = 1.25
	cfg.wall_jump_forward_boost = 2.5
	cfg.wall_jump_max_horizontal_speed = 20.0
	var boosted := WallJumpMath.compute_exit_horizontal(v_in, n, Vector3.ZERO, cfg)
	assert_lt(boosted.z, base.z - 3.0, "bem mais rápido para frente")
	assert_gt(boosted.x, base.x, "e ainda se afasta mais da parede")


func test_forward_boost_does_not_apply_head_on() -> void:
	var cfg := _neutral_cfg()
	cfg.wall_jump_forward_boost = 5.0
	var out := WallJumpMath.compute_exit_horizontal(Vector3(0, 0, -8), Vector3(0, 0, 1), Vector3.ZERO, cfg)
	assert_almost_eq(out.x, 0.0, 0.0001, "de frente: sem empurrão lateral")
