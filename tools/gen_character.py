#!/usr/bin/env python3
"""Gera o personagem base do REBELLIUM como malha lisa, com esqueleto e pesos de pele.

Uso: python3 tools/gen_character.py   (requer numpy e scikit-image)
Saídas:
  assets/character/body.glb  -> corpo (traje, pele, ombreiras/joelheiras), linhas emissivas e olhos,
                                todos com pele (skin) no esqueleto abaixo
  assets/character/hair.glb  -> cabelo (sem pele; origem na articulação da cabeça)

Como funciona: o corpo é esculpido como um campo de distância (SDF) — elipsoides e cones
arredondados unidos com "smooth union" — e a superfície é extraída com marching cubes. Assim a malha
é contínua e lisa (nada de blocos). Cada vértice recebe a cor/material da parte mais próxima e pesos
para os ossos permitidos daquela parte. As linhas do traje são tubos projetados sobre a superfície.

Esqueleto (mesmos nomes e posições usados por scenes/player/character_model.gd). Frente = -Z,
pés em y = 0, braços caídos ao lado do corpo (pose de descanso).
"""
import json
import math
import os
import struct

import numpy as np
from skimage import measure

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "character")
VOXEL = 0.008       # resolução do corpo (m)
HAIR_VOXEL = 0.005  # resolução do cabelo (m)

# --- Esqueleto -----------------------------------------------------------------------
# nome: (posição de descanso, pai)
BONES = {
    "hips": ((0.0, 0.97, 0.0), None),
    "spine": ((0.0, 1.07, 0.0), "hips"),
    "chest": ((0.0, 1.27, 0.0), "spine"),
    "head": ((0.0, 1.61, 0.0), "chest"),
}
for side, sx in (("l", -1.0), ("r", 1.0)):
    BONES[f"shoulder_{side}"] = ((0.195 * sx, 1.505, 0.0), "chest")
    BONES[f"elbow_{side}"] = ((0.195 * sx, 1.215, 0.0), f"shoulder_{side}")
    BONES[f"wrist_{side}"] = ((0.195 * sx, 0.935, 0.0), f"elbow_{side}")
    BONES[f"thigh_{side}"] = ((0.095 * sx, 0.94, 0.0), "hips")
    BONES[f"knee_{side}"] = ((0.095 * sx, 0.49, 0.0), f"thigh_{side}")
    BONES[f"foot_{side}"] = ((0.095 * sx, 0.05, 0.0), f"knee_{side}")
BONE_NAMES = list(BONES.keys())

# Segmentos usados para calcular os pesos (início, fim).
SEGMENTS = {
    "hips": ((0, 0.88, 0), (0, 1.07, 0)),
    "spine": ((0, 1.07, 0), (0, 1.27, 0)),
    "chest": ((0, 1.27, 0), (0, 1.52, 0)),
    "head": ((0, 1.58, 0), (0, 1.82, 0)),
}
for side, sx in (("l", -1.0), ("r", 1.0)):
    x = 0.195 * sx
    lx = 0.095 * sx
    SEGMENTS[f"shoulder_{side}"] = ((x, 1.505, 0), (x, 1.215, 0))
    SEGMENTS[f"elbow_{side}"] = ((x, 1.215, 0), (x, 0.935, 0))
    SEGMENTS[f"wrist_{side}"] = ((x, 0.935, 0), (x, 0.84, 0))
    SEGMENTS[f"thigh_{side}"] = ((lx, 0.94, 0), (lx, 0.49, 0))
    SEGMENTS[f"knee_{side}"] = ((lx, 0.49, 0), (lx, 0.06, 0))
    SEGMENTS[f"foot_{side}"] = ((lx, 0.05, 0.02), (lx, 0.03, -0.15))

# A malha é esculpida em pose "A" (braços abertos) para a mão não se fundir à coxa; depois os
# vértices voltam à pose de repouso pela própria pele (ossos com rotação identidade no repouso).
ARM_POSE_ANGLE = 0.45  # rad


def arm_side(bone):
    for prefix in ("shoulder_", "elbow_", "wrist_"):
        if bone.startswith(prefix):
            return bone[-1]
    return None


def arm_rotation(side, inverse=False):
    """(matriz 3x3, pivô) da pose A para o braço do lado dado."""
    sx = -1.0 if side == "l" else 1.0
    a = sx * ARM_POSE_ANGLE * (-1.0 if inverse else 1.0)
    c, s_ = math.cos(a), math.sin(a)
    rot = np.array([[c, -s_, 0], [s_, c, 0], [0, 0, 1]], np.float32)
    return rot, np.array(BONES[f"shoulder_{side}"][0], np.float32)


def pose_points(points, side, inverse=False):
    rot, pivot = arm_rotation(side, inverse)
    return (np.asarray(points, np.float32) - pivot) @ rot.T + pivot


for _name, (_a, _b) in list(SEGMENTS.items()):
    if arm_side(_name):
        SEGMENTS[_name] = tuple(pose_points(np.array([_a, _b], np.float32), arm_side(_name)))

# --- Materiais (cores de vértice) ------------------------------------------------------
SUIT = (0.08, 0.08, 0.1)
ARMOR = (0.12, 0.12, 0.145)
SKIN = (0.98, 0.84, 0.75)
MATERIALS = {"suit": SUIT, "armor": ARMOR, "skin": SKIN}


# --- Primitivas SDF ---------------------------------------------------------------------

def sd_ellipsoid(p, c, r):
    r = np.asarray(r, dtype=np.float32)
    q = (p - np.asarray(c, dtype=np.float32)) / r
    k0 = np.linalg.norm(q, axis=1)
    k1 = np.linalg.norm(q / r, axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def sd_round_cone(p, a, ra, b, rb):
    a = np.asarray(a, dtype=np.float32)
    b = np.asarray(b, dtype=np.float32)
    ba = b - a
    t = np.clip(((p - a) @ ba) / max(float(ba @ ba), 1e-9), 0.0, 1.0)
    closest = a + t[:, None] * ba
    return np.linalg.norm(p - closest, axis=1) - (ra + (rb - ra) * t)


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


class Part:
    def __init__(self, name, kind, params, material, bones, k=0.03):
        self.name, self.kind, self.params = name, kind, params
        self.material, self.bones, self.k = material, bones, k
        self.side = arm_side(bones[0])

    def sdf(self, p):
        if self.side:
            p = pose_points(p, self.side, inverse=True)
        if self.kind == "ellipsoid":
            return sd_ellipsoid(p, *self.params)
        return sd_round_cone(p, *self.params)


def body_parts():
    parts = [
        Part("head", "ellipsoid", ((0, 1.69, 0.0), (0.091, 0.114, 0.1)), "skin", ["head"]),
        Part("jaw", "cone", ((0, 1.665, -0.01), 0.074, (0, 1.595, -0.045), 0.027), "skin", ["head"], 0.025),
        Part("nose", "cone", ((0, 1.695, -0.088), 0.007, (0, 1.668, -0.103), 0.009), "skin", ["head"], 0.012),
        Part("collar", "cone", ((0, 1.49, 0.0), 0.056, (0, 1.565, 0.002), 0.05), "suit", ["chest", "head"], 0.015),
        Part("neck", "cone", ((0, 1.55, 0.003), 0.043, (0, 1.64, 0.005), 0.042), "skin", ["chest", "head"], 0.015),
        Part("chest", "ellipsoid", ((0, 1.39, -0.005), (0.152, 0.14, 0.1)), "suit", ["chest", "spine"]),
        Part("lats", "ellipsoid", ((0, 1.36, 0.025), (0.165, 0.15, 0.085)), "suit", ["chest", "spine"]),
        Part("waist", "ellipsoid", ((0, 1.18, 0.0), (0.118, 0.12, 0.088)), "suit", ["spine", "chest", "hips"], 0.05),
        Part("pelvis", "ellipsoid", ((0, 1.0, 0.002), (0.142, 0.1, 0.102)), "suit", ["hips", "spine"], 0.04),
    ]
    for side, sx in (("l", -1.0), ("r", 1.0)):
        x = 0.197 * sx
        lx = 0.096 * sx
        sh, el, wr = f"shoulder_{side}", f"elbow_{side}", f"wrist_{side}"
        th, kn, ft = f"thigh_{side}", f"knee_{side}", f"foot_{side}"
        parts += [
            Part(f"pec_{side}", "ellipsoid", ((0.068 * sx, 1.405, -0.058), (0.072, 0.058, 0.048)), "suit", ["chest"]),
            Part(f"glute_{side}", "ellipsoid", ((0.064 * sx, 0.965, 0.045), (0.07, 0.078, 0.062)), "suit", ["hips", th]),
            Part(f"deltoid_{side}", "ellipsoid", ((0.19 * sx, 1.468, 0.0), (0.06, 0.06, 0.06)), "suit", [sh, "chest"], 0.035),
            Part(f"pad_{side}", "ellipsoid", ((0.2 * sx, 1.49, 0.0), (0.062, 0.05, 0.068)), "armor", [sh, "chest"], 0.012),
            Part(f"upperarm_{side}", "cone", ((x, 1.47, 0.0), 0.048, (x, 1.235, 0.0), 0.039), "suit", [sh], 0.025),
            Part(f"elbowj_{side}", "ellipsoid", ((x, 1.215, 0.004), (0.037, 0.04, 0.037)), "suit", [sh, el], 0.02),
            Part(f"forearm_{side}", "cone", ((x, 1.2, -0.004), 0.042, (x, 0.975, 0.0), 0.03), "suit", [el], 0.02),
            Part(f"cuff_{side}", "cone", ((x, 1.0, 0.0), 0.034, (x, 0.962, 0.0), 0.034), "armor", [el], 0.008),
            Part(f"hand_{side}", "ellipsoid", ((0.199 * sx, 0.886, -0.006), (0.023, 0.05, 0.04)), "skin", [wr], 0.015),
            Part(f"thumb_{side}", "cone", ((0.186 * sx, 0.918, -0.032), 0.011, (0.182 * sx, 0.877, -0.048), 0.009),
                 "skin", [wr], 0.01),
            Part(f"thigh_{side}", "cone", ((lx, 0.94, 0.0), 0.084, (0.097 * sx, 0.52, 0.0), 0.055), "suit", ["hips", th], 0.04),
            Part(f"kneepad_{side}", "ellipsoid", ((0.097 * sx, 0.5, -0.044), (0.054, 0.068, 0.034)), "armor", [th, kn], 0.01),
            Part(f"calf_{side}", "ellipsoid", ((0.098 * sx, 0.36, 0.022), (0.05, 0.1, 0.05)), "suit", [kn], 0.03),
            Part(f"shin_{side}", "cone", ((0.097 * sx, 0.49, 0.0), 0.055, (0.097 * sx, 0.085, 0.0), 0.035), "suit", [kn], 0.03),
            Part(f"ankle_{side}", "cone", ((0.097 * sx, 0.115, 0.0), 0.04, (0.097 * sx, 0.085, 0.0), 0.04),
                 "armor", [kn], 0.006),
            Part(f"foot_{side}", "cone", ((0.097 * sx, 0.045, 0.018), 0.04, (0.097 * sx, 0.028, -0.125), 0.031),
                 "skin", [ft, kn], 0.02),
            Part(f"heel_{side}", "ellipsoid", ((0.097 * sx, 0.04, 0.024), (0.036, 0.04, 0.04)), "skin", [ft, kn], 0.02),
        ]
    return parts


def eval_body(points, parts):
    d = None
    for part in parts:
        di = part.sdf(points)
        d = di if d is None else smin(d, di, part.k)
    return d


# --- Malha ------------------------------------------------------------------------------

def extract_mesh(sdf_fn, lo, hi, voxel):
    lo = np.asarray(lo, dtype=np.float32)
    hi = np.asarray(hi, dtype=np.float32)
    shape = np.ceil((hi - lo) / voxel).astype(int) + 1
    axes = [lo[i] + np.arange(shape[i], dtype=np.float32) * voxel for i in range(3)]
    gx, gy, gz = np.meshgrid(*axes, indexing="ij")
    pts = np.stack([gx.ravel(), gy.ravel(), gz.ravel()], axis=1)
    values = sdf_fn(pts).reshape(shape)
    verts, faces, normals, _ = measure.marching_cubes(values, 0.0, spacing=(voxel,) * 3)
    verts += lo
    return verts.astype(np.float32), faces.astype(np.uint32), normals.astype(np.float32)


def orient_faces(verts, faces, normals):
    """Garante sentido anti-horário visto de fora (frente no glTF), triângulo a triângulo."""
    v0, v1, v2 = verts[faces[:, 0]], verts[faces[:, 1]], verts[faces[:, 2]]
    face_n = np.cross(v1 - v0, v2 - v0)
    vert_n = normals[faces[:, 0]] + normals[faces[:, 1]] + normals[faces[:, 2]]
    flip = np.einsum("ij,ij->i", face_n, vert_n) < 0
    faces = faces.copy()
    faces[flip] = faces[flip][:, ::-1]
    return faces


def numeric_normals(sdf_fn, pts, eps=0.002):
    offs = np.eye(3, dtype=np.float32) * eps
    grad = np.stack([sdf_fn(pts + offs[i]) - sdf_fn(pts - offs[i]) for i in range(3)], axis=1)
    return grad / np.maximum(np.linalg.norm(grad, axis=1, keepdims=True), 1e-9)


def seg_distance(p, a, b):
    a = np.asarray(a, dtype=np.float32)
    b = np.asarray(b, dtype=np.float32)
    ba = b - a
    t = np.clip(((p - a) @ ba) / max(float(ba @ ba), 1e-9), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ba), axis=1)


def skin_weights(points, allowed_lists):
    """Pesos (até 4 ossos) pela distância aos segmentos dos ossos permitidos de cada vértice."""
    n = len(points)
    dist = np.stack([seg_distance(points, *SEGMENTS[name]) for name in BONE_NAMES], axis=1)
    mask = np.zeros_like(dist, dtype=bool)
    for i, allowed in enumerate(allowed_lists):
        for name in allowed:
            mask[i, BONE_NAMES.index(name)] = True
    dist = np.where(mask, dist, 1e3)
    dmin = dist.min(axis=1, keepdims=True)
    w = np.exp(-(dist - dmin) / 0.022) * mask
    order = np.argsort(-w, axis=1)[:, :4]
    top_w = np.take_along_axis(w, order, axis=1)
    top_w = top_w / np.maximum(top_w.sum(axis=1, keepdims=True), 1e-9)
    return order.astype(np.uint16), top_w.astype(np.float32)


def unpose(verts, normals, joints, weights):
    """Leva os vértices da pose A de volta ao repouso (skinning linear com as rotações inversas)."""
    out_v = np.zeros_like(verts)
    out_n = np.zeros_like(normals)
    for b, name in enumerate(BONE_NAMES):
        w = (weights * (joints == b)).sum(axis=1)[:, None]
        if not np.any(w):
            continue
        side = arm_side(name)
        if side:
            rot, _ = arm_rotation(side, inverse=True)
            out_v += w * pose_points(verts, side, inverse=True)
            out_n += w * (normals @ rot.T)
        else:
            out_v += w * verts
            out_n += w * normals
    out_n /= np.maximum(np.linalg.norm(out_n, axis=1, keepdims=True), 1e-9)
    return out_v.astype(np.float32), out_n.astype(np.float32)


def assign_parts(points, parts):
    d = np.stack([part.sdf(points) for part in parts], axis=1)
    return np.argmin(d, axis=1)


# --- Linhas emissivas do traje ------------------------------------------------------------

def resample(polyline, step=0.006):
    pts = [np.asarray(p, dtype=np.float32) for p in polyline]
    out = [pts[0]]
    for a, b in zip(pts[:-1], pts[1:]):
        n = max(int(np.linalg.norm(b - a) / step), 1)
        for i in range(1, n + 1):
            out.append(a + (b - a) * (i / n))
    return np.array(out, dtype=np.float32)


def ring(center, radii, y, n=40, front_only=False):
    c = np.asarray(center, dtype=np.float32)
    start, end = (math.pi * 0.08, math.pi * 0.92) if front_only else (0.0, 2.0 * math.pi)
    pts = []
    for i in range(n + (0 if front_only else 1)):
        a = start + (end - start) * i / (n - (1 if front_only else 0))
        pts.append((c[0] + math.cos(a) * radii[0], y, c[2] - math.sin(a) * radii[1]))
    return pts


def suit_curves():
    curves = [
        [(-0.15, 1.47, -0.09), (0, 1.335, -0.112), (0.15, 1.47, -0.09)],  # V do peito
        [(0, 1.335, -0.112), (0, 1.12, -0.1)],  # linha central
        [(-0.135, 1.27, -0.075), (0, 1.245, -0.11), (0.135, 1.27, -0.075)],  # faixa das costelas
        [(-0.11, 1.245, -0.09), (0, 1.13, -0.1), (0.11, 1.245, -0.09)],  # losango do abdômen
        [(-0.115, 1.05, -0.088), (0, 1.13, -0.1), (0.115, 1.05, -0.088)],
        ring((0, 1.06, 0), (0.135, 0.1), 1.06),  # cinto
        [(0, 1.5, 0.1), (0, 1.07, 0.1)],  # coluna nas costas
        [(-0.14, 1.45, 0.08), (0, 1.3, 0.11), (0.14, 1.45, 0.08)],  # escápulas
    ]
    for sx in (-1.0, 1.0):
        x = 0.197 * sx
        side = "l" if sx < 0 else "r"
        arm = [
            [(0.245 * sx, 1.49, 0.0), (0.245 * sx, 1.36, 0.0), (0.238 * sx, 1.215, 0.0), (0.228 * sx, 0.985, 0.0)],
            ring((x, 0, 0), (0.05, 0.05), 1.33),  # anel do bíceps
            ring((x, 0, 0), (0.044, 0.044), 1.1),  # anel do antebraço
        ]
        curves += [pose_points(c, side) for c in arm]
        curves += [
            [(0.05 * sx, 0.93, -0.095), (0.13 * sx, 0.64, -0.065)],  # diagonal da coxa
            [(0.17 * sx, 0.93, 0.0), (0.15 * sx, 0.56, 0.0)],  # lateral da coxa
            [(0.125 * sx, 1.035, -0.092), (0.035 * sx, 0.875, -0.1)],  # virilha
            [(0.097 * sx, 0.44, -0.057), (0.097 * sx, 0.11, -0.04)],  # canela
            [(0.06 * sx, 0.42, -0.04), (0.135 * sx, 0.2, -0.02)],  # X da canela
            [(0.135 * sx, 0.42, -0.03), (0.06 * sx, 0.2, -0.03)],
        ]
    return curves


def project_to_surface(sdf_fn, pts, offset=0.0025, iterations=12):
    p = pts.copy()
    for _ in range(iterations):
        d = sdf_fn(p)
        n = numeric_normals(sdf_fn, p)
        p = p - n * (d - offset)[:, None]
    return p, numeric_normals(sdf_fn, p)


def tube_mesh(path, normals, radius=0.0065, sides=6):
    verts, norms, faces = [], [], []
    for i in range(len(path)):
        t = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
        t /= max(np.linalg.norm(t), 1e-9)
        up = normals[i]
        side = np.cross(t, up)
        side /= max(np.linalg.norm(side), 1e-9)
        up = np.cross(side, t)
        for s in range(sides):
            a = 2 * math.pi * s / sides
            dir_ = side * math.cos(a) + up * math.sin(a) * 0.55  # achatado contra o corpo
            verts.append(path[i] + dir_ * radius)
            norms.append(dir_ / max(np.linalg.norm(dir_), 1e-9))
    for i in range(len(path) - 1):
        for s in range(sides):
            a = i * sides + s
            b = i * sides + (s + 1) % sides
            c = a + sides
            d = b + sides
            faces += [(a, c, b), (b, c, d)]
    return np.array(verts, np.float32), np.array(norms, np.float32), np.array(faces, np.uint32)


# --- Olhos (decalques no rosto) -----------------------------------------------------------

def flat_shape(points2d, center, depth=0.002, normal_tilt=0.0):
    """Polígono 2D (plano XY) extrudado de leve, posicionado em `center`, virado para -Z."""
    from itertools import chain  # noqa: F401
    pts = np.asarray(points2d, dtype=np.float32)
    n = len(pts)
    verts, norms, faces = [], [], []
    for z, nz in ((-depth, -1.0), (0.0, 1.0)):
        for x, y in pts:
            verts.append((center[0] + x, center[1] + y, center[2] + z))
            norms.append((0.0, normal_tilt, nz))
    # leque (formas convexas)
    for i in range(1, n - 1):
        faces.append((0, i + 1, i))  # frente (-Z)
        faces.append((n, n + i, n + i + 1))
    return np.array(verts, np.float32), np.array(norms, np.float32), np.array(faces, np.uint32)


def almond(w, h, n=14, tilt=0.0):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x = math.cos(a) * w
        y = math.sin(a) * h * (1.0 if math.sin(a) > 0 else 0.55)
        pts.append((x, y + x * tilt))
    return pts


def circle(r, n=14):
    return [(math.cos(2 * math.pi * i / n) * r, math.sin(2 * math.pi * i / n) * r) for i in range(n)]


def face_parts(sdf_fn):
    """Olhos anime (branco + íris verde + pupila + cílios), sobrancelhas e boca."""
    meshes = []
    for sx in (-1.0, 1.0):
        base = np.array([[0.036 * sx, 1.703, -0.12]], np.float32)
        surf, _ = project_to_surface(sdf_fn, base, offset=0.0015)
        c = surf[0]
        tilt = -0.18 * sx
        meshes.append((flat_shape(almond(0.023, 0.0145, tilt=tilt), c), (0.97, 0.97, 1.0)))
        meshes.append((flat_shape(circle(0.0115), (c[0] + 0.001 * sx, c[1] - 0.0012, c[2] - 0.0008)), (0.22, 0.9, 0.38)))
        meshes.append((flat_shape(circle(0.0055), (c[0] + 0.001 * sx, c[1] - 0.0012, c[2] - 0.0014)), (0.02, 0.08, 0.04)))
        meshes.append((flat_shape(circle(0.0028), (c[0] - 0.004 * sx, c[1] + 0.0035, c[2] - 0.002)), (1.0, 1.0, 1.0)))
        lash = [(x, 0.0145 + 0.004 * (1 - (x / 0.025) ** 2) + x * tilt) for x in np.linspace(-0.025, 0.025, 8)]
        lash += [(x, 0.011 + 0.002 * (1 - (x / 0.025) ** 2) + x * tilt) for x in np.linspace(0.025, -0.025, 8)]
        meshes.append((flat_shape(lash, (c[0], c[1], c[2] - 0.0016)), (0.03, 0.03, 0.05)))
        brow = [(-0.017, 0.0), (0.017, 0.0 + 0.004 * -sx), (0.016, 0.0035 + 0.004 * -sx), (-0.017, 0.0035)]
        meshes.append((flat_shape(brow, (c[0] + 0.002 * sx, c[1] + 0.027, c[2] + 0.002)), (0.9, 0.91, 0.95)))
    mouth_base, _ = project_to_surface(sdf_fn, np.array([[0, 1.632, -0.1]], np.float32), offset=0.0012)
    mouth = [(-0.011, 0.0), (0.011, 0.0), (0.009, 0.0016), (-0.009, 0.0016)]
    meshes.append((flat_shape(mouth, mouth_base[0]), (0.55, 0.3, 0.3)))
    return meshes


# --- Cabelo ------------------------------------------------------------------------------

HEAD = np.array(BONES["head"][0], np.float32)


def hair_sdf(p):
    # Coordenadas locais da cabeça (origem na articulação da cabeça).
    q = p
    cap = sd_ellipsoid(q, (0, 0.105, 0.01), (0.1, 0.098, 0.108))
    face_cut = sd_ellipsoid(q, (0, 0.05, -0.075), (0.086, 0.07, 0.07))
    cap = np.maximum(cap, -face_cut)
    # Mechas curvas: (base, meio, ponta, raio da base). Estilo do conceito: bagunçado,
    # topo levemente para cima e para trás, franja caindo sobre a testa, laterais cobrindo as orelhas.
    strands = [
        ((0, 0.19, 0.0), (0, 0.225, 0.05), (0, 0.225, 0.125), 0.034),
        ((-0.02, 0.19, -0.03), (-0.03, 0.225, -0.01), (-0.06, 0.235, 0.05), 0.028),
        ((0.025, 0.19, -0.03), (0.04, 0.222, -0.005), (0.075, 0.228, 0.05), 0.028),
        ((-0.05, 0.185, 0.01), (-0.09, 0.22, 0.05), (-0.125, 0.215, 0.11), 0.032),
        ((0.05, 0.185, 0.01), (0.09, 0.22, 0.05), (0.13, 0.205, 0.1), 0.032),
        ((0, 0.15, 0.08), (0, 0.13, 0.15), (0, 0.06, 0.185), 0.04),
        ((-0.06, 0.14, 0.07), (-0.09, 0.1, 0.13), (-0.105, 0.03, 0.155), 0.035),
        ((0.06, 0.14, 0.07), (0.09, 0.1, 0.13), (0.105, 0.03, 0.15), 0.035),
        ((0, 0.08, 0.095), (0, 0.02, 0.12), (0.005, -0.045, 0.12), 0.034),
        ((-0.05, 0.07, 0.09), (-0.07, 0.0, 0.11), (-0.075, -0.05, 0.1), 0.03),
        ((0.05, 0.07, 0.09), (0.07, 0.0, 0.11), (0.075, -0.05, 0.1), 0.03),
        ((-0.09, 0.12, 0.0), (-0.112, 0.07, 0.0), (-0.108, 0.01, -0.012), 0.03),
        ((0.09, 0.12, 0.0), (0.112, 0.07, 0.0), (0.108, 0.01, -0.012), 0.03),
        ((-0.09, 0.1, 0.04), (-0.116, 0.05, 0.06), (-0.112, -0.01, 0.065), 0.03),
        ((0.09, 0.1, 0.04), (0.116, 0.05, 0.06), (0.112, -0.01, 0.065), 0.03),
        # franja
        ((0, 0.17, -0.07), (0.005, 0.14, -0.112), (0.016, 0.093, -0.118), 0.026),
        ((-0.035, 0.165, -0.07), (-0.045, 0.135, -0.11), (-0.062, 0.103, -0.107), 0.024),
        ((0.035, 0.165, -0.07), (0.046, 0.135, -0.11), (0.058, 0.108, -0.107), 0.024),
        ((-0.065, 0.155, -0.055), (-0.086, 0.12, -0.09), (-0.097, 0.078, -0.086), 0.024),
        ((0.065, 0.155, -0.055), (0.086, 0.12, -0.09), (0.097, 0.08, -0.082), 0.024),
    ]
    d = cap
    for a, m, b, r in strands:
        d = smin(d, sd_round_cone(q, a, r, m, r * 0.6), 0.012)
        d = smin(d, sd_round_cone(q, m, r * 0.6, b, 0.003), 0.008)
    return d


# --- glTF -------------------------------------------------------------------------------

class GltfWriter:
    def __init__(self):
        self.json = {"asset": {"version": "2.0", "generator": "REBELLIUM gen_character.py"},
                     "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [],
                     "materials": [], "accessors": [], "bufferViews": [], "buffers": []}
        self.bin = bytearray()

    def _view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        view = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        if target:
            view["target"] = target
        self.bin += data
        self.json["bufferViews"].append(view)
        return len(self.json["bufferViews"]) - 1

    def accessor(self, array, kind, component, target=None, minmax=False):
        array = np.ascontiguousarray(array)
        view = self._view(array.tobytes(), target)
        acc = {"bufferView": view, "componentType": component, "count": int(array.shape[0]), "type": kind}
        if minmax:
            acc["min"] = array.min(axis=0).tolist()
            acc["max"] = array.max(axis=0).tolist()
        self.json["accessors"].append(acc)
        return len(self.json["accessors"]) - 1

    def material(self, name, color, emissive=None):
        mat = {"name": name, "pbrMetallicRoughness": {"baseColorFactor": [*color, 1.0], "metallicFactor": 0.0,
                                                         "roughnessFactor": 0.8}}
        if emissive:
            mat["emissiveFactor"] = list(emissive)
        self.json["materials"].append(mat)
        return len(self.json["materials"]) - 1

    def mesh(self, name, verts, normals, faces, colors=None, joints=None, weights=None, material=None):
        attrs = {"POSITION": self.accessor(verts, "VEC3", 5126, 34962, True),
                 "NORMAL": self.accessor(normals, "VEC3", 5126, 34962)}
        if colors is not None:
            attrs["COLOR_0"] = self.accessor(colors.astype(np.float32), "VEC4", 5126, 34962)
        if joints is not None:
            attrs["JOINTS_0"] = self.accessor(joints.astype(np.uint16), "VEC4", 5123, 34962)
            attrs["WEIGHTS_0"] = self.accessor(weights.astype(np.float32), "VEC4", 5126, 34962)
        faces = orient_faces(verts, faces, normals)
        prim = {"attributes": attrs, "indices": self.accessor(faces.reshape(-1).astype(np.uint32), "SCALAR", 5125, 34963)}
        if material is not None:
            prim["material"] = material
        self.json["meshes"].append({"name": name, "primitives": [prim]})
        return len(self.json["meshes"]) - 1

    def node(self, data, root=False):
        self.json["nodes"].append(data)
        index = len(self.json["nodes"]) - 1
        if root:
            self.json["scenes"][0]["nodes"].append(index)
        return index

    def save(self, path):
        while len(self.bin) % 4:
            self.bin.append(0)
        self.json["buffers"] = [{"byteLength": len(self.bin)}]
        js = json.dumps(self.json, separators=(",", ":")).encode()
        while len(js) % 4:
            js += b" "
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(path, "wb") as f:
            f.write(struct.pack("<4sII", b"glTF", 2, total))
            f.write(struct.pack("<I4s", len(js), b"JSON"))
            f.write(js)
            f.write(struct.pack("<I4s", len(self.bin), b"BIN\x00"))
            f.write(self.bin)


def main():
    os.makedirs(OUT, exist_ok=True)
    parts = body_parts()
    sdf = lambda p: eval_body(p, parts)  # noqa: E731

    # Corpo
    verts, faces, normals = extract_mesh(sdf, (-0.52, -0.02, -0.19), (0.52, 1.84, 0.19), VOXEL)
    normals = numeric_normals(sdf, verts)
    part_idx = assign_parts(verts, parts)
    # Cor = média ponderada das partes próximas (divisas suaves, sem serrilhado).
    # Alfa codifica o material: 1 = traje, 0.5 = armadura, 0 = pele.
    alpha = {"suit": 1.0, "armor": 0.5, "skin": 0.0}
    dists = np.stack([part.sdf(verts) for part in parts], axis=1)
    soft = np.exp(-(dists - dists.min(axis=1, keepdims=True)) / 0.0025)
    soft /= soft.sum(axis=1, keepdims=True)
    palette = np.array([[*MATERIALS[p.material], alpha[p.material]] for p in parts], np.float32)
    colors = (soft @ palette).astype(np.float32)
    joints, weights = skin_weights(verts, [parts[i].bones for i in part_idx])
    verts, normals = unpose(verts, normals, joints, weights)
    print(f"corpo: {len(verts)} vértices, {len(faces)} triângulos")

    # Linhas do traje
    line_v, line_n, line_f, line_allowed = [], [], [], []
    offset = 0
    for curve in suit_curves():
        path = resample(curve)
        path, path_n = project_to_surface(sdf, path)
        v, n, f = tube_mesh(path, path_n)
        idx = assign_parts(v, parts)
        line_allowed += [parts[i].bones for i in idx]
        line_v.append(v)
        line_n.append(n)
        line_f.append(f + offset)
        offset += len(v)
    line_v = np.concatenate(line_v)
    line_n = np.concatenate(line_n)
    line_f = np.concatenate(line_f)
    line_j, line_w = skin_weights(line_v, line_allowed)
    line_v, line_n = unpose(line_v, line_n, line_j, line_w)
    print(f"linhas: {len(line_v)} vértices")

    # Rosto
    face_v, face_n, face_f, face_c = [], [], [], []
    offset = 0
    for (v, n, f), color in face_parts(sdf):
        face_v.append(v)
        face_n.append(n)
        face_f.append(f + offset)
        face_c.append(np.tile([*color, 1.0], (len(v), 1)))
        offset += len(v)
    face_v = np.concatenate(face_v)
    face_n = np.concatenate(face_n)
    face_f = np.concatenate(face_f)
    face_c = np.concatenate(face_c).astype(np.float32)
    head_idx = BONE_NAMES.index("head")
    face_j = np.tile([head_idx, 0, 0, 0], (len(face_v), 1)).astype(np.uint16)
    face_w = np.tile([1.0, 0, 0, 0], (len(face_v), 1)).astype(np.float32)

    w = GltfWriter()
    m_body = w.material("body", (1, 1, 1))
    m_lines = w.material("suit_lines", (0.48, 0.22, 1.0), (0.48, 0.22, 1.0))
    m_face = w.material("face", (1, 1, 1))
    # Esqueleto: nós com translação relativa ao pai.
    node_of = {}
    for name in BONE_NAMES:
        pos, parent = BONES[name]
        local = np.array(pos) - (np.array(BONES[parent][0]) if parent else 0.0)
        node_of[name] = w.node({"name": name, "translation": [float(x) for x in local]})
    for name in BONE_NAMES:
        children = [node_of[c] for c in BONE_NAMES if BONES[c][1] == name]
        if children:
            w.json["nodes"][node_of[name]]["children"] = children
    armature = w.node({"name": "Armature", "children": [node_of["hips"]]}, root=True)
    ibm = []
    for name in BONE_NAMES:
        m = np.eye(4, dtype=np.float32)
        m[:3, 3] = -np.array(BONES[name][0], np.float32)
        ibm.append(m.T.reshape(-1))  # coluna-major
    ibm_acc = w.accessor(np.array(ibm, np.float32), "MAT4", 5126)
    w.json["skins"] = [{"name": "Skin", "joints": [node_of[n] for n in BONE_NAMES], "skeleton": node_of["hips"],
                        "inverseBindMatrices": ibm_acc}]
    body_mesh = w.mesh("Body", verts, normals, faces, colors, joints, weights, m_body)
    lines_mesh = w.mesh("SuitLines", line_v, line_n, line_f, None, line_j, line_w, m_lines)
    face_mesh = w.mesh("Face", face_v, face_n, face_f, face_c, face_j, face_w, m_face)
    for name, mesh in (("Body", body_mesh), ("SuitLines", lines_mesh), ("Face", face_mesh)):
        w.node({"name": name, "mesh": mesh, "skin": 0}, root=True)
    _ = armature
    w.save(os.path.join(OUT, "body.glb"))

    # Cabelo (sem pele), em coordenadas locais da cabeça.
    hv, hf, hn = extract_mesh(hair_sdf, (-0.2, -0.07, -0.17), (0.2, 0.32, 0.24), HAIR_VOXEL)
    hn = numeric_normals(hair_sdf, hv)
    hw = GltfWriter()
    m_hair = hw.material("hair", (0.93, 0.94, 0.98))
    hmesh = hw.mesh("Hair", hv, hn, hf, None, None, None, m_hair)
    hw.node({"name": "Hair", "mesh": hmesh}, root=True)
    hw.save(os.path.join(OUT, "hair.glb"))
    print(f"cabelo: {len(hv)} vértices, {len(hf)} triângulos")


if __name__ == "__main__":
    main()
