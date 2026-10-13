extends GutTest
## Fluxo real do modo na estação em oito: pisos, rotas, núcleo, entrega, queda e fim da partida.
## Coordenadas em Godot (o Blender usa (x, y, z) -> Godot (x, z, -y)).

const ARENA: PackedScene = preload("res://scenes/arenas/TouchdownArena.tscn")
const Driver = preload("res://tests/helpers/player_driver.gd")
const SPAWN := Vector3(40, 8.12, -3)
const CORE := Vector3(0, 8.12, 0)
const RED_GOAL := Vector3(-32.4, 8.12, -9.9)

var arena: TouchdownArena
var player: Player


func before_each() -> void:
	arena = ARENA.instantiate() as TouchdownArena
	player = arena.get_node("Player") as Player
	player.external_control = true
	arena.config = arena.config.duplicate() as TouchdownConfig
	add_child_autofree(arena)
	await wait_physics_frames(3)


func _floor_at(x: float, z: float, from_y: float) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -6, z))
	ray.exclude = [player.get_rid()]
	return arena.get_world_3d().direct_space_state.intersect_ray(ray)


## yaw da câmera que faz o "frente" do PlayerInput andar na direção `dir` do mundo.
func _yaw_towards(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _clear_guards() -> void:
	for child: Node in arena.dummies.get_children():
		child.queue_free()
	await wait_physics_frames(1)


func test_spawn_and_blender_collisions() -> void:
	assert_almost_eq(player.global_position.x, SPAWN.x, 0.2)
	var shapes := arena.get_node("Platform").find_children("*", "CollisionShape3D", true, false)
	assert_gt(shapes.size(), 10, "o modelo importa pisos e obstáculos como colisores")
	for shape: CollisionShape3D in shapes:
		assert_true(shape.shape is ConvexPolygonShape3D, "colisões da arena são convexas")
	for sample: Vector3 in [
			Vector3(40, 8, -3), Vector3(-40, 8, 3),      # blocos de spawn
			Vector3(15, 8, 0), Vector3(0, 8, 0),         # ponte e largo do núcleo
			Vector3(-26, 8, 8), Vector3(26, 8, -8),      # passarelas laterais
			Vector3(-3.5, 0, 8), Vector3(3.5, 0, -8),    # plataforma baixa ao lado do trem
			Vector3(0, 3.9, 8),                          # teto do trem
			Vector3(-13, 4, 25), Vector3(13, 4, -25),    # meio das voltas em U
			Vector3(-14, 4, -9), Vector3(14, 4, 9),      # meio das escadas rolantes
			Vector3(-32.1, 8, -10.2), Vector3(32.1, 8, 10.2)]:        # pátios dos gols
		var hit := _floor_at(sample.x, sample.z, sample.y + 1.5)
		assert_false(hit.is_empty(), "há piso em %s" % sample)
		if not hit.is_empty():
			assert_almost_eq((hit.position as Vector3).y, sample.y, 0.3, "altura do piso em %s" % sample)
	assert_true(_floor_at(-13, 14, 10).is_empty(), "o miolo das voltas é vazio")


func test_spawn_bridge_core_and_red_goal_route() -> void:
	await _clear_guards()
	var d: Driver = Driver.new()
	d.attach(player, arena)
	player.respawn(Transform3D(Basis(), Vector3(40, 8.12, -1)))
	await wait_physics_frames(2)
	d.look_yaw = _yaw_towards(Vector3(-1, 0, 0))
	var at_core: int = d.step_until(
		func() -> bool: return player.global_position.x < 0.5, 700, Vector2(0, 1))
	assert_gt(at_core, 0, "do spawn azul pela ponte até o núcleo; posição %s" % player.global_position)
	await wait_physics_frames(3)  # as Area3D só notam o corpo no passo da física
	assert_true(arena.carrying, "pegou o núcleo no largo da ponte")
	var reached_court: int = d.step_until(
		func() -> bool: return player.global_position.x < -24.0, 500, Vector2(0, 1))
	assert_gt(reached_court, 0, "a ponte chega ao pátio vermelho")
	d.look_yaw = _yaw_towards(Vector3(0, 0, -1))
	var north: int = d.step_until(
		func() -> bool: return player.global_position.z < -12.0, 300, Vector2(0, 1))
	assert_gt(north, 0, "contorna o balcão pelo lado da ponte")
	d.look_yaw = _yaw_towards(RED_GOAL - player.global_position)
	var in_goal: int = d.step_until(
		func() -> bool: return Vector2(player.global_position.x - RED_GOAL.x,
			player.global_position.z - RED_GOAL.z).length() < 1.5, 300, Vector2(0, 1))
	assert_gt(in_goal, 0, "chega ao gol vermelho; posição %s" % player.global_position)
	await wait_physics_frames(3)
	assert_eq(arena.score, 1, "entrega no gol vermelho")


func test_outer_loop_descends_to_train_platform() -> void:
	var d: Driver = Driver.new()
	d.attach(player, arena)
	player.respawn(Transform3D(Basis(), Vector3(-26, 8.12, 6)))
	await wait_physics_frames(2)
	var center := Vector2(-13, -14)  # centro da volta vermelha no plano do Blender
	var arrived := false
	for i: int in 900:
		var b := Vector2(player.global_position.x, -player.global_position.z)
		if b.x > -2.0 and b.y > -13.0:
			arrived = true
			break
		var rel := b - center
		var angle := atan2(rel.y, rel.x)
		var radial := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-sin(angle), cos(angle))
		var dir := tangent - radial * (rel.length() - 13.0) * 0.3
		if b.y > -14.0 and b.x < -20.0:
			dir = Vector2(0, -1)  # ainda na passarela: desce reto até a curva
		d.look_yaw = _yaw_towards(Vector3(dir.x, 0, -dir.y))
		d.step(1, Vector2(0, 1))
	assert_true(arrived, "a volta em U leva da passarela à plataforma; posição %s" % player.global_position)
	assert_lt(player.global_position.y, 0.6, "chega ao nível baixo")


func test_escalator_climbs_from_platform_to_red_court() -> void:
	var d: Driver = Driver.new()
	d.attach(player, arena)
	player.respawn(Transform3D(Basis(), Vector3(-3.5, 0.12, -9)))
	await wait_physics_frames(2)
	d.look_yaw = _yaw_towards(Vector3(-1, 0, 0))
	var climbed: int = d.step_until(
		func() -> bool: return player.global_position.x < -23.5, 500, Vector2(0, 1))
	assert_gt(climbed, 0, "sobe a escada rolante; posição %s" % player.global_position)
	assert_gt(player.global_position.y, 7.5)


func test_drop_from_core_plaza_lands_on_train_roof() -> void:
	var d: Driver = Driver.new()
	d.attach(player, arena)
	player.respawn(Transform3D(Basis(), Vector3(0, 8.12, -3.6)))
	await wait_physics_frames(2)
	d.look_yaw = _yaw_towards(Vector3(0, 0, -1))
	d.step(30, Vector2(0, 1))
	var landed: int = d.step_until(
		func() -> bool: return player.is_on_floor() and player.global_position.y < 6.0, 200)
	assert_gt(landed, 0, "cai pela abertura do largo")
	assert_almost_eq(player.global_position.y, 3.9, 0.3, "pousa no teto do trem")


func test_goal_requires_ball_from_center() -> void:
	player.respawn(Transform3D(Basis(), RED_GOAL))
	await wait_physics_frames(3)
	assert_eq(arena.score, 0, "a base sozinha não pontua")
	player.respawn(Transform3D(Basis(), CORE))
	await wait_physics_frames(3)
	assert_true(arena.carrying, "pegou o núcleo no meio da ponte")
	assert_false(arena.ball.visible)
	player.respawn(Transform3D(Basis(), RED_GOAL))
	await wait_physics_frames(3)
	assert_eq(arena.score, 1, "entregou na base vermelha")
	assert_false(arena.carrying)
	assert_almost_eq(player.global_position.x, SPAWN.x, 0.2, "nova rodada começa no spawn azul")


func test_fall_drops_ball_and_returns_player() -> void:
	arena.config.ball_reset_delay = 0.05
	player.respawn(Transform3D(Basis(), CORE))
	await wait_physics_frames(3)
	assert_true(arena.carrying)
	player.global_position = Vector3(0, -20, 0)
	await wait_physics_frames(3)
	assert_false(arena.carrying)
	assert_almost_eq(player.global_position.x, SPAWN.x, 0.2)
	await wait_physics_frames(6)
	assert_true(arena.ball_available, "núcleo reaparece no meio após a queda")


func test_score_limit_ends_and_reset_starts_new_match() -> void:
	arena.config.score_limit = 1
	player.respawn(Transform3D(Basis(), CORE))
	await wait_physics_frames(3)
	player.respawn(Transform3D(Basis(), RED_GOAL))
	await wait_physics_frames(3)
	assert_eq(arena.score, 1)
	assert_true(arena.finished)
	arena.reset_match()
	assert_eq(arena.score, 0)
	assert_false(arena.finished)
	assert_true(arena.ball_available)
