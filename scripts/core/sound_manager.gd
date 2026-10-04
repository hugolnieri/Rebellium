extends Node
## Autoload "SoundManager": toca os efeitos sonoros ouvindo GameEvents (a lógica nunca chama som).
## Sons 3D posicionais com um pool de players; volumes em config/audio_config.tres.

const SFX_DIR: String = "res://assets/sfx/"
const POOL_SIZE: int = 24
const CONFIG_PATH: String = "res://config/audio_config.tres"

enum Category { COMBAT, MOVEMENT, FOOTSTEPS, INTERFACE }

var config: AudioConfig
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _next: int = 0


func _ready() -> void:
	config = load(CONFIG_PATH) as AudioConfig if ResourceLoader.exists(CONFIG_PATH) else AudioConfig.new()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.max_distance = config.max_distance
		player.unit_size = 6.0
		add_child(player)
		_pool.append(player)
	GameEvents.attack_started.connect(_on_attack_started)
	GameEvents.hit_landed.connect(_on_hit_landed)
	GameEvents.jumped.connect(func(who: Node) -> void: play(&"jump", _pos(who), Category.MOVEMENT))
	GameEvents.landed.connect(func(who: Node, impact: float) -> void:
		if impact > 4.0:
			play(&"land", _pos(who), Category.MOVEMENT, clampf(impact / 20.0, 0.0, 1.0) * 6.0 - 3.0))
	GameEvents.wall_jump_executed.connect(func(who: Node, _d: Dictionary) -> void:
		play(&"wall_jump", _pos(who), Category.MOVEMENT))
	GameEvents.dodged.connect(func(who: Node, _dir: Vector3) -> void: play(&"dash", _pos(who), Category.MOVEMENT))
	GameEvents.weapon_changed.connect(func(who: Node, _w: Resource, _s: int) -> void:
		play(&"weapon_swap", _pos(who), Category.INTERFACE))
	GameEvents.technique_executed.connect(_on_technique)
	GameEvents.player_hurt.connect(func(who: Node, _i: Dictionary) -> void: play(&"hurt", _pos(who), Category.COMBAT))
	GameEvents.sp_depleted.connect(func(who: Node) -> void: play(&"sp_empty", _pos(who), Category.INTERFACE))
	GameEvents.footstep.connect(_on_footstep)
	GameEvents.dummy_warning.connect(func(who: Node) -> void: play(&"dummy_warning", _pos(who), Category.COMBAT))
	GameEvents.dummy_attack.connect(func(who: Node) -> void: play(&"dummy_swing", _pos(who), Category.COMBAT))


## Toca um som pelo nome do arquivo (sem extensão) numa posição do mundo.
func play(sound: StringName, at: Vector3, category: Category, extra_db: float = 0.0,
		pitch: float = 1.0) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.global_position = at
	player.volume_db = config.master_db + _category_db(category) + extra_db
	player.pitch_scale = pitch * (1.0 + randf_range(-config.pitch_variation, config.pitch_variation))
	player.play()


func _on_attack_started(who: Node, attack: Resource, weapon: Resource, kind: StringName) -> void:
	var w := weapon as WeaponConfig
	var sound := &"fang_swing" if w != null and w.model == WeaponConfig.Model.PHASE_FANG else &"blade_swing"
	if kind == CombatRules.KIND_HEAVY and sound == &"blade_swing":
		sound = &"blade_swing_heavy"
	var pitch := 1.0 + (attack as AttackData).startup * -0.5
	play(sound, _pos(who), Category.COMBAT, 0.0, pitch)


func _on_hit_landed(_attacker: Node, _target: Node, info: Dictionary) -> void:
	var w := info.get("weapon") as WeaponConfig
	var sound := &"hit_fang" if w != null and w.model == WeaponConfig.Model.PHASE_FANG else &"hit_blade"
	if info.get("kind", &"") == CombatRules.KIND_HEAVY:
		sound = &"hit_heavy"
	play(sound, info.get("point", Vector3.ZERO), Category.COMBAT)


func _on_technique(who: Node, technique: StringName, _data: Dictionary) -> void:
	var sound := &"perfect_dodge" if technique == MovementRules.TECH_PERFECT_DODGE else &"technique"
	play(sound, _pos(who), Category.INTERFACE)


func _on_footstep(who: Node, intensity: float) -> void:
	var variant := StringName("footstep_%d" % (randi() % 3 + 1))
	play(variant, _pos(who), Category.FOOTSTEPS, intensity * 4.0,
		1.0 + intensity * config.footstep_pitch_by_speed)


func _stream(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		var path := SFX_DIR + String(sound) + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


func _category_db(category: Category) -> float:
	match category:
		Category.COMBAT:
			return config.combat_db
		Category.MOVEMENT:
			return config.movement_db
		Category.FOOTSTEPS:
			return config.footsteps_db
	return config.interface_db


func _pos(node: Node) -> Vector3:
	return (node as Node3D).global_position if node is Node3D else Vector3.ZERO
