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


def deck(name, x, y, length, width, steel, trim, light):
    box(name, (x, y, -0.55), (length, width, 1.1), steel, collide=True, bevel=0.08)
    box(name + "_Underframe", (x, y, -1.3), (length - 0.4, width - 0.4, 0.4), trim, bevel=0.04)
    for side in (-1, 1):
        box(name + "_Edge%d" % side, (x, y + side * (width / 2 - 0.12), 0.025),
            (length - 0.25, 0.12, 0.05), light)
    # Juntas transversais dão escala sem bloquear o movimento.
    for offset in range(-int(length // 2) + 3, int(length // 2), 4):
        box(name + "_Joint%d" % offset, (x + offset, y, 0.014), (0.035, width - 0.3, 0.025), trim)


def lane_rail(name, x, y, length, steel, accent):
    box(name, (x, y, 0.62), (length, 0.22, 1.24), steel, collide=True, bevel=0.04)
    box(name + "_Light", (x, y, 1.27), (length, 0.14, 0.08), accent)


def base_arch(name, x, color, steel):
    for y in (-5.3, 5.3):
        box(name + "_Pillar_%d" % int(y), (x, y, 2.8), (0.72, 0.72, 5.6), steel, collide=True)
        box(name + "_PillarLight_%d" % int(y), (x, y, 3.0), (0.76, 0.80, 0.12), color)
    box(name + "_Header", (x, 0, 5.7), (0.9, 11.1, 0.7), steel)
    box(name + "_HeaderLight", (x, 0, 5.78), (1.0, 10.8, 0.12), color)
    cylinder(name + "_Beacon", (x, 0, 6.28), 0.62, 0.24, color)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    steel = material("Graphite panels", (0.075, 0.105, 0.15), metal=0.75)
    trim = material("Dark titanium", (0.025, 0.038, 0.06), metal=0.85)
    rail = material("Guard rail", (0.17, 0.21, 0.26), metal=0.7)
    blue = material("Azure team", (0.025, 0.57, 1.0), glow=3.0)
    red = material("Crimson team", (1.0, 0.11, 0.23), glow=3.0)
    violet = material("Neutral core", (0.78, 0.27, 1.0), glow=3.5)
    pale = material("Deck numbers", (0.63, 0.7, 0.73), metal=0.3)

    # Eixo principal e duas rotas simétricas contornando o vazio: as três chegam às duas bases.
    deck("CentralSpine", 0, 0, 64, 6.4, steel, trim, violet)
    deck("CorePlaza", 0, 0, 12, 10, steel, trim, violet)
    for side in (-1, 1):
        tag = "North" if side < 0 else "South"
        deck(tag + "Bypass", 0, side * 12, 52, 5, steel, trim, blue if side < 0 else red)
        for end in (-1, 1):
            deck(tag + ("West" if end < 0 else "East") + "Link", end * 25, side * 6,
                 5, 12, steel, trim, blue if end < 0 else red)
        lane_rail(tag + "OuterGuard", 0, side * 14.5, 52, rail, blue if side < 0 else red)
    for team, x, color in (("Azure", -33, blue), ("Crimson", 33, red)):
        deck(team + "Base", x, 0, 16, 13, steel, trim, color)
        base_arch(team + "Goal", -36 if x < 0 else 36, color, rail)
        for y in (-4, 4):
            cylinder(team + "GoalDisc%d" % y, (x + (2 if x > 0 else -2), y, 0.05),
                     0.64, 0.10, color)
        box(team + "BackStop", (x + (-7.7 if x < 0 else 7.7), 0, 1.15),
            (0.36, 13, 2.3), rail, collide=True)
    # Barreiras baixas e apoios centrais: coberturas para dash e superfícies para wall jump.
    for x in (-13, 13):
        for side in (-1, 1):
            y = side * 8.2
            box("RouteCover_%d_%d" % (x, side), (x, y, 1.45),
                (2.2, 0.70, 2.9), rail, collide=True, bevel=0.06)
            box("RouteCoverNeon_%d_%d" % (x, side), (x, y, 2.98),
                (2.0, 0.18, 0.08), violet)
    # Núcleo da bola, rebaixado e visível de qualquer rota.
    cylinder("CoreBase", (0, 0, 0.08), 2.35, 0.16, trim)
    cylinder("CoreRing", (0, 0, 0.18), 1.75, 0.08, violet)
    cylinder("CorePedestal", (0, 0, 0.30), 0.6, 0.44, pale)
    for x in (-22, -11, 11, 22):
        for y in (-12, 12):
            beam("UnderTruss_%d_%d" % (x, y), (x, y, -1.4),
                 (x + (3 if x < 0 else -3), y, -6.0), 0.16, rail)
    # Antenas e arcos deixam a silhueta própria sem reproduzir a estação de referência.
    for x in (-31, 31):
        for y in (-13, 13):
            box("SignalTower_%d_%d" % (x, y), (x, y, 3.9), (0.75, 0.75, 7.8), rail)
            cylinder("SignalLamp_%d_%d" % (x, y), (x, y, 8.0), 0.34, 0.30,
                     blue if x < 0 else red)
    for side in (-1, 1):
        beam("CoreSuspension_%d_A" % side, (-7, side * 12, 4.4), (0, side * 5, 7.5),
             0.16, rail)
        beam("CoreSuspension_%d_B" % side, (7, side * 12, 4.4), (0, side * 5, 7.5),
             0.16, rail)

    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_yup=True,
                              export_apply=True, export_extras=False, export_animations=False)
    print("[relay_arena]", OUT_BLEND, OUT_GLB, flush=True)


if __name__ == "__main__":
    build()
