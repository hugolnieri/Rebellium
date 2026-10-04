extends Node3D
## Feedback visual greybox (só ouve GameEvents; não altera gameplay):
## rastro no dodge, faísca no wall jump e brilho da cápsula na cor de cada técnica.

var player: Player
var _trail_ticks_left: int = 0
var _trail_counter: int = 0
var _flash_material: StandardMaterial3D
var _flash_time_left: float = 0.0
var _flash_color: Color = Color.WHITE


func _ready() -> void:
	player = get_parent() as Player
	top_level = true
	GameEvents.dodged.connect(_on_dodged)
	GameEvents.wall_jump_executed.connect(_on_wall_jump)
	GameEvents.technique_executed.connect(_on_technique)


func _fb() -> FeedbackConfig:
	return player.feedback_config


func _on_dodged(who: Node, _direction: Vector3) -> void:
	if who != player:
		return
	_trail_ticks_left = player.secs_to_ticks(player.config.dodge_duration)
	_trail_counter = 0
	_spawn_ghost()


func _on_wall_jump(who: Node, data: Dictionary) -> void:
	if who != player:
		return
	var technique: StringName = data.get("technique", MovementRules.TECH_NORMAL)
	_spawn_spark(data.get("position", player.global_position), data.get("normal", Vector3.UP),
		_fb().get_technique_color(technique))


func _on_technique(who: Node, technique: StringName, data: Dictionary) -> void:
	if who != player:
		return
	var color := _fb().get_technique_color(technique)
	_flash(color)
	if technique == MovementRules.TECH_BUNNY_HOP or technique == MovementRules.TECH_CANCEL:
		_spawn_spark(data.get("position", player.global_position), Vector3.UP, color)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if _trail_ticks_left > 0:
		_trail_ticks_left -= 1
		_trail_counter += 1
		if _trail_counter % _fb().trail_spawn_interval_ticks == 0:
			_spawn_ghost()
	if _flash_time_left > 0.0:
		_flash_time_left = maxf(_flash_time_left - delta, 0.0)
		var k := _flash_time_left / maxf(_fb().body_flash_time, 0.001)
		_flash_material.emission = _flash_color
		_flash_material.emission_energy_multiplier = _fb().body_flash_energy * k
		if _flash_time_left == 0.0:
			player.body_mesh.material_overlay = null


func _spawn_ghost() -> void:
	var fb := _fb()
	var ghost := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = player.config.body_radius
	mesh.height = player.config.body_height
	ghost.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var color := fb.color_dodge_trail
	color.a = fb.trail_start_alpha
	material.albedo_color = color
	ghost.material_override = material
	_add_to_world(ghost)
	ghost.global_position = player.global_position + Vector3.UP * player.config.body_height * 0.5
	var tween := ghost.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, fb.trail_lifetime)
	tween.tween_callback(ghost.queue_free)


func _spawn_spark(at: Vector3, normal: Vector3, color: Color) -> void:
	var fb := _fb()
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = fb.spark_amount
	particles.lifetime = fb.spark_lifetime
	particles.direction = normal if normal.length_squared() > 0.0 else Vector3.UP
	particles.spread = 70.0
	particles.initial_velocity_min = fb.spark_speed * 0.5
	particles.initial_velocity_max = fb.spark_speed
	particles.gravity = Vector3.DOWN * fb.spark_speed * 2.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.06
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material = material
	particles.mesh = mesh
	_add_to_world(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _flash(color: Color) -> void:
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.albedo_color = Color(0, 0, 0)
		_flash_material.emission_enabled = true
	_flash_color = color
	_flash_time_left = _fb().body_flash_time
	player.body_mesh.material_overlay = _flash_material


func _add_to_world(node: Node3D) -> void:
	var world := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	world.add_child(node)
