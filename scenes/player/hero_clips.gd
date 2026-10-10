class_name HeroClips
extends RefCounted
## Animações feitas no Blender (art/character/hero.blend → hero.glb, ver tools/blender/).
## Cada clipe é pré-amostrado a 60 Hz uma vez (cache compartilhado) como uma pose por quadro:
## rotação local de cada osso animado + posição do quadril. O jogo consulta por tempo NORMALIZADO
## 0–1 (quem escolhe o quadro é o gameplay: fase da passada, progresso do dash, fase do golpe...).
## O osso Root (prévia dos giros no Blender) e os ossos do cabelo/olhos ficam de fora.
##
## Uma pose é um Array: [Quaternion por osso de `bones` ..., Vector3 posição do quadril].

const SAMPLE_RATE: float = 60.0
const SKIPPED_PREFIXES: Array[String] = ["Root", "HairJoint", "J_Sec", "J_Adj"]

## Ossos animados (índices do Skeleton3D), na ordem das poses.
static var bones: PackedInt32Array = PackedInt32Array()
static var hips_slot: int = -1
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
	hips_slot = bones.find(hips_bone)
	for clip_name: StringName in player.get_animation_list():
		_cache[clip_name] = _bake(player.get_animation(clip_name), skeleton, hips_bone)


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
