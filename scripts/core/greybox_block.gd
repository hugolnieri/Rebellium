@tool
class_name GreyboxBlock
extends StaticBody3D
## Bloco de greybox: gera mesh + colisão a partir de `size`.
## Edite `size` e `surface` no inspetor; a geometria é refeita na hora.

enum Surface { FLOOR, WALL, PLATFORM, METAL, ACCENT_RED, ACCENT_VIOLET, ACCENT_BLUE, ACCENT_GREEN }

const SURFACE_COLORS: Dictionary = {
	Surface.FLOOR: [Color(0.11, 0.11, 0.12), Color(0.15, 0.15, 0.16)],
	Surface.WALL: [Color(0.22, 0.22, 0.23), Color(0.27, 0.27, 0.28)],
	Surface.PLATFORM: [Color(0.72, 0.70, 0.66), Color(0.80, 0.78, 0.74)],
	Surface.METAL: [Color(0.42, 0.44, 0.47), Color(0.48, 0.50, 0.53)],
	Surface.ACCENT_RED: [Color(0.75, 0.10, 0.12), Color(0.85, 0.15, 0.17)],
	Surface.ACCENT_VIOLET: [Color(0.45, 0.20, 0.80), Color(0.52, 0.27, 0.88)],
	Surface.ACCENT_BLUE: [Color(0.10, 0.45, 0.95), Color(0.18, 0.55, 1.0)],
	Surface.ACCENT_GREEN: [Color(0.55, 0.90, 0.10), Color(0.62, 0.97, 0.18)],
}

static var _material_cache: Dictionary = {}

@export var size: Vector3 = Vector3(4, 1, 4):
	set(value):
		size = value
		_rebuild()
@export var surface: Surface = Surface.WALL:
	set(value):
		surface = value
		_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	if _collision == null:
		_collision = CollisionShape3D.new()
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	_mesh_instance.mesh = box_mesh
	_mesh_instance.material_override = _get_material(surface)
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape


static func _get_material(kind: Surface) -> StandardMaterial3D:
	if _material_cache.has(kind):
		return _material_cache[kind]
	var colors: Array = SURFACE_COLORS[kind]
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, colors[0])
	image.set_pixel(1, 1, colors[0])
	image.set_pixel(1, 0, colors[1])
	image.set_pixel(0, 1, colors[1])
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_triplanar = true
	# Um quadrado do xadrez = 1 m: ajuda a perceber velocidade e altura.
	material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	material.roughness = 0.6 if kind == Surface.METAL else 0.9
	material.metallic = 0.5 if kind == Surface.METAL else 0.0
	if kind >= Surface.ACCENT_RED:
		material.emission_enabled = true
		material.emission = colors[1]
		material.emission_energy_multiplier = 0.4
	_material_cache[kind] = material
	return material
