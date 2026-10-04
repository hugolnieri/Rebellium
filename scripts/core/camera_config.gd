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
@export_range(0.0, 40.0, 0.5, "suffix:°") var max_speed_fov_bonus: float = 10.0
## FOV extra por m/s acima da velocidade de andar.
@export_range(0.0, 10.0, 0.05, "suffix:°/(m/s)") var fov_bonus_per_speed: float = 1.5
@export_range(0.5, 40.0, 0.5) var fov_lerp_speed: float = 8.0
