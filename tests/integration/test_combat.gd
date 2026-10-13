extends GutTest
## Combate com física real: golpes no poste, combo, pesado, aéreo, dash, cancels,
## troca de arma, mira assistida, dano recebido e esquiva perfeita.

const Driver = preload("res://tests/helpers/player_driver.gd")

var d: Driver


func before_each() -> void:
	d = Driver.new()
	d.setup(self, Vector3(0, 0, 0))
	d.add_block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))


func _ready_world() -> void:
	await d.ready_physics(self)
	d.step(10)


func _blade() -> WeaponConfig:
	return d.player.weapons[0]


func _attack_ticks(attack: AttackData) -> int:
	# O hitstop pausa o golpe: soma a pausa do impacto.
	return d.player.secs_to_ticks(attack.total_time() + attack.hitstop) + 2


func test_light_attack_hits_dummy_in_front() -> void:
	var dummy := d.add_dummy(Vector3(0, 0, -1.8))
	await _ready_world()
	d.press_attack()
	d.step(1)
	assert_eq(d.state(), &"Attack")
	d.step(_attack_ticks(_blade().light_combo[0]))
	assert_almost_eq(dummy.total_damage, _blade().light_combo[0].damage, 0.01)
	assert_ne(d.state(), &"Attack", "golpe terminou")


func test_hitstop_freezes_player_on_hit() -> void:
	d.add_dummy(Vector3(0, 0, -1.8))
	await _ready_world()
	d.press_attack()
	var froze := false
	for i in 30:
		d.step(1)
		froze = froze or d.player.hitstop_ticks > 0
	assert_true(froze, "acerto congela o atacante por alguns ticks")


func test_miss_out_of_reach() -> void:
	var dummy := d.add_dummy(Vector3(0, 0, -8.0))
	await _ready_world()
	d.press_attack()
	d.step(40)
	assert_eq(dummy.total_damage, 0.0)


func test_three_hit_combo_then_restarts() -> void:
	var dummy := d.add_dummy(Vector3(0, 0, -1.6))
	await _ready_world()
	var hits: Array[String] = []
	GameEvents.attack_started.connect(func(_p: Node, a: Resource, _w: Resource, _k: StringName) -> void:
		hits.append((a as AttackData).display_name))
	for i in 3:
		d.press_attack()
		d.step(d.player.secs_to_ticks(_blade().light_combo[i].chain_after) + 1)
	d.step(60)
	assert_eq(hits.size(), 3, "três golpes: %s" % [hits])
	assert_eq(hits[2], _blade().light_combo[2].display_name)
	var expected := 0.0
	for attack in _blade().light_combo:
		expected += attack.damage
	assert_almost_eq(dummy.total_damage, expected, 0.01)
	d.press_attack()
	d.step(1)
	assert_eq(d.state(), &"Attack")
	assert_eq(d.player.state_machine.current.combo_index, 0, "depois do fim, o combo recomeça")


func test_heavy_hits_all_around_and_costs_sp() -> void:
	var behind := d.add_dummy(Vector3(0, 0, 1.8))
	await _ready_world()
	d.press_attack(true)
	d.step(1)
	assert_almost_eq(d.player.sp.current, 100.0 - _blade().heavy.sp_cost, 0.01)
	d.step(_attack_ticks(_blade().heavy))
	assert_almost_eq(behind.total_damage, _blade().heavy.damage, 0.01, "giro acerta atrás")


func _jump_and_click(heavy: bool = false, hold: bool = false) -> void:
	await _ready_world()
	d.press_jump()
	d.step(12)
	d.press_attack(heavy)
	d.attack_light_held = hold
	d.step(d.player.combat_config.heavy_hold_ticks + 1 if hold else 1)
	d.attack_light_held = false


func test_air_click_freezes_then_plunges_and_stays_down() -> void:
	await _jump_and_click()
	var attack: Node = d.player.state_machine.current
	assert_eq(d.state(), &"Attack")
	assert_eq(attack.kind, CombatRules.KIND_AIR)
	assert_eq(attack.plunge, attack.Plunge.HOVER, "começa congelado no ar")
	var frozen_at := d.player.global_position
	d.step(d.player.secs_to_ticks(_blade().air.plunge_hover_time) - 2, Vector2(1, 0))
	assert_almost_eq(d.player.global_position.distance_to(frozen_at), 0.0, 0.01, "parado no ar, mesmo com direcional")
	d.step(4)
	assert_eq(attack.plunge, attack.Plunge.DIVE, "desce")
	assert_almost_eq(d.player.velocity.y, -_blade().air.plunge_speed, 0.01, "com tudo")
	assert_almost_eq(d.player.get_horizontal_speed(), 0.0, 0.001, "reto para baixo, no ponto onde clicou")
	var landed := d.step_until(func() -> bool: return d.player.is_on_floor(), 60)
	assert_gt(landed, 0)
	assert_lt(Vector2(d.player.global_position.x - frozen_at.x, d.player.global_position.z - frozen_at.z).length(),
		0.05, "caiu embaixo de onde clicou")
	d.step(1)
	assert_eq(d.state(), &"Attack", "preso no chão levantando")
	assert_true(attack.is_plunge_landing())
	var x0 := d.player.global_position
	d.press_dodge()
	d.press_jump()
	d.step(5, Vector2(1, 0))
	assert_eq(d.state(), &"Attack", "não cancela com dash nem pulo")
	assert_almost_eq(d.player.global_position.distance_to(x0), 0.0, 0.02, "não anda enquanto levanta")
	var ended := d.step_until(func() -> bool: return d.state() != &"Attack",
		d.player.secs_to_ticks(_blade().air.plunge_landing_time) + 5)
	assert_gt(ended, 0, "levanta depois de plunge_landing_time")
	assert_ne(d.state(), &"Land", "não passa pela aterrissagem")


func test_plunge_hits_the_target_below_on_impact() -> void:
	var dummy := d.add_dummy(Vector3(1.2, 0, 0))
	await _jump_and_click()
	var hit := d.step_until(func() -> bool: return dummy.total_damage > 0.0, 120)
	assert_gt(hit, 0, "o impacto acerta quem está em volta")
	assert_almost_eq(dummy.total_damage, _blade().air.damage, 0.01)


func test_heavy_in_air_by_holding_left_click_is_the_plunge() -> void:
	await _jump_and_click(false, true)
	assert_eq(d.state(), &"Attack")
	assert_eq(d.player.state_machine.current.kind, CombatRules.KIND_AIR, "no ar o pesado é o mergulho")


func test_heavy_in_air_with_right_click_is_the_plunge() -> void:
	await _jump_and_click(true)
	assert_eq(d.state(), &"Attack")
	assert_eq(d.player.state_machine.current.kind, CombatRules.KIND_AIR)


func test_attack_during_air_dash_is_a_normal_light_attack() -> void:
	# No meio do dash no ar o golpe conta como de chão: leve normal, velocidade de pulo e para sem direcional.
	await _ready_world()
	d.player.respawn(Transform3D(Basis(), Vector3(0, 8, 0)))
	d.step(2)
	d.press_dodge()
	d.step(3, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_false(d.player.is_on_floor(), "dash no ar")
	d.press_attack()
	d.step(1)
	var attack: Node = d.player.state_machine.current
	assert_eq(d.state(), &"Attack")
	assert_eq(attack.kind, CombatRules.KIND_LIGHT, "golpe leve normal")
	assert_eq(attack.combo_index, 0)
	assert_true(attack.from_air_dash)
	assert_eq(attack.plunge, attack.Plunge.NONE, "não é o mergulho")
	assert_lte(d.player.get_horizontal_speed(), d.player.get_walk_speed() + 0.01, "velocidade de um pulo normal")
	d.step(20)
	assert_lt(d.player.get_horizontal_speed(), 0.1, "sem direcional, para no lugar do golpe")
	assert_lt(d.player.velocity.y, 0.0, "cai com a gravidade normal")


func test_air_dash_attack_chains_the_light_combo() -> void:
	await _ready_world()
	d.player.respawn(Transform3D(Basis(), Vector3(0, 40, 0)))
	d.step(2)
	d.press_dodge()
	d.step(3, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge")
	d.press_attack()
	d.step(1)
	assert_eq(d.state(), &"Attack")
	assert_eq(d.player.state_machine.current.combo_index, 0)
	d.step(d.player.secs_to_ticks(_blade().light_combo[0].chain_after))
	d.press_attack()
	d.step(1)
	assert_false(d.player.is_on_floor())
	assert_eq(d.player.state_machine.current.kind, CombatRules.KIND_LIGHT, "segue o combo leve, não mergulha")
	assert_eq(d.player.state_machine.current.combo_index, 1)


func test_jump_during_ground_attack_keeps_attacking_in_the_air() -> void:
	await _ready_world()
	d.press_attack()
	d.step(3)
	assert_eq(d.state(), &"Attack")
	d.press_jump()
	d.step(1)
	assert_eq(d.state(), &"Attack", "o golpe continua")
	assert_true(d.player.state_machine.current.airborne)
	assert_gt(d.player.velocity.y, 0.0, "saiu pulando")


func test_jump_during_attack_has_normal_height() -> void:
	await _ready_world()
	var start_y := d.player.global_position.y
	d.press_attack()
	d.step(2)
	d.press_jump()
	var top := start_y
	for i in 90:
		d.step(1)
		top = maxf(top, d.player.global_position.y)
	assert_almost_eq(top - start_y, d.player.config.jump_height, 0.1, "pulo no golpe tem a altura normal")


func test_heavy_hold_during_dash_cancels_dash() -> void:
	await _ready_world()
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	d.press_attack()
	d.attack_light_held = true
	d.step(d.player.combat_config.heavy_hold_ticks + 1, Vector2(1, 0))
	assert_eq(d.state(), &"Attack")
	assert_eq(d.player.state_machine.current.kind, CombatRules.KIND_HEAVY)
	d.attack_light_held = false


func test_attack_cuts_dash_momentum() -> void:
	await _ready_world()
	d.press_dodge()
	d.step(2, Vector2(1, 0))
	assert_gt(d.player.get_horizontal_speed(), 15.0)
	d.press_attack()
	d.step(1)
	assert_eq(d.state(), &"Attack")
	assert_lte(d.player.get_horizontal_speed(), d.player.get_walk_speed() + 0.01, "golpe corta o dash")


func test_attack_during_dash_is_dash_attack() -> void:
	await _ready_world()
	d.press_dodge()
	d.step(2, Vector2(1, 0))
	d.press_attack()
	d.step(2, Vector2(1, 0))
	assert_eq(d.state(), &"Attack")
	assert_eq(d.player.state_machine.current.kind, CombatRules.KIND_DASH)


func test_attack_without_input_stays_in_place() -> void:
	await _ready_world()
	d.press_attack()
	d.step(10)
	assert_eq(d.state(), &"Attack")
	assert_almost_eq(d.player.get_horizontal_speed(), 0.0, 0.05, "o golpe não empurra o personagem")


func test_ground_attack_keeps_walking() -> void:
	await _ready_world()
	d.step(40, Vector2(0, 1))
	d.press_attack()
	d.step(10, Vector2(0, 1))
	assert_eq(d.state(), &"Attack")
	assert_almost_eq(d.player.get_horizontal_speed(), d.player.get_walk_speed(), 0.05, "anda golpeando")


func test_sprint_attack_keeps_running_and_drains_sp() -> void:
	await _ready_world()
	d.step(40, Vector2(0, 1), true)
	assert_eq(d.state(), &"Sprint")
	d.press_attack()
	d.step(1, Vector2(0, 1), true)
	var sp_before := d.player.sp.current
	d.step(10, Vector2(0, 1), true)
	assert_eq(d.state(), &"Attack")
	assert_almost_eq(d.player.get_horizontal_speed(), d.player.get_sprint_speed(), 0.05, "corre golpeando")
	assert_lt(d.player.sp.current, sp_before, "correr golpeando gasta SP")


func test_tap_fires_light_on_release() -> void:
	await _ready_world()
	d.press_attack()
	d.attack_light_held = true
	d.step(4)
	assert_ne(d.state(), &"Attack", "segurando: ainda carregando")
	assert_gt(d.player.get_heavy_charge(), 0.0)
	d.attack_light_held = false
	d.step(1)
	assert_eq(d.state(), &"Attack")
	assert_eq(d.player.state_machine.current.kind, CombatRules.KIND_LIGHT)


func test_holding_left_click_fires_heavy() -> void:
	await _ready_world()
	d.press_attack()
	d.attack_light_held = true
	d.step(d.player.combat_config.heavy_hold_ticks + 1)
	assert_eq(d.state(), &"Attack")
	assert_eq(d.player.state_machine.current.kind, CombatRules.KIND_HEAVY)
	d.attack_light_held = false
	d.step(2)
	assert_eq(d.player.state_machine.current.kind, CombatRules.KIND_HEAVY, "soltar depois não vira leve")


func test_dodge_cancels_attack_recovery() -> void:
	await _ready_world()
	var attack := _blade().light_combo[0]
	d.press_attack()
	d.step(d.player.secs_to_ticks(attack.startup + attack.active) + 3)
	assert_true(d.player.state_machine.current.is_recovery())
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_has(d.techniques, MovementRules.TECH_DODGE_CANCEL)


func test_swap_cancels_attack_recovery_and_changes_weapon() -> void:
	await _ready_world()
	var attack := _blade().light_combo[0]
	d.press_attack()
	d.step(d.player.secs_to_ticks(attack.startup + attack.active) + 3)
	d.press_weapon_swap(2)
	d.step(1)
	assert_eq(d.player.weapon_slot, 1)
	assert_ne(d.state(), &"Attack")
	assert_has(d.techniques, MovementRules.TECH_SWAP_CANCEL)


func test_swap_during_startup_does_not_cancel() -> void:
	await _ready_world()
	d.press_attack()
	d.step(1)
	d.press_weapon_swap(2)
	d.step(1)
	assert_eq(d.state(), &"Attack", "só a recuperação é cancelável")
	assert_does_not_have(d.techniques, MovementRules.TECH_SWAP_CANCEL)


func test_toggle_swap_and_weapon_speed() -> void:
	await _ready_world()
	d.press_weapon_swap(0)
	d.step(1)
	assert_eq(d.player.weapon_slot, 1)
	d.step(60, Vector2(0, 1))
	assert_almost_eq(d.player.get_horizontal_speed(), 6.0 * d.player.get_weapon().move_speed_multiplier, 0.05,
		"a adaga é mais leve")


func test_attack_goes_where_camera_looks_without_aim_assist() -> void:
	d.add_dummy(Vector3(1.4, 0, -2.4))
	await _ready_world()
	d.press_attack()
	d.step(1)
	var dir: Vector3 = d.player.state_machine.current.direction
	assert_almost_eq(dir.x, 0.0, 0.001, "mira assistida desligada por padrão")


func test_aim_assist_turns_attack_toward_target_when_enabled() -> void:
	var dummy := d.add_dummy(Vector3(1.4, 0, -2.4))  # ~30° à direita da câmera
	d.player.combat_config = d.player.combat_config.duplicate() as CombatConfig
	d.player.combat_config.aim_assist_enabled = true
	await _ready_world()
	d.press_attack()
	d.step(1)
	var dir: Vector3 = d.player.state_machine.current.direction
	assert_gt(dir.x, 0.3, "golpe virou para o poste")
	d.step(40)
	assert_gt(dummy.total_damage, 0.0)


func test_player_takes_damage_and_recovers() -> void:
	await _ready_world()
	var hit := d.player.take_hit({"damage": 25.0, "knockback": Vector3(0, 3, 5), "hitstop_ticks": 2})
	assert_true(hit)
	assert_eq(d.player.health.current, 75.0)
	d.step(1)
	assert_eq(d.state(), &"Hurt")
	d.step(60)
	assert_ne(d.state(), &"Hurt")


func test_dodge_iframes_cause_perfect_dodge() -> void:
	await _ready_world()
	d.press_dodge()
	d.step(2, Vector2(1, 0))
	assert_true(d.player.is_invulnerable)
	var hit := d.player.take_hit({"damage": 25.0, "knockback": Vector3.ZERO})
	assert_false(hit)
	assert_eq(d.player.health.current, 100.0)
	assert_has(d.techniques, MovementRules.TECH_PERFECT_DODGE)


func test_death_respawns_with_full_health() -> void:
	await _ready_world()
	d.player.take_hit({"damage": 500.0, "knockback": Vector3.ZERO})
	assert_true(d.player.health.is_dead())
	d.step(d.player.secs_to_ticks(d.player.combat_config.respawn_delay) + 5)
	assert_false(d.player.health.is_dead())
	assert_eq(d.player.health.current, d.player.combat_config.max_hp)


func test_aggressive_dummy_hits_player_in_range() -> void:
	var dummy := d.add_dummy(Vector3(0, 0, -1.5), TrainingDummy.Mode.AGGRESSIVE)
	dummy.config.attack_interval = 0.3
	dummy.config.attack_windup = 0.1
	await _ready_world()
	await wait_physics_frames(30)
	assert_lt(d.player.health.current, 100.0, "poste agressivo acertou")


func test_dummy_regenerates_after_delay() -> void:
	var dummy := d.add_dummy(Vector3(0, 0, -5))
	dummy.config.regen_delay = 0.2
	await _ready_world()
	dummy.take_hit({"damage": 50.0})
	assert_eq(dummy.hp, dummy.config.max_hp - 50.0)
	await wait_physics_frames(20)
	assert_eq(dummy.hp, dummy.config.max_hp)
