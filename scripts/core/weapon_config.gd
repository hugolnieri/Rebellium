class_name WeaponConfig
extends Resource
## Uma arma: identidade visual + golpes (cada golpe é um AttackData em arquivo próprio).

enum Model { ARC_BLADE, PHASE_FANG }

@export_group("Identidade")
@export var display_name: String = "Arma"
@export var model: Model = Model.ARC_BLADE
## Cor do brilho e do rastro dos golpes.
@export var glow_color: Color = Color(0.25, 0.95, 1.0)

@export_group("Golpes")
## Combo do ataque leve (botão esquerdo), em ordem.
@export var light_combo: Array[AttackData] = []
## Ataque pesado (botão direito). Também serve de finalizador no meio do combo.
@export var heavy: AttackData
## Ataque leve no ar.
@export var air: AttackData
## Ataque leve durante o dash.
@export var dash: AttackData

@export_group("Manuseio")
## Multiplicador da velocidade de andar/correr com esta arma.
@export_range(0.5, 1.5, 0.01) var move_speed_multiplier: float = 1.0
## Parado/andando a arma fica apoiada no ombro (no sprint segue a corrida ninja).
@export var rest_on_shoulder: bool = false
