class_name TouchdownConfig
extends Resource
## Parâmetros do modo Touch Down, editáveis no F2 como os demais Resources de gameplay.

@export_group("Partida")
@export_range(30.0, 1200.0, 1.0, "suffix:s") var duration: float = 180.0
@export_range(1, 20, 1) var score_limit: int = 3
@export_range(-100.0, 0.0, 0.5, "suffix:m") var fall_reset_height: float = -8.0

@export_group("Núcleo")
@export_range(0.5, 5.0, 0.05, "suffix:m") var pickup_radius: float = 1.45
@export_range(0.0, 10.0, 0.1, "suffix:s") var ball_reset_delay: float = 1.2

@export_group("Base adversária")
@export_range(1.0, 12.0, 0.1, "suffix:m") var goal_width: float = 6.0
@export_range(1.0, 8.0, 0.1, "suffix:m") var goal_height: float = 3.2
@export_range(1.0, 14.0, 0.1, "suffix:m") var goal_depth: float = 6.0
