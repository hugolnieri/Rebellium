class_name FeedbackConfig
extends Resource
## Cores e durações de feedback visual (greybox). Acentos só para feedback.

@export_group("Paleta")
@export var color_base_black: Color = Color(0.04, 0.04, 0.05)
@export var color_dark_grey: Color = Color(0.18, 0.18, 0.19)
@export var color_dirty_white: Color = Color(0.86, 0.84, 0.79)
@export var color_metal: Color = Color(0.47, 0.49, 0.52)
@export var accent_red: Color = Color(0.92, 0.12, 0.15)
@export var accent_violet: Color = Color(0.58, 0.28, 0.98)
@export var accent_electric_blue: Color = Color(0.12, 0.62, 1.0)
@export var accent_acid_green: Color = Color(0.62, 1.0, 0.12)

@export_group("Modelo")
## Velocidade com que a cápsula vira para a direção do movimento.
@export_range(0.5, 60.0, 0.5) var model_turn_speed: float = 16.0

@export_group("HUD")
@export var sp_bar_color: Color = Color(0.12, 0.62, 1.0)
@export var sp_exhausted_color: Color = Color(0.92, 0.12, 0.15)
@export var hp_bar_color: Color = Color(0.62, 1.0, 0.12)
