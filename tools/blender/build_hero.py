"""Monta o personagem do jogo no Blender: modelo, texturas e animações.

Gera:
  art/character/hero.blend     — arquivo editável (abra no Blender para ver/ajustar as animações)
  assets/character/hero.glb    — o que o jogo carrega (malha + esqueleto + todas as animações)

Base: "HairSample_Male", modelo de exemplo do VRoid Studio (pixiv), licença CC0 (uso comercial,
edição e redistribuição livres), baixado de github.com/madjin/vrm-samples na primeira execução
(cache em tools/.cache/). O script:
  - remove as roupas originais (moletom, calça, sapatos) e os ossos do capuz;
  - pinta o corpo como um traje justo azul-marinho de gola alta (costuras, barra, emblema no
    peito); mãos e pés ficam de pele (descalço, como na arte de referência);
  - cabelo branco, íris cinza, pinta embaixo do olho esquerdo;
  - cria as animações (tools/blender/hero_animations.py) como Actions do Blender.

Uso (qualquer um dos dois):
  blender -b -P tools/blender/build_hero.py        # Blender instalado
  python3 tools/blender/build_hero.py              # módulo bpy do pip (pip install bpy==4.2.0)

Depois de editar o hero.blend no Blender, exporte de novo: aba Scripting → "exportar_para_o_jogo.py" →
Run Script (ou tools/blender/export_hero.py).
ATENÇÃO: rodar este script de novo recria o hero.blend do zero (perde edições manuais).
"""
import json
import math
import os
import shutil
import struct
import sys
import urllib.request

import bpy  # noqa: I001 (bpy precisa vir antes de bmesh/mathutils)
import bmesh
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import export_hero  # noqa: E402
import hero_animations  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CACHE = os.path.join(ROOT, "tools", ".cache")
SOURCE_URL = "https://raw.githubusercontent.com/madjin/vrm-samples/master/vroid/beta/HairSample_Male.vrm"
SOURCE = os.path.join(CACHE, "HairSample_Male.vrm")
OUT_BLEND = os.path.join(ROOT, "art", "character", "hero.blend")
OUT_GLB = os.path.join(ROOT, "assets", "character", "hero.glb")

DROP_MATERIALS = ("CLOTH",)
DROP_BONES = ("J_Sec_C_Hood", "J_Sec_L_HoodString", "J_Sec_R_HoodString")

# --- Cores (sRGB 0–1) --------------------------------------------------------------------------
SUIT = np.array([0.105, 0.11, 0.165])         # azul-marinho escuro do traje
SEAM = np.array([0.06, 0.063, 0.098])         # costuras (mais escuras)
HEM_SHADOW = np.array([0.075, 0.078, 0.12])   # sombra da barra da blusa
EMBLEM_METAL = np.array([0.86, 0.88, 0.92])
EMBLEM_DARK = np.array([0.16, 0.17, 0.24])
MOLE = np.array([0.33, 0.25, 0.27])

# --- Medidas do corpo em T-pose (espaço do Blender: x = esquerda(-)/direita(+) do personagem,
# y = frente, z = cima; metros) ------------------------------------------------------------------
COLLAR_TOP = 1.515
WRIST_X = 0.598
ANKLE_Z = 0.138
WAIST_Z = 0.985
ARM_Z, ARM_Y = 1.40, 0.005
SEAM_HALF_WIDTH = 0.0016
SEAM_SOFTNESS = 0.0012
EMBLEM_CENTER = (-0.078, 1.338)  # (x, z) no peito esquerdo
EMBLEM_SIZE = (0.017, 0.021)     # meia-largura, meia-altura


def log(*args):
    print("[build_hero]", *args, flush=True)


# --- Importação ---------------------------------------------------------------------------------

def glb_json(path):
    data = open(path, "rb").read()
    length = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + length])


def import_source():
    os.makedirs(CACHE, exist_ok=True)
    if not os.path.exists(SOURCE):
        log("baixando", SOURCE_URL)
        urllib.request.urlretrieve(SOURCE_URL, SOURCE)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    # O VRM é um glb com extensões extras; o importador de glTF do Blender lê a parte padrão.
    tmp = os.path.join(CACHE, "_hero_source.glb")
    shutil.copy(SOURCE, tmp)
    bpy.ops.import_scene.gltf(filepath=tmp)
    os.remove(tmp)
    # Nomes das blend shapes (piscar etc.): o VRoid guarda em primitives[].extras.targetNames.
    gltf = glb_json(SOURCE)
    for mesh in gltf["meshes"]:
        names = mesh["primitives"][0].get("extras", {}).get("targetNames")
        obj_name = mesh["name"].replace(".baked", "")
        obj = bpy.data.objects.get(obj_name)
        if not names or obj is None or obj.data.shape_keys is None:
            continue
        for i, key in enumerate(obj.data.shape_keys.key_blocks[1:]):
            if i < len(names):
                key.name = names[i]


def armature():
    return next(o for o in bpy.data.objects if o.type == "ARMATURE")


def strip_clothes():
    body = bpy.data.objects["Body"]
    drop = [i for i, m in enumerate(body.data.materials) if any(k in m.name for k in DROP_MATERIALS)]
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in drop], context="FACES")
    bm.to_mesh(body.data)
    bm.free()
    for i in sorted(drop, reverse=True):
        body.data.materials.pop(index=i)
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)
    # Ossos do capuz (só moviam o moletom).
    arm = armature()
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in list(arm.data.edit_bones):
        if bone.name.startswith(DROP_BONES):
            arm.data.edit_bones.remove(bone)
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            for group in list(obj.vertex_groups):
                if group.name.startswith(DROP_BONES):
                    obj.vertex_groups.remove(group)


# --- Pintura em espaço UV a partir de posições 3D ------------------------------------------------

def image_of(material_name):
    mat = next(m for m in bpy.data.materials if material_name in m.name)
    node = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
    return node.image


def read_pixels(img):
    w, h = img.size
    arr = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(arr)
    return arr.reshape(h, w, 4)


def write_pixels(img, arr):
    img.pixels.foreach_set(arr.astype(np.float32).ravel())
    img.update()
    img.pack()


def paint_mesh(obj, material_key, shade, dilate=3, write=True):
    """Para cada texel coberto pelas faces com o material, chama shade(pos3d, rgba) → rgba."""
    img = image_of(material_key)
    src = read_pixels(img)
    out = src.copy()
    h, w = src.shape[:2]
    painted = np.zeros((h, w), bool)
    mesh = obj.data
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers.active.data
    slots = {i for i, m in enumerate(mesh.materials) if material_key in m.name}
    co = np.array([v.co[:] for v in mesh.vertices], np.float32)
    for tri in mesh.loop_triangles:
        if tri.material_index not in slots:
            continue
        t2 = np.array([uv[l].uv[:] for l in tri.loops], np.float32) * np.array([w, h], np.float32)
        t3 = co[list(tri.vertices)]
        _raster(t2, t3, src, out, painted, shade)
    for _ in range(dilate):
        grow = painted.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted = np.roll(painted, (dy, dx), (0, 1))
            fill = shifted & ~grow
            out[fill] = np.roll(out, (dy, dx), (0, 1))[fill]
            grow |= fill
        painted = grow
    if write:
        write_pixels(img, out)


def _raster(t2, t3, src, out, painted, shade):
    h, w = painted.shape
    lo = np.maximum(np.floor(t2.min(axis=0) - 1).astype(int), 0)
    hi = np.minimum(np.ceil(t2.max(axis=0) + 1).astype(int), [w - 1, h - 1])
    if hi[0] < lo[0] or hi[1] < lo[1]:
        return
    xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
    q = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], axis=1).astype(np.float32)
    a, b, c = t2
    v0, v1 = b - a, c - a
    den = v0[0] * v1[1] - v1[0] * v0[1]
    if abs(den) < 1e-8:
        return
    r = q - a
    l1 = (r[:, 0] * v1[1] - v1[0] * r[:, 1]) / den
    l2 = (v0[0] * r[:, 1] - r[:, 0] * v0[1]) / den
    bary = np.stack([1 - l1 - l2, l1, l2], axis=1)
    # Inclui texels até ~1 px fora da aresta (costuras do UV), com a posição presa ao triângulo.
    edge = np.array([np.linalg.norm(c - b), np.linalg.norm(a - c), np.linalg.norm(b - a)]) + 1e-6
    inside = np.all(bary * (abs(den) / edge) > -1.0, axis=1)
    if not np.any(inside):
        return
    bary = np.clip(bary[inside], 0, None)
    bary /= bary.sum(axis=1, keepdims=True)
    p3 = bary @ t3
    xi = xs.ravel()[inside]
    yi = ys.ravel()[inside]
    out[yi, xi] = shade(p3, src[yi, xi])
    painted[yi, xi] = True


# --- Traje ---------------------------------------------------------------------------------------

def _polyline_distance(p2, pts):
    pts = np.asarray(pts, np.float32)
    best = np.full(len(p2), 1e3, np.float32)
    for a, b in zip(pts[:-1], pts[1:]):
        ab = b - a
        t = np.clip(((p2 - a) @ ab) / float(ab @ ab), 0.0, 1.0)
        best = np.minimum(best, np.linalg.norm(p2 - (a + t[:, None] * ab), axis=1))
    return best


FOOT_SKIN = None  # tom de pele das mãos (medido na textura antes de pintar)


def measure_hand_skin(body):
    found = []

    def collect(p, rgba):
        mask = np.abs(p[:, 0]) > WRIST_X + 0.03
        if np.any(mask):
            found.append(rgba[mask, :3])
        return rgba

    paint_mesh(body, "Body_00_SKIN", collect, dilate=0, write=False)
    return np.median(np.concatenate(found), axis=0)


def suit_shade(p, rgba):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    arm = (ax > 0.16) & (z > 1.3)
    torso = ~arm & (z > WAIST_Z - 0.03)
    leg = ~arm & ~torso
    seam = np.full(len(p), 1e3, np.float32)

    def add(mask, dist):
        nonlocal seam
        seam = np.where(mask, np.minimum(seam, dist), seam)

    axz = np.stack([ax, z], axis=1)
    # Raglan: da base do pescoço até a axila, na frente e nas costas.
    add(torso | arm, _polyline_distance(axz, [(0.06, 1.475), (0.125, 1.39), (0.165, 1.335)]))
    # Costura lateral do tronco e barra da blusa.
    add(torso & (ax > 0.08), np.abs(y - 0.0))
    add(torso | leg, np.abs(z - WAIST_Z))
    # Gola alta: dobra perto do topo.
    add(~arm & (z > 1.44), np.abs(z - (COLLAR_TOP - 0.022)))
    # Manga: costura embaixo do braço e punho.
    add(arm & (z < ARM_Z), np.abs(y - ARM_Y))
    add(arm, np.abs(ax - (WRIST_X - 0.018)))
    # Calça: costura lateral externa e barra no tornozelo.
    leg_center = np.interp(z, [0.12, 0.58, 0.98], [0.05, 0.062, 0.088])
    add(leg & (ax > leg_center + 0.03), np.abs(y - 0.0))
    add(leg, np.abs(z - (ANKLE_Z + 0.012)))
    line = np.clip(1.0 - (seam - SEAM_HALF_WIDTH) / SEAM_SOFTNESS, 0.0, 1.0)[:, None]
    color = SUIT * (1 - line) + SEAM * line
    # Sombra suave logo abaixo da barra (a blusa sobrepõe a calça).
    hem = np.clip(1.0 - (WAIST_Z - z) / 0.018, 0.0, 1.0) * (z < WAIST_Z)
    color = color * (1 - 0.5 * hem[:, None]) + HEM_SHADOW * 0.5 * hem[:, None]
    color = _emblem(p, color)
    skin = (z > COLLAR_TOP) | (ax > WRIST_X) | (z < ANKLE_Z)
    feet = z < ANKLE_Z
    # Pés descalços: a textura original tinha meias pintadas; tom de pele com sombra na sola.
    sole = np.clip(z / ANKLE_Z, 0.0, 1.0)[:, None]
    skin_color = np.where(feet[:, None], FOOT_SKIN * (0.82 + 0.1 * sole), rgba[:, :3])
    result = rgba.copy()
    result[:, :3] = np.where(skin[:, None], skin_color, color)
    result[:, 3] = 1.0
    return result


def _emblem(p, color):
    """Emblema original: escudo prateado com um chevron (V) escuro, no peito esquerdo."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    u = (x - EMBLEM_CENTER[0]) / EMBLEM_SIZE[0]
    v = (z - EMBLEM_CENTER[1]) / EMBLEM_SIZE[1]
    front = y > 0.04
    # Escudo: topo reto, laterais que afinam até a ponta de baixo.
    half_width = np.where(v > 0.2, 1.0, np.clip((v + 1.0) / 1.2, 0.0, 1.0))
    shield = front & (np.abs(u) <= half_width) & (v <= 1.0) & (v >= -1.0)
    inner = front & (np.abs(u) <= half_width - 0.22) & (v <= 0.78) & (v >= -0.72)
    chevron = inner & (np.abs(v - (0.35 - np.abs(u) * 0.9)) < 0.17)
    color = np.where(shield[:, None], EMBLEM_METAL, color)
    color = np.where((inner & ~chevron)[:, None], EMBLEM_DARK, color)
    return color


# --- Cabelo, olhos e rosto -----------------------------------------------------------------------

def recolor_white(material_key, dark, light):
    img = image_of(material_key)
    a = read_pixels(img)
    lum = a[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)
    mask = a[..., 3] > 0.5
    lo, hi = np.percentile(lum[mask], [5, 95]) if np.any(mask) else (0.0, 1.0)
    t = np.clip((lum - lo) / max(hi - lo, 1e-3), 0, 1)[..., None]
    a[..., :3] = np.asarray(dark) * (1 - t) + np.asarray(light) * t
    write_pixels(img, a)


def recolor_iris():
    img = image_of("EyeIris")
    a = read_pixels(img)
    lum = a[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)
    t = np.clip(lum * 1.4, 0, 1)[..., None]
    a[..., :3] = np.array([0.2, 0.21, 0.25]) * (1 - t) + np.array([0.72, 0.74, 0.78]) * t
    write_pixels(img, a)


def paint_mole():
    face = bpy.data.objects["Face"]
    iris = [i for i, m in enumerate(face.data.materials) if "EyeIris" in m.name]
    pts = [face.data.vertices[v].co for poly in face.data.polygons if poly.material_index in iris
           for v in poly.vertices]
    left = [c for c in pts if c.x < 0]
    eye = sum(left, Vector()) / max(len(left), 1)
    target = np.array([eye.x - 0.013, eye.z - 0.03], np.float32)  # abaixo e para fora do olho
    log("pinta em", target, "olho", tuple(round(v, 3) for v in eye))

    def shade(p, rgba):
        d = np.linalg.norm(p[:, [0, 2]] - target, axis=1)
        k = np.clip(1.0 - (d - 0.0011) / 0.0006, 0.0, 1.0) * (p[:, 1] > eye.y - 0.03)
        out = rgba.copy()
        out[:, :3] = rgba[:, :3] * (1 - k[:, None]) + MOLE * k[:, None]
        return out

    paint_mesh(face, "Face_00_SKIN", shade, dilate=0)


# --- Cena de visualização --------------------------------------------------------------------------

def setup_scene():
    scene = bpy.context.scene
    scene.render.fps = hero_animations.FPS
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(cam)
    cam.location = (2.6, 3.4, 1.4)
    cam.rotation_euler = (math.radians(82), 0, math.radians(142))
    cam.data.lens = 40
    scene.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(150))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world


def export_glb():
    export_hero.export(OUT_GLB)


def embed_export_script():
    """Coloca o exportador dentro do .blend (aba Scripting → Run Script)."""
    text = bpy.data.texts.new("exportar_para_o_jogo.py")
    text.from_string(open(os.path.join(HERE, "export_hero.py"), encoding="utf-8").read())


def main():
    import_source()
    strip_clothes()
    log("pintando o traje")
    global FOOT_SKIN
    FOOT_SKIN = measure_hand_skin(bpy.data.objects["Body"])
    log("pele das mãos", FOOT_SKIN)
    paint_mesh(bpy.data.objects["Body"], "Body_00_SKIN", suit_shade)
    recolor_white("HAIR", (0.66, 0.68, 0.76), (0.97, 0.97, 1.0))
    recolor_white("FaceBrow", (0.55, 0.56, 0.62), (0.8, 0.81, 0.86))
    recolor_iris()
    paint_mole()
    log("criando animações")
    hero_animations.build(armature())
    setup_scene()
    embed_export_script()
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
    log("ok", OUT_BLEND)
    export_glb()


if __name__ == "__main__":
    main()
