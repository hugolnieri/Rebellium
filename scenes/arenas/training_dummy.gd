class_name TrainingDummy
extends AnimatableBody3D
## Poste de treino: alvo dos golpes (grupo "hittable"). Mostra vida, números de dano e balança.
## Modos: parado, patrulha (vai e volta) e agressivo (contra-ataca em área com aviso).

enum Mode { STATIC, PATROL, AGGRESSIVE }

@export var config: DummyConfig
@export var mode: Mode = Mode.STATIC
## Direção da patrulha (local).
@export var patrol_axis: Vector3 = Vector3.RIGHT

var hp: float = 0.0
var total_damage: float = 0.0

var _home: Vector3
var _time_since_hit: float = 999.0
var _broken_left: float = 0.0
var _patrol_t: float = 0.0
var _wobble: Vector2 = Vector2.ZERO
var _wobble_velocity: Vector2 = Vector2.ZERO
var _attack_timer: float = 0.0
var _winding_up: bool = false
var _pivot: Node3D
var _hp_label: Label3D
var _target_material: StandardMaterial3D
var _warning_material: StandardMaterial3D
var _flash_left: float = 0.0
var _spin_arm: Node3D
var _arm_spin: float = 0.0


func _ready() -> void:
	add_to_group(&"hittable")
	if config == null:
		config = DummyConfig.new()
	hp = config.max_hp
	_home = global_position
	sync_to_physics = true
	_build()


func get_hit_center() -> Vector3:
	return global_position + Vector3.UP * 1.25


func get_hit_radius() -> float:
	return config.hit_radius


func take_hit(info: Dictionary) -> bool:
	if _broken_left > 0.0:
		return false
	var amount: float = info.get("damage", 0.0)
	hp = maxf(hp - amount, 0.0)
	total_damage += amount
	_time_since_hit = 0.0
	_flash_left = 0.12
	var knockback: Vector3 = info.get("knockback", Vector3.ZERO)
	var push := Vector2(knockback.x, knockback.z) * config.wobble_per_knockback * 4.0
	_wobble_velocity += push
	_spawn_damage_number(amount, info.get("kind", &"light") == CombatRules.KIND_HEAVY)
	if hp <= 0.0:
		_broken_left = config.broken_time
	return true


func _physics_process(delta: float) -> void:
	_time_since_hit += delta
	if _broken_left > 0.0:
		_broken_left -= delta
		if _broken_left <= 0.0:
			hp = config.max_hp
	elif _time_since_hit > config.regen_delay and hp < config.max_hp:
		hp = config.max_hp
	match mode:
		Mode.PATROL:
			_patrol_t += delta * config.patrol_speed / maxf(config.patrol_distance, 0.01)
			var offset := sin(_patrol_t * PI) * config.patrol_distance * 0.5
			global_position = _home + patrol_axis.normalized() * offset
		Mode.AGGRESSIVE:
			_update_aggressive(delta)
	_update_visuals(delta)


func _update_aggressive(delta: float) -> void:
	_attack_timer += delta
	if not _winding_up and _attack_timer >= config.attack_interval - config.attack_windup:
		_winding_up = true
	if _attack_timer < config.attack_interval:
		return
	_attack_timer = 0.0
	_winding_up = false
	_arm_spin = TAU
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	if player == null or _broken_left > 0.0:
		return
	var to_player := player.get_hit_center() - get_hit_center()
	if Vector2(to_player.x, to_player.z).length() > config.attack_radius or absf(to_player.y) > 2.0:
		return
	var flat := Vector3(to_player.x, 0.0, to_player.z).normalized()
	player.take_hit({
		"attacker": self, "damage": config.attack_damage, "kind": &"dummy",
		"knockback": flat * config.attack_knockback + Vector3.UP * 3.0,
		"hitstop_ticks": MovementRules.seconds_to_ticks(config.attack_hitstop),
		"point": player.get_hit_center(),
	})


func _update_visuals(delta: float) -> void:
	# Mola 2D do balanço (inclinação em X/Z a partir da base).
	var omega := TAU * config.wobble_frequency
	var accel := -omega * omega * _wobble - 2.0 * config.wobble_damping * omega * _wobble_velocity
	_wobble_velocity += accel * delta
	_wobble += _wobble_velocity * delta
	_pivot.rotation = Vector3(_wobble.y, 0.0, -_wobble.x)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_target_material.emission_energy_multiplier = 4.0 * (_flash_left / 0.12) if _flash_left > 0.0 else 0.0
	var warning := 0.0
	if mode == Mode.AGGRESSIVE and _winding_up:
		var k := 1.0 - (config.attack_interval - _attack_timer) / maxf(config.attack_windup, 0.01)
		warning = clampf(k, 0.0, 1.0) * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.03))
	_warning_material.emission_energy_multiplier = warning * 5.0
	if _spin_arm != null:
		_arm_spin = maxf(_arm_spin - delta * TAU * 3.0, 0.0)
		_spin_arm.rotation.y = TAU - _arm_spin
	var state := "QUEBRADO" if _broken_left > 0.0 else "%d / %d" % [ceili(hp), roundi(config.max_hp)]
	_hp_label.text = "%s\n%s" % [_mode_name(), state]


func _mode_name() -> String:
	match mode:
		Mode.PATROL:
			return "POSTE MÓVEL"
		Mode.AGGRESSIVE:
			return "POSTE AGRESSIVO"
	return "POSTE"


func _spawn_damage_number(amount: float, big: bool) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 96 if big else 64
	label.outline_size = 16
	label.pixel_size = 0.005
	label.modulate = Color(1.0, 0.85, 0.3) if big else Color(0.95, 0.95, 0.95)
	label.outline_modulate = Color(0.05, 0.02, 0.1)
	get_parent().add_child(label)
	var side := randf_range(-0.4, 0.4)
	label.global_position = get_hit_center() + Vector3(side, 0.6, 0.0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector3(side, 1.0, 0.0), 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


func _build() -> void:
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 2.1
	collision.shape = shape
	collision.position = Vector3.UP * 1.05
	add_child(collision)

	var metal := _mat(Color(0.42, 0.44, 0.47), 0.35, 0.8)
	var dark := _mat(Color(0.08, 0.08, 0.09), 0.6, 0.2)
	_target_material = _mat(Color(0.86, 0.84, 0.79), 0.7, 0.0)
	_target_material.emission_enabled = true
	_target_material.emission = Color(1, 1, 1)
	_warning_material = _mat(Color(0.25, 0.04, 0.05), 0.5, 0.0)
	_warning_material.emission_enabled = true
	_warning_material.emission = Color(1.0, 0.1, 0.12)

	_add_mesh(self, _cyl(0.45, 0.5, 0.12), Vector3.UP * 0.06, dark)  # base
	_pivot = Node3D.new()
	_pivot.position = Vector3.UP * 0.12
	add_child(_pivot)
	_add_mesh(_pivot, _cyl(0.07, 0.09, 1.0), Vector3.UP * 0.5, metal)  # haste
	_add_mesh(_pivot, _capsule(0.3, 0.85), Vector3.UP * 1.15, _target_material)  # tronco-alvo
	for ring_y: float in [0.95, 1.15, 1.35]:
		_add_mesh(_pivot, _cyl(0.31, 0.31, 0.04), Vector3.UP * ring_y, dark)
	_add_mesh(_pivot, _sphere(0.17), Vector3.UP * 1.78, _target_material)  # cabeça
	_add_mesh(_pivot, _cyl(0.32, 0.32, 0.06), Vector3.UP * 1.56, _warning_material)  # anel de aviso
	if mode == Mode.AGGRESSIVE:
		_spin_arm = Node3D.new()
		_spin_arm.position = Vector3.UP * 1.25
		_pivot.add_child(_spin_arm)
		var arm := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(config.attack_radius * 2.0 * 0.85, 0.08, 0.12)
		arm.mesh = box
		arm.material_override = _warning_material
		_spin_arm.add_child(arm)

	_hp_label = Label3D.new()
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.position = Vector3.UP * 2.35
	_hp_label.font_size = 40
	_hp_label.outline_size = 10
	_hp_label.pixel_size = 0.005
	_hp_label.modulate = Color(0.86, 0.84, 0.79)
	add_child(_hp_label)


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)


func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh
