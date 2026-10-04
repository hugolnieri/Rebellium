class_name WeaponVisual
extends Node3D
## Modelo procedural da arma na mão do personagem. Espaço local: empunhadura na origem,
## lâmina para -Z. Expõe a base e a ponta da lâmina para o rastro do golpe.

var weapon: WeaponConfig
var trail_base: Node3D
var trail_tip: Node3D

var _glow_materials: Array[StandardMaterial3D] = []
var _base_energy: Array[float] = []
var _boost: float = 0.0


func build(config: WeaponConfig) -> void:
	weapon = config
	for child in get_children():
		child.queue_free()
	_glow_materials.clear()
	_base_energy.clear()
	trail_base = Node3D.new()
	trail_tip = Node3D.new()
	add_child(trail_base)
	add_child(trail_tip)
	match config.model:
		WeaponConfig.Model.PHASE_FANG:
			_build_phase_fang(config.glow_color)
		_:
			_build_arc_blade(config.glow_color)


## Brilho extra (0–1) durante o golpe.
func set_boost(amount: float) -> void:
	_boost = clampf(amount, 0.0, 1.0)
	for i in _glow_materials.size():
		_glow_materials[i].emission_energy_multiplier = _base_energy[i] * (1.0 + _boost * 1.5)


# --- Lâmina de Arco: espada de plasma ciano com lâmina bifurcada --------------------

func _build_arc_blade(glow: Color) -> void:
	var silver := _metal(Color(0.78, 0.8, 0.84))
	var dark := _metal(Color(0.1, 0.1, 0.12))
	var core_blue := _solid(Color(0.32, 0.38, 0.95), 0.4, 0.3)
	var sigil := _emissive(Color(0.8, 0.85, 1.0), 1.2, false)
	var blade := _emissive(glow, 3.0, false)
	var halo := _emissive(glow, 1.5, true)

	_cylinder(Vector3(0, 0, 0.0), 0.021, 0.24, dark)  # empunhadura
	_cylinder(Vector3(0, 0, 0.14), 0.028, 0.04, core_blue)  # pomo
	_cylinder(Vector3(0, 0, 0.17), 0.018, 0.03, silver)
	# Guarda em "D" (arco de proteção da mão).
	_box(Vector3(0, 0.055, 0.13), Vector3(0.018, 0.11, 0.018), silver)
	_box(Vector3(0, 0.1, 0.0), Vector3(0.018, 0.018, 0.27), silver)
	_box(Vector3(0, 0.06, -0.13), Vector3(0.018, 0.1, 0.018), silver)
	# Núcleo azul com sigilo.
	_box(Vector3(0, 0, -0.26), Vector3(0.08, 0.055, 0.25), core_blue)
	_box(Vector3(0, 0.029, -0.26), Vector3(0.04, 0.004, 0.12), sigil)
	_box(Vector3(0, 0, -0.395), Vector3(0.12, 0.035, 0.03), silver)  # colar
	# Lâmina bifurcada: duas pontas com fenda no meio + halo aditivo.
	var length := 0.82
	var prong := PackedVector2Array([Vector2(0.008, 0.0), Vector2(0.055, 0.06), Vector2(0.05, length * 0.65),
		Vector2(0.012, length), Vector2(0.006, length * 0.6)])
	for side: float in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for p in prong:
			points.append(Vector2(p.x * side, p.y))
		_blade_mesh(points, 0.012, Vector3(0, 0, -0.41), blade, 1.0)
		_blade_mesh(points, 0.03, Vector3(0, 0, -0.41), halo, 1.35)
	trail_base.position = Vector3(0, 0, -0.45)
	trail_tip.position = Vector3(0, 0, -0.41 - length)


# --- Presa de Fase: adaga curva laranja ------------------------------------------

func _build_phase_fang(glow: Color) -> void:
	var silver := _metal(Color(0.8, 0.82, 0.86))
	var dark := _metal(Color(0.09, 0.09, 0.1))
	var red := _emissive(Color(1.0, 0.15, 0.1), 2.0, false)
	var orange := _emissive(glow, 1.6, false)
	var halo := _emissive(glow.lerp(Color(1, 0.9, 0.3), 0.4), 0.9, true)

	_cylinder(Vector3(0, 0, 0.03), 0.022, 0.17, dark)  # empunhadura enfaixada
	for i in 3:
		_box(Vector3(0, 0.023, 0.08 - i * 0.05), Vector3(0.012, 0.006, 0.012), red)
	_cylinder(Vector3(0, 0, 0.13), 0.03, 0.03, silver)  # pomo
	_box(Vector3(0, 0, -0.07), Vector3(0.075, 0.055, 0.07), orange)  # carcaça laranja
	_box(Vector3(0, 0.029, -0.07), Vector3(0.05, 0.004, 0.04), silver)
	# Lâmina em crescente: corpo laranja + fio prateado na borda externa.
	var radius := 0.42
	var body := MeshFactory.crescent_points(radius, 0.1, -90.0, 15.0, 18)
	var edge := MeshFactory.crescent_points(radius + 0.018, 0.03, -90.0, 18.0, 18)
	var offset := Vector2(0, radius)
	_blade_mesh(_shift(body, offset), 0.014, Vector3(0, 0, -0.1), orange, 1.0)
	_blade_mesh(_shift(edge, offset), 0.01, Vector3(0, 0, -0.1), silver, 1.0)
	_blade_mesh(_shift(body, offset), 0.03, Vector3(0, 0, -0.1), halo, 1.15)
	trail_base.position = Vector3(0, 0, -0.14)
	var tip_angle := deg_to_rad(15.0)
	var tip := Vector2(cos(tip_angle), sin(tip_angle)) * radius + offset
	trail_tip.position = Vector3(tip.x, 0, -0.1 - tip.y)


# --- Peças ------------------------------------------------------------------------

func _shift(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(p + offset)
	return result


## Polígono no plano XY vira lâmina ao longo de -Z (Y do polígono → -Z), fina em Y.
func _blade_mesh(points: PackedVector2Array, depth: float, base: Vector3, material: Material,
		scale_factor: float) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = MeshFactory.extrude_polygon(points, depth)
	instance.material_override = material
	instance.position = base
	instance.rotation = Vector3(-PI * 0.5, 0, 0)
	instance.scale = Vector3(scale_factor, scale_factor, 1.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _box(pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(mesh, pos, Vector3.ZERO, material)


func _cylinder(pos: Vector3, radius: float, length: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	_add(mesh, pos, Vector3(PI * 0.5, 0, 0), material)


func _add(mesh: Mesh, pos: Vector3, rot: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	instance.material_override = material
	add_child(instance)


func _metal(color: Color) -> StandardMaterial3D:
	return _solid(color, 0.25, 0.85)


func _solid(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _emissive(color: Color, energy: float, additive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, 0.35 if additive else 1.0)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_materials.append(material)
	_base_energy.append(energy)
	return material
