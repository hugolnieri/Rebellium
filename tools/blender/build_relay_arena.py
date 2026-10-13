"""Gera a arena original de Touch Down "Revezamento": estação em oito com duas bases opostas.

Uso: blender --background --python tools/blender/build_relay_arena.py
     (ou python3.11 tools/blender/build_relay_arena.py com o bpy do pip)
Saídas: art/arena/relay_arena.blend e assets/arena/relay_arena.glb.
Os volumes *-convcolonly fornecem colisão convexa ao importador do Godot.
Eixos: Blender (x, y, z) -> Godot (x, z, -y).

Planta (vista de cima, Blender): o mapa é simétrico por rotação de 180° em torno do centro.
- Base vermelha (noroeste) e base azul (sudeste): um quarto de círculo com galeria coberta,
  um bloco retangular onde a ponte chega e o gol dentro do pátio. Nível alto (HIGH).
- Duas passarelas laterais (x = ±26) descem para o nível baixo por voltas em U
  (escadaria do lado de fora, rampa do lado de dentro) até a plataforma central.
- Plataforma central (x = 0, nível 0) com a composição de trânsito parada nos trilhos.
- Ponte alta (y = 0) cruza tudo por cima do trem; o núcleo fica no largo do meio da ponte.
- Escadas rolantes ligam cada passarela à plataforma central (atalho de descida/subida).
"""
import math
import os

import bpy
import bmesh  # depois do bpy: o módulo do pip só registra o bmesh ao importar o bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_BLEND = os.path.join(ROOT, "art", "arena", "relay_arena.blend")
OUT_GLB = os.path.join(ROOT, "assets", "arena", "relay_arena.glb")

HIGH = 8.0           # bases, passarelas e ponte
LOW = 0.0            # plataforma central do trem
STRIP_X = 26.0       # eixo das passarelas laterais
STRIP_W = 7.0
STRIP_END = 14.0     # onde a passarela vira a volta em U
LOOP_R = 13.0
CENTER_W = 11.0      # plataforma central
BRIDGE_W = 5.0
PLAZA = 10.0         # largo do núcleo no meio da ponte
BASE_R = 25.0
BASE_C = 22.5        # centro do quarto de círculo da base (|x|)
GALLERY_R = 19.0     # galeria coberta da base (de GALLERY_R até BASE_R)
ESCALATOR_Y = 9.0
RAIL_H = 1.1


def material(name, color, metal=0.0, glow=0.0, rough=0.46):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    if glow:
        shader.inputs["Emission Color"].default_value = (*color, 1.0)
        shader.inputs["Emission Strength"].default_value = glow
    return mat


def _link(name, mesh, mat):
    if mat:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _collider_of(obj):
    collider = obj.copy()
    collider.data = obj.data.copy()
    collider.data.materials.clear()
    collider.name = obj.name + "-convcolonly"
    bpy.context.collection.objects.link(collider)
    return collider


def hull(name, points, mat, collide=False):
    """Malha convexa a partir de pontos (cada peça de colisão precisa ser convexa)."""
    mesh = bpy.data.meshes.new(name + " mesh")
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = _link(name, mesh, mat)
    if collide:
        _collider_of(obj)
    return obj


def box(name, center, size, mat, collide=False, yaw=0.0, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = yaw
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Soft edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    if collide:
        bpy.ops.mesh.primitive_cube_add(size=1, location=center)
        col = bpy.context.object
        col.name = name + "-convcolonly"
        col.dimensions = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        col.rotation_euler.z = yaw
    return obj


def cylinder(name, center, radius, depth, mat, vertices=32, collide=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    if collide:
        _collider_of(obj)
    return obj


def beam(name, start, end, radius, mat, vertices=8):
    start, end = Vector(start), Vector(end)
    vec = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=vec.length,
                                        location=(start + end) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(vec)
    obj.data.materials.append(mat)
    return obj


def wall_between(name, a, b, bottom, height, thick, mat, collide=True, bevel=0.0):
    """Parede reta entre dois pontos do plano (base em `bottom`)."""
    a, b = Vector(a), Vector(b)
    mid = (a + b) * 0.5
    d = b - a
    return box(name, (mid.x, mid.y, bottom + height * 0.5), (d.length, thick, height), mat,
               collide=collide, yaw=math.atan2(d.y, d.x), bevel=bevel)


def rail_line(name, a, b, floor, steel, accent, height=RAIL_H):
    """Guarda-corpo baixo (colide, dá para pular por cima) com friso de luz."""
    wall_between(name, a, b, floor, height, 0.2, steel)
    a3 = Vector((a[0], a[1], floor + height + 0.04))
    b3 = Vector((b[0], b[1], floor + height + 0.04))
    wall_between(name + "_Light", a, b, floor + height, 0.08, 0.14, accent, collide=False)
    return a3, b3


def slab(name, x0, x1, y0, y1, top, mat, trim, light, thick=1.2, edges=True, collide=True):
    """Piso retangular com junta e frisos (topo em `top`)."""
    cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
    sx, sy = abs(x1 - x0), abs(y1 - y0)
    box(name, (cx, cy, top - thick * 0.5), (sx, sy, thick), mat, collide=collide, bevel=0.06)
    box(name + "_Under", (cx, cy, top - thick - 0.2), (sx - 0.4, sy - 0.4, 0.4), trim)
    if edges and light:
        long_x = sx >= sy
        for side in (-1, 1):
            if long_x:
                box(name + "_Edge%d" % side, (cx, cy + side * (sy * 0.5 - 0.15), top + 0.02),
                    (sx - 0.3, 0.12, 0.04), light)
            else:
                box(name + "_Edge%d" % side, (cx + side * (sx * 0.5 - 0.15), cy, top + 0.02),
                    (0.12, sy - 0.3, 0.04), light)


def ring_points(center, radius, angle, height):
    return (center[0] + math.cos(angle) * radius, center[1] + math.sin(angle) * radius, height)


def pie(name, center, radius, a0, a1, top, bottom, mat, segments, collide=True):
    """Fatia de disco (setor) dividida em peças convexas."""
    for index in range(segments):
        b0 = a0 + (a1 - a0) * index / segments
        b1 = a0 + (a1 - a0) * (index + 1) / segments
        pts = []
        for z in (bottom, top):
            pts.append((center[0], center[1], z))
            pts.append(ring_points(center, radius, b0, z))
            pts.append(ring_points(center, radius, b1, z))
        hull("%s_%02d" % (name, index), pts, mat, collide)


def annulus(name, center, r_in, r_out, a0, a1, h0, h1, thick, mat, segments, collide=True):
    """Anel (ou rampa em anel quando h0 != h1) em peças convexas; devolve topo por peça."""
    tops = []
    for index in range(segments):
        t0, t1 = index / segments, (index + 1) / segments
        b0, b1 = a0 + (a1 - a0) * t0, a0 + (a1 - a0) * t1
        z0, z1 = h0 + (h1 - h0) * t0, h0 + (h1 - h0) * t1
        pts = []
        for angle, z in ((b0, z0), (b1, z1)):
            for r in (r_in, r_out):
                pts.append(ring_points(center, r, angle, z))
                pts.append(ring_points(center, r, angle, min(z0, z1) - thick))
        hull("%s_%02d" % (name, index), pts, mat, collide)
        tops.append((b0, b1, z0, z1))
    return tops


def arc_wall(name, center, radius, a0, a1, bottom0, bottom1, height, thick, mat, segments,
             collide=True, light=None, skip=()):
    """Parede curva em peças; a base acompanha a rampa (bottom0 -> bottom1)."""
    for index in range(segments):
        if index in skip:
            continue
        t0, t1 = index / segments, (index + 1) / segments
        b0, b1 = a0 + (a1 - a0) * t0, a0 + (a1 - a0) * t1
        z0, z1 = bottom0 + (bottom1 - bottom0) * t0, bottom0 + (bottom1 - bottom0) * t1
        pts = []
        for angle, z in ((b0, z0), (b1, z1)):
            for r in (radius - thick * 0.5, radius + thick * 0.5):
                pts.append(ring_points(center, r, angle, z))
                pts.append(ring_points(center, r, angle, z + height))
        hull("%s_%02d" % (name, index), pts, mat, collide)
        if light:
            lp = []
            for angle, z in ((b0, z0), (b1, z1)):
                for r in (radius - thick * 0.5 - 0.02, radius + thick * 0.5 + 0.02):
                    lp.append(ring_points(center, r, angle, z + height))
                    lp.append(ring_points(center, r, angle, z + height + 0.08))
            hull("%s_Light%02d" % (name, index), lp, light)


def sloped_path(name, start, end, low, high, width, steel, trim, accent,
                steps=0, wall_height=0.0, landing=0.0):
    """Rampa convexa inclinada sob degraus visuais: transitável sem travar no espelho."""
    a, b = Vector(start), Vector(end)
    direction = (b - a).normalized()
    cross = Vector((-direction.y, direction.x))
    yaw = math.atan2(direction.y, direction.x)
    bottom = min(low, high) - 1.2
    sections = [(a, low), (b, high)]
    if landing:
        sections.append((b + direction * landing, high))
    for index in range(len(sections) - 1):
        pts = []
        for position, top in sections[index:index + 2]:
            for side in (-1, 1):
                p = position + cross * side * width * 0.5
                pts.extend(((p.x, p.y, bottom), (p.x, p.y, top)))
        hull("%s_Body%d" % (name, index), pts, steel, collide=True)
    length = (b - a).length
    count = steps if steps else max(2, round(length / 2))
    stride = length / count
    for index in range(count):
        t = (index + 0.5) / count
        p = a.lerp(b, t)
        top = low + (high - low) * t
        box(name + "_Tread%02d" % index, (p.x, p.y, top + 0.035),
            (stride - 0.04, width - 0.35, 0.07), trim, yaw=yaw)
        if steps:
            q = p + direction * stride * 0.4
            box(name + "_Nose%02d" % index, (q.x, q.y, top + 0.08),
                (0.11, width - 0.35, 0.05), accent, yaw=yaw)
    if wall_height:
        for side in (-1, 1):
            off = cross * side * (width * 0.5 + 0.12)
            pts = []
            for position, top in sections:
                p = position + off
                for s2 in (-0.12, 0.12):
                    q = p + cross * s2
                    pts.extend(((q.x, q.y, top), (q.x, q.y, top + wall_height)))
            # A balaustrada segue a inclinação: uma peça por trecho para continuar convexa.
            for index in range(len(sections) - 1):
                hull("%s_Balustrade%d_%d" % (name, side, index), pts[index * 4:index * 4 + 8],
                     trim, collide=True)
            for index in range(len(sections) - 1):
                p0 = sections[index][0] + off
                p1 = sections[index + 1][0] + off
                z0 = sections[index][1] + wall_height
                z1 = sections[index + 1][1] + wall_height
                beam("%s_Handrail%d_%d" % (name, side, index),
                     (p0.x, p0.y, z0 + 0.06), (p1.x, p1.y, z1 + 0.06), 0.07, accent)


class Team:
    """Constrói uma base; o lado azul é a rotação de 180° do vermelho (canônico: x < 0)."""

    def __init__(self, tag, sign, accent, mats):
        self.tag = tag
        self.sign = sign  # +1 vermelho (como desenhado), -1 azul (girado 180°)
        self.accent = accent
        self.m = mats

    def p(self, x, y):
        return (self.sign * x, self.sign * y)

    def p3(self, x, y, z):
        return (self.sign * x, self.sign * y, z)

    def a(self, angle):
        return angle if self.sign > 0 else angle + math.pi

    def name(self, part):
        return self.tag + part


def build_base(t):
    m = t.m
    c = t.p(-BASE_C, 0.0)
    a0, a1 = t.a(math.pi * 0.5), t.a(math.pi)
    # Pátio: quarto de círculo maciço (prédio da estação) até o nível baixo.
    pie(t.name("Court"), c, BASE_R, a0, a1, HIGH, LOW - 4.0, m["steel"], 10)
    annulus(t.name("CourtTrim"), c, BASE_R - 0.35, BASE_R + 0.15, a0, a1, HIGH + 0.03, HIGH + 0.03,
            0.06, t.accent, 20, collide=False)
    # Bloco retangular onde a ponte chega (e onde o time nasce).
    x0, x1 = sorted((t.sign * -48.0, t.sign * -(STRIP_X + STRIP_W * 0.5)))
    y0, y1 = sorted((t.sign * -6.0, 0.0))
    box(t.name("Annex"), ((x0 + x1) * 0.5, (y0 + y1) * 0.5, (HIGH + LOW - 4.0) * 0.5),
        (x1 - x0, y1 - y0, HIGH - LOW + 4.0), m["steel"], collide=True, bevel=0.08)
    for i in range(4):
        px = -46.0 + i * 4.5
        box(t.name("AnnexWindow%d" % i), (*t.p(px, -6.08), HIGH - 3.0), (3.2, 0.08, 1.6), m["glass"])
    box(t.name("AnnexStripe"), (*t.p(-38.75, -6.06), HIGH - 0.6), (18.5, 0.06, 0.25), t.accent)
    # Fachada curva com janelas e galeria coberta (o teto é alcançável com wall jump).
    arc_wall(t.name("OuterWall"), c, BASE_R - 0.25, a0, a1, HIGH, HIGH, 5.6, 0.5, m["wall"], 16,
             light=t.accent)
    arc_wall(t.name("Windows"), c, BASE_R - 0.55, a0, a1, HIGH + 1.4, HIGH + 1.4, 2.0, 0.06,
             m["glass"], 16, collide=False)
    arc_wall(t.name("Facade"), c, BASE_R + 0.05, a0, a1, LOW - 4.0, LOW - 4.0, HIGH - LOW + 4.0, 0.3,
             m["trim"], 16, collide=False)
    annulus(t.name("GalleryRoof"), c, GALLERY_R, BASE_R, a0, a1, HIGH + 5.6, HIGH + 5.6, 0.6,
            m["wall"], 12)
    annulus(t.name("GalleryRoofTrim"), c, GALLERY_R - 0.1, GALLERY_R + 0.25, a0, a1,
            HIGH + 5.0, HIGH + 5.0, 0.12, t.accent, 12, collide=False)
    for i in range(7):
        ang = a0 + (a1 - a0) * (i + 0.5) / 7
        x, y, _ = ring_points(c, GALLERY_R + 0.3, ang, 0)
        box(t.name("GalleryColumn%d" % i), (x, y, HIGH + 2.7), (0.55, 0.55, 5.4), m["rail"],
            collide=True, yaw=ang)
        box(t.name("GalleryColumnLight%d" % i), (x, y, HIGH + 3.4), (0.6, 0.6, 0.12), t.accent, yaw=ang)
    # Parede dos fundos do bloco e guarda-corpos.
    wall_between(t.name("AnnexBack"), t.p(-48.0, -6.0), t.p(-48.0, 0.0), HIGH, 4.2, 0.5, m["wall"])
    rail_line(t.name("AnnexRail"), t.p(-48.0, -6.0), t.p(-(STRIP_X + STRIP_W * 0.5), -6.0),
              HIGH, m["rail"], t.accent)
    # Borda leste do pátio voltada ao vazio: aberturas para a ponte e a escada rolante.
    ex = -(BASE_C)
    for ya, yb in ((BRIDGE_W * 0.5, ESCALATOR_Y - 2.4), (ESCALATOR_Y + 2.4, BASE_R)):
        rail_line(t.name("CourtRail_%d" % int(ya)), t.p(ex, ya), t.p(ex, yb), HIGH, m["rail"], t.accent)
    # Balcão curvo protege o gol da entrada direta pela ponte (cobertura de 1,3 m).
    arc_wall(t.name("Counter"), c, 8.0, t.a(math.radians(108)), t.a(math.radians(162)),
             HIGH, HIGH, 1.3, 0.8, m["trim"], 6, light=t.accent)
    # Gol: plataforma luminosa no pátio, com pórtico.
    gx, gy = t.p(*GOAL_XY)
    cylinder(t.name("GoalPad"), (gx, gy, HIGH + 0.04), 3.0, 0.08, m["trim"], 40)
    cylinder(t.name("GoalRing"), (gx, gy, HIGH + 0.09), 2.6, 0.04, t.accent, 40)
    cylinder(t.name("GoalCore"), (gx, gy, HIGH + 0.11), 1.0, 0.04, t.accent, 24)
    gate_yaw = t.a(math.radians(135)) + math.pi * 0.5
    tangent = Vector((math.cos(gate_yaw), math.sin(gate_yaw)))
    for side in (-1, 1):
        q = Vector((gx, gy)) + tangent * side * 3.4
        box(t.name("GoalPillar%d" % side), (q.x, q.y, HIGH + 2.4), (0.7, 0.7, 4.8), m["rail"],
            collide=True, yaw=gate_yaw)
        box(t.name("GoalPillarLight%d" % side), (q.x, q.y, HIGH + 2.8), (0.76, 0.76, 0.14), t.accent,
            yaw=gate_yaw)
    box(t.name("GoalHeader"), (gx, gy, HIGH + 5.0), (7.6, 0.8, 0.5), m["rail"], yaw=gate_yaw)
    box(t.name("GoalHeaderLight"), (gx, gy, HIGH + 5.1), (7.4, 0.9, 0.1), t.accent, yaw=gate_yaw)
    # Cobertura no spawn (bancos) e placa do time.
    for i, (bx, by) in enumerate(((-43.0, -2.2), (-35.0, -4.2))):
        box(t.name("SpawnCover%d" % i), (*t.p(bx, by), HIGH + 0.7), (2.8, 1.0, 1.4), m["trim"],
            collide=True, bevel=0.08)
    for i, ang in enumerate((math.radians(100), math.radians(170))):
        x, y, _ = ring_points(c, BASE_R + 1.2, t.a(ang), 0)
        box(t.name("SignalTower%d" % i), (x, y, HIGH + 3.0), (0.6, 0.6, 22.0), m["rail"])
        cylinder(t.name("SignalLamp%d" % i), (x, y, HIGH + 14.2), 0.4, 0.4, t.accent)


GOAL_XY = (-BASE_C + 14.0 * math.cos(math.radians(135)), 14.0 * math.sin(math.radians(135)))


def build_strip(t):
    """Passarela lateral alta e volta em U até a plataforma central."""
    m = t.m
    x0, x1 = -(STRIP_X + STRIP_W * 0.5), -(STRIP_X - STRIP_W * 0.5)
    p0, p1 = t.p(x0, -STRIP_END), t.p(x1, 0.0)
    slab(t.name("Walkway"), min(p0[0], p1[0]), max(p0[0], p1[0]), min(p0[1], p1[1]),
         max(p0[1], p1[1]), HIGH, m["steel"], m["trim"], t.accent)
    rail_line(t.name("WalkwayRailOut"), t.p(x0, -STRIP_END), t.p(x0, -6.0), HIGH, m["rail"], t.accent)
    rail_line(t.name("WalkwayRailIn"), t.p(x1, -STRIP_END), t.p(x1, -BRIDGE_W * 0.5), HIGH,
              m["rail"], t.accent)
    for y in (-4.0, -11.0):
        box(t.name("WalkwayPier%d" % int(y)), (*t.p(-STRIP_X, y), (HIGH + LOW - 10.0) * 0.5),
            (2.2, 2.2, HIGH - LOW + 10.0), m["trim"], collide=True)
    # Volta em U: o lado de fora é escadaria, o de dentro é rampa lisa (mesma inclinação).
    c = t.p(-LOOP_R, -STRIP_END)
    a0, a1 = t.a(math.pi), t.a(2.0 * math.pi)
    r_in, r_out = LOOP_R - STRIP_W * 0.5, LOOP_R + STRIP_W * 0.5
    segments = 28
    annulus(t.name("Loop"), c, r_in, r_out, a0, a1, HIGH, LOW, 1.1, m["steel"], segments)
    for index in range(segments * 2):
        u0, u1 = index / (segments * 2), (index + 1) / (segments * 2)
        b0, b1 = a0 + (a1 - a0) * u0, a0 + (a1 - a0) * u1
        z = HIGH + (LOW - HIGH) * (u0 + u1) * 0.5
        pts = []
        for ang in (b0 + 0.004, b1 - 0.004):
            for r in (LOOP_R + 0.1, r_out - 0.2):
                pts.append(ring_points(c, r, ang, z + 0.0))
                pts.append(ring_points(c, r, ang, z + 0.07))
        hull(t.name("LoopTread%02d" % index), pts, m["trim"])
        nose = []
        for r in (LOOP_R + 0.1, r_out - 0.2):
            for dz in (0.07, 0.11):
                nose.append(ring_points(c, r, b1 - 0.004, z + dz))
                nose.append(ring_points(c, r, b1 - 0.018, z + dz))
        hull(t.name("LoopNose%02d" % index), nose, t.accent)
    annulus(t.name("LoopSplit"), c, LOOP_R - 0.06, LOOP_R + 0.06, a0, a1, HIGH + 0.03, LOW + 0.03,
            0.02, t.accent, segments, collide=False)
    # Fora: tela alta (boa para wall jump); dentro: mureta baixa.
    arc_wall(t.name("LoopFence"), c, r_out + 0.15, a0, a1, HIGH, LOW, 2.6, 0.3, m["fence"], segments,
             light=t.accent)
    arc_wall(t.name("LoopInnerWall"), c, r_in - 0.2, a0, a1, HIGH, LOW, 1.2, 0.4, m["wall"], segments,
             light=t.accent)
    for i in range(1, 6):
        ang = a0 + (a1 - a0) * i / 6
        x, y, _ = ring_points(c, LOOP_R, ang, 0)
        top = HIGH + (LOW - HIGH) * i / 6
        box(t.name("LoopPier%d" % i), (x, y, (top - 1.1 + LOW - 10.0) * 0.5),
            (1.8, 1.8, top - 1.1 - LOW + 10.0), m["trim"], yaw=ang)
    # Painel luminoso sobre a curva (parede alta para saltos).
    mid = a0 + (a1 - a0) * 0.5
    px, py, _ = ring_points(c, r_out + 1.0, mid, 0)
    zmid = (HIGH + LOW) * 0.5
    box(t.name("Billboard"), (px, py, zmid + 5.0), (11.0, 0.4, 4.6), m["trim"], collide=True,
        yaw=mid + math.pi * 0.5)
    sx, sy, _ = ring_points(c, r_out + 0.75, mid, 0)
    box(t.name("BillboardScreen"), (sx, sy, zmid + 5.0), (10.2, 0.08, 3.8), m["screen"],
        yaw=mid + math.pi * 0.5)
    for side in (-1, 1):
        ang = mid + side * 0.2
        x, y, _ = ring_points(c, r_out + 1.0, ang, 0)
        box(t.name("BillboardLeg%d" % side), (x, y, (zmid + 2.7 + LOW - 10.0) * 0.5),
            (0.4, 0.4, zmid + 2.7 - LOW + 10.0), m["rail"], yaw=mid)
    # Escada rolante: da passarela (alto) até a plataforma central (baixo).
    sloped_path(t.name("Escalator"), t.p(-(BASE_C), ESCALATOR_Y), t.p(-(CENTER_W * 0.5), ESCALATOR_Y),
                HIGH, LOW, 4.4, m["steel"], m["trim"], t.accent, steps=22, wall_height=1.2, landing=1.5)
    # Linha aérea (decorativa, sem colisão): postes em T ao longo da passarela e da volta.
    pts = []
    for i in range(6):
        y = 22.0 - i * 7.2
        pts.append(t.p3(-STRIP_X, y, HIGH + 7.0))
    for i in range(1, 13):
        ang = a0 + (a1 - a0) * i / 12
        x, y, _ = ring_points(c, LOOP_R - 1.5, ang, 0)
        pts.append((x, y, HIGH + 7.0 - (HIGH + 7.0 - (LOW + 6.5)) * i / 12))
    for i in range(len(pts) - 1):
        beam(t.name("Monorail%02d" % i), pts[i], pts[i + 1], 0.18, m["rail"])
    for i in (3, 4, 5):
        x, y, z = pts[i]
        post = t.p(-(STRIP_X + STRIP_W * 0.5 + 0.6), t.sign * y)
        box(t.name("CatenaryPost%d" % i), (post[0], post[1], (LOW - 4.0 + z) * 0.5), (0.35, 0.35, z - LOW + 4.0),
            m["rail"], collide=True)
        beam(t.name("CatenaryArm%d" % i), (post[0], post[1], z), (x, y, z), 0.1, m["rail"])
        box(t.name("CatenaryLamp%d" % i), (x, y, z - 0.25), (1.6, 0.4, 0.12), t.accent)


def build_center(mats):
    m = mats
    h = CENTER_W * 0.5
    slab("Platform", -h, h, -STRIP_END, STRIP_END, LOW, m["steel"], m["trim"], m["violet"])
    for y in (-8.0, 0.0, 8.0):
        box("PlatformPier%d" % int(y), (0, y, (LOW - 1.2 + LOW - 10.0) * 0.5), (3.0, 3.0, 8.8),
            m["trim"])
    # Trilhos e composição de trânsito (o teto do trem é um piso a 3,9 m).
    for x in (-0.75, 0.75):
        box("TrackRail%d" % int(x * 10), (x, 0, LOW + 0.06), (0.12, STRIP_END * 2, 0.12), m["rail"])
    for i in range(-13, 14, 2):
        box("TrackTie%d" % i, (0, i, LOW + 0.02), (2.2, 0.3, 0.04), m["trim"])
    length, width, top = 22.0, 3.4, LOW + 3.9
    box("TrainBody", (0, 0, (LOW + 0.45 + top) * 0.5), (width, length, top - LOW - 0.45),
        m["pale"], collide=True, bevel=0.15)
    box("TrainSkirt", (0, 0, LOW + 0.3), (width - 0.4, length - 1.0, 0.5), m["trim"], collide=True)
    for side in (-1, 1):
        box("TrainStripe%d" % side, (side * (width * 0.5 + 0.01), 0, LOW + 1.25),
            (0.04, length - 1.0, 0.18), m["red"])
        box("TrainWindows%d" % side, (side * (width * 0.5 + 0.01), 0, LOW + 2.45),
            (0.04, length - 3.0, 0.9), m["glass"])
        for d in (-6.0, 0.0, 6.0):
            box("TrainDoor%d_%d" % (side, int(d)), (side * (width * 0.5 + 0.02), d, LOW + 1.9),
                (0.04, 1.6, 2.6), m["trim"])
    for end in (-1, 1):
        y = end * (length * 0.5)
        hull("TrainNose%d" % end, [
            (-width * 0.5, y, LOW + 0.45), (width * 0.5, y, LOW + 0.45),
            (-width * 0.5, y, top), (width * 0.5, y, top),
            (-width * 0.4, y + end * 1.6, LOW + 0.45), (width * 0.4, y + end * 1.6, LOW + 0.45),
            (-width * 0.36, y + end * 1.2, LOW + 2.6), (width * 0.36, y + end * 1.2, LOW + 2.6),
            (-width * 0.3, y + end * 0.5, top - 0.1), (width * 0.3, y + end * 0.5, top - 0.1),
        ], m["pale"], collide=True)
        box("TrainHeadlight%d" % end, (0, y + end * 1.45, LOW + 1.25), (2.2, 0.06, 0.18), m["red"])
        box("TrainCab%d" % end, (0, y + end * 0.95, LOW + 2.75), (2.4, 0.06, 0.9), m["glass"],
            yaw=0.0)
    for y in (-6.0, 6.0):
        box("Pantograph%d" % int(y), (0, y, top + 0.15), (1.6, 1.0, 0.3), m["trim"])
        beam("PantographArm%d" % int(y), (0, y - 0.3, top + 0.3), (0, y + 0.6, top + 1.5), 0.05, m["rail"])
        box("PantographShoe%d" % int(y), (0, y + 0.6, top + 1.55), (1.8, 0.12, 0.06), m["rail"])
    # Guarda-corpos da plataforma com aberturas nas escadas rolantes e nas pontas.
    for side in (-1, 1):
        x = side * h
        gap = -side * ESCALATOR_Y  # vermelho chega em y = +9 do lado oeste; azul em y = -9 do leste
        for ya, yb in ((-STRIP_END + 3.0, gap - 2.4), (gap + 2.4, STRIP_END - 3.0)):
            if yb - ya > 0.5:
                rail_line("PlatformRail%d_%d" % (side, int(ya)), (x, ya), (x, yb), LOW, m["rail"],
                          m["violet"])
    # Chegada das voltas em U: escadas largas dos dois lados do trilho (visual).
    for end in (-1, 1):
        for i in range(4):
            y = end * (STRIP_END - 0.4 - i * 0.7)
            box("PlatformStep%d_%d" % (end, i), (0, y, LOW + 0.03), (CENTER_W - 0.6, 0.08, 0.05),
                m["violet"] if i == 0 else m["trim"])


def build_bridge(mats):
    m = mats
    hx = BASE_C
    hw = BRIDGE_W * 0.5
    slab("Bridge", -hx, hx, -hw, hw, HIGH, m["steel"], m["trim"], m["violet"])
    for side in (-1, 1):
        y0, y1 = sorted((side * hw, side * PLAZA * 0.5))
        slab("CorePlaza%d" % side, -PLAZA * 0.5, PLAZA * 0.5, y0, y1, HIGH, m["steel"], m["trim"], None,
             edges=False)
    for side in (-1, 1):
        for xa, xb in ((-hx + 1.0, -PLAZA * 0.5), (PLAZA * 0.5, hx - 1.0)):
            rail_line("BridgeRail%d_%d" % (side, int(xa)), (xa, side * hw), (xb, side * hw), HIGH,
                      m["rail"], m["violet"])
        # O largo tem guarda-corpo só nas quinas: o meio é aberto para cair no teto do trem.
        for xa, xb in ((-PLAZA * 0.5, -1.8), (1.8, PLAZA * 0.5)):
            rail_line("PlazaRail%d_%d" % (side, int(xa)), (xa, side * PLAZA * 0.5),
                      (xb, side * PLAZA * 0.5), HIGH, m["rail"], m["violet"])
        for ya, yb in ((hw, PLAZA * 0.5),):
            rail_line("PlazaRailSide%d" % side, (side * PLAZA * 0.5, ya), (side * PLAZA * 0.5, yb),
                      HIGH, m["rail"], m["violet"])
            rail_line("PlazaRailSideB%d" % side, (side * PLAZA * 0.5, -yb), (side * PLAZA * 0.5, -ya),
                      HIGH, m["rail"], m["violet"])
    # Pilares e arcos sob a ponte, com faixas de sinalização.
    for x in (-12.5, 12.5):
        box("BridgePier%d" % int(x), (x, 0, (HIGH - 1.2 + LOW - 12.0) * 0.5),
            (2.4, 2.6, HIGH - 1.2 - LOW + 12.0), m["wall"], collide=True, bevel=0.1)
        for d in (-1, 1):
            hull("BridgeHaunch%d_%d" % (int(x), d), [
                (x + d * 1.2, -1.3, HIGH - 1.2), (x + d * 1.2, 1.3, HIGH - 1.2),
                (x + d * 5.5, -1.3, HIGH - 1.2), (x + d * 5.5, 1.3, HIGH - 1.2),
                (x + d * 1.2, -1.3, HIGH - 4.0), (x + d * 1.2, 1.3, HIGH - 4.0),
            ], m["wall"])
            for s in (-1, 1):
                box("BridgeChevron%d_%d_%d" % (int(x), d, s), (x + d * 2.6, s * 1.32, HIGH - 2.1),
                    (1.4, 0.04, 0.16), m["amber"], yaw=0.0)
    # Núcleo: pedestal no centro do largo (a esfera de verdade é a Area3D do Godot).
    cylinder("CoreBase", (0, 0, HIGH + 0.08), 2.35, 0.16, m["trim"])
    cylinder("CoreRing", (0, 0, HIGH + 0.18), 1.75, 0.06, m["violet"])
    cylinder("CorePedestal", (0, 0, HIGH + 0.25), 0.7, 0.3, m["pale"])


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {
        "steel": material("Station deck", (0.62, 0.64, 0.66), metal=0.15, rough=0.6),
        "wall": material("Station concrete", (0.46, 0.48, 0.52), metal=0.05, rough=0.7),
        "trim": material("Dark titanium", (0.06, 0.075, 0.1), metal=0.8),
        "rail": material("Guard rail", (0.22, 0.25, 0.3), metal=0.7),
        "fence": material("Mesh fence", (0.16, 0.19, 0.24), metal=0.6),
        "pale": material("Transit white", (0.86, 0.87, 0.88), metal=0.2, rough=0.35),
        "glass": material("Transit glass", (0.08, 0.22, 0.33), metal=0.35, glow=0.6, rough=0.1),
        "screen": material("Ad screen", (0.3, 0.75, 1.0), glow=2.2),
        "violet": material("Neutral core", (0.78, 0.27, 1.0), glow=3.5),
        "amber": material("Signal amber", (1.0, 0.72, 0.12), glow=2.5),
        "red": material("Train stripe", (1.0, 0.11, 0.18), glow=1.5),
    }
    red = material("Crimson team", (1.0, 0.11, 0.23), glow=3.0)
    blue = material("Azure team", (0.025, 0.57, 1.0), glow=3.0)
    for team in (Team("Crimson", 1, red, mats), Team("Azure", -1, blue, mats)):
        build_base(team)
        build_strip(team)
    build_center(mats)
    build_bridge(mats)

    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_yup=True,
                              export_apply=True, export_extras=False, export_animations=False)
    print("[relay_arena]", OUT_BLEND, OUT_GLB, flush=True)


if __name__ == "__main__":
    build()
