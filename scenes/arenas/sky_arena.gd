extends "res://scenes/arenas/combat_arena.gd"
## Arena flutuante (modelo feito no Blender: tools/blender/build_sky_arena.py → assets/arena/sky_arena.glb).
## Herda da arena de combate (spawn, postes, R reinicia, queda volta ao spawn) e só anima o cenário:
## drones em órbita, luzes das antenas piscando, chamas dos propulsores tremendo e
## prédios da cidade lá embaixo. Nada aqui altera gameplay.

const TOWER_SHADER: Shader = preload("res://scenes/arenas/sky/tower.gdshader")

## Prédios distantes (abaixo das nuvens).
@export var tower_count: int = 140
@export var tower_min_distance: float = 140.0
@export var tower_max_distance: float = 650.0
@export var city_level: float = -260.0
@export var drone_orbit_speed: float = 0.12
@export var beacon_period: float = 1.4

var _time: float = 0.0
var _drones: Array[Node3D] = []
var _drone_bases: Array[Vector3] = []
var _beacons: Array[Node3D] = []
var _flames: Array[Node3D] = []


func _ready() -> void:
	super()
	var platform := $Platform as Node3D
	for node in platform.find_children("*", "Node3D", true, false):
		var node_name := String(node.name)
		if node_name.begins_with("Drone_"):
			_drones.append(node)
			_drone_bases.append(node.position)
		elif node_name.begins_with("Beacon_"):
			_beacons.append(node)
		elif node_name.begins_with("Flame_"):
			_flames.append(node)
	_build_towers()


func _process(delta: float) -> void:
	_time += delta
	for i in _drones.size():
		var base := _drone_bases[i]
		var angle := _time * drone_orbit_speed * (1.0 + 0.2 * i)
		var p := base.rotated(Vector3.UP, angle)
		p.y = base.y + sin(_time * 1.3 + i) * 0.6
		_drones[i].position = p
		_drones[i].rotation.y = -angle
	for i in _beacons.size():
		_beacons[i].visible = fmod(_time + i * 0.35, beacon_period) < beacon_period * 0.3
	for i in _flames.size():
		var flicker := 1.0 + 0.08 * sin(_time * 31.0 + i * 1.7) + 0.05 * sin(_time * 53.0 + i)
		_flames[i].scale = Vector3(1.0, flicker, 1.0)


## Prédios escuros com janelas acesas espalhados ao redor, bem abaixo da plataforma.
func _build_towers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var mesh := BoxMesh.new()
	var material := ShaderMaterial.new()
	material.shader = TOWER_SHADER
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = tower_count
	for i in tower_count:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(tower_min_distance, tower_max_distance)
		var height := rng.randf_range(50.0, 170.0)
		var width := rng.randf_range(14.0, 34.0)
		var basis := Basis.from_scale(Vector3(width, height, rng.randf_range(14.0, 34.0)))
		var origin := Vector3(cos(angle) * distance, city_level + height * 0.5, sin(angle) * distance)
		multimesh.set_instance_transform(i, Transform3D(basis, origin))
	var towers := MultiMeshInstance3D.new()
	towers.name = "Towers"
	towers.multimesh = multimesh
	towers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(towers)
