extends GutTest
## SP: consumo, atraso de regeneração, bloqueio com SP zerado e recuperação.

const DT: float = 1.0 / 60.0

var cfg: MovementConfig
var sp: SPPool


func before_each() -> void:
	cfg = MovementConfig.new()
	sp = SPPool.new(cfg)


func _advance(seconds: float) -> void:
	for i in roundi(seconds / DT):
		sp.update(DT)


func test_starts_full_with_spec_defaults() -> void:
	assert_eq(cfg.sp_max, 100.0)
	assert_eq(cfg.sp_regen_per_second, 25.0)
	assert_eq(cfg.sp_regen_delay, 0.6)
	assert_eq(cfg.sprint_sp_cost_per_second, 12.0)
	assert_eq(cfg.sp_recovery_threshold, 20.0)
	assert_eq(sp.current, 100.0)
	assert_false(sp.exhausted)


func test_try_spend_consumes_exact_amount() -> void:
	assert_true(sp.try_spend(18.0))
	assert_almost_eq(sp.current, 82.0, 0.001)


func test_try_spend_fails_without_enough_and_spends_nothing() -> void:
	sp.current = 10.0
	assert_false(sp.try_spend(20.0))
	assert_almost_eq(sp.current, 10.0, 0.001)


func test_sprint_drain_costs_12_per_second() -> void:
	for i in 60:
		sp.update(DT)
		sp.drain(cfg.sprint_sp_cost_per_second * DT)
	assert_almost_eq(sp.current, 88.0, 0.01)


func test_no_regen_before_delay() -> void:
	sp.try_spend(50.0)
	_advance(0.58)
	assert_almost_eq(sp.current, 50.0, 0.001, "não pode regenerar antes de 0,6 s")


func test_regen_after_delay_at_25_per_second() -> void:
	sp.try_spend(50.0)
	_advance(0.6)
	var at_delay := sp.current
	_advance(1.0)
	assert_almost_eq(sp.current - at_delay, 25.0, 0.5)


func test_spending_resets_regen_delay() -> void:
	sp.try_spend(50.0)
	_advance(0.5)
	sp.try_spend(1.0)
	_advance(0.5)
	assert_almost_eq(sp.current, 49.0, 0.001)


func test_regen_caps_at_max() -> void:
	sp.try_spend(10.0)
	_advance(5.0)
	assert_eq(sp.current, 100.0)


func test_reaching_zero_exhausts_and_emits_signal() -> void:
	watch_signals(sp)
	sp.current = 20.0
	assert_true(sp.try_spend(20.0))
	assert_true(sp.exhausted)
	assert_signal_emitted(sp, "depleted")


func test_drain_to_zero_exhausts() -> void:
	sp.current = 0.1
	sp.drain(1.0)
	assert_eq(sp.current, 0.0)
	assert_true(sp.exhausted)


func test_exhausted_blocks_all_spending_until_threshold() -> void:
	sp.current = 5.0
	sp.drain(5.0)
	assert_true(sp.exhausted)
	_advance(0.6 + 0.5)  # ~12,5 SP regenerados, abaixo de 20
	assert_lt(sp.current, cfg.sp_recovery_threshold)
	assert_true(sp.exhausted)
	assert_false(sp.can_spend(5.0), "exausto: nem custos baixos são permitidos")
	assert_false(sp.try_spend(5.0))
	assert_false(sp.can_drain(), "exausto: sem sprint")


func test_recovers_at_threshold_and_emits_signal() -> void:
	watch_signals(sp)
	sp.current = 1.0
	sp.drain(1.0)
	_advance(0.6 + 0.85)  # 21,25 SP
	assert_false(sp.exhausted)
	assert_signal_emitted(sp, "recovered")
	assert_true(sp.try_spend(18.0))


func test_threshold_is_configurable() -> void:
	cfg.sp_recovery_threshold = 50.0
	sp.current = 1.0
	sp.drain(1.0)
	_advance(0.6 + 1.0)
	assert_true(sp.exhausted, "com limiar 50, 25 SP ainda é exausto")
