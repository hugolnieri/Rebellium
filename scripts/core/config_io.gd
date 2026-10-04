class_name ConfigIO
extends RefCounted
## Salva Resources de configuração escrevendo TODAS as propriedades exportadas
## (o ResourceSaver padrão omite valores iguais ao padrão, o que esconde números no .tres).
## Sub-recursos salvos em arquivo próprio (ex.: golpes de uma arma) viram ExtResource.


static func save_full(resource: Resource, path: String = "") -> Error:
	var target := path if path != "" else resource.resource_path
	if target == "":
		return ERR_FILE_BAD_PATH
	var script := resource.get_script() as Script
	var ext_ids: Dictionary = {}  # resource_path -> id
	var ext_lines: PackedStringArray = ['[ext_resource type="Script" path="%s" id="1"]' % script.resource_path]
	var body: PackedStringArray = ["[resource]", 'script = ExtResource("1")']
	for property in get_editable_properties(resource):
		var value: Variant = resource.get(property.name)
		body.append("%s = %s" % [property.name, _value_to_str(value, ext_ids, ext_lines)])
	var lines: PackedStringArray = [
		'[gd_resource type="Resource" script_class="%s" format=3]' % script.get_global_name(), ""]
	lines.append_array(ext_lines)
	lines.append("")
	lines.append_array(body)
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return OK


## Salva o recurso e, recursivamente, os sub-recursos que têm arquivo próprio.
static func save_tree(resource: Resource) -> Error:
	for child in get_file_subresources(resource):
		var err := save_tree(child)
		if err != OK:
			return err
	return save_full(resource)


## Sub-recursos (propriedades ou arrays) que vivem em arquivo próprio.
static func get_file_subresources(resource: Resource) -> Array[Resource]:
	var result: Array[Resource] = []
	for property in get_editable_properties(resource):
		var value: Variant = resource.get(property.name)
		if value is Resource and _is_file_resource(value):
			result.append(value)
		elif value is Array:
			for item: Variant in value:
				if item is Resource and _is_file_resource(item):
					result.append(item)
	return result


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
## Sub-recursos em arquivo próprio são mantidos (cada um é recarregado separadamente).
static func copy_properties(source: Resource, target: Resource) -> void:
	for property in get_editable_properties(source):
		var value: Variant = source.get(property.name)
		if value is Resource or value is Array:
			continue
		target.set(property.name, value)
	target.emit_changed()


static func _is_file_resource(resource: Resource) -> bool:
	return resource.resource_path != "" and not resource.resource_path.contains("::")


static func _value_to_str(value: Variant, ext_ids: Dictionary, ext_lines: PackedStringArray) -> String:
	if value is Resource and _is_file_resource(value):
		return 'ExtResource("%s")' % _ext_id(value, ext_ids, ext_lines)
	if value is Array:
		var items: PackedStringArray = []
		for item: Variant in value:
			items.append(_value_to_str(item, ext_ids, ext_lines))
		var typed := ""
		var array := value as Array
		if array.is_typed() and array.get_typed_script() != null:
			typed = "Array[ExtResource(\"%s\")]" % _script_ext_id(array.get_typed_script(), ext_ids, ext_lines)
			return "%s([%s])" % [typed, ", ".join(items)]
		return "[%s]" % ", ".join(items)
	if value == null:
		return "null"
	return var_to_str(value)


static func _ext_id(resource: Resource, ext_ids: Dictionary, ext_lines: PackedStringArray) -> String:
	if not ext_ids.has(resource.resource_path):
		var id := str(ext_lines.size() + 1)
		ext_ids[resource.resource_path] = id
		ext_lines.append('[ext_resource type="Resource" path="%s" id="%s"]' % [resource.resource_path, id])
	return ext_ids[resource.resource_path]


static func _script_ext_id(script: Script, ext_ids: Dictionary, ext_lines: PackedStringArray) -> String:
	if not ext_ids.has(script.resource_path):
		var id := str(ext_lines.size() + 1)
		ext_ids[script.resource_path] = id
		ext_lines.append('[ext_resource type="Script" path="%s" id="%s"]' % [script.resource_path, id])
	return ext_ids[script.resource_path]
