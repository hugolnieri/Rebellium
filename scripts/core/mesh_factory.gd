class_name MeshFactory
extends RefCounted
## Gera malhas procedurais simples (greybox estilizado) sem assets externos.


## Extruda um polígono 2D (plano XY, sentido qualquer) com espessura `depth` em Z (centrado).
## Normais por face (arestas duras), bom para lâminas e placas.
static func extrude_polygon(points: PackedVector2Array, depth: float) -> ArrayMesh:
	var indices := Geometry2D.triangulate_polygon(points)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := depth * 0.5
	# Frente (+Z) e verso (-Z).
	for i in range(0, indices.size(), 3):
		var a := points[indices[i]]
		var b := points[indices[i + 1]]
		var c := points[indices[i + 2]]
		var ccw := (b - a).cross(c - a) > 0.0
		_tri(st, Vector3(a.x, a.y, half), Vector3(b.x, b.y, half), Vector3(c.x, c.y, half), Vector3.BACK, ccw)
		_tri(st, Vector3(a.x, a.y, -half), Vector3(b.x, b.y, -half), Vector3(c.x, c.y, -half), Vector3.FORWARD, not ccw)
	# Laterais.
	var clockwise := _signed_area(points) < 0.0
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		var edge := q - p
		var normal_2d := Vector2(edge.y, -edge.x).normalized()
		if clockwise:
			normal_2d = -normal_2d
		var n := Vector3(normal_2d.x, normal_2d.y, 0.0)
		var p0 := Vector3(p.x, p.y, half)
		var p1 := Vector3(q.x, q.y, half)
		var p2 := Vector3(q.x, q.y, -half)
		var p3 := Vector3(p.x, p.y, -half)
		_quad(st, p0, p1, p2, p3, n)
	return st.commit()


## Polígono de crescente (lua) entre dois arcos, para lâminas curvas.
## Os arcos vão de `start_deg` a `end_deg` em torno da origem; a espessura afina até a ponta.
static func crescent_points(outer_radius: float, max_width: float, start_deg: float, end_deg: float,
		segments: int) -> PackedVector2Array:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / segments
		var angle := deg_to_rad(lerpf(start_deg, end_deg, t))
		var width := max_width * sin(PI * clampf(t * 0.85 + 0.15, 0.0, 1.0)) * (1.0 - t * 0.9)
		var dir := Vector2(cos(angle), sin(angle))
		outer.append(dir * outer_radius)
		inner.append(dir * (outer_radius - maxf(width, 0.002)))
	inner.reverse()
	outer.append_array(inner)
	return outer


static func _signed_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		area += p.x * q.y - q.x * p.y
	return area * 0.5


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, keep_order: bool) -> void:
	st.set_normal(n)
	# Godot usa sentido horário como face frontal.
	if (n.z > 0.0) == keep_order:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3) -> void:
	var face_normal := (p1 - p0).cross(p3 - p0)
	st.set_normal(n)
	if face_normal.dot(n) > 0.0:
		for v: Vector3 in [p0, p3, p1, p1, p3, p2]:
			st.add_vertex(v)
	else:
		for v: Vector3 in [p0, p1, p3, p1, p2, p3]:
			st.add_vertex(v)
