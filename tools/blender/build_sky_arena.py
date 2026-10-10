"""Monta no Blender a arena flutuante (plataforma circular sobre as nuvens) e exporta para o jogo.

Gera:
  art/arena/sky_arena.blend   — arquivo editável
  assets/arena/sky_arena.glb  — o que o Godot carrega (scenes/arenas/SkyArena.tscn)

Tudo é feito por código (malhas, UVs e texturas geradas com numpy), sem assets de terceiros.
Objetos com sufixo "-col" viram colisão no Godot (StaticBody3D com trimesh, mantendo a malha).
Os nós "Hologram", "Drone_*", "Beacon_*" e "Flame_*" são animados por scenes/arenas/sky_arena.gd.

Medidas (metros, chão da plataforma em z = 0):
  anel externo   r 17–24,5   passarela, com mureta de 1,4 m na borda (r 24,5–26)
  muro interno   r 15,5–17   6 m de altura (bom para wall jump), 4 passagens nas diagonais
  centro         r < 15,5    chão liso, palco com holograma

Uso:  blender -b -P tools/blender/build_sky_arena.py    ou    python3 tools/blender/build_sky_arena.py
"""
import math
import os

import bpy  # noqa: I001 (bpy antes de bmesh/mathutils)
import bmesh
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT_BLEND = os.path.join(ROOT, "art", "arena", "sky_arena.blend")
OUT_GLB = os.path.join(ROOT, "assets", "arena", "sky_arena.glb")

TAU = math.tau
SEG = 96  # segmentos de um círculo completo

R_RIM_OUT, R_RIM_IN, RIM_H = 26.0, 24.5, 1.4
R_WALL_OUT, R_WALL_IN, WALL_H = 17.0, 15.5, 6.0
TIERS = []  # arquibancada (r_in, r_out, altura) — removida: o centro é plano
GATE_ANGLES = [TAU / 8, 3 * TAU / 8, 5 * TAU / 8, 7 * TAU / 8]
GATE_HALF = 0.15  # rad (≈ 4,7 m de passagem no muro)
BASE_TOP, BASE_BOTTOM = 0.0, -1.2


def log(*args):
    print("[sky_arena]", *args, flush=True)


# --- Texturas (numpy → imagem do Blender, embutida no glb) -----------------------------------------

def _image(name, rgba):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(np.clip(rgba, 0, 1).astype(np.float32).ravel())
    img.pack()
    return img


def _noise(size, scale, seed):
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), np.float32)
    amp = 1.0
    cells = scale
    total = 0.0
    while cells <= size:
        grid = rng.random((cells + 1, cells + 1)).astype(np.float32)
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
        x = np.linspace(0, cells, size, endpoint=False)
        i = x.astype(int)
        f = x - i
        f = f * f * (3 - 2 * f)
        a = grid[i][:, i]
        b = grid[i][:, i + 1]
        c = grid[i + 1][:, i]
        d = grid[i + 1][:, i + 1]
        fx = f[None, :]
        fy = f[:, None]
        out += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
        total += amp
        amp *= 0.5
        cells *= 2
    return out / total


def tex_metal(name, base, panel, seed, rust=0.35, rivets=True):
    n = 512
    y, x = np.mgrid[0:n, 0:n] / n
    grime = _noise(n, 4, seed)
    fine = _noise(n, 32, seed + 1)
    color = np.ones((n, n, 4), np.float32)
    rgb = np.array(base, np.float32)[None, None, :] * (0.82 + 0.3 * grime[..., None] + 0.08 * fine[..., None])
    # Placas com frestas escuras e bordas levemente claras.
    px, py = (x * panel) % 1.0, (y * panel) % 1.0
    seam = np.minimum(np.minimum(px, 1 - px), np.minimum(py, 1 - py))
    rgb *= np.where(seam < 0.012, 0.35, np.where(seam < 0.03, 1.12, 1.0))[..., None]
    if rivets:
        for cx in (0.06, 0.94):
            for cy in (0.06, 0.94):
                d = np.hypot(px - cx, py - cy)
                rgb *= np.where(d < 0.018, 1.35, np.where(d < 0.026, 0.6, 1.0))[..., None]
    # Ferrugem: manchas marrons onde o ruído é alto, escorrendo para baixo.
    stain = np.clip((_noise(n, 6, seed + 2) - (1 - rust)) * 4, 0, 1)
    rust_rgb = np.array([0.32, 0.16, 0.08], np.float32)
    rgb = rgb * (1 - 0.7 * stain[..., None]) + rust_rgb * 0.7 * stain[..., None]
    color[..., :3] = rgb
    return _image(name, color)


def tex_hazard():
    n = 256
    y, x = np.mgrid[0:n, 0:n] / n
    band = ((x + y) * 4) % 1.0 < 0.5
    rgb = np.where(band[..., None], np.array([0.95, 0.72, 0.08]), np.array([0.05, 0.05, 0.05]))
    rgb = rgb * (0.85 + 0.15 * _noise(n, 8, 7)[..., None])
    return _image("T_Hazard", np.concatenate([rgb, np.ones((n, n, 1))], axis=2))


# --- Materiais ---------------------------------------------------------------------------------------

def material(name, color=(0.2, 0.2, 0.2), metallic=0.0, roughness=0.6, image=None, emission=None,
             strength=0.0, alpha=1.0, emission_image=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if image is not None:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if emission_image:
            mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
    bsdf.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.blend_method = "BLEND"
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
    return mat


def make_materials():
    m = {}
    m["floor"] = material("M_Floor", (1, 1, 1), 0.55, 0.55, tex_metal("T_Floor", (0.2, 0.21, 0.23), 4, 11, 0.25))
    m["hull"] = material("M_Hull", (1, 1, 1), 0.7, 0.6, tex_metal("T_Hull", (0.17, 0.16, 0.16), 3, 21, 0.5))
    m["wall"] = material("M_Wall", (1, 1, 1), 0.6, 0.5, tex_metal("T_Wall", (0.13, 0.14, 0.16), 2, 31, 0.2))
    m["trim"] = material("M_Trim", (0.06, 0.06, 0.07), 0.8, 0.35)
    m["truss"] = material("M_Truss", (0.12, 0.1, 0.09), 0.8, 0.7)
    m["cable"] = material("M_Cable", (0.02, 0.02, 0.025), 0.2, 0.5)
    m["hazard"] = material("M_Hazard", (1, 1, 1), 0.2, 0.6, tex_hazard())
    m["cyan"] = material("M_Neon_Cyan", (0.1, 0.9, 1.0), emission=(0.1, 0.9, 1.0), strength=2.5)
    m["magenta"] = material("M_Neon_Magenta", (1.0, 0.15, 0.75), emission=(1.0, 0.15, 0.75), strength=2.5)
    m["orange"] = material("M_Neon_Orange", (1.0, 0.5, 0.1), emission=(1.0, 0.5, 0.1), strength=2.2)
    m["red"] = material("M_Beacon_Red", (1.0, 0.1, 0.05), emission=(1.0, 0.1, 0.05), strength=8.0)
    m["blue"] = material("M_Neon_Blue", (0.2, 0.4, 1.0), emission=(0.2, 0.4, 1.0), strength=2.5)
    m["holo"] = material("M_Hologram", (0.2, 0.9, 1.0), emission=(0.2, 0.9, 1.0), strength=0.9, alpha=0.18)
    m["holo_line"] = material("M_HologramLine", (0.4, 1.0, 1.0), emission=(0.4, 1.0, 1.0), strength=2.5)
    m["flame_o"] = material("M_Flame_Orange", (1.0, 0.55, 0.15), emission=(1.0, 0.55, 0.15), strength=2.5,
                            alpha=0.35)
    m["flame_b"] = material("M_Flame_Blue", (0.3, 0.6, 1.0), emission=(0.3, 0.6, 1.0), strength=2.5, alpha=0.35)
    m["dish"] = material("M_Dish", (0.55, 0.56, 0.58), 0.6, 0.4)
    return m


# --- Construção de malhas -------------------------------------------------------------------------

class Builder:
    """Acumula geometria num bmesh e vira um objeto (um por material/colisão)."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []

    def mat_index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def quad(self, pts, uvs, mat):
        verts = [self.bm.verts.new(p) for p in pts]
        face = self.bm.faces.new(verts)
        face.material_index = self.mat_index(mat)
        for loop, uv in zip(face.loops, uvs):
            loop[self.uv].uv = uv
        return face

    def ring(self, r_in, r_out, z0, z1, mat, a0=0.0, a1=TAU, top=True, bottom=False, inner=True, outer=True,
             caps=True, side_mat=None, tile=4.0):
        """Anel (ou setor) sólido entre os raios e alturas dados. UV em metros / `tile`."""
        side_mat = side_mat or mat
        n = max(2, int(SEG * (a1 - a0) / TAU))
        angs = [a0 + (a1 - a0) * i / n for i in range(n + 1)]

        def p(r, a, z):
            return Vector((r * math.cos(a), r * math.sin(a), z))

        for i in range(n):
            a, b = angs[i], angs[i + 1]
            if top:
                pts = [p(r_in, a, z1), p(r_out, a, z1), p(r_out, b, z1), p(r_in, b, z1)]
                self.quad(pts, [(q.x / tile, q.y / tile) for q in pts], mat)
            if bottom:
                pts = [p(r_in, b, z0), p(r_out, b, z0), p(r_out, a, z0), p(r_in, a, z0)]
                self.quad(pts, [(q.x / tile, q.y / tile) for q in pts], mat)
            if outer:
                pts = [p(r_out, a, z0), p(r_out, b, z0), p(r_out, b, z1), p(r_out, a, z1)]
                u0, u1 = a * r_out / tile, b * r_out / tile
                self.quad(pts, [(u0, z0 / tile), (u1, z0 / tile), (u1, z1 / tile), (u0, z1 / tile)], side_mat)
            if inner:
                pts = [p(r_in, b, z0), p(r_in, a, z0), p(r_in, a, z1), p(r_in, b, z1)]
                u0, u1 = a * r_in / tile, b * r_in / tile
                self.quad(pts, [(u1, z0 / tile), (u0, z0 / tile), (u0, z1 / tile), (u1, z1 / tile)], side_mat)
        if caps and (a1 - a0) < TAU - 1e-6:
            for a, flip in ((a0, False), (a1, True)):
                pts = [p(r_in, a, z0), p(r_out, a, z0), p(r_out, a, z1), p(r_in, a, z1)]
                if flip:
                    pts = pts[::-1]
                self.quad(pts, [(0, 0), (1, 0), (1, 1), (0, 1)], side_mat)

    def disc(self, r, z, mat, tile=4.0, up=True):
        n = SEG
        center = self.bm.verts.new((0, 0, z))
        ring = [self.bm.verts.new((r * math.cos(TAU * i / n), r * math.sin(TAU * i / n), z)) for i in range(n)]
        for i in range(n):
            vs = [center, ring[i], ring[(i + 1) % n]] if up else [center, ring[(i + 1) % n], ring[i]]
            face = self.bm.faces.new(vs)
            face.material_index = self.mat_index(mat)
            for loop in face.loops:
                loop[self.uv].uv = (loop.vert.co.x / tile, loop.vert.co.y / tile)

    def box(self, center, size, mat, rot_z=0.0, tile=2.0):
        cx, cy, cz = center
        sx, sy, sz = (s / 2 for s in size)
        m = Matrix.Translation(center) @ Matrix.Rotation(rot_z, 4, "Z")
        corners = [m @ Vector((x * sx, y * sy, z * sz)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for f in faces:
            pts = [corners[i] for i in f]
            self.quad(pts, [(0, 0), (size[0] / tile, 0), (size[0] / tile, size[2] / tile), (0, size[2] / tile)], mat)

    def beam(self, a, b, thickness, mat):
        """Viga de seção quadrada entre dois pontos."""
        a, b = Vector(a), Vector(b)
        d = b - a
        length = d.length
        z = d.normalized()
        x = z.cross(Vector((0, 0, 1)))
        if x.length < 1e-4:
            x = Vector((1, 0, 0))
        x.normalize()
        y = z.cross(x)
        t = thickness / 2
        corners = []
        for end in (a, b):
            for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                corners.append(end + x * sx * t + y * sy * t)
        for i in range(4):
            j = (i + 1) % 4
            pts = [corners[i], corners[j], corners[4 + j], corners[4 + i]]
            self.quad(pts, [(0, 0), (thickness, 0), (thickness, length), (0, length)], mat)

    def tube(self, points, radius, mat, sides=6):
        rings = []
        for k, c in enumerate(points):
            d = (points[min(k + 1, len(points) - 1)] - points[max(k - 1, 0)]).normalized()
            x = d.cross(Vector((0, 0, 1)))
            if x.length < 1e-4:
                x = Vector((1, 0, 0))
            x.normalize()
            y = d.cross(x)
            rings.append([self.bm.verts.new(c + (x * math.cos(TAU * s / sides) + y * math.sin(TAU * s / sides))
                                            * radius) for s in range(sides)])
        for k in range(len(rings) - 1):
            for s in range(sides):
                t = (s + 1) % sides
                face = self.bm.faces.new([rings[k][s], rings[k][t], rings[k + 1][t], rings[k + 1][s]])
                face.material_index = self.mat_index(mat)

    def cylinder(self, center, r, h, mat, sides=24, cap_top=True, cap_bottom=True, r_top=None):
        cx, cy, cz = center
        r_top = r if r_top is None else r_top
        bot = [self.bm.verts.new((cx + r * math.cos(TAU * i / sides), cy + r * math.sin(TAU * i / sides), cz))
               for i in range(sides)]
        top = [self.bm.verts.new((cx + r_top * math.cos(TAU * i / sides), cy + r_top * math.sin(TAU * i / sides),
                                  cz + h)) for i in range(sides)]
        mi = self.mat_index(mat)
        for i in range(sides):
            j = (i + 1) % sides
            face = self.bm.faces.new([bot[i], bot[j], top[j], top[i]])
            face.material_index = mi
            for loop, uv in zip(face.loops, [(i / sides, 0), ((i + 1) / sides, 0), ((i + 1) / sides, 1),
                                             (i / sides, 1)]):
                loop[self.uv].uv = uv
        if cap_top and r_top > 0:
            self.bm.faces.new(top).material_index = mi
        if cap_bottom:
            self.bm.faces.new(bot[::-1]).material_index = mi

    def finish(self, name, parent=None):
        mesh = bpy.data.meshes.new(name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat in self.mats:
            mesh.materials.append(mat)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        if parent is not None:
            obj.parent = parent
        return obj


def gaps(r_in, r_out):
    """Setores entre as passagens (a0, a1)."""
    out = []
    for i, g in enumerate(GATE_ANGLES):
        nxt = GATE_ANGLES[(i + 1) % len(GATE_ANGLES)] + (TAU if i == len(GATE_ANGLES) - 1 else 0)
        out.append((g + GATE_HALF, nxt - GATE_HALF))
    return out


# --- Peças ---------------------------------------------------------------------------------------

def build_platform(m, root):
    # Chão + casco (com colisão).
    b = Builder()
    b.disc(R_RIM_OUT, BASE_TOP, m["floor"])
    b.ring(0.0, R_RIM_OUT, BASE_BOTTOM, BASE_TOP, m["hull"], top=False, bottom=True, inner=False)
    b.finish("Deck-col", root)
    # Mureta da borda.
    b = Builder()
    b.ring(R_RIM_IN, R_RIM_OUT, BASE_TOP, RIM_H, m["wall"], side_mat=m["hull"], tile=3.0)
    b.finish("Rim-col", root)
    # Muro interno com 4 passagens (bom para wall jump) e arquibancada.
    b = Builder()
    for a0, a1 in gaps(R_WALL_IN, R_WALL_OUT):
        b.ring(R_WALL_IN, R_WALL_OUT, BASE_TOP, WALL_H, m["wall"], a0, a1, tile=3.0)
        for r_in, r_out, h in TIERS:
            b.ring(r_in, r_out, BASE_TOP, h, m["floor"], a0, a1, outer=False, side_mat=m["wall"], tile=3.0)
    b.finish("InnerRing-col", root)
    # Palco central.
    b = Builder()
    b.ring(0.0, 3.2, BASE_TOP, 0.35, m["wall"], inner=False, tile=2.0)
    b.finish("Dais-col", root)


def build_neon(m, root):
    b = Builder()
    eps = 0.01
    # Passarela: faixa no pé da mureta e no topo da mureta.
    b.ring(R_RIM_IN - 0.06, R_RIM_IN - eps, 0.05, 0.14, m["cyan"], top=True, outer=False)
    b.ring(R_RIM_IN - 0.02, R_RIM_IN + 0.12, RIM_H, RIM_H + 0.02, m["cyan"], inner=False, outer=False)
    b.ring(R_RIM_OUT + eps, R_RIM_OUT + 0.06, -0.5, -0.4, m["blue"], inner=False, top=True)
    for a0, a1 in gaps(R_WALL_IN, R_WALL_OUT):
        # Muro interno: faixa laranja no meio da face externa e ciano no topo.
        b.ring(R_WALL_OUT + eps, R_WALL_OUT + 0.06, 1.5, 1.6, m["orange"], a0, a1, inner=False)
        b.ring(R_WALL_IN - 0.06, R_WALL_IN - eps, 1.5, 1.6, m["magenta"], a0, a1, outer=False)
        b.ring(R_WALL_OUT + eps, R_WALL_OUT + 0.06, 4.2, 4.28, m["cyan"], a0, a1, inner=False)
        b.ring(R_WALL_IN - 0.06, R_WALL_IN - eps, 4.2, 4.28, m["cyan"], a0, a1, outer=False)
        b.ring(R_WALL_IN - 0.02, R_WALL_IN + 0.1, WALL_H, WALL_H + 0.02, m["cyan"], a0, a1, inner=False,
               outer=False, caps=False)
        # Espelhos dos degraus: magenta e ciano alternados por setor.
        for k, (r_in, r_out, h) in enumerate(TIERS):
            mat = m["magenta"] if k % 2 == 0 else m["cyan"]
            b.ring(r_in - 0.05, r_in - eps, h - 0.14, h - 0.06, mat, a0, a1, top=True, outer=False)
    # Chão: faixa zebrada perto do muro e anéis no centro.
    b.ring(R_WALL_OUT + 0.4, R_WALL_OUT + 0.9, BASE_TOP, BASE_TOP + 0.01, m["hazard"], inner=False, outer=False,
           tile=1.0)
    b.ring(R_RIM_IN - 1.2, R_RIM_IN - 0.9, BASE_TOP, BASE_TOP + 0.01, m["hazard"], inner=False, outer=False,
           tile=1.0)
    b.ring(7.8, 8.05, BASE_TOP, BASE_TOP + 0.012, m["cyan"], inner=False, outer=False)
    b.ring(5.0, 5.15, BASE_TOP, BASE_TOP + 0.012, m["orange"], inner=False, outer=False)
    b.ring(3.2, 3.3, 0.0, 0.36, m["cyan"], inner=False)
    b.ring(1.6, 1.75, 0.35, 0.37, m["magenta"], inner=False, outer=False)
    b.ring(2.4, 2.5, 0.35, 0.37, m["cyan"], inner=False, outer=False)
    b.finish("Neon", root)


def build_underside(m, root):
    b = Builder()
    # Casco inferior em degraus e motor central.
    b.ring(0.0, 23.0, -2.3, BASE_BOTTOM, m["hull"], top=False, bottom=True, inner=False)
    b.ring(0.0, 16.0, -3.4, -2.3, m["hull"], top=False, bottom=True, inner=False)
    b.cylinder((0, 0, -6.0), 4.0, 2.6, m["hull"], sides=32)
    b.cylinder((0, 0, -7.2), 2.6, 1.2, m["trim"], sides=32)
    b.finish("Hull", root)
    # Treliça em volta do casco (montantes e X).
    t = Builder()
    n = 72
    r = R_RIM_OUT - 0.25
    z0, z1 = -2.2, -0.15
    for i in range(n):
        a, c = TAU * i / n, TAU * (i + 1) / n
        pa0 = Vector((r * math.cos(a), r * math.sin(a), z0))
        pa1 = Vector((r * math.cos(a), r * math.sin(a), z1))
        pc0 = Vector((r * math.cos(c), r * math.sin(c), z0))
        pc1 = Vector((r * math.cos(c), r * math.sin(c), z1))
        t.beam(pa0, pa1, 0.18, m["truss"])
        t.beam(pa0, pc1, 0.1, m["truss"])
        t.beam(pa1, pc0, 0.1, m["truss"])
    t.ring(r - 0.1, r + 0.1, z0 - 0.1, z0 + 0.1, m["truss"])
    t.ring(r - 0.1, r + 0.1, z1 - 0.1, z1, m["truss"])
    t.finish("Truss", root)
    # Cabos pendurados entre pontos do casco.
    c = Builder()
    rng = np.random.default_rng(5)
    for i in range(28):
        a = TAU * i / 28 + rng.uniform(-0.05, 0.05)
        span = rng.uniform(0.12, 0.3)
        ra, rb = rng.uniform(17, 22.5), rng.uniform(17, 22.5)
        pa = Vector((ra * math.cos(a), ra * math.sin(a), -2.3))
        pb = Vector((rb * math.cos(a + span), rb * math.sin(a + span), -2.3))
        sag = rng.uniform(1.0, 3.2)
        pts = [pa.lerp(pb, k / 12) - Vector((0, 0, sag * math.sin(math.pi * k / 12))) for k in range(13)]
        c.tube(pts, 0.05, m["cable"])
    c.finish("Cables", root)


def build_thrusters(m, root):
    for i in range(6):
        a = TAU * i / 6 + TAU / 12
        r = 19.0
        x, y = r * math.cos(a), r * math.sin(a)
        b = Builder()
        b.cylinder((x, y, -3.9), 1.3, 1.6, m["hull"], sides=20, cap_bottom=False)
        b.cylinder((x, y, -4.3), 1.0, 0.4, m["trim"], sides=20, cap_bottom=False, r_top=1.3)
        b.ring(0.0, 0.95, -4.31, -4.3, m["orange"] if i % 3 else m["blue"], inner=False, outer=False, top=False,
               bottom=True)
        # Ajusta o anel emissivo para o bocal (o ring é centrado na origem).
        obj = b.finish("Thruster_%d" % i, root)
        for v in obj.data.vertices:
            if v.co.z < -4.305:
                v.co.x += x
                v.co.y += y
        f = Builder()
        f.cylinder((0, 0, -4.0), 0.9, 4.2, m["flame_o"] if i % 3 else m["flame_b"], sides=16, r_top=0.05,
                   cap_top=False)
        flame = f.finish("Flame_%d" % i, root)
        for v in flame.data.vertices:  # cone apontando para baixo
            v.co.z = -4.3 - (v.co.z + 4.0)
        flame.location = (x, y, 0)


def build_antennas(m, root):
    for i, a in enumerate([TAU * k / 4 + 0.35 for k in range(4)]):
        r = (R_RIM_IN + R_RIM_OUT) / 2
        x, y = r * math.cos(a), r * math.sin(a)
        b = Builder()
        h = 9.0 if i % 2 == 0 else 6.5
        s = 0.35
        corners = [(x + s * dx, y + s * dy) for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        for k in range(4):
            cx, cy = corners[k]
            b.beam((cx, cy, RIM_H), (x + (cx - x) * 0.3, y + (cy - y) * 0.3, RIM_H + h), 0.08, m["truss"])
        for level in range(1, int(h)):
            z = RIM_H + level
            f = 1 - 0.7 * level / h
            pts = [(x + (cx - x) * f, y + (cy - y) * f, z) for cx, cy in corners]
            for k in range(4):
                b.beam(pts[k], pts[(k + 1) % 4], 0.05, m["truss"])
        b.box((x, y, RIM_H + 0.15), (1.2, 1.2, 0.3), m["trim"])
        # Prato.
        dish_z = RIM_H + h * 0.55
        out = Vector((math.cos(a), math.sin(a), 0))
        dc = Vector((x, y, dish_z)) + out * 0.6
        b.beam((x, y, dish_z), dc, 0.12, m["trim"])
        rings = 6
        for k in range(rings):
            r0, r1 = 1.1 * k / rings, 1.1 * (k + 1) / rings
            d0, d1 = 0.35 * (k / rings) ** 2, 0.35 * ((k + 1) / rings) ** 2
            for j in range(16):
                t0, t1 = TAU * j / 16, TAU * (j + 1) / 16
                up = Vector((0, 0, 1))
                side = Vector((-math.sin(a), math.cos(a), 0))
                axis = (out * 0.8 + up * 0.6).normalized()
                u = side
                v = axis.cross(u)

                def pt(rr, dd, tt):
                    return dc + axis * dd + (u * math.cos(tt) + v * math.sin(tt)) * rr
                b.quad([pt(r0, d0, t0), pt(r1, d1, t0), pt(r1, d1, t1), pt(r0, d0, t1)],
                       [(0, 0), (1, 0), (1, 1), (0, 1)], m["dish"])
        b.finish("Antenna_%d" % i, root)
        beacon = Builder()
        beacon.cylinder((0, 0, -0.12), 0.12, 0.24, m["red"], sides=10)
        obj = beacon.finish("Beacon_%d" % i, root)
        obj.location = (x, y, RIM_H + h + 0.12)


def build_hologram(m, root):
    holo = bpy.data.objects.new("Hologram", None)
    bpy.context.scene.collection.objects.link(holo)
    holo.parent = root
    holo.location = (0, 0, 3.6)
    b = Builder()
    rings = 16
    seg = 32
    r = 1.8
    for i in range(rings):
        p0, p1 = math.pi * i / rings - math.pi / 2, math.pi * (i + 1) / rings - math.pi / 2
        for j in range(seg):
            t0, t1 = TAU * j / seg, TAU * (j + 1) / seg

            def pt(p, t):
                return Vector((r * math.cos(p) * math.cos(t), r * math.cos(p) * math.sin(t), r * math.sin(p)))
            b.quad([pt(p0, t0), pt(p0, t1), pt(p1, t1), pt(p1, t0)], [(0, 0), (1, 0), (1, 1), (0, 1)], m["holo"])
    b.finish("HoloSphere", holo)
    lines = Builder()
    for k in range(6):  # meridianos e paralelos brilhantes
        t = TAU * k / 6
        pts = [Vector((r * 1.01 * math.cos(p) * math.cos(t), r * 1.01 * math.cos(p) * math.sin(t), r * 1.01 * math.sin(p)))
               for p in np.linspace(-math.pi / 2, math.pi / 2, 24)]
        lines.tube(pts, 0.015, m["holo_line"], sides=4)
    for p in (-0.6, 0.0, 0.6):
        rr = r * 1.01 * math.cos(p)
        pts = [Vector((rr * math.cos(t), rr * math.sin(t), r * 1.01 * math.sin(p))) for t in np.linspace(0, TAU, 40)]
        lines.tube(pts, 0.015, m["holo_line"], sides=4)
    lines.finish("HoloLines", holo)
    for k, (tilt, rad) in enumerate(((0.4, 2.6), (-0.7, 3.0))):
        o = Builder()
        pts = [Vector((rad * math.cos(t), rad * math.sin(t) * math.cos(tilt), rad * math.sin(t) * math.sin(tilt)))
               for t in np.linspace(0, TAU, 64)]
        o.tube(pts, 0.03, m["holo_line"] if k == 0 else m["orange"], sides=5)
        o.finish("HoloOrbit_%d" % k, holo)
    beam = Builder()
    beam.cylinder((0, 0, 0.36), 1.4, 1.5, m["holo"], sides=24, r_top=0.4, cap_top=False, cap_bottom=False)
    beam.finish("HoloBeam", root)


def build_drones(m, root):
    for i in range(3):
        drone = bpy.data.objects.new("Drone_%d" % i, None)
        bpy.context.scene.collection.objects.link(drone)
        drone.parent = root
        a = TAU * i / 3 + 0.5
        drone.location = (31 * math.cos(a), 31 * math.sin(a), 6 + 2 * i)
        b = Builder()
        b.box((0, 0, 0), (0.6, 0.6, 0.22), m["trim"])
        for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            b.beam((0, 0, 0.05), (0.55 * dx, 0.55 * dy, 0.1), 0.07, m["trim"])
            b.cylinder((0.55 * dx, 0.55 * dy, 0.12), 0.28, 0.02, m["dish"], sides=12)
        b.cylinder((0, 0, -0.2), 0.12, 0.08, m["blue"], sides=10)
        b.finish("DroneBody_%d" % i, drone)


# --- Montagem -------------------------------------------------------------------------------------

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    m = make_materials()
    root = bpy.data.objects.new("SkyArena", None)
    bpy.context.scene.collection.objects.link(root)
    build_platform(m, root)
    build_neon(m, root)
    build_underside(m, root)
    build_thrusters(m, root)
    build_antennas(m, root)
    build_hologram(m, root)
    build_drones(m, root)
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
    log("ok", OUT_BLEND)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_yup=True, export_apply=True,
                              export_extras=False, export_animations=False)
    log("ok", OUT_GLB, os.path.getsize(OUT_GLB) // 1024, "KB")


if __name__ == "__main__":
    main()
