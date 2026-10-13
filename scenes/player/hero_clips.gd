class_name HeroClips
extends RefCounted
## Animações feitas no Blender (art/character/hero.blend → hero.glb, ver tools/blender/).
## Cada clipe é pré-amostrado a 60 Hz uma vez (cache compartilhado) como uma pose por quadro:
## rotação local de cada osso animado + posição do quadril. O jogo consulta por tempo NORMALIZADO
## 0–1 (quem escolhe o quadro é o gameplay: fase da passada, progresso do dash, fase do golpe...).
## O osso Root (prévia dos giros no Blender) e os ossos do cabelo/olhos ficam de fora.
##
## Uma pose é um Array: [Quaternion por osso de `bones` ..., Vector3 posição do quadril].
##
## Os clipes saem sempre do hero.glb, mas tocam em QUALQUER modelo do VRoid (ex.: um personagem exportado do
## VRoid Studio): todos têm os mesmos ossos J_Bip_* em T-pose com descanso neutro, então `bind()` liga cada osso
## pelo nome e a pose vale direto (o quadril escala com a altura; modelo virado para +Z é espelhado).

const SOURCE_SCENE: PackedScene = preload("res://assets/character/hero.glb")
const SAMPLE_RATE: float = 60.0
const SKIPPED_PREFIXES: Array[String] = ["Root", "HairJoint", "J_Sec", "J_Adj"]

## Ossos animados (índices do Skeleton3D do hero.glb), na ordem das poses.
static var bones: PackedInt32Array = PackedInt32Array()
## Nomes dos ossos animados (mesma ordem): é por eles que outros modelos se ligam aos clipes.
static var bone_names: PackedStringArray = PackedStringArray()
static var hips_slot: int = -1
## Descanso do quadril e altura da cabeça no hero.glb (referência para outros modelos).
static var source_hips_rest: Vector3 = Vector3.ZERO
static var source_head_height: float = 1.0
## clipe -> {"frames": Array[Array], "length": float}
static var _cache: Dictionary = {}


## Converte todas as animações do modelo (uma vez por execução).
static func load_from(rig: Node, skeleton: Skeleton3D, hips_bone: int) -> void:
	if not _cache.is_empty():
		return
	var players := rig.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	var animated := {}
	for clip_name: StringName in player.get_animation_list():
		var anim := player.get_animation(clip_name)
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				var bone_name := String(anim.track_get_path(i).get_concatenated_subnames())
				var bone := skeleton.find_bone(bone_name)
				if bone >= 0 and not _skipped(bone_name):
					animated[bone] = true
	var list := animated.keys()
	list.sort()
	bones = PackedInt32Array(list)
	bone_names = PackedStringArray()
	for bone: int in bones:
		bone_names.append(skeleton.get_bone_name(bone))
	hips_slot = bones.find(hips_bone)
	source_hips_rest = skeleton.get_bone_rest(hips_bone).origin
	var head := skeleton.find_bone("J_Bip_C_Head")
	if head >= 0:
		source_head_height = skeleton.get_bone_global_rest(head).origin.y
	for clip_name: StringName in player.get_animation_list():
		_cache[clip_name] = _bake(player.get_animation(clip_name), skeleton, hips_bone)


## Carrega os clipes do hero.glb se ainda não estiverem carregados.
static func ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	var rig := SOURCE_SCENE.instantiate() as Node3D
	var skeleton := rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	load_from(rig, skeleton, skeleton.find_bone("J_Bip_C_Hips"))
	rig.free()


## Liga os clipes a um esqueleto qualquer do VRoid (pelo nome dos ossos).
static func bind(skeleton: Skeleton3D, hips_bone: int) -> Binding:
	ensure_loaded()
	return Binding.new(skeleton, hips_bone)


## Liga as poses dos clipes aos ossos de um esqueleto (o do herói ou outro modelo do VRoid).
class Binding:
	var skeleton: Skeleton3D
	## Índice do osso neste esqueleto para cada osso animado (-1 = o modelo não tem esse osso).
	var targets: PackedInt32Array = PackedInt32Array()
	var hips_bone: int = -1
	## Modelo virado para +Z (VRM 1.0): espelha as poses; quem usa gira o modelo 180° (`facing_flipped`).
	var facing_flipped: bool = false
	var _hips_rest: Vector3 = Vector3.ZERO
	var _hips_scale: float = 1.0

	func _init(target: Skeleton3D, hips: int) -> void:
		skeleton = target
		hips_bone = hips
		for bone_name in HeroClips.bone_names:
			targets.append(target.find_bone(bone_name))
		_hips_rest = target.get_bone_rest(hips).origin
		var source_hips := HeroClips.source_hips_rest
		_hips_scale = _hips_rest.y / source_hips.y if source_hips.y > 0.001 else 1.0
		var foot := target.find_bone("J_Bip_L_Foot")
		var toe := target.find_bone("J_Bip_L_ToeBase")
		if foot >= 0 and toe >= 0:
			facing_flipped = target.get_bone_global_rest(toe).origin.z > target.get_bone_global_rest(foot).origin.z

	## Altura da cabeça deste modelo em T-pose (para escalar todos à mesma altura).
	func head_height() -> float:
		var head := skeleton.find_bone("J_Bip_C_Head")
		return skeleton.get_bone_global_rest(head).origin.y if head >= 0 else HeroClips.source_head_height

	func apply(pose: Array) -> void:
		var count := targets.size()
		for slot in count:
			var bone := targets[slot]
			if bone < 0:
				continue
			var q: Quaternion = pose[slot]
			if facing_flipped:
				q = Quaternion(-q.x, q.y, -q.z, q.w)
			skeleton.set_bone_pose_rotation(bone, q)
		var offset: Vector3 = (pose[count] as Vector3) - HeroClips.source_hips_rest
		if facing_flipped:
			offset = Vector3(-offset.x, offset.y, -offset.z)
		skeleton.set_bone_pose_position(hips_bone, _hips_rest + offset * _hips_scale)


static func _skipped(bone_name: String) -> bool:
	for prefix in SKIPPED_PREFIXES:
		if bone_name.begins_with(prefix):
			return true
	return false


static func has_clip(clip: StringName) -> bool:
	return _cache.has(clip)


## Duração original do clipe (s).
static func length_of(clip: StringName) -> float:
	return _cache[clip]["length"] if _cache.has(clip) else 1.0


## Pose no tempo normalizado `u` (0–1). `loop` faz o tempo dar a volta.
static func sample(clip: StringName, u: float, loop: bool = false) -> Array:
	var frames: Array = _cache[clip]["frames"]
	var last := frames.size() - 1
	var t := fposmod(u, 1.0) if loop else clampf(u, 0.0, 1.0)
	var f := t * last
	var i := mini(int(f), maxi(last - 1, 0))
	return blend(frames[i], frames[mini(i + 1, last)], clampf(f - i, 0.0, 1.0))


## Mistura duas poses (slerp por osso, lerp na posição do quadril).
static func blend(a: Array, b: Array, t: float) -> Array:
	if t <= 0.0:
		return a
	if t >= 1.0:
		return b
	var out := []
	out.resize(a.size())
	var n := a.size() - 1
	for i in n:
		out[i] = (a[i] as Quaternion).slerp(b[i], t)
	out[n] = (a[n] as Vector3).lerp(b[n], t)
	return out


## Mistura com peso por osso (`weights` alinhado com `bones`; o quadril usa `hips_weight`).
static func blend_masked(a: Array, b: Array, weights: PackedFloat32Array, hips_weight: float) -> Array:
	var out := []
	out.resize(a.size())
	var n := a.size() - 1
	for i in n:
		out[i] = (a[i] as Quaternion).slerp(b[i], weights[i]) if weights[i] > 0.0 else a[i]
	out[n] = (a[n] as Vector3).lerp(b[n], hips_weight)
	return out


static func _bake(anim: Animation, skeleton: Skeleton3D, hips_bone: int) -> Dictionary:
	var rotation_tracks := {}
	var hips_track := -1
	for i in anim.get_track_count():
		var bone := skeleton.find_bone(String(anim.track_get_path(i).get_concatenated_subnames()))
		if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			rotation_tracks[bone] = i
		elif anim.track_get_type(i) == Animation.TYPE_POSITION_3D and bone == hips_bone:
			hips_track = i
	var count := maxi(int(ceil(anim.length * SAMPLE_RATE)), 1) + 1
	var frames: Array[Array] = []
	var previous := []
	for n in count:
		var time := anim.length * n / float(count - 1)
		var frame := []
		frame.resize(bones.size() + 1)
		for slot in bones.size():
			var bone := bones[slot]
			var q := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			if rotation_tracks.has(bone):
				q = anim.rotation_track_interpolate(rotation_tracks[bone], time)
			# Mesmo hemisfério do quadro anterior (slerp pelo caminho curto entre quadros).
			if not previous.is_empty() and q.dot(previous[slot]) < 0.0:
				q = -q
			frame[slot] = q
		var hips := skeleton.get_bone_rest(hips_bone).origin
		if hips_track >= 0:
			hips = anim.position_track_interpolate(hips_track, time)
		frame[bones.size()] = hips
		frames.append(frame)
		previous = frame
	return {"frames": frames, "length": anim.length}
