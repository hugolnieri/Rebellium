extends GutTest
## Caçador (bot vermelho): reage com os clipes do personagem; só o golpe pesado o arremessa; bate em paredes, cai,
## levanta e volta ao spawn. O bot é avançado tick a tick (`step`) sobre um chão plano, ao lado de um Player real.

const Driver = preload("res://tests/helpers/player_driver.gd")
const BOT_SCENE: PackedScene = preload("res://scenes/arenas/HunterBot.tscn")
const DT: float = 1.0 / 60.0
const HOME := Vector3(0.0, 0.0, -1.8)

var d: Driver
var bot: HunterBot


func before_each() -> void:
	d = Driver.new()
	d.setup(self, Vector3(0, 0, 0))
	d.add_block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	bot = BOT_SCENE.instantiate() as HunterBot
	bot.position = HOME
	d.world.add_child(bot)
	await d.ready_physics(self)
	d.step(10)


func _hit(kind: StringName, knockback: Vector3, damage: float = 10.0) -> void:
	assert_true(bot.take_hit({"attacker": d.player, "damage": damage, "kind": kind, "knockback": knockback}))


func _run(ticks: int) -> void:
	for i in ticks:
		bot.step(DT)


func _run_until(predicate: Callable, max_ticks: int) -> int:
	for i in max_ticks:
		bot.step(DT)
		if predicate.call():
			return i + 1
	return -1


func _phase_is(phase: HunterBot.Phase) -> Callable:
	return func() -> bool: return bot.phase == phase


func test_heavy_hit_launches_the_bot_away_from_the_attacker() -> void:
	_hit(CombatRules.KIND_HEAVY, Vector3(0, 4, -10))
	assert_eq(bot.phase, HunterBot.Phase.LAUNCHED)
	_run(20)
	assert_gt(bot.global_position.y, 0.5, "está no ar")
	assert_lt(bot.global_position.z, HOME.z - 3.0, "voa para longe de quem bateu")
	assert_gt(_run_until(_phase_is(HunterBot.Phase.DOWN), 120), 0, "cai no chão")
	assert_almost_eq(bot.global_position.y, 0.0, 0.05, "pousa no chão")


func test_heavy_hit_cycle_ends_back_at_the_spawn() -> void:
	_hit(CombatRules.KIND_HEAVY, Vector3(0, 4, -10))
	var seen := {}
	for i in 900:
		bot.step(DT)
		seen[bot.phase] = true
		if bot.phase == HunterBot.Phase.IDLE:
			break
	for phase in [HunterBot.Phase.LAUNCHED, HunterBot.Phase.DOWN, HunterBot.Phase.GETUP]:
		assert_true(seen.has(phase), "passou pela fase %d" % phase)
	assert_eq(bot.phase, HunterBot.Phase.IDLE)
	assert_lt(bot.global_position.distance_to(HOME), 0.05, "voltou ao spawn do caçador")


func test_light_hit_only_staggers_and_slides_a_little() -> void:
	_hit(CombatRules.KIND_LIGHT, Vector3(0, 0, -7))
	assert_eq(bot.phase, HunterBot.Phase.STAGGER)
	var launched := false
	for i in 90:
		bot.step(DT)
		launched = launched or bot.phase == HunterBot.Phase.LAUNCHED
		if bot.phase == HunterBot.Phase.IDLE:
			break
	assert_false(launched, "golpe leve não arremessa")
	assert_eq(bot.phase, HunterBot.Phase.IDLE, "recupera")
	var slid := HOME.z - bot.global_position.z
	assert_gt(slid, 0.3, "o empurrão se vê")
	assert_lt(slid, 4.0, "mas é bem menor que o arremesso")
	assert_almost_eq(bot.global_position.y, 0.0, 0.05)


func test_launch_distance_grows_with_the_recoil() -> void:
	_hit(CombatRules.KIND_HEAVY, Vector3(0, 4, -6))
	_run_until(_phase_is(HunterBot.Phase.DOWN), 200)
	var near := HOME.z - bot.global_position.z
	bot.reset_target()
	_hit(CombatRules.KIND_HEAVY, Vector3(0, 4, -12))
	_run_until(_phase_is(HunterBot.Phase.DOWN), 200)
	var far := HOME.z - bot.global_position.z
	assert_gt(far, near + 3.0, "recuo maior, arremesso mais longe (%.1f m contra %.1f m)" % [far, near])


func test_launched_bot_bounces_off_a_wall() -> void:
	d.add_block(Vector3(0, 2, -12), Vector3(20, 4, 1))  # face em z = -11,5
	var wall_distance := absf(-11.5 - HOME.z)
	_hit(CombatRules.KIND_HEAVY, Vector3(0, 4, -14))
	var farthest := 0.0
	for i in 200:
		bot.step(DT)
		farthest = maxf(farthest, HOME.z - bot.global_position.z)
		if bot.phase == HunterBot.Phase.DOWN and i > 30:
			break
	assert_lt(farthest, wall_distance + 0.2, "não atravessa a parede (foi até %.2f m)" % farthest)
	assert_gt(farthest, 6.0, "mas chega nela")


func test_player_heavy_attack_launches_the_hunter() -> void:
	d.press_attack(true)
	var launched_at := -1
	for i in 120:
		d.step(1)
		bot.step(DT)
		if bot.phase == HunterBot.Phase.LAUNCHED:
			launched_at = i
			break
	assert_gt(launched_at, 0, "o golpe pesado do jogador arremessa o caçador")
	assert_almost_eq(bot.total_damage, d.player.weapons[0].heavy.damage, 0.01, "e o dano também conta")
	_run(15)
	assert_lt(bot.global_position.z, HOME.z - 1.0, "para longe do jogador")


func test_reset_target_brings_the_hunter_home_with_full_hp() -> void:
	_hit(CombatRules.KIND_HEAVY, Vector3(0, 4, -10), 50.0)
	_run(15)
	bot.reset_target()
	assert_eq(bot.phase, HunterBot.Phase.IDLE)
	assert_lt(bot.global_position.distance_to(HOME), 0.05)
	assert_almost_eq(bot.hp, bot.config.max_hp, 0.01)
	assert_almost_eq(bot.total_damage, 0.0, 0.01)


func test_fallen_bot_returns_to_the_spawn() -> void:
	bot.global_position = Vector3(0, bot.config.fall_respawn_height - 5.0, -4)
	bot.step(DT)
	assert_eq(bot.phase, HunterBot.Phase.IDLE)
	assert_lt(bot.global_position.distance_to(HOME), 0.05)


func test_label_shows_the_launch_distance() -> void:
	assert_false(bot._label_text().contains("ARREMESSO"), "sem arremesso ainda")
	_hit(CombatRules.KIND_HEAVY, Vector3(0, 4, -10))
	_run_until(_phase_is(HunterBot.Phase.DOWN), 200)
	assert_true(bot._label_text().contains("ARREMESSO"), "a etiqueta mostra a distância")


func test_hunter_only_blocks_the_player_while_standing() -> void:
	assert_false(bot._collision.disabled, "de pé ele bloqueia")
	_hit(CombatRules.KIND_HEAVY, Vector3(0, 4, -10))
	await wait_physics_frames(2)
	assert_true(bot._collision.disabled, "voando ou deitado não bloqueia")


func test_the_bot_plays_the_blender_clips() -> void:
	var hips := bot._puppet._hips_bone as int
	var skeleton := bot._puppet._skeleton as Skeleton3D
	_run(30)
	var standing := skeleton.get_bone_pose_position(hips).y
	_hit(CombatRules.KIND_HEAVY, Vector3(0, 4, -10))
	_run_until(_phase_is(HunterBot.Phase.DOWN), 200)
	_run(int(HeroClips.length_of(&"knockdown") / DT) + 6)
	var lying := skeleton.get_bone_pose_position(hips).y
	assert_lt(lying, standing - 0.4, "deitado, o quadril desce (de pé %.2f, deitado %.2f)" % [standing, lying])
