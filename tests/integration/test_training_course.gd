extends GutTest
## Percurso de treino: bots com input sintético provam que cada trecho é completável
## com a técnica pretendida (e, quando faz sentido, NÃO é completável sem ela).
## Também cobre cronômetro, melhor tempo, checkpoints, queda e reset.

const Driver = preload("res://tests/helpers/player_driver.gd")
const COURSE: PackedScene = preload("res://scenes/arenas/TrainingCourse.tscn")
const FWD := Vector2(0, 1)

var course: Node3D
var d: Driver


func before_each() -> void:
	course = COURSE.instantiate() as Node3D
	var player := course.get_node("Player") as Player
	player.external_control = true
	player.config = player.config.duplicate() as MovementConfig
	add_child_autofree(course)
	d = Driver.new()
	d.attach(player, course)
	await d.ready_physics(self)


func _teleport(pos: Vector3, yaw_deg: float = 0.0) -> void:
	d.player.respawn(Transform3D(Basis(), pos))
	d.look_yaw = deg_to_rad(yaw_deg)
	await wait_physics_frames(2)
	d.step(5)


func _block(node_name: String) -> GreyboxBlock:
	return course.get_node("Geometry/" + node_name) as GreyboxBlock


## Pula em toda parede tocada (sem input direcional) até aterrissar. Devolve nº de wall jumps.
## Se true, o bot vira a câmera para a direção de saída antes de cada wall jump.
var follow_camera := false


func _auto_wall_jump_until_landed(max_ticks: int, move: Vector2 = Vector2.ZERO) -> int:
	var count := 0
	for i in max_ticks:
		var reason := d.player.get_wall_jump_block_reason()
		if reason == "" and d.player.wall_sensor.last_contact_tick == d.player.tick:
			if follow_camera:
				# Como um jogador: câmera virada para onde o salto vai levar.
				var out := WallJumpMath.reflect_horizontal(d.player.wall_sensor.entry_velocity,
					d.player.wall_sensor.normal)
				if out.length_squared() > 0.01:
					d.look_yaw = atan2(-out.x, -out.z)
			d.press_jump()
			count += 1
		d.step(1, move)
		if d.player.is_on_floor() and d.state() != &"Jump":
			return count
		if d.player.global_position.y < -3.0:
			return -1
	return count


func test_corridor_is_crossed_with_zigzag_wall_jumps() -> void:
	await _teleport(Vector3(1.0, 0, 6))
	d.step_until(func() -> bool: return d.player.global_position.z < 1.0, 120, FWD, true)
	var diagonal := Vector2(-0.5, 0.866)  # entra em diagonal rumo à parede esquerda
	d.step_until(func() -> bool: return d.player.global_position.z < -0.6, 60, diagonal, true)
	d.press_jump()
	d.step(1, diagonal, true)
	follow_camera = true
	var jumps := _auto_wall_jump_until_landed(400)
	assert_gt(jumps, 2, "atravessou com vários wall jumps (%d)" % jumps)
	assert_lt(d.player.global_position.z, -17.0, "chegou na pista do vão")
	assert_gt(d.player.global_position.y, -0.1)


func test_corridor_pit_cannot_be_crossed_with_plain_jump() -> void:
	await _teleport(Vector3(0, 0, 6))
	d.step_until(func() -> bool: return d.player.global_position.z < -0.6, 120, FWD, true)
	d.press_jump()
	d.step(80, FWD)
	assert_lt(d.player.global_position.y, -1.0, "caiu no fosso")


func test_side_jump_crosses_wide_gap() -> void:
	await _teleport(Vector3(1.5, 0, -30))
	d.step_until(func() -> bool: return d.player.global_position.z < -35.0, 120, FWD, true)
	var diagonal := Vector2(-0.5, 0.866)  # 30° para a esquerda, rumo à parede lateral
	d.step_until(func() -> bool: return d.player.global_position.z < -38.7, 60, diagonal, true)
	d.press_jump()
	d.step(1, diagonal, true)
	var jumps := _auto_wall_jump_until_landed(200)
	assert_eq(jumps, 1)
	assert_has(d.techniques, MovementRules.TECH_SIDE_JUMP)
	assert_lt(d.player.global_position.z, -47.0, "aterrissou depois do vão")
	assert_almost_eq(d.player.global_position.y, 0.0, 0.05)


func test_wide_gap_cannot_be_crossed_with_sprint_jump() -> void:
	await _teleport(Vector3(3.0, 0, -30))
	d.step_until(func() -> bool: return d.player.global_position.z < -38.8, 120, FWD, true)
	d.press_jump()
	d.step(90, FWD)
	assert_lt(d.player.global_position.y, -1.0, "sprint + pulo não alcança o outro lado")


func test_reverse_wall_jump_climbs_the_ledge() -> void:
	await _teleport(Vector3(1.75, 0, -52))
	d.step_until(func() -> bool: return d.player.global_position.z < -57.4, 120, FWD)
	d.press_jump()
	d.step(1, FWD)
	assert_gt(d.step_until_wall(_block("ReverseLedge"), 60, FWD), 0)
	d.press_jump()
	d.step(1)
	assert_has(d.techniques, MovementRules.TECH_REVERSE)
	d.step(60)
	assert_almost_eq(d.player.global_position.y, 3.6, 0.05, "em cima da borda")


func test_back_coming_then_reverse_climbs_the_smooth_wall() -> void:
	await _teleport(Vector3(1.75, 3.6, -67))
	d.step_until(func() -> bool: return d.player.wall_sensor.has_contact, 120, FWD)
	d.step(5, FWD)
	d.press_jump()
	d.step(3, FWD)
	d.press_jump()
	d.step(1)
	assert_has(d.techniques, MovementRules.TECH_BACK_COMING)
	assert_gt(d.step_until(func() -> bool: return d.player.wall_sensor.is_near_top(), 40), 0)
	d.press_jump()
	d.step(1)
	assert_eq(d.techniques.count(MovementRules.TECH_REVERSE), 1)
	d.step(60)
	assert_almost_eq(d.player.global_position.y, 8.0, 0.05, "em cima da parede lisa")


func test_smooth_wall_cannot_be_climbed_with_single_jump_wall_jump() -> void:
	await _teleport(Vector3(1.75, 3.6, -66))
	d.step_until(func() -> bool: return d.player.global_position.z < -67.6, 120, FWD)
	d.press_jump()
	d.step(1, FWD)
	_auto_wall_jump_until_landed(200, FWD)
	assert_lt(d.player.global_position.y, 4.0, "voltou para a borda; não subiu")


func test_tower_is_climbed_with_chained_wall_jumps() -> void:
	await _teleport(Vector3(1.75, 8.0, -86))
	course.running = true
	d.step(3, Vector2(-1, 0), true)
	d.press_jump()
	d.step(1, Vector2(-1, 0), true)
	var jumps := _auto_wall_jump_until_landed(400)
	assert_gte(jumps, 3, "wall jumps encadeados: %d" % jumps)
	assert_almost_eq(d.player.global_position.y, 17.0, 0.05, "chegou no topo da torre")
	await wait_physics_frames(3)
	assert_true(course.finished, "zona de chegada alcançada")


func test_timer_runs_from_start_to_finish_and_keeps_best() -> void:
	assert_false(course.running)
	await _teleport(Vector3(1.75, 0, -32))  # sai da área de largada
	await wait_physics_frames(3)
	assert_true(course.running, "cronômetro começou ao sair da largada")
	d.step(10)
	await wait_physics_frames(30)
	var finish := course.get_node("FinishZone") as Area3D
	d.player.respawn(Transform3D(Basis(), finish.global_position + Vector3.DOWN))
	await wait_physics_frames(3)
	assert_true(course.finished)
	assert_false(course.running)
	assert_gt(course.best_ticks, 0)
	var first_best: int = course.best_ticks
	course.reset_run()
	assert_eq(course.run_ticks, 0)
	assert_eq(course.best_ticks, first_best, "melhor tempo da sessão sobrevive ao reset")


func test_falling_into_pit_respawns_at_checkpoint() -> void:
	await _teleport(Vector3(1.75, 0, -32))
	await wait_physics_frames(3)
	assert_eq(course.get_checkpoint_label(), "Vão de side jump")
	d.player.respawn(Transform3D(Basis(), Vector3(1.75, -7.0, -42)))
	await wait_physics_frames(2)
	assert_eq(course.falls, 1)
	assert_almost_eq(d.player.global_position.z, -19.0, 0.01, "voltou ao checkpoint do vão")


func test_reset_returns_to_start_and_clears_counters() -> void:
	await _teleport(Vector3(1.75, 0, -52))
	course.technique_counts[&"side_jump"] = 2
	course.reset_run()
	assert_eq(course.get_total_techniques(), 0)
	assert_almost_eq(d.player.global_position.z, 8.0, 0.01)


func test_course_counts_techniques_during_run() -> void:
	course.running = true
	GameEvents.technique_executed.emit(d.player, &"bunny_hop", {})
	GameEvents.technique_executed.emit(d.player, &"bunny_hop", {})
	GameEvents.technique_executed.emit(d.player, &"cancel", {})
	assert_eq(course.technique_counts[&"bunny_hop"], 2)
	assert_eq(course.get_total_techniques(), 3)
