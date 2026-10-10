class_name AttackPoses
extends RefCounted
## Metadados dos golpes para a animação. As poses ficam nos clipes atk_<anim> do Blender
## (tools/blender/hero_animations.py → art/character/hero.blend → hero.glb).
## "spin": giro total do corpo no eixo Y durante o acerto (o jogo aplica por código, no ritmo do golpe).

const SPIN: Dictionary = {
	"spin": -TAU,  # gira para a DIREITA (sentido horário visto de cima)
}


static func get_spin(anim: String) -> float:
	return SPIN.get(anim, 0.0)
