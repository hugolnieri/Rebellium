extends GutTest
## Regras puras do combate: área do golpe, mira assistida, combo, recuo e vida.

const ORIGIN := Vector3(0, 1, 0)
const FORWARD := Vector3(0, 0, -1)


func _in(target: Vector3, radius: float = 0.4, reach: float = 2.0, arc: float = 120.0,
		vertical: float = 1.4) -> bool:
	return CombatRules.is_in_attack_area(ORIGIN, FORWARD, target, radius, reach, arc, vertical)


func test_target_in_front_within_reach_is_hit() -> void:
	assert_true(_in(Vector3(0, 1, -2.0)))


func test_target_beyond_reach_is_missed() -> void:
	assert_false(_in(Vector3(0, 1, -2.5)))
	assert_true(_in(Vector3(0, 1, -2.35)), "a borda do alvo conta")


func test_target_behind_is_missed_unless_360() -> void:
	assert_false(_in(Vector3(0, 1, 1.5)))
	assert_true(_in(Vector3(0, 1, 1.5), 0.4, 2.0, 360.0))


func test_arc_edges() -> void:
	var at_50 := Vector3(sin(deg_to_rad(50.0)), 0.0, -cos(deg_to_rad(50.0))) * 1.8 + ORIGIN
	var at_80 := Vector3(sin(deg_to_rad(80.0)), 0.0, -cos(deg_to_rad(80.0))) * 1.8 + ORIGIN
	assert_true(_in(at_50, 0.05), "dentro de 60° (arco de 120)")
	assert_false(_in(at_80, 0.05), "fora do arco")


func test_vertical_reach() -> void:
	assert_true(_in(Vector3(0, 2.5, -1.5)))
	assert_false(_in(Vector3(0, 3.5, -1.5)))


func test_overlapping_target_is_always_hit() -> void:
	assert_true(_in(Vector3(0.1, 1, 0.1), 0.4))


func test_aim_assist_prefers_most_aligned_target() -> void:
	var centers: Array[Vector3] = [Vector3(3, 1, -3), Vector3(0.4, 1, -4), Vector3(0, 1, 5)]
	assert_eq(CombatRules.pick_aim_target(ORIGIN, FORWARD, centers, 6.0, 55.0), 1)


func test_aim_assist_ignores_far_or_wide_targets() -> void:
	var centers: Array[Vector3] = [Vector3(0, 1, -9), Vector3(5, 1, -1)]
	assert_eq(CombatRules.pick_aim_target(ORIGIN, FORWARD, centers, 6.0, 55.0), -1)


func test_combo_index_advances_and_ends() -> void:
	assert_eq(CombatRules.next_combo_index(0, 3), 1)
	assert_eq(CombatRules.next_combo_index(1, 3), 2)
	assert_eq(CombatRules.next_combo_index(2, 3), -1)


func test_knockback_points_away_from_attacker() -> void:
	var kb := CombatRules.knockback_vector(Vector3.ZERO, Vector3(0, 0, -2), 5.0, 2.0, FORWARD)
	assert_almost_eq(kb.distance_to(Vector3(0, 2, -5)), 0.0, 0.001)
	var overlap := CombatRules.knockback_vector(Vector3.ZERO, Vector3.ZERO, 5.0, 0.0, Vector3(1, 0, 0))
	assert_almost_eq(overlap.x, 5.0, 0.001, "alvo em cima do atacante usa a direção do golpe")


func test_health_pool() -> void:
	var health := HealthPool.new(100.0)
	watch_signals(health)
	assert_eq(health.damage(30.0), 30.0)
	assert_eq(health.current, 70.0)
	assert_eq(health.damage(100.0), 70.0, "não passa de zero")
	assert_true(health.is_dead())
	assert_signal_emitted(health, "died")
	assert_eq(health.damage(10.0), 0.0, "morto não leva mais dano")
	health.refill()
	assert_eq(health.current, 100.0)


func test_weapon_files_load_with_all_attacks() -> void:
	for path: String in ["res://config/weapons/arc_blade/weapon.tres", "res://config/weapons/phase_fang/weapon.tres"]:
		var weapon := load(path) as WeaponConfig
		assert_not_null(weapon, path)
		assert_gte(weapon.light_combo.size(), 3)
		assert_not_null(weapon.heavy)
		assert_not_null(weapon.air)
		assert_not_null(weapon.dash)
		for attack in weapon.light_combo:
			assert_lte(attack.chain_after, attack.total_time(), "%s pode encadear" % attack.display_name)
