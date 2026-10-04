class_name HealthPool
extends RefCounted
## Vida pura (sem cena). Emite sinais ao mudar e ao zerar.

signal changed(current: float, maximum: float)
signal died

var maximum: float = 100.0
var current: float = 100.0


func _init(max_hp: float) -> void:
	maximum = max_hp
	current = max_hp


func is_dead() -> bool:
	return current <= 0.0


## Aplica dano; retorna o dano efetivo (não passa de zero).
func damage(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var dealt := minf(amount, current)
	current -= dealt
	changed.emit(current, maximum)
	if current <= 0.0:
		current = 0.0
		died.emit()
	return dealt


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	current = minf(maximum, current + amount)
	changed.emit(current, maximum)


func refill() -> void:
	current = maximum
	changed.emit(current, maximum)


func get_ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0
