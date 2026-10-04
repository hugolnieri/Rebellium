class_name AttackPoses
extends RefCounted
## Poses-chave dos golpes para a animação procedural (só apresentação).
## Cada golpe tem 3 poses: preparação (fim do startup), acerto (fim do active) e
## acompanhamento (meio da recuperação). Canais em radianos (Euler X, Y, Z do nó).
## "spin": giro total do corpo no eixo Y durante o acerto (golpes giratórios).
##
## Convenções do esqueleto (frente = -Z):
##  shoulder_r.x > 0 levanta o braço para frente; shoulder_r.y > 0 leva o braço para a esquerda;
##  elbow.x > 0 dobra o antebraço; wrist_r.x ≈ -1.5 deixa a lâmina na linha do braço;
##  spine/chest.y > 0 gira o tronco para a esquerda; spine.x < 0 inclina para frente.

const POSES: Dictionary = {
	"slash_r": [
		{"spine": Vector3(0.05, -0.55, 0), "chest": Vector3(0, -0.35, 0), "shoulder_r": Vector3(1.25, -1.35, 0.25),
			"elbow_r": Vector3(0.7, 0, 0), "wrist_r": Vector3(-1.0, 0, 0.3), "shoulder_l": Vector3(0.6, 0, -0.35),
			"elbow_l": Vector3(1.3, 0, 0), "thigh_l": Vector3(0.35, 0, 0), "knee_l": Vector3(-0.45, 0, 0),
			"thigh_r": Vector3(-0.25, 0, 0), "knee_r": Vector3(-0.35, 0, 0), "hips": Vector3(0, -0.3, 0)},
		{"spine": Vector3(-0.15, 0.55, 0), "chest": Vector3(0, 0.4, 0), "shoulder_r": Vector3(1.45, 1.0, 0),
			"elbow_r": Vector3(0.1, 0, 0), "wrist_r": Vector3(-1.4, 0, -0.2), "shoulder_l": Vector3(0.2, 0, -0.7),
			"elbow_l": Vector3(0.6, 0, 0), "thigh_l": Vector3(0.55, 0, 0), "knee_l": Vector3(-0.6, 0, 0),
			"thigh_r": Vector3(-0.35, 0, 0), "knee_r": Vector3(-0.2, 0, 0), "hips": Vector3(0, 0.35, 0)},
		{"spine": Vector3(-0.1, 0.75, 0), "chest": Vector3(0, 0.45, 0), "shoulder_r": Vector3(1.05, 1.45, 0),
			"elbow_r": Vector3(0.45, 0, 0), "wrist_r": Vector3(-1.0, 0, 0), "shoulder_l": Vector3(0.3, 0, -0.5),
			"elbow_l": Vector3(0.9, 0, 0)},
	],
	"slash_l": [
		{"spine": Vector3(0.05, 0.6, 0), "chest": Vector3(0, 0.35, 0), "shoulder_r": Vector3(1.2, 1.25, 0),
			"elbow_r": Vector3(1.2, 0, 0), "wrist_r": Vector3(-0.8, 0, -0.4), "shoulder_l": Vector3(0.3, 0, -0.6),
			"elbow_l": Vector3(0.8, 0, 0), "thigh_r": Vector3(0.35, 0, 0), "knee_r": Vector3(-0.45, 0, 0),
			"thigh_l": Vector3(-0.25, 0, 0), "knee_l": Vector3(-0.35, 0, 0), "hips": Vector3(0, 0.3, 0)},
		{"spine": Vector3(-0.15, -0.6, 0), "chest": Vector3(0, -0.4, 0), "shoulder_r": Vector3(1.45, -1.2, 0.1),
			"elbow_r": Vector3(0.12, 0, 0), "wrist_r": Vector3(-1.4, 0, 0.3), "shoulder_l": Vector3(0.7, 0, -0.3),
			"elbow_l": Vector3(1.2, 0, 0), "thigh_r": Vector3(0.5, 0, 0), "knee_r": Vector3(-0.55, 0, 0),
			"thigh_l": Vector3(-0.35, 0, 0), "knee_l": Vector3(-0.2, 0, 0), "hips": Vector3(0, -0.35, 0)},
		{"spine": Vector3(-0.1, -0.8, 0), "chest": Vector3(0, -0.45, 0), "shoulder_r": Vector3(1.0, -1.55, 0.2),
			"elbow_r": Vector3(0.5, 0, 0), "wrist_r": Vector3(-1.0, 0, 0.2)},
	],
	"overhead": [
		{"spine": Vector3(0.25, -0.2, 0), "chest": Vector3(0.15, 0, 0), "shoulder_r": Vector3(2.75, 0.1, 0.15),
			"elbow_r": Vector3(1.3, 0, 0), "wrist_r": Vector3(-0.5, 0, 0), "shoulder_l": Vector3(2.4, 0, -0.2),
			"elbow_l": Vector3(1.4, 0, 0), "thigh_l": Vector3(0.3, 0, 0), "knee_l": Vector3(-0.3, 0, 0),
			"thigh_r": Vector3(-0.2, 0, 0)},
		{"spine": Vector3(-0.55, 0.1, 0), "chest": Vector3(-0.25, 0, 0), "shoulder_r": Vector3(0.95, 0.15, 0),
			"elbow_r": Vector3(0.05, 0, 0), "wrist_r": Vector3(-1.45, 0, 0), "shoulder_l": Vector3(0.5, 0, -0.4),
			"elbow_l": Vector3(0.7, 0, 0), "thigh_l": Vector3(0.75, 0, 0), "knee_l": Vector3(-0.9, 0, 0),
			"thigh_r": Vector3(-0.45, 0, 0), "knee_r": Vector3(-0.5, 0, 0), "hips_y": -0.12},
		{"spine": Vector3(-0.45, 0.1, 0), "shoulder_r": Vector3(0.55, 0.2, 0), "elbow_r": Vector3(0.3, 0, 0),
			"wrist_r": Vector3(-1.3, 0, 0), "hips_y": -0.1},
	],
	"thrust": [
		{"spine": Vector3(0.05, -0.5, 0), "shoulder_r": Vector3(0.9, -0.5, 0.35), "elbow_r": Vector3(1.9, 0, 0),
			"wrist_r": Vector3(-1.55, 0, 0), "shoulder_l": Vector3(1.0, 0, -0.2), "elbow_l": Vector3(0.4, 0, 0),
			"thigh_l": Vector3(0.3, 0, 0), "knee_l": Vector3(-0.5, 0, 0), "thigh_r": Vector3(-0.3, 0, 0),
			"knee_r": Vector3(-0.4, 0, 0)},
		{"spine": Vector3(-0.3, 0.35, 0), "shoulder_r": Vector3(1.5, 0.15, 0), "elbow_r": Vector3(0.0, 0, 0),
			"wrist_r": Vector3(-1.57, 0, 0), "shoulder_l": Vector3(0.2, 0, -0.9), "elbow_l": Vector3(0.3, 0, 0),
			"thigh_l": Vector3(0.75, 0, 0), "knee_l": Vector3(-0.7, 0, 0), "thigh_r": Vector3(-0.55, 0, 0),
			"knee_r": Vector3(-0.1, 0, 0), "hips_y": -0.1},
		{"spine": Vector3(-0.2, 0.3, 0), "shoulder_r": Vector3(1.2, 0.1, 0), "elbow_r": Vector3(0.4, 0, 0)},
	],
	"spin": [
		{"spine": Vector3(0.1, -0.7, 0), "chest": Vector3(0, -0.3, 0), "shoulder_r": Vector3(0.4, -0.3, 1.2),
			"elbow_r": Vector3(0.6, 0, 0), "wrist_r": Vector3(-1.2, 0, 0), "shoulder_l": Vector3(0.5, 0, -1.0),
			"elbow_l": Vector3(0.6, 0, 0), "thigh_l": Vector3(0.4, 0, -0.25), "knee_l": Vector3(-0.8, 0, 0),
			"thigh_r": Vector3(0.1, 0, 0.3), "knee_r": Vector3(-0.8, 0, 0), "hips_y": -0.2},
		{"spine": Vector3(-0.1, 0.2, 0), "shoulder_r": Vector3(0.15, 0, 1.45), "elbow_r": Vector3(0.05, 0, 0),
			"wrist_r": Vector3(-1.5, 0, 0), "shoulder_l": Vector3(0.1, 0, -1.3), "elbow_l": Vector3(0.2, 0, 0),
			"thigh_l": Vector3(0.2, 0, -0.35), "knee_l": Vector3(-0.5, 0, 0), "thigh_r": Vector3(0.2, 0, 0.35),
			"knee_r": Vector3(-0.5, 0, 0), "hips_y": -0.15, "spin": TAU},
		{"spine": Vector3(-0.15, 0.4, 0), "shoulder_r": Vector3(0.8, 0.8, 0.6), "elbow_r": Vector3(0.4, 0, 0),
			"hips_y": -0.1},
	],
	"rising": [
		{"spine": Vector3(-0.3, -0.3, 0), "shoulder_r": Vector3(-0.3, -0.3, 0.4), "elbow_r": Vector3(0.4, 0, 0),
			"wrist_r": Vector3(-1.2, 0, 0), "shoulder_l": Vector3(0.8, 0, -0.3), "elbow_l": Vector3(1.2, 0, 0),
			"thigh_l": Vector3(0.7, 0, 0), "knee_l": Vector3(-1.2, 0, 0), "thigh_r": Vector3(0.1, 0, 0),
			"knee_r": Vector3(-1.1, 0, 0), "hips_y": -0.25},
		{"spine": Vector3(0.3, 0.3, 0), "chest": Vector3(0.2, 0, 0), "shoulder_r": Vector3(2.9, 0.2, 0.1),
			"elbow_r": Vector3(0.1, 0, 0), "wrist_r": Vector3(-1.5, 0, 0), "shoulder_l": Vector3(0.3, 0, -0.9),
			"thigh_l": Vector3(0.9, 0, 0), "knee_l": Vector3(-1.4, 0, 0), "thigh_r": Vector3(-0.2, 0, 0),
			"knee_r": Vector3(-0.2, 0, 0), "hips_y": 0.05},
		{"spine": Vector3(0.15, 0.2, 0), "shoulder_r": Vector3(2.4, 0.2, 0.1), "elbow_r": Vector3(0.4, 0, 0)},
	],
	"air_slam": [
		{"spine": Vector3(0.35, 0, 0), "chest": Vector3(0.2, 0, 0), "shoulder_r": Vector3(3.0, 0, 0.1),
			"elbow_r": Vector3(1.0, 0, 0), "wrist_r": Vector3(-0.6, 0, 0), "shoulder_l": Vector3(2.8, 0, -0.1),
			"elbow_l": Vector3(1.1, 0, 0), "thigh_l": Vector3(1.2, 0, 0), "knee_l": Vector3(-1.8, 0, 0),
			"thigh_r": Vector3(0.9, 0, 0), "knee_r": Vector3(-1.6, 0, 0)},
		{"spine": Vector3(-0.7, 0, 0), "chest": Vector3(-0.3, 0, 0), "shoulder_r": Vector3(0.7, 0.1, 0),
			"elbow_r": Vector3(0.05, 0, 0), "wrist_r": Vector3(-1.55, 0, 0), "shoulder_l": Vector3(0.4, 0, -0.8),
			"thigh_l": Vector3(1.4, 0, 0), "knee_l": Vector3(-1.9, 0, 0), "thigh_r": Vector3(0.6, 0, 0),
			"knee_r": Vector3(-1.2, 0, 0)},
		{"spine": Vector3(-0.6, 0, 0), "shoulder_r": Vector3(0.5, 0.1, 0), "elbow_r": Vector3(0.2, 0, 0)},
	],
	"dash_thrust": [
		{"spine": Vector3(-0.2, -0.4, 0), "shoulder_r": Vector3(0.6, -0.4, 0.3), "elbow_r": Vector3(1.8, 0, 0),
			"wrist_r": Vector3(-1.55, 0, 0), "shoulder_l": Vector3(1.3, 0, -0.1), "elbow_l": Vector3(0.3, 0, 0),
			"thigh_l": Vector3(0.6, 0, 0), "knee_l": Vector3(-0.8, 0, 0), "thigh_r": Vector3(-0.5, 0, 0),
			"knee_r": Vector3(-0.6, 0, 0), "hips_y": -0.18},
		{"spine": Vector3(-0.6, 0.25, 0), "chest": Vector3(-0.15, 0, 0), "shoulder_r": Vector3(1.55, 0.1, 0),
			"elbow_r": Vector3(0.0, 0, 0), "wrist_r": Vector3(-1.57, 0, 0), "shoulder_l": Vector3(-0.5, 0, -0.5),
			"elbow_l": Vector3(0.2, 0, 0), "thigh_l": Vector3(0.9, 0, 0), "knee_l": Vector3(-0.9, 0, 0),
			"thigh_r": Vector3(-0.8, 0, 0), "knee_r": Vector3(-0.15, 0, 0), "hips_y": -0.22},
		{"spine": Vector3(-0.4, 0.2, 0), "shoulder_r": Vector3(1.2, 0.1, 0), "elbow_r": Vector3(0.3, 0, 0),
			"hips_y": -0.12},
	],
	"jab": [
		{"spine": Vector3(0, -0.35, 0), "shoulder_r": Vector3(0.9, -0.3, 0.3), "elbow_r": Vector3(1.7, 0, 0),
			"wrist_r": Vector3(-1.5, 0, 0), "shoulder_l": Vector3(1.0, 0, -0.2), "elbow_l": Vector3(1.4, 0, 0),
			"thigh_l": Vector3(0.25, 0, 0), "knee_l": Vector3(-0.4, 0, 0), "thigh_r": Vector3(-0.2, 0, 0),
			"knee_r": Vector3(-0.35, 0, 0)},
		{"spine": Vector3(-0.15, 0.3, 0), "shoulder_r": Vector3(1.5, 0.12, 0), "elbow_r": Vector3(0.05, 0, 0),
			"wrist_r": Vector3(-1.5, 0, 0), "shoulder_l": Vector3(0.6, 0, -0.4), "elbow_l": Vector3(1.5, 0, 0),
			"thigh_l": Vector3(0.45, 0, 0), "knee_l": Vector3(-0.5, 0, 0)},
		{"spine": Vector3(-0.1, 0.2, 0), "shoulder_r": Vector3(1.2, 0.1, 0), "elbow_r": Vector3(0.5, 0, 0)},
	],
	"backhand": [
		{"spine": Vector3(0, 0.5, 0), "shoulder_r": Vector3(1.0, 1.1, 0), "elbow_r": Vector3(1.6, 0, 0),
			"wrist_r": Vector3(-0.9, 0, -0.4), "shoulder_l": Vector3(0.5, 0, -0.5), "elbow_l": Vector3(1.0, 0, 0),
			"thigh_r": Vector3(0.3, 0, 0), "knee_r": Vector3(-0.4, 0, 0)},
		{"spine": Vector3(-0.1, -0.5, 0), "shoulder_r": Vector3(1.35, -1.1, 0.2), "elbow_r": Vector3(0.2, 0, 0),
			"wrist_r": Vector3(-1.3, 0, 0.3), "shoulder_l": Vector3(0.8, 0, -0.2), "elbow_l": Vector3(1.3, 0, 0),
			"thigh_r": Vector3(0.45, 0, 0), "knee_r": Vector3(-0.5, 0, 0)},
		{"spine": Vector3(-0.05, -0.6, 0), "shoulder_r": Vector3(1.0, -1.4, 0.2), "elbow_r": Vector3(0.5, 0, 0)},
	],
}


static func get_keys(anim: String) -> Array:
	return POSES.get(anim, POSES["slash_r"])
