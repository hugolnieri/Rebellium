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
                steps=0, wall_height=0.0, landing=0.0, entry=0.0):
    """Piso convexo inclinado sob degraus visuais: transitável sem travar no espelho."""
    from mathutils import Vector
    a, b = Vector(start), Vector(end)
    direction = (b - a).normalized()
    cross = Vector((-direction.y, direction.x))
    bottom = min(low, high) - 1.1
    sections = []
    if entry:
        sections.append((a - direction * entry, low))
    sections.extend(((a, low), (b, high)))
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
    if entry:
        p = a - direction * entry * 0.5
        approach = box(name + "_Entry", (p.x, p.y, low + 0.025),
                       (entry, width - 0.35, 0.05), trim)
        approach.rotation_euler.z = math.atan2(direction.y, direction.x)
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


def curved_path(name, center, radius, width, start_angle, end_angle,
                start_height, end_height, steel, trim, accent, segments=24):
    """Rampa em U, dividida em peças convexas para a física Jolt."""
    for index in range(segments):
        t0 = index / segments
        t1 = (index + 1) / segments
        a0 = start_angle + (end_angle - start_angle) * t0
        a1 = start_angle + (end_angle - start_angle) * t1
        h0 = start_height + (end_height - start_height) * t0
        h1 = start_height + (end_height - start_height) * t1
        bottom = min(h0, h1) - 0.9
        points = []
        for angle, top in ((a0, h0), (a1, h1)):
            for r in (radius - width * 0.5, radius + width * 0.5):
                x = center[0] + math.cos(angle) * r
                y = center[1] + math.sin(angle) * r
                points.extend(((x, y, bottom), (x, y, top)))
        faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
                 (2, 6, 7, 3), (1, 3, 7, 5), (0, 4, 6, 2)]
        mesh = bpy.data.meshes.new("%s_%02d mesh" % (name, index))
        mesh.from_pydata(points, [], faces)
        mesh.materials.append(steel)
        obj = bpy.data.objects.new("%s_%02d" % (name, index), mesh)
        bpy.context.collection.objects.link(obj)
        collider = obj.copy()
        collider.data = obj.data.copy()
        collider.name = obj.name + "-convcolonly"
        bpy.context.collection.objects.link(collider)
        if index % 2 == 0:
            beam(name + "_Seam%02d" % index, points[1], points[3], 0.035, accent)
        mid = (a0 + a1) * 0.5
        outer = radius + width * 0.5 + 0.12
        px = center[0] + math.cos(mid) * outer
        py = center[1] + math.sin(mid) * outer
        high = (h0 + h1) * 0.5
        length = outer * abs(a1 - a0) + 0.05
        guard = box("%s_Guard%02d" % (name, index),
                    (px, py, high + 0.8), (length, 0.24, 1.6),
                    trim, collide=True, bevel=0.02)
        guard.rotation_euler.z = mid + math.pi * 0.5
        bpy.data.objects[guard.name + "-convcolonly"].rotation_euler.z = guard.rotation_euler.z
        glow = box("%s_Glow%02d" % (name, index),
                   (px, py, high + 1.63), (length, 0.13, 0.08), accent)
        glow.rotation_euler.z = guard.rotation_euler.z


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    steel = material("Graphite panels", (0.075, 0.105, 0.15), metal=0.75)
    trim = material("Dark titanium", (0.025, 0.038, 0.06), metal=0.85)
    rail = material("Guard rail", (0.17, 0.21, 0.26), metal=0.7)
    blue = material("Azure team", (0.025, 0.57, 1.0), glow=3.0)
    red = material("Crimson team", (1.0, 0.11, 0.23), glow=3.0)
    violet = material("Neutral core", (0.78, 0.27, 1.0), glow=3.5)
    pale = material("Deck numbers", (0.63, 0.7, 0.73), metal=0.3)
    glass = material("Transit glass", (0.08, 0.22, 0.33), metal=0.35, glow=0.5)

    station_height = 0.0
    spawn_height = 8.0
    goal_height = 9.4
    # A estação com o núcleo é o ponto BAIXO. Duas rampas em U contornam o vazio.
    deck("StationFloor", 0, 0, 26, 12, steel, trim, violet, station_height)
    deck("CorePlatform", 0, 0, 12, 14, steel, trim, violet, station_height)
    curved_path("AzureOuterLoop", (-18, -6), 16, 4.5, math.pi, 2 * math.pi,
                spawn_height, station_height, steel, rail, blue)
    curved_path("CrimsonOuterLoop", (18, 6), 16, 4.5, 0, math.pi,
                spawn_height, station_height, steel, rail, red)
    for flank in (-1, 1):
        deck(("North" if flank < 0 else "South") + "StationApproach",
             0, flank * 8, 12, 5, steel, trim, violet, station_height)
    # Ponte elevada une os terminais; o miolo é aberto para saltar ao núcleo.
    deck("SkyBridge", 0, 0, 54, 4.4, steel, trim, violet, spawn_height)
    for flank in (-1, 1):
        lane_rail("SkyBridgeRail%dL" % flank, -18, flank * 2.2, 16,
                  rail, violet, spawn_height)
        lane_rail("SkyBridgeRail%dR" % flank, 18, flank * 2.2, 16,
                  rail, violet, spawn_height)
    for x in (-11, 11):
        box("BridgeSupport_%d" % x, (x, 0, 3.8),
            (0.8, 2.4, 7.6), trim, collide=True)
    # Pórtico aberto do terminal: o núcleo continua visível e acessível dos dois lados.
    for x in (-7.2, 7.2):
        for y in (-5.3, 5.3):
            box("StationColumn_%d_%d" % (x, y), (x, y, 2.6),
                (0.5, 0.5, 5.2), rail, collide=True)
            box("StationColumnLight_%d_%d" % (x, y), (x, y, 3.7),
                (0.55, 0.55, 0.12), violet)
    for y in (-5.3, 5.3):
        box("StationCanopy_%d" % y, (0, y, 5.4),
            (16, 1.3, 0.45), trim, bevel=0.08)
    for x in (-6, 0, 6):
        box("StationRib_%d" % x, (x, 0, 5.5),
            (0.3, 10.5, 0.3), rail)
    # Cápsula de trânsito própria do Rebellium: portas largas voltadas às escadas,
    # centro aberto para coletar o núcleo e teto parcial utilizável em saltos.
    for side in (-1, 1):
        for end in (-1, 1):
            box("TransitShell_%d_%d" % (side, end),
                (side * 4.6, end * 4.5, 1.35),
                (0.28, 4.2, 2.7), pale, collide=True, bevel=0.06)
            box("TransitWindow_%d_%d" % (side, end),
                (side * 4.78, end * 4.5, 2.05),
                (0.08, 3.4, 0.8), glass)
        box("TransitRoofRail_%d" % side, (side * 4.6, 0, 3.45),
            (0.6, 14.5, 0.45), trim, collide=True)
    for end in (-1, 1):
        box("TransitNose_%d" % end, (0, end * 7.1, 1.25),
            (9.0, 0.65, 2.5), pale, collide=True, bevel=0.12)
        box("TransitRoofBridge_%d" % end, (0, end * 6.5, 3.55),
            (9.5, 0.8, 0.38), trim, collide=True)
    # Cada terminal tem um saguão alto; a escadaria de 8 m desce ao núcleo.
    # Da borda do saguão é possível pular e cortar parte da descida.
    for tag, side, accent in (("Azure", -1, blue), ("Crimson", 1, red)):
        spawn_x = side * 36
        deck(tag + "Concourse", spawn_x, 0, 18, 18,
             steel, trim, accent, spawn_height)
        deck(tag + "Lookout", side * 38, 11.5, 11, 5,
             steel, trim, accent, spawn_height)
        sloped_path(tag + "GrandStairs", (side * 27, side * 6),
                    (side * 13, side * 3),
                    spawn_height, station_height, 7.2, steel, trim, accent,
                    steps=18, wall_height=3.4, landing=4.0, entry=2.0)
        # Corredor protegido no spawn, com uma abertura frontal larga.
        box(tag + "BackWall", (side * 44.6, 0, spawn_height + 2.8),
            (0.35, 17, 5.6), rail, collide=True, bevel=0.05)
        box(tag + "OuterWall", (spawn_x, -side * 8.6, spawn_height + 1.9),
            (15, 0.35, 3.8), rail, collide=True, bevel=0.05)
        for y in (-7.5, 7.5):
            box(tag + "ExitPillar_%d" % y, (side * 27.4, y, spawn_height + 2.8),
                (0.7, 0.7, 5.6), rail, collide=True)
            box(tag + "ExitSignal_%d" % y, (side * 27.4, y, spawn_height + 3.2),
                (0.75, 0.8, 0.16), accent)
        box(tag + "ExitHeader", (side * 27.4, 0, spawn_height + 5.8),
            (0.85, 16, 0.6), trim)
        # Vigas deixam o teto aberto para câmera e saltos; os bancos dão cobertura.
        for x_offset in (-5.5, 0.0, 5.5):
            box(tag + "RoofRib_%s" % x_offset,
                (spawn_x + x_offset, 0, spawn_height + 6.2),
                (0.36, 17, 0.42), rail)
        for y in (-5.8, 5.8):
            if y * side > 0:
                continue  # O acesso lateral ao gol precisa ficar livre.
            box(tag + "SpawnCover_%d" % y,
                (spawn_x + side * 3, y, spawn_height + 0.75),
                (3.5, 1.2, 1.5), trim, collide=True, bevel=0.08)
        # Gol pouco acima do saguão, separado dele por uma escada lateral curta.
        goal_x = side * 39
        deck(tag + "GoalDeck", goal_x, side * 14, 10, 8,
             steel, trim, accent, goal_height)
        sloped_path(tag + "GoalSteps", (goal_x, side * 6), (goal_x, side * 9.5),
                    spawn_height, goal_height + 0.2, 7.2,
                    steel, trim, accent, steps=8, wall_height=1.9, landing=2.0)
        base_arch(tag + "Goal", goal_x, side * 14, accent, rail, goal_height)
        for offset in (-2.0, 2.0):
            cylinder(tag + "GoalDisc%d" % offset,
                     (goal_x + offset, side * 14, goal_height + 0.05),
                     0.55, 0.10, accent)
        box(tag + "GoalBackStop", (goal_x, side * 18.1, goal_height + 1.2),
            (10, 0.24, 2.4), rail, collide=True)
        for offset in (-3.9, 3.9):
            box(tag + "GoalGuard_%d" % offset,
                (goal_x + offset, side * 14, goal_height + 1.15),
                (0.35, 7.5, 2.3), rail, collide=True, bevel=0.04)
        # Estrutura sob o saguão mostra a grande diferença de altura.
        for y in (-7, 7):
            beam(tag + "Underframe_%d" % y,
                 (spawn_x - side * 6, y, spawn_height - 1),
                 (spawn_x + side * 2, y, -5), 0.23, rail)
    # Um núcleo sob a cobertura da estação, com dois corredores laterais.
    cylinder("CoreBase", (0, 0, 0.08), 2.35, 0.16, trim)
    cylinder("CoreRing", (0, 0, 0.18), 1.75, 0.08, violet)
    cylinder("CorePedestal", (0, 0, 0.30), 0.6, 0.44, pale)
    for x in (-11, 11):
        for y in (-13, 13):
            beam("StationTruss_%d_%d" % (x, y), (x, y, -1.4),
                 (x + (3 if x < 0 else -3), y, -6.0), 0.16, rail)
    for x in (-43, 43):
        for y in (-20, 15):
            box("SignalTower_%d_%d" % (x, y), (x, y, 8.0),
                (0.65, 0.65, 16.0), rail)
            cylinder("SignalLamp_%d_%d" % (x, y), (x, y, 16.2), 0.34, 0.30,
                     blue if x < 0 else red)

    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_yup=True,
                              export_apply=True, export_extras=False, export_animations=False)
    print("[relay_arena]", OUT_BLEND, OUT_GLB, flush=True)


if __name__ == "__main__":
    build()
