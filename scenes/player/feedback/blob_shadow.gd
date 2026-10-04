extends Node3D
## Sombra redonda projetada direto abaixo do jogador: ajuda a medir altura e ponto de
## aterrissagem no ar (a sombra do sol fica de lado). Só apresentação.

## Folga para a sombra não piscar dentro do chão.
const SURFACE_OFFSET: float = 0.02

var player: Player
var _disc: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	player = get_parent() as Player
	top_level = true
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(0, 0, 0, 1)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	_material.albedo_texture = texture
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.0
	quad.orientation = PlaneMesh.FACE_Y
	_disc = MeshInstance3D.new()
	_disc.mesh = quad
	_disc.material_override = _material
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)


func _physics_process(_delta: float) -> void:
	var fb := player.feedback_config
	var from := player.global_position + Vector3.UP * SURFACE_OFFSET * 5.0
	var to := from + Vector3.DOWN * fb.shadow_max_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, player.collision_mask, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		visible = false
		return
	visible = true
	var distance := from.distance_to(hit.position)
	var k := 1.0 - clampf(distance / fb.shadow_max_distance, 0.0, 1.0)
	global_position = hit.position + hit.normal * SURFACE_OFFSET
	var radius := fb.shadow_radius * lerpf(0.6, 1.0, k)
	scale = Vector3.ONE * radius
	_material.albedo_color.a = fb.shadow_max_alpha * k
