class_name CameraConfig
extends Resource
## Números da câmera em terceira pessoa (sobre o ombro).

@export_group("Enquadramento")
## Altura do pivô da câmera acima dos pés.
@export_range(0.0, 3.0, 0.01, "suffix:m") var pivot_height: float = 1.55
## Comprimento do braço (SpringArm3D) atrás do jogador.
@export_range(0.5, 10.0, 0.05, "suffix:m") var arm_length: float = 3.4
## Deslocamento lateral do ombro (sinal trocado pela tecla V).
@export_range(0.0, 2.0, 0.01, "suffix:m") var shoulder_offset: float = 0.75
## Velocidade da transição ao trocar de ombro.
@export_range(0.5, 40.0, 0.5) var shoulder_lerp_speed: float = 12.0
## Margem da colisão do braço para não atravessar paredes.
@export_range(0.0, 1.0, 0.01, "suffix:m") var spring_margin: float = 0.2

@export_group("Olhar")
@export_range(0.0001, 0.02, 0.0001, "suffix:rad/px") var mouse_sensitivity: float = 0.0025
@export var invert_y: bool = false
@export_range(-89.0, 0.0, 1.0, "suffix:°") var pitch_min_deg: float = -70.0
@export_range(0.0, 89.0, 1.0, "suffix:°") var pitch_max_deg: float = 55.0
## Inclinação inicial da câmera ao entrar na cena (negativo = olhando para baixo).
@export_range(-89.0, 89.0, 1.0, "suffix:°") var initial_pitch_deg: float = -12.0

@export_group("Campo de visão")
@export_range(40.0, 120.0, 0.5, "suffix:°") var base_fov: float = 75.0
## FOV extra máximo conforme a velocidade horizontal passa da velocidade de andar.
@export_range(0.0, 40.0, 0.5, "suffix:°") var max_speed_fov_bonus: float = 18.0
## FOV extra por m/s acima da velocidade de andar.
@export_range(0.0, 10.0, 0.05, "suffix:°/(m/s)") var fov_bonus_per_speed: float = 2.0
@export_range(0.5, 40.0, 0.5) var fov_lerp_speed: float = 8.0

@export_group("Tremor")
## Intensidade (0–1) somada ao trauma em cada wall jump.
@export_range(0.0, 1.0, 0.01) var shake_on_wall_jump: float = 0.18
## Trauma por m/s de impacto acima do mínimo ao aterrissar.
@export_range(0.0, 0.2, 0.005) var shake_land_per_speed: float = 0.03
## Tremor ao acertar um golpe (pesado vale o dobro) e ao levar dano.
@export_range(0.0, 1.0, 0.01) var shake_on_hit: float = 0.2
@export_range(0.0, 1.0, 0.01) var shake_on_hurt: float = 0.5
@export_range(0.0, 40.0, 0.5, "suffix:m/s") var shake_land_min_speed: float = 12.0
@export_range(0.0, 0.5, 0.005, "suffix:m") var shake_max_offset: float = 0.08
@export_range(0.1, 10.0, 0.1, "suffix:/s") var shake_decay: float = 2.5
@export_range(1.0, 60.0, 0.5, "suffix:Hz") var shake_frequency: float = 22.0

@export_group("Sensação de velocidade")
## Velocidade em que os efeitos começam (linhas, recuo da câmera).
@export_range(0.0, 40.0, 0.5, "suffix:m/s") var speed_fx_start_speed: float = 8.0
## Velocidade em que os efeitos chegam ao máximo.
@export_range(1.0, 60.0, 0.5, "suffix:m/s") var speed_fx_full_speed: float = 17.0
## Recuo extra do braço da câmera na velocidade máxima.
@export_range(0.0, 5.0, 0.05, "suffix:m") var speed_arm_bonus: float = 0.9
@export_range(0.0, 1.0, 0.01) var speed_lines_max_alpha: float = 0.32
@export_range(10.0, 300.0, 1.0) var speed_lines_count: float = 110.0
## Raio (0–1 do centro à borda) onde as linhas começam: mantém o centro limpo.
@export_range(0.0, 1.0, 0.01) var speed_lines_inner_radius: float = 0.32
@export var speed_lines_color: Color = Color(0.86, 0.84, 0.79, 1)
## Tremor contínuo leve proporcional à velocidade (0 = desligado).
@export_range(0.0, 1.0, 0.01) var speed_shake_trauma: float = 0.22
