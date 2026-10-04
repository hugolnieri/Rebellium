extends GutTest
## Arena de combate e troca de cenas: tudo carrega, golpe acerta poste e R reinicia.

const ARENA: PackedScene = preload("res://scenes/arenas/CombatArena.tscn")
const Driver = preload("res://tests/helpers/player_driver.gd")


func test_all_cycled_scenes_load() -> void:
	var cycler := get_tree().root.get_node_or_null("SceneCycler")
	assert_not_null(cycler)
	for path: String in cycler.SCENES:
		assert_not_null(load(path), path)


func test_arena_attack_hits_dummy_and_reset_clears() -> void:
	var arena := ARENA.instantiate() as Node3D
	var player := arena.get_node("Player") as Player
	player.external_control = true
	add_child_autofree(arena)
	var d := Driver.new()
	d.attach(player, arena)
	await d.ready_physics(self)
	var dummy := arena.get_node("Dummies/DummyCenter") as TrainingDummy
	player.respawn(Transform3D(Basis(), dummy.global_position + Vector3(0, 0, 1.8)))
	await wait_physics_frames(2)
	d.step(5)
	d.press_attack()
	d.step(30)
	assert_gt(dummy.total_damage, 0.0, "golpe acertou o poste da arena")
	arena.call(&"reset")
	assert_eq(dummy.total_damage, 0.0)
	assert_almost_eq(player.global_position.z, 8.0, 0.01, "voltou ao spawn")
