class_name AttackData
extends Resource
## Um golpe: tempos, alcance, dano, impulso e animação. Um arquivo .tres por golpe
## (config/weapons/<arma>/<golpe>.tres), editável no F2 (aba Armas).

@export_group("Identidade")
## Nome do golpe (HUD de debug e log).
@export var display_name: String = "golpe"
## Pose de animação procedural (ver scenes/player/attack_poses.gd).
@export_enum("slash_r", "slash_l", "overhead", "thrust", "spin", "rising", "air_slam",
	"dash_thrust", "jab", "backhand") var anim: String = "slash_r"

@export_group("Tempos")
## Preparação antes de acertar.
@export_range(0.0, 1.5, 0.01, "suffix:s") var startup: float = 0.12
## Janela em que o golpe acerta.
@export_range(0.01, 1.0, 0.01, "suffix:s") var active: float = 0.1
## Recuperação depois do golpe (cancelável por dash ou troca de arma).
@export_range(0.0, 2.0, 0.01, "suffix:s") var recovery: float = 0.3
## A partir de quando (desde o início) o próximo golpe do combo pode sair, se já foi apertado.
@export_range(0.0, 2.0, 0.01, "suffix:s") var chain_after: float = 0.25

@export_group("Acerto")
@export_range(0.0, 200.0, 0.5) var damage: float = 12.0
## Alcance à frente do jogador.
@export_range(0.3, 8.0, 0.05, "suffix:m") var reach: float = 2.2
## Abertura do arco do golpe (360 = em volta).
@export_range(10.0, 360.0, 1.0, "suffix:°") var arc_deg: float = 140.0
## Alcance vertical (acima e abaixo do centro do jogador).
@export_range(0.2, 5.0, 0.05, "suffix:m") var vertical_reach: float = 1.4
## Recuo horizontal aplicado ao alvo.
@export_range(0.0, 40.0, 0.5, "suffix:m/s") var knockback: float = 3.0
## Lançamento vertical aplicado ao alvo.
@export_range(-30.0, 30.0, 0.5, "suffix:m/s") var knockback_up: float = 0.0
## Congelamento dos dois no impacto (dá peso ao golpe).
@export_range(0.0, 0.5, 0.005, "suffix:s") var hitstop: float = 0.06

@export_group("Movimento")
## Avanço durante preparação + acerto (0 = parado).
@export_range(0.0, 40.0, 0.5, "suffix:m/s") var lunge_speed: float = 0.0
## No ar: velocidade vertical ao começar o golpe (0 = mantém).
@export_range(-40.0, 20.0, 0.5, "suffix:m/s") var air_start_vertical_speed: float = 0.0
## No ar: velocidade vertical ao entrar na janela de acerto (0 = mantém). Negativo = desce.
@export_range(-60.0, 20.0, 0.5, "suffix:m/s") var air_active_vertical_speed: float = 0.0
## Gravidade durante o golpe no ar (0 = flutua, 1 = normal).
@export_range(0.0, 2.0, 0.05) var air_gravity_scale: float = 0.35
@export_range(0.0, 100.0, 1.0) var sp_cost: float = 0.0


func total_time() -> float:
	return startup + active + recovery
