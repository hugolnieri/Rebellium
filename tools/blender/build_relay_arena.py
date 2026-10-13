"""Gera a arena original de Touch Down: duas bases, núcleo central e duas rotas laterais.

Uso: blender --background --python tools/blender/build_relay_arena.py
Saídas: art/arena/relay_arena.blend e assets/arena/relay_arena.glb.
Os volumes *-convcolonly fornecem colisão convexa ao importador do Godot.
Eixos: Blender (x, y, z) -> Godot (x, z, -y).
"""
import math
import os

import bpy

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_BLEND = os.path.join(ROOT, "art", "arena", "relay_arena.blend")
OUT_GLB = os.path.join(ROOT, "assets", "arena", "relay_arena.glb")


def material(name, color, metal=0.0, glow=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = 0.46
    if glow:
        shader.inputs["Emission Color"].default_value = (*color, 1.0)
        shader.inputs["Emission Strength"].default_value = glow
    return mat


def box(name, center, size, mat, collide=False, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Soft metal edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    if collide:
        bpy.ops.mesh.primitive_cube_add(size=1, location=center)
        col = bpy.context.object
        col.name = name + "-convcolonly"
        col.dimensions = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def cylinder(name, center, radius, depth, mat, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def beam(name, start, end, radius, mat):
    midpoint = tuple((start[i] + end[i]) * 0.5 for i in range(3))
    vec = tuple(end[i] - start[i] for i in range(3))
    length = math.sqrt(sum(v * v for v in vec))
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=length, location=midpoint)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    from mathutils import Vector
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(vec))
    obj.data.materials.append(mat)
    return obj


def deck(name, x, y, length, width, steel, trim, light, height=0.0):
    box(name, (x, y, height - 0.55), (length, width, 1.1),
        steel, collide=True, bevel=0.08)
    box(name + "_Underframe", (x, y, height - 1.3),
        (length - 0.4, width - 0.4, 0.4), trim, bevel=0.04)
    for side in (-1, 1):
        box(name + "_Edge%d" % side, (x, y + side * (width / 2 - 0.12), height + 0.025),
            (length - 0.25, 0.12, 0.05), light)
    for offset in range(-int(length // 2) + 3, int(length // 2), 4):
        box(name + "_Joint%d" % offset, (x + offset, y, height + 0.014),
            (0.035, width - 0.3, 0.025), trim)


def lane_rail(name, x, y, length, steel, accent, height=0.0):
    box(name, (x, y, height + 0.62), (length, 0.22, 1.24),
        steel, collide=True, bevel=0.04)
    box(name + "_Light", (x, y, height + 1.27), (length, 0.14, 0.08), accent)


def base_arch(name, x, y, color, steel, height):
    for offset in (-3.3, 3.3):
        box(name + "_Pillar_%d" % int(offset), (x + offset, y, height + 2.5),
            (0.72, 0.72, 5.0), steel, collide=True)
        box(name + "_PillarLight_%d" % int(offset),
            (x + offset, y, height + 2.8), (0.80, 0.76, 0.12), color)
    box(name + "_Header", (x, y, height + 5.2), (7.4, 0.9, 0.65), steel)
    box(name + "_HeaderLight", (x, y, height + 5.3), (7.2, 1.0, 0.1), color)
    cylinder(name + "_Beacon", (x, y, height + 5.8), 0.62, 0.24, color)


def sloped_path(name, start, end, low, high, width, steel, trim, accent,
                steps=0, wall_height=0.0, landing=0.0):
    """Piso convexo inclinado sob degraus visuais: transitável sem travar no espelho."""
    from mathutils import Vector
    a, b = Vector(start), Vector(end)
    direction = (b - a).normalized()
    cross = Vector((-direction.y, direction.x))
    bottom = min(low, high) - 1.1
    sections = [(a, low), (b, high)]
    if landing:
        sections.append((b + direction * landing, high))
    corners = []
    for position, top in sections:
        for side in (-1, 1):
            p = position + cross * side * width * 0.5
            corners.extend(((p.x, p.y, bottom), (p.x, p.y, top)))
    last = 4 * (len(sections) - 1)
    faces = [(0, 2, 3, 1), (last, last + 1, last + 3, last + 2)]
    for index in range(len(sections) - 1):
        i = index * 4
        j = i + 4
        faces.extend(((i, i + 1, j + 1, j), (i + 2, j + 2, j + 3, i + 3),
                      (i + 1, i + 3, j + 3, j + 1), (i, j, j + 2, i + 2)))
    mesh = bpy.data.meshes.new(name + " mesh")
    mesh.from_pydata(corners, [], faces)
    mesh.materials.append(steel)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    collider = obj.copy()
    collider.data = obj.data.copy()
    collider.name = name + "-convcolonly"
    bpy.context.collection.objects.link(collider)
    length = (b - a).length
    count = steps if steps else max(2, round(length / 2))
    for index in range(count):
        t = (index + 0.5) / count
        p = a.lerp(b, t)
        top = low + (high - low) * t
        stride = length / count
        tread = box(name + "_Tread%02d" % index, (p.x, p.y, top + 0.035),
                    (stride - 0.04, width - 0.35, 0.07),
                    trim if steps else steel, bevel=0.02)
        tread.rotation_euler.z = math.atan2(direction.y, direction.x)
        if steps:
            nose = box(name + "_Nose%02d" % index,
                       (p.x + direction.x * stride * 0.4,
                        p.y + direction.y * stride * 0.4, top + 0.08),
                       (0.11, width - 0.35, 0.05), accent)
            nose.rotation_euler.z = tread.rotation_euler.z
    if landing:
        p = b + direction * landing * 0.5
        platform = box(name + "_Landing", (p.x, p.y, high + 0.025),
                       (landing, width - 0.35, 0.05), trim)
        platform.rotation_euler.z = math.atan2(direction.y, direction.x)
    if wall_height:
        for side in (-1, 1):
            for index in range(count):
                t = (index + 0.5) / count
                p = a.lerp(b, t) + cross * side * (width * 0.5 + 0.13)
                top = low + (high - low) * t
                panel = box(name + "_JumpWall_%d_%02d" % (side, index),
                            (p.x, p.y, top + wall_height * 0.5),
                            (length / count - 0.02, 0.22, wall_height),
                            trim, collide=True, bevel=0.03)
                panel.rotation_euler.z = math.atan2(direction.y, direction.x)
                bpy.data.objects[panel.name + "-convcolonly"].rotation_euler.z = panel.rotation_euler.z
                light = box(name + "_WallLight_%d_%02d" % (side, index),
                            (p.x, p.y, top + wall_height + 0.04),
                            (length / count - 0.05, 0.13, 0.08), accent)
                light.rotation_euler.z = panel.rotation_euler.z


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    steel = material("Graphite panels", (0.075, 0.105, 0.15), metal=0.75)
    trim = material("Dark titanium", (0.025, 0.038, 0.06), metal=0.85)
    rail = material("Guard rail", (0.17, 0.21, 0.26), metal=0.7)
    blue = material("Azure team", (0.025, 0.57, 1.0), glow=3.0)
    red = material("Crimson team", (1.0, 0.11, 0.23), glow=3.0)
    violet = material("Neutral core", (0.78, 0.27, 1.0), glow=3.5)
    pale = material("Deck numbers", (0.63, 0.7, 0.73), metal=0.3)

    station_height = 2.4
    # A estação fica elevada. As alas formam rotas de combate curtas em torno do núcleo.
    deck("CentralStation", 0, 0, 20, 10, steel, trim, violet, station_height)
    deck("CorePlaza", 0, 0, 9, 13, steel, trim, violet, station_height)
    for side in (-1, 1):
        tag = "North" if side < 0 else "South"
        deck(tag + "StationWing", 0, side * 10, 23, 4.5,
             steel, trim, violet, station_height)
        for end in (-1, 1):
            deck(tag + ("Blue" if end < 0 else "Red") + "Connector",
                 end * 8, side * 6.8, 4.5, 7.2,
                 steel, trim, violet, station_height)
        lane_rail(tag + "OuterGuard", 0, side * 12.2, 22.5,
                  rail, violet, station_height)

    # Cada lado espelha spawn baixo -> rampa -> escadaria -> estação.
    # O gol fica acima e ao lado do spawn, acessível por uma segunda escadaria.
    for tag, side, accent in (("Azure", -1, blue), ("Crimson", 1, red)):
        spawn_x = side * 38
        deck(tag + "Spawn", spawn_x, 0, 10, 12, steel, trim, accent)
        sloped_path(tag + "ExitRamp", (side * 33, 0), (side * 24, 0),
                    0.0, 0.7, 7.2, steel, trim, accent, wall_height=1.15)
        sloped_path(tag + "StationStairs", (side * 24, 0), (side * 10, 0),
                    0.7, station_height, 7.2, steel, trim, accent,
                    steps=12, wall_height=2.15)
        deck(tag + "GoalDeck", spawn_x, -14, 10, 8, steel, trim,
             accent, station_height)
        sloped_path(tag + "GoalStairs", (spawn_x, -3), (spawn_x, -9.5),
                    0.0, station_height + 0.2, 7.2, steel, trim, accent,
                    steps=12, wall_height=2.15, landing=2.0)
        base_arch(tag + "Goal", spawn_x, -14, accent, rail, station_height)
        for x_offset in (-2.0, 2.0):
            cylinder(tag + "GoalDisc%d" % x_offset,
                     (spawn_x + x_offset, -14, station_height + 0.05),
                     0.55, 0.10, accent)
        box(tag + "BackStop", (spawn_x, -18.1, station_height + 1.2),
            (10, 0.24, 2.4), rail, collide=True)
        # A parede lateral da escada é uma superfície de wall jump de verdade.
        for offset in (-3.9, 3.9):
            box(tag + "GoalWall_%d" % offset,
                (spawn_x + offset, -14, station_height + 1.15),
                (0.35, 7.5, 2.3), rail, collide=True, bevel=0.04)
        box(tag + "SpawnOuterWall", (spawn_x, 5.0, 1.2),
            (7.5, 0.35, 2.4), rail, collide=True, bevel=0.04)
    # Plataforma e moldura do núcleo na mesma altura do piso central.
    cylinder("CoreBase", (0, 0, station_height + 0.08), 2.35, 0.16, trim)
    cylinder("CoreRing", (0, 0, station_height + 0.18), 1.75, 0.08, violet)
    cylinder("CorePedestal", (0, 0, station_height + 0.30), 0.6, 0.44, pale)
    for x in (-8, 8):
        for y in (-10, 10):
            beam("UnderTruss_%d_%d" % (x, y), (x, y, station_height - 1.4),
                 (x + (3 if x < 0 else -3), y, -5.0), 0.16, rail)
    for x in (-37, 37):
        for y in (-21, 8):
            box("SignalTower_%d_%d" % (x, y), (x, y, 3.9),
                (0.65, 0.65, 7.8), rail)
            cylinder("SignalLamp_%d_%d" % (x, y), (x, y, 8.0), 0.34, 0.30,
                     blue if x < 0 else red)
    for side in (-1, 1):
        beam("CoreSuspension_%d_A" % side, (-7, side * 10, 5.0),
             (0, side * 5, 8.0), 0.16, rail)
        beam("CoreSuspension_%d_B" % side, (7, side * 10, 5.0),
             (0, side * 5, 8.0), 0.16, rail)

    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_yup=True,
                              export_apply=True, export_extras=False, export_animations=False)
    print("[relay_arena]", OUT_BLEND, OUT_GLB, flush=True)


if __name__ == "__main__":
    build()
