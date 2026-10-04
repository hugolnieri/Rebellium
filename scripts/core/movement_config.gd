class_name MovementConfig
extends Resource
## TODOS os números de gameplay da movimentação. Editável no inspetor, no .tres e no menu F2.
## Regra: nenhum estado/regra usa número mágico; tudo sai daqui.

@export_group("Corpo")
## Raio da cápsula do jogador.
@export_range(0.2, 1.0, 0.01, "suffix:m") var body_radius: float = 0.4
## Altura total da cápsula (origem do corpo fica nos pés).
@export_range(1.0, 3.0, 0.01, "suffix:m") var body_height: float = 1.8
## Inclinação máxima considerada chão.
@export_range(10.0, 80.0, 1.0, "suffix:°") var floor_max_angle_deg: float = 46.0
## Distância de "grude" no chão ao descer degraus/rampas.
@export_range(0.0, 1.0, 0.01, "suffix:m") var floor_snap_length: float = 0.3

@export_group("Chão")
@export_range(0.5, 30.0, 0.1, "suffix:m/s") var walk_speed: float = 6.0
@export_range(0.5, 40.0, 0.1, "suffix:m/s") var sprint_speed: float = 10.0
## Aceleração no chão até a velocidade alvo.
@export_range(1.0, 300.0, 0.5, "suffix:m/s²") var ground_acceleration: float = 60.0
## Desaceleração no chão (sem input ou acima da velocidade alvo).
@export_range(1.0, 300.0, 0.5, "suffix:m/s²") var ground_deceleration: float = 45.0

@export_group("Pulo e ar")
## Altura do pulo do chão.
@export_range(0.2, 10.0, 0.05, "suffix:m") var jump_height: float = 2.2
## Tempo do chão até o ápice do pulo (define a gravidade de subida).
@export_range(0.1, 1.5, 0.01, "suffix:s") var jump_time_to_apex: float = 0.38
## Multiplicador da gravidade quando caindo (queda mais seca que a subida).
@export_range(0.5, 4.0, 0.05) var fall_gravity_multiplier: float = 1.6
@export_range(5.0, 100.0, 0.5, "suffix:m/s") var terminal_fall_speed: float = 30.0
## Aceleração de controle no ar (não aumenta a velocidade além da atual/andar).
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var air_acceleration: float = 18.0
## Ticks após sair de uma borda em que o pulo do chão ainda é aceito (conta como PULO).
@export_range(0, 20, 1, "suffix:ticks") var coyote_ticks: int = 5
## Ticks que um aperto de pulo fica "guardado" antes de tocar o chão/parede.
@export_range(0, 20, 1, "suffix:ticks") var jump_buffer_ticks: int = 4

@export_group("Aterrissagem")
## Duração do estado Land (recuperação curta).
@export_range(0, 30, 1, "suffix:ticks") var land_recovery_ticks: int = 5

@export_group("SP")
@export_range(1.0, 500.0, 1.0) var sp_max: float = 100.0
@export_range(0.0, 200.0, 0.5, "suffix:SP/s") var sp_regen_per_second: float = 25.0
## Tempo sem gastar SP até a regeneração começar.
@export_range(0.0, 5.0, 0.05, "suffix:s") var sp_regen_delay: float = 0.6
@export_range(0.0, 100.0, 0.5, "suffix:SP/s") var sprint_sp_cost_per_second: float = 12.0
## Com SP zerado, sprint/dodge/wall jump ficam bloqueados até o SP voltar a este valor.
@export_range(0.0, 500.0, 1.0) var sp_recovery_threshold: float = 20.0


## Gravidade de subida derivada de altura e tempo de ápice: g = 2h / t².
func get_jump_gravity() -> float:
	return 2.0 * jump_height / (jump_time_to_apex * jump_time_to_apex)


func get_fall_gravity() -> float:
	return get_jump_gravity() * fall_gravity_multiplier


## Velocidade inicial do pulo do chão (atinge `jump_height` na simulação a 60 ticks).
func get_jump_velocity() -> float:
	return velocity_for_height(jump_height)


## Velocidade vertical para subir `height` metros com a gravidade de subida.
## Compensa a integração discreta (o tick do impulso move com v cheio, sem gravidade):
## altura_discreta ≈ v²/2g + v·dt/2  →  v = −g·dt/2 + sqrt((g·dt/2)² + 2gh).
func velocity_for_height(height: float) -> float:
	var g := get_jump_gravity()
	var half_step := g * (1.0 / Engine.physics_ticks_per_second) * 0.5
	return -half_step + sqrt(half_step * half_step + 2.0 * g * maxf(height, 0.0))
