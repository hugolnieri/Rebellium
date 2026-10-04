class_name SPPool
extends RefCounted
## Reserva de SP (stamina). Lógica pura, sem cena: lê os valores do MovementConfig ao vivo.
##
## - Regenera `sp_regen_per_second` após `sp_regen_delay` segundos sem gastar.
## - Ao chegar a zero fica EXAUSTO: nenhum gasto é permitido até voltar a `sp_recovery_threshold`.

signal depleted
signal recovered

var config: MovementConfig
var current: float = 0.0
var exhausted: bool = false
## Segundos desde o último gasto.
var time_since_spend: float = 0.0


func _init(movement_config: MovementConfig) -> void:
	config = movement_config
	current = config.sp_max
	time_since_spend = config.sp_regen_delay


## Avança o tempo. Chamar uma vez por tick ANTES da lógica de movimento.
func update(delta: float) -> void:
	time_since_spend += delta
	if time_since_spend >= config.sp_regen_delay and current < config.sp_max:
		current = minf(config.sp_max, current + config.sp_regen_per_second * delta)
	if exhausted and current >= config.sp_recovery_threshold:
		exhausted = false
		recovered.emit()


## Pode pagar um custo único (dodge, wall jump)?
func can_spend(amount: float) -> bool:
	return not exhausted and current >= amount


## Paga um custo único. Retorna false (sem gastar nada) se não puder.
func try_spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	_consume(amount)
	return true


## Pode drenar continuamente (sprint)?
func can_drain() -> bool:
	return not exhausted and current > 0.0


## Drena até `amount` (custo contínuo). Retorna quanto foi efetivamente drenado.
func drain(amount: float) -> float:
	if not can_drain():
		return 0.0
	var used := minf(amount, current)
	_consume(used)
	return used


func get_ratio() -> float:
	return current / config.sp_max if config.sp_max > 0.0 else 0.0


## Restaura SP cheio (reset do modo treino).
func refill() -> void:
	current = config.sp_max
	exhausted = false
	time_since_spend = config.sp_regen_delay


func _consume(amount: float) -> void:
	current -= amount
	time_since_spend = 0.0
	if current <= 0.0001:
		current = 0.0
		if not exhausted:
			exhausted = true
			depleted.emit()
