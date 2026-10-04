class_name ConfigIO
extends RefCounted
## Salva Resources de configuração escrevendo TODAS as propriedades exportadas
## (o ResourceSaver padrão omite valores iguais ao padrão, o que esconde números no .tres).


static func save_full(resource: Resource, path: String = "") -> Error:
	var target := path if path != "" else resource.resource_path
	if target == "":
		return ERR_FILE_BAD_PATH
	var script := resource.get_script() as Script
	var lines: PackedStringArray = [
		'[gd_resource type="Resource" script_class="%s" format=3]' % script.get_global_name(),
		"",
		'[ext_resource type="Script" path="%s" id="1"]' % script.resource_path,
		"",
		"[resource]",
		'script = ExtResource("1")',
	]
	for property in get_editable_properties(resource):
		lines.append("%s = %s" % [property.name, var_to_str(resource.get(property.name))])
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return OK


## Propriedades @export do script (inclui marcadores de grupo com usage GROUP se `with_groups`).
static func get_editable_properties(resource: Resource, with_groups: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for property in resource.get_property_list():
		var usage: int = property.usage
		if with_groups and usage & PROPERTY_USAGE_GROUP:
			result.append(property)
		elif usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			result.append(property)
	return result


## Copia todas as propriedades exportadas de `source` para `target` (recarregar / padrões).
static func copy_properties(source: Resource, target: Resource) -> void:
	for property in get_editable_properties(source):
		target.set(property.name, source.get(property.name))
	target.emit_changed()
