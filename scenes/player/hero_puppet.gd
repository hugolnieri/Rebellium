class_name HeroPuppet
extends Node3D
## Boneco do herói para alvos (ex.: o caçador): instancia o hero.glb na mesma escala do personagem do jogador
## (pés na origem) e toca os clipes do Blender (`HeroClips`) direto nos ossos, com crossfade nas trocas.
## Só apresentação: quem usa decide qual clipe e em que ponto dele (tempo normalizado 0–1).

const MODEL_SCENE: PackedScene = preload("res://assets/character/hero.glb")

var _rig: Node3D
var _skeleton: Skeleton3D
var _hips_bone: int = -1
var _binding: HeroClips.Binding
var _current: Array = []
var _fade_from: Array = []
var _fade_t: float = 0.0
var _fade_time: float = 0.0
var _key: int = -1


func _ready() -> void:
	_rig = MODEL_SCENE.instantiate() as Node3D
	_rig.scale = Vector3.ONE * (CharacterModel.REFERENCE_HEIGHT / CharacterModel.MODEL_HEIGHT)
	add_child(_rig)
	_skeleton = _rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_hips_bone = _skeleton.find_bone(CharacterModel.HIPS_BONE)
	_binding = HeroClips.bind(_skeleton, _hips_bone)


## Cobre o corpo todo com um material só (ex.: o vermelho do caçador).
func paint(material: Material) -> void:
	for mesh in _rig.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material


## Mostra `clip` no ponto `u` (0–1; `loop` dá a volta). `key` identifica o trecho em andamento: quando muda, a
## pose anterior se mistura com a nova por `blend_time` segundos (`delta` é o tempo desde a última chamada).
func show_clip(key: int, clip: StringName, u: float, loop: bool, delta: float, blend_time: float = 0.1) -> void:
	if not HeroClips.has_clip(clip):
		return
	var pose := HeroClips.sample(clip, u, loop)
	if key != _key:
		_key = key
		if not _current.is_empty():
			_fade_from = _current
			_fade_t = 0.0
			_fade_time = blend_time
	if _fade_t < _fade_time:
		_fade_t += delta
		pose = HeroClips.blend(_fade_from, pose, smoothstep(0.0, 1.0, _fade_t / _fade_time))
	_current = pose
	_binding.apply(pose)
