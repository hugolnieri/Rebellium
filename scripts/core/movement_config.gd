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
## Sprint = toque duplo para frente (W): intervalo máximo entre os dois toques.
@export_range(1, 60, 1, "suffix:ticks") var sprint_double_tap_ticks: int = 15
## O sprint continua enquanto o input para frente for maior que isto (soltou W = parou).
@export_range(0.0, 1.0, 0.01) var sprint_forward_threshold: float = 0.3
## Correndo (sprint no chão ou corrida no ar), a velocidade vira NA HORA para a direção da
## câmera/input, mantendo o embalo. Se false, vira com a aceleração normal.
@export var sprint_instant_turn: bool = true
## Corrida no ar: toque duplo em W no ar acelera até a velocidade de sprint...
@export var air_sprint_enabled: bool = true
@export_range(0.0, 200.0, 0.5, "suffix:m/s²") var air_sprint_acceleration: float = 30.0
## ...mas a gravidade fica multiplicada por isto enquanto corre no ar (cai mais rápido).
@export_range(1.0, 5.0, 0.05) var air_sprint_gravity_multiplier: float = 1.7
@export_range(0.0, 100.0, 0.5, "suffix:SP/s") var air_sprint_sp_cost_per_second: float = 12.0
## Com SP zerado, sprint/dodge/wall jump ficam bloqueados até o SP voltar a este valor.
@export_range(0.0, 500.0, 1.0) var sp_recovery_threshold: float = 20.0

@export_group("Dodge")
@export_range(0.0, 100.0, 1.0) var dodge_sp_cost: float = 20.0
## Velocidade do passo rápido.
@export_range(1.0, 60.0, 0.5, "suffix:m/s") var dodge_speed: float = 16.0
## Duração do deslocamento (distância ≈ velocidade × duração).
@export_range(0.02, 1.0, 0.01, "suffix:s") var dodge_duration: float = 0.18
## Janela de invencibilidade desde o início do dodge (`is_invulnerable`).
@export_range(0.0, 1.0, 0.01, "suffix:s") var dodge_invulnerability: float = 0.15
## Recuperação após o deslocamento (cancelável por outro dodge).
@export_range(0.0, 1.0, 0.01, "suffix:s") var dodge_recovery: float = 0.12
## Velocidade horizontal ao entrar na recuperação.
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var dodge_exit_speed: float = 5.0
## Dash exige uma direção (Shift + A/D/W/S). Se false, Shift sozinho usa a direção neutra.
@export var dodge_requires_direction: bool = true
## Sem direção pressionada (só se não exigir direção): true = para trás, false = para frente.
@export var dodge_neutral_backward: bool = true
@export var dodge_allow_in_air: bool = true
## Quantos dashes no ar por pulo (recarrega ao aterrissar e, se ligado, a cada wall jump).
@export_range(0, 5, 1) var air_dodge_max_per_air: int = 1
@export var air_dodge_refresh_on_wall_jump: bool = true
## Durante o dash no ar a gravidade é suspensa (dash reto, sem cair).
@export var air_dodge_suspends_gravity: bool = true
## Velocidade horizontal mantida ao fim do dash no ar (não há recuperação no ar).
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var air_dodge_exit_speed: float = 9.0
## Dodge pode interromper estados de recuperação (Land, recuperação do dodge).
@export var dodge_cancel_enabled: bool = true
@export_range(0, 20, 1, "suffix:ticks") var dodge_buffer_ticks: int = 3

@export_group("Wall jump")
@export_range(0.0, 100.0, 1.0) var wall_jump_sp_cost: float = 18.0
## Depois de um pulo (ou wall jump), por quanto tempo o wall jump continua liberado mesmo caindo.
@export_range(0.0, 3.0, 0.01, "suffix:s") var wall_jump_window_after_jump: float = 0.6
## Altura ganha pelo impulso vertical do wall jump.
@export_range(0.0, 10.0, 0.05, "suffix:m") var wall_jump_height: float = 2.6
## Multiplicador da velocidade horizontal refletida.
@export_range(0.1, 3.0, 0.01) var wall_jump_horizontal_multiplier: float = 1.1
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var wall_jump_min_horizontal_speed: float = 8.0
@export_range(1.0, 60.0, 0.1, "suffix:m/s") var wall_jump_max_horizontal_speed: float = 18.0
## Empurrão extra ao longo da parede, no sentido em que o jogador já ia (lança mais para frente).
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var wall_jump_forward_boost: float = 2.0
## Componente mínima de afastamento da parede na saída (evita grudar/entrar na parede).
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var wall_jump_min_away_speed: float = 3.0
## Peso da direção da câmera no ajuste fino da saída (side jump). 0 = reflexão pura.
@export_range(0.0, 1.0, 0.01) var wall_jump_camera_weight: float = 0.4
## Tempo sem controle aéreo logo após o wall jump (estado WallJump).
@export_range(0.0, 1.0, 0.01, "suffix:s") var wall_jump_lock_time: float = 0.15
## Proíbe dois wall jumps seguidos na MESMA parede (exceto após back-coming).
@export var wall_jump_same_wall_lockout: bool = true
## Distância extra (além do raio) em que a parede conta como tocada.
@export_range(0.0, 1.0, 0.01, "suffix:m") var wall_detect_distance: float = 0.2
## |normal.y| máximo para uma superfície contar como parede.
@export_range(0.0, 0.9, 0.01) var wall_max_normal_y: float = 0.35
## Ticks que o contato com a parede é "lembrado" depois de se afastar.
@export_range(0, 20, 1, "suffix:ticks") var wall_contact_grace_ticks: int = 4
## Velocidade mínima em direção à parede para registrar uma nova entrada.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var wall_approach_min_speed: float = 0.2
## Ângulo de entrada (a partir da normal) a partir do qual o wall jump conta como side jump.
@export_range(0.0, 89.0, 1.0, "suffix:°") var side_jump_min_incidence_deg: float = 30.0

@export_group("Técnicas avançadas")
## Janela justa (reverse/back-coming): Space até N ticks do contato com a parede.
@export_range(0, 30, 1, "suffix:ticks") var technique_window_ticks: int = 6
## Altura (acima dos pés) do raio que procura o topo da parede.
@export_range(0.5, 4.0, 0.05, "suffix:m") var reverse_probe_height: float = 2.0
@export_range(0.0, 10.0, 0.05, "suffix:m") var reverse_jump_height: float = 2.3
## Velocidade para FRENTE (por cima da parede) no reverse wall jump.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var reverse_forward_speed: float = 6.5
## Distância máxima dos pés ao chão para o contato contar como "base da parede".
@export_range(0.0, 4.0, 0.05, "suffix:m") var back_coming_max_feet_height: float = 1.0
@export_range(0.0, 10.0, 0.05, "suffix:m") var back_coming_height: float = 2.6
## Leve empurrão de volta PARA a parede no back-coming: o jogador sobe colado nela e ganha
## um segundo wall jump na mesma parede (sem precisar de nova janela justa).
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var back_coming_wall_push_speed: float = 1.0
## Cancel: troca de arma até N ticks do wall jump.
@export_range(0, 20, 1, "suffix:ticks") var cancel_window_ticks: int = 4
## Fração da velocidade de entrada preservada pelo cancel.
@export_range(0.0, 1.0, 0.01) var cancel_speed_retained: float = 0.5
## Bunny hop: pulo nos primeiros N ticks após aterrissar preserva a velocidade horizontal.
@export_range(0, 20, 1, "suffix:ticks") var bunny_hop_window_ticks: int = 3
@export_range(1.0, 60.0, 0.5, "suffix:m/s") var bunny_hop_speed_cap: float = 16.0


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
