class_name HeroClips
extends RefCounted
## Animações feitas no Blender (art/character/hero.blend → hero.glb, ver tools/blender/) convertidas
## para os canais do esqueleto de referência de CharacterModel (Euler YXZ por articulação + hips_y).
## Cada clipe é pré-amostrado a 60 Hz uma vez (cache compartilhado) e consultado por tempo
## NORMALIZADO 0–1: quem escolhe o quadro é o gameplay (fase da passada, progresso do dash...).

const SAMPLE_RATE: float = 60.0

## clipe -> {"frames": Array[Dictionary], "length": float}
static var _cache: Dictionary = {}


## Converte todas as animações do modelo (uma vez por execução).
static func load_from(rig: Node, bone_map: Dictionary, arm_ref: Dictionary, hips_rest: Vector3,
		rig_scale: float) -> void:
	if not _cache.is_empty():
		return
	var players := rig.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	for clip_name: StringName in player.get_animation_list():
		_cache[clip_name] = _bake(player.get_animation(clip_name), bone_map, arm_ref, hips_rest, rig_scale)


static func has_clip(clip: StringName) -> bool:
	return _cache.has(clip)


## Duração original do clipe (s).
static func length_of(clip: StringName) -> float:
	return _cache[clip]["length"] if _cache.has(clip) else 1.0


## Pose no tempo normalizado `u` (0–1). `loop` faz o tempo dar a volta.
static func sample(clip: StringName, u: float, loop: bool = false) -> Dictionary:
	var frames: Array = _cache[clip]["frames"]
	var last := frames.size() - 1
	var t := fposmod(u, 1.0) if loop else clampf(u, 0.0, 1.0)
	var f := t * last
	var i := mini(int(f), maxi(last - 1, 0))
	var k := clampf(f - i, 0.0, 1.0)
	var a: Dictionary = frames[i]
	var b: Dictionary = frames[mini(i + 1, last)]
	var out := {}
	for channel: StringName in a:
		out[channel] = (a[channel] as Vector3).lerp(b[channel], k)
	return out


static func _bake(anim: Animation, bone_map: Dictionary, arm_ref: Dictionary, hips_rest: Vector3,
		rig_scale: float) -> Dictionary:
	var rotation_tracks := {}
	var hips_track := -1
	var hips_bone: StringName = bone_map[&"hips"]
	for i in anim.get_track_count():
		var bone := StringName(anim.track_get_path(i).get_concatenated_subnames())
		if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			rotation_tracks[bone] = i
		elif anim.track_get_type(i) == Animation.TYPE_POSITION_3D and bone == hips_bone:
			hips_track = i
	var count := maxi(int(ceil(anim.length * SAMPLE_RATE)), 1) + 1
	var frames: Array[Dictionary] = []
	var previous := {}
	for n in count:
		var time := anim.length * n / float(count - 1)
		var frame := {}
		for joint: StringName in bone_map:
			var bone: StringName = bone_map[joint]
			var q := Quaternion.IDENTITY
			if rotation_tracks.has(bone):
				q = anim.rotation_track_interpolate(rotation_tracks[bone], time)
			var euler := _closest_euler(_to_reference(joint, q, arm_ref), previous.get(joint, Vector3.ZERO),
				not previous.has(joint))
			previous[joint] = euler
			frame[joint] = euler
		var hips_y := 0.0
		if hips_track >= 0:
			hips_y = (anim.position_track_interpolate(hips_track, time).y - hips_rest.y) * rig_scale
		frame[&"hips_y"] = Vector3(hips_y, 0, 0)
		frames.append(frame)
	return {"frames": frames, "length": anim.length}


## Inverso de CharacterModel._set_joint: rotação do osso → rotação no esqueleto de referência.
static func _to_reference(joint: StringName, q: Quaternion, arm_ref: Dictionary) -> Quaternion:
	var joint_name := String(joint)
	if joint_name.begins_with("shoulder") or joint_name.begins_with("elbow") or joint_name.begins_with("wrist"):
		var ref: Quaternion = arm_ref[StringName(joint_name.right(1))]
		return q * ref.inverse() if joint_name.begins_with("shoulder") else ref * q * ref.inverse()
	return q


## Escolhe, entre as representações Euler equivalentes, a mais próxima da anterior (continuidade
## para as molas) — ou a de menor ângulo no primeiro quadro.
static func _closest_euler(q: Quaternion, near: Vector3, first: bool) -> Vector3:
	var e := q.get_euler()
	var candidates: Array[Vector3] = [e, Vector3(PI - e.x, e.y + PI, e.z + PI)]
	var best := Vector3.ZERO
	var best_cost := INF
	for c in candidates:
		var target := Vector3.ZERO if first else near
		var w := Vector3(_wrap_near(c.x, target.x), _wrap_near(c.y, target.y), _wrap_near(c.z, target.z))
		var cost := w.length() if first else w.distance_to(near)
		if cost < best_cost:
			best_cost = cost
			best = w
	return best


static func _wrap_near(angle: float, target: float) -> float:
	return target + wrapf(angle - target, -PI, PI)
