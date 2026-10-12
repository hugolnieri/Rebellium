extends GutTest
## Arena flutuante (modelo do Blender): chão em degradê (centro preto = ponto mais baixo), muro roxo serve
## para wall jump e tem passagens verdes, o caçador vermelho é o único bot e a queda volta ao spawn.

const ARENA: PackedScene = preload("res://scenes/arenas/SkyArena.tscn")
const Driver = preload("res://tests/helpers/player_driver.gd")

var arena: Node3D
var player: Player
var d: Driver


func before_each() -> void:
	arena = ARENA.instantiate() as Node3D
	player = arena.get_node("Player") as Player
	player.external_control = true
	add_child_autofree(arena)
	d = Driver.new()
	d.attach(player, arena)
	await d.ready_physics(self)
	await wait_physics_frames(2)
	d.step(20)


func test_player_stands_on_the_spawn() -> void:
	var spawn := arena.get_node("Spawn") as Marker3D
	assert_true(player.is_on_floor(), "pisa no chão gerado pelo Blender")
	assert_almost_eq(player.global_position.y, spawn.global_position.y, 0.1)


func test_spawn_faces_the_center() -> void:
	var spawn := arena.get_node("Spawn") as Marker3D
	var forward := -spawn.global_basis.z
	var to_center := -spawn.global_position
	to_center.y = 0.0
	assert_gt(forward.dot(to_center.normalized()), 0.99, "começa virado para o centro")


func test_character_faces_the_direction_it_walks() -> void:
	# O yaw do spawn não pode ficar no corpo: o visual recebe um yaw do mundo e encararia 22,5° fora do caminho.
	d.look_yaw = 1.0
	d.step(30, Vector2(0, 1))
	var velocity := player.get_horizontal_velocity()
	assert_gt(velocity.length(), 3.0, "está andando")
	var heading := atan2(-velocity.x, -velocity.z)
	var facing := player.visual.global_rotation.y
	assert_almost_eq(wrapf(facing - heading, -PI, PI), 0.0, 0.05, "o personagem encara para onde anda")
	assert_almost_eq(player.global_rotation.y, 0.0, 0.001, "o corpo do jogador fica sem rotação")


func test_black_base_is_the_lowest_point_and_the_floor_rises_outward() -> void:
	var spawn := arena.get_node("Spawn") as Marker3D
	player.respawn(Transform3D(Basis(), Vector3(1.5, 2.0, 1.5)))
	d.step(60)
	assert_true(player.is_on_floor(), "centro preto tem chão")
	assert_almost_eq(player.global_position.y, 0.0, 0.1, "centro preto é o ponto mais baixo")
	assert_gt(spawn.global_position.y, player.global_position.y + 0.8, "o chão sobe em degradê até a borda")


func test_inner_wall_allows_wall_jump() -> void:
	# De fora do muro roxo (r = 14,6), andando para o centro a partir de z = -17.
	player.respawn(Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.0, -17.0)))
	d.look_yaw = PI
	d.step_until(func() -> bool: return player.global_position.z > -16.0, 60, Vector2(0, 1))
	d.press_jump()
	d.step(1, Vector2(0, 1))
	assert_gt(d.step_until(func() -> bool: return player.wall_sensor.has_contact, 90, Vector2(0, 1)), 0,
		"encostou no muro roxo")
	d.press_jump()
	d.step(1)
	assert_eq(player.get_state_name(), &"WallJump")


func test_falling_off_the_platform_respawns() -> void:
	var spawn := arena.get_node("Spawn") as Marker3D
	player.respawn(Transform3D(Basis(), Vector3(40, -25, 0)))
	await wait_physics_frames(3)
	assert_lt(player.global_position.distance_to(spawn.global_position), 0.3, "voltou ao spawn depois de cair")


func test_purple_wall_blocks_walking_but_green_doors_let_through() -> void:
	# O muro roxo fecha o caminho (de -z para o centro)...
	player.respawn(Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.0, -17.0)))
	d.look_yaw = PI
	d.step(120, Vector2(0, 1))
	var r := Vector2(player.global_position.x, player.global_position.z).length()
	assert_gt(r, 14.4, "parou no muro roxo (r = %.2f)" % r)
	assert_true(player.is_on_floor())
	# ...mas a passagem verde na diagonal (-X, -Z) deixa entrar andando.
	var dir := Vector3(-1, 0, -1).normalized()
	player.respawn(Transform3D(Basis(), dir * 17.5 + Vector3.UP))
	d.look_yaw = -0.75 * PI  # olhando para o centro
	d.step(120, Vector2(0, 1))
	r = Vector2(player.global_position.x, player.global_position.z).length()
	assert_lt(r, 10.0, "passou pela passagem verde (r = %.2f)" % r)


func test_wall_collision_is_smooth_convex_blocks() -> void:
	var shapes := arena.get_node("Platform").find_children("*", "CollisionShape3D", true, false)
	assert_gt(shapes.size(), 100)
	for shape: CollisionShape3D in shapes:
		assert_true(shape.shape is ConvexPolygonShape3D, "colisão convexa (sem emendas de triângulos)")


func test_sliding_along_the_curved_wall_does_not_snag() -> void:
	# Passarela colada no muro roxo por fora (r = 15,3), andando na tangente e empurrando para dentro.
	player.respawn(Transform3D(Basis(), Vector3(0.0, 1.0, -15.3)))
	d.look_yaw = PI * 0.5 + 0.35
	d.step(20, Vector2(0, 1))
	var slowest := INF
	for i in 60:
		d.step(1, Vector2(0, 1))
		slowest = minf(slowest, player.get_horizontal_speed())
	assert_gt(slowest, 3.0, "não engancha nas emendas do muro (mínimo %.2f m/s)" % slowest)


func test_hunter_bot_is_the_only_bot_on_the_map() -> void:
	var bots: Array = arena.get_node("Dummies").get_children().filter(
		func(n: Node) -> bool: return n is TrainingDummy)
	assert_eq(bots.size(), 1, "só o caçador é bot na arena")
	assert_eq(String(bots[0].name), "HunterBot")


func test_hunter_bot_stands_on_the_black_base_and_only_takes_damage() -> void:
	var bot := arena.get_node("Dummies/HunterBot") as TrainingDummy
	var hunter_spawn := arena.get_node("HunterSpawn") as Marker3D
	assert_true(bot.is_in_group(&"hittable"), "é alvo dos golpes")
	assert_eq(bot.mode, TrainingDummy.Mode.STATIC, "parado: não faz nada, só recebe dano")
	assert_lt(bot.global_position.distance_to(hunter_spawn.global_position), 0.05, "nasce no spawn do caçador")
	assert_gt(bot.find_children("*", "MeshInstance3D", true, false).size(), 0, "corpo é o modelo do personagem")
	var max_hp: float = bot.config.max_hp
	assert_true(bot.take_hit({"damage": 10.0, "kind": &"light", "knockback": Vector3.ZERO}), "aceita dano")
	assert_almost_eq(bot.hp, max_hp - 10.0, 0.01)
