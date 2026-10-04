class_name WeaponTrail
extends MeshInstance3D
## Rastro do golpe: faixa entre a base e a ponta da lâmina nos últimos quadros, sumindo.

## Quantas amostras (quadros) a faixa guarda.
const MAX_SAMPLES: int = 14

var emitting: bool = false
var color: Color = Color(0.25, 0.95, 1.0)
var source: WeaponVisual

var _bases: Array[Vector3] = []
var _tips: Array[Vector3] = []
var _immediate: ImmediateMesh
var _material: StandardMaterial3D


func _ready() -> void:
	top_level = true
	_immediate = ImmediateMesh.new()
	mesh = _immediate
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_transform = Transform3D.IDENTITY


func _process(_delta: float) -> void:
	if source != null and is_instance_valid(source) and emitting:
		_bases.push_front(source.trail_base.global_position)
		_tips.push_front(source.trail_tip.global_position)
	elif not _bases.is_empty():
		_bases.pop_back()
		_tips.pop_back()
	while _bases.size() > MAX_SAMPLES:
		_bases.pop_back()
		_tips.pop_back()
	_redraw()


func clear() -> void:
	_bases.clear()
	_tips.clear()
	_immediate.clear_surfaces()


func _redraw() -> void:
	_immediate.clear_surfaces()
	if _bases.size() < 2:
		return
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var count := _bases.size()
	for i in count:
		var fade := 1.0 - float(i) / float(count - 1)
		_immediate.surface_set_color(Color(color.r, color.g, color.b, fade * fade * 0.8))
		_immediate.surface_add_vertex(_tips[i])
		_immediate.surface_set_color(Color(color.r, color.g, color.b, fade * 0.15))
		_immediate.surface_add_vertex(_bases[i])
	_immediate.surface_end()
