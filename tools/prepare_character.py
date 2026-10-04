"""Prepara o personagem a partir de um modelo VRM (glTF) pronto, licença CC0.

Fonte: "Sakurada Fumiriya", modelo de exemplo do VRoid Studio (pixiv), licença CC0
(uso comercial, edição e redistribuição livres). Baixado do espelho público
github.com/madjin/vrm-samples na primeira execução (cache em tools/.cache/).

O que o script faz (tudo offline, resultado em assets/character/hero.glb):
  - remove as roupas originais (camisa, gravata, calça, sapatos) e as texturas que não usamos;
  - pinta o corpo como um traje preto justo com linhas roxas emissivas. As linhas são definidas
    em 3D (sobre o corpo em T-pose) e "assadas" na textura pelo mapa UV, então ficam nítidas;
    mãos e pés continuam pele (descalço, como na arte de referência);
  - cabelo e sobrancelhas brancos, íris verdes;
  - grava uma textura de emissão para as linhas (lida pelo shader toon do jogo).

Uso: python3 tools/prepare_character.py   (requer numpy e Pillow)
"""
import io
import json
import math
import os
import struct
import urllib.request

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CACHE = os.path.join(ROOT, "tools", ".cache")
SOURCE_URL = "https://raw.githubusercontent.com/madjin/vrm-samples/master/vroid/beta/Sakurada_Fumiriya.vrm"
SOURCE = os.path.join(CACHE, "Sakurada_Fumiriya.vrm")
OUT = os.path.join(ROOT, "assets", "character", "hero.glb")
OUT_EMISSION = os.path.join(ROOT, "assets", "character", "hero_suit_emission.png")

DROP_MATERIALS = ("Tops", "AccessoryNeck", "Bottoms", "Shoes")


# --- glTF ---------------------------------------------------------------------------------

def load_glb(path):
    data = open(path, "rb").read()
    json_len = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + json_len])
    bin_start = 20 + json_len + 8
    bin_len = struct.unpack("<I", data[20 + json_len:24 + json_len])[0]
    return gltf, data[bin_start:bin_start + bin_len]


COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
DTYPES = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}


def read_accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    dtype = np.dtype(DTYPES[acc["componentType"]])
    n = COMPONENTS[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 0) or dtype.itemsize * n
    raw = np.frombuffer(binary, dtype=np.uint8, count=stride * (acc["count"] - 1) + dtype.itemsize * n, offset=start)
    rows = np.lib.stride_tricks.as_strided(raw, shape=(acc["count"], dtype.itemsize * n), strides=(stride, 1))
    out = np.ascontiguousarray(rows).view(dtype).reshape(acc["count"], n)
    if acc.get("normalized"):
        out = out.astype(np.float32) / np.iinfo(dtype).max
    return out


def read_image(gltf, binary, index):
    view = gltf["bufferViews"][gltf["images"][index]["bufferView"]]
    start = view.get("byteOffset", 0)
    return Image.open(io.BytesIO(binary[start:start + view["byteLength"]])).convert("RGBA")


def save_glb(gltf, binary, images, path):
    """Regrava o glb só com os bufferViews usados; `images` substitui imagens por índice."""
    used_views = set()
    for acc in gltf["accessors"]:
        if "bufferView" in acc:
            used_views.add(acc["bufferView"])
    blob = bytearray()
    remap = {}
    new_views = []

    def push(data):
        while len(blob) % 4:
            blob.append(0)
        offset = len(blob)
        blob.extend(data)
        return offset

    for i, view in enumerate(gltf["bufferViews"]):
        if i not in used_views:
            continue
        start = view.get("byteOffset", 0)
        new = dict(view)
        new["byteOffset"] = push(binary[start:start + view["byteLength"]])
        remap[i] = len(new_views)
        new_views.append(new)
    for acc in gltf["accessors"]:
        if "bufferView" in acc:
            acc["bufferView"] = remap[acc["bufferView"]]
    for i, image in enumerate(gltf["images"]):
        buf = io.BytesIO()
        images[i].save(buf, "PNG", optimize=True)
        data = buf.getvalue()
        image.clear()
        image.update({"name": f"image_{i}", "mimeType": "image/png", "bufferView": len(new_views)})
        new_views.append({"buffer": 0, "byteOffset": push(data), "byteLength": len(data)})
    while len(blob) % 4:
        blob.append(0)
    gltf["bufferViews"] = new_views
    gltf["buffers"] = [{"byteLength": len(blob)}]
    text = json.dumps(gltf, separators=(",", ":")).encode()
    text += b" " * ((4 - len(text) % 4) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(text) + 8 + len(blob)))
        f.write(struct.pack("<II", len(text), 0x4E4F534A) + text)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


def prune(gltf, binary):
    """Remove roupas, malhas extras e imagens sem uso; devolve as imagens restantes (PIL)."""
    for mesh in gltf["meshes"]:
        # Nomes das blend shapes (piscar etc.): o VRoid guarda por primitiva; o Godot lê na malha.
        names = mesh["primitives"][0].get("extras", {}).get("targetNames")
        if names:
            mesh.setdefault("extras", {})["targetNames"] = names
        mesh["primitives"] = [p for p in mesh["primitives"]
                              if not any(k in gltf["materials"][p["material"]]["name"] for k in DROP_MATERIALS)]
    # Texturas usadas só como cor base (o shader toon do jogo não usa normal map / matcap).
    used_textures = set()
    for mesh in gltf["meshes"]:
        for p in mesh["primitives"]:
            tex = gltf["materials"][p["material"]].get("pbrMetallicRoughness", {}).get("baseColorTexture")
            if tex:
                used_textures.add(tex["index"])
    for mat in gltf["materials"]:
        for key in ("normalTexture", "emissiveTexture", "occlusionTexture"):
            mat.pop(key, None)
        pbr = mat.get("pbrMetallicRoughness", {})
        pbr.pop("metallicRoughnessTexture", None)
        if pbr.get("baseColorTexture", {}).get("index") not in used_textures:
            pbr.pop("baseColorTexture", None)
    used_images = sorted({gltf["textures"][t]["source"] for t in used_textures})
    image_map = {old: new for new, old in enumerate(used_images)}
    tex_map = {}
    new_textures = []
    for t in sorted(used_textures):
        tex = dict(gltf["textures"][t])
        tex["source"] = image_map[tex["source"]]
        tex_map[t] = len(new_textures)
        new_textures.append(tex)
    for mat in gltf["materials"]:
        tex = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if tex:
            tex["index"] = tex_map[tex["index"]]
    images = [read_image(gltf, binary, i) for i in used_images]
    gltf["images"] = [gltf["images"][i] for i in used_images]
    gltf["textures"] = new_textures
    # A extensão VRM referencia texturas/miniatura antigas; o jogo não a usa.
    gltf.pop("extensions", None)
    gltf["extensionsUsed"] = [e for e in gltf.get("extensionsUsed", []) if e != "VRM"]
    return images


# --- Traje: linhas definidas em 3D (T-pose, frente = -Z, direita = +X) ------------------------

SUIT = np.array([0.085, 0.085, 0.11])
ARMOR = np.array([0.2, 0.2, 0.24])
LINE = np.array([0.5, 0.3, 1.0])
LINE_GLOW = np.array([0.3, 0.1, 1.0])  # emissão mais saturada (o brilho clareia)
GREEN = np.array([0.2, 1.0, 0.3])
CYAN = np.array([0.1, 0.7, 1.0])
FOOT_SKIN = np.array([0.98, 0.86, 0.78])
LINE_HALF_WIDTH = 0.0042  # m
LINE_SOFTNESS = 0.0016    # m (antisserrilhado)

TORSO_Z = -0.01
ARM_Y, ARM_Z = 1.54, -0.01
NECK_TOP = 1.595
WRIST_X = 0.6
ANKLE_Y = 0.15


def polyline_distance_2d(p2, pts):
    pts = np.asarray(pts, np.float32)
    best = np.full(len(p2), 1e3, np.float32)
    for a, b in zip(pts[:-1], pts[1:]):
        ab = b - a
        t = np.clip(((p2 - a) @ ab) / float(ab @ ab), 0.0, 1.0)
        best = np.minimum(best, np.linalg.norm(p2 - (a + t[:, None] * ab), axis=1))
    return best


def mirror(pts):
    return [(-x, y) for x, y in pts]


def suit_layers(p):
    """Para pontos da superfície (N,3): distância às linhas, máscaras de armadura e de dispositivos."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    xy = p[:, :2]
    axy = np.stack([ax, y], axis=1)
    far = np.full(len(p), 1e3, np.float32)
    d = far.copy()
    arm = (ax > 0.17) & (y > 1.42)
    torso = ~arm & (y > 1.08)
    leg = ~arm & ~torso
    front = z < TORSO_Z
    back = ~front

    def add(mask, dist):
        nonlocal d
        d = np.where(mask, np.minimum(d, dist), d)

    # Tronco (frente): V do peito, linha central, faixa das costelas, losango do abdômen.
    add(torso & front, polyline_distance_2d(xy, [(-0.13, 1.5), (0, 1.36), (0.13, 1.5)]))
    add(torso & front, polyline_distance_2d(xy, [(0, 1.36), (0, 1.16)]))
    add(torso & front, polyline_distance_2d(xy, [(-0.125, 1.31), (0, 1.285), (0.125, 1.31)]))
    add(torso & front, polyline_distance_2d(xy, [(-0.095, 1.27), (0, 1.18), (0.095, 1.27)]))
    add(torso & front, polyline_distance_2d(xy, [(-0.1, 1.11), (0, 1.18), (0.1, 1.11)]))
    # Costas: coluna e escápulas.
    add(torso & back, polyline_distance_2d(xy, [(0, 1.56), (0, 1.14)]))
    add(torso & back, polyline_distance_2d(xy, [(-0.12, 1.5), (0, 1.39), (0.12, 1.5)]))
    # Cinto e gola.
    add(torso, np.abs(y - 1.115))
    add(torso & (ax < 0.075), np.abs(y - (NECK_TOP - 0.02)))
    # Braços (ao longo de X): linha de cima (vira a lateral externa com o braço abaixado) e anéis.
    dy, dz = y - ARM_Y, z - ARM_Z
    add(arm & (dy > 0), np.abs(dz))
    add(arm, np.abs(ax - 0.29))
    add(arm, np.abs(ax - 0.47))
    # Pernas: diagonal da coxa, lateral externa, X da canela, tornozeleira.
    add(leg & front, polyline_distance_2d(axy, [(0.025, 1.06), (0.125, 0.72)]))
    leg_center_x = np.interp(y, [0.12, 0.58, 1.1], [0.043, 0.056, 0.085])
    add(leg & (ax > leg_center_x + 0.03), np.abs(z - 0.0))
    for a, b in (((0.02, 0.46), (0.085, 0.22)), ((0.085, 0.46), (0.02, 0.22))):
        add(leg & front, polyline_distance_2d(axy, [a, b]))
    add(leg, np.abs(y - (ANKLE_Y + 0.025)))

    # Armadura: ombreiras, joelheiras, punhos.
    pad = (np.linalg.norm((p - np.stack([np.sign(x) * 0.2, np.full_like(x, 1.565), np.full_like(x, -0.01)], 1))
                          / np.array([0.075, 0.05, 0.075]), axis=1) < 1.0) & (y > 1.52)
    knee_r = np.linalg.norm(np.stack([(ax - 0.056) / 0.055, (y - 0.6) / 0.075], 1), axis=1)
    knee = leg & front & (knee_r < 1.0)
    cuff = arm & (ax > 0.555) & (ax < WRIST_X - 0.005)
    armor = pad | knee | cuff
    # Borda da joelheira também brilha.
    add(leg & front, np.abs(knee_r - 1.0) * 0.055)
    # Dispositivo de pulso (esquerdo, verde) e display do braço (direito, ciano).
    device_l = arm & (x < 0) & (ax > 0.5) & (ax < 0.55) & (dy > 0.01) & (np.abs(dz) < 0.028)
    device_r = arm & (x > 0) & (ax > 0.33) & (ax < 0.37) & (dy > 0.01) & (np.abs(dz) < 0.022)
    skin = (y > NECK_TOP) | (ax > WRIST_X) | (y < ANKLE_Y)
    feet = y < ANKLE_Y
    return d, armor, device_l, device_r, skin, feet


def bake_suit(gltf, binary, body_image):
    w, h = body_image.size
    src = np.asarray(body_image, np.float32) / 255.0
    albedo = src.copy()
    emission = np.zeros((h, w, 3), np.float32)
    painted = np.zeros((h, w), bool)
    for mesh in gltf["meshes"]:
        for prim in mesh["primitives"]:
            if "Body_00_SKIN" not in gltf["materials"][prim["material"]]["name"]:
                continue
            pos = read_accessor(gltf, binary, prim["attributes"]["POSITION"]).astype(np.float32)
            uv = read_accessor(gltf, binary, prim["attributes"]["TEXCOORD_0"]).astype(np.float32)
            tris = read_accessor(gltf, binary, prim["indices"]).reshape(-1, 3)
            px = uv * np.array([w, h], np.float32)
            for tri in tris:
                _raster_triangle(px[tri], pos[tri], src, albedo, emission, painted)
    # Expande 3 texels nas costuras do UV para não aparecer a cor antiga no mipmap.
    for _ in range(3):
        grow = painted.copy()
        for dy_, dx_ in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted = np.roll(painted, (dy_, dx_), (0, 1))
            fill = shifted & ~grow
            albedo[fill] = np.roll(albedo, (dy_, dx_), (0, 1))[fill]
            emission[fill] = np.roll(emission, (dy_, dx_), (0, 1))[fill]
            grow |= fill
        painted = grow
    out = Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8), "RGBA")
    glow = Image.fromarray((np.clip(emission, 0, 1) * 255).astype(np.uint8), "RGB")
    return out, glow


def _raster_triangle(t2, t3, src, albedo, emission, painted):
    h, w = painted.shape
    lo = np.floor(t2.min(axis=0) - 1).astype(int)
    hi = np.ceil(t2.max(axis=0) + 1).astype(int)
    lo = np.maximum(lo, 0)
    hi = np.minimum(hi, [w - 1, h - 1])
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
    # Inclui texels até ~1 px fora da aresta (costuras), com posição presa ao triângulo.
    edge_px = np.array([np.linalg.norm(c - b), np.linalg.norm(a - c), np.linalg.norm(b - a)]) + 1e-6
    height_px = abs(den) / edge_px
    inside = np.all(bary * height_px > -1.0, axis=1)
    if not np.any(inside):
        return
    bary = np.clip(bary[inside], 0, None)
    bary /= bary.sum(axis=1, keepdims=True)
    p3 = bary @ t3
    xi = xs.ravel()[inside]
    yi = ys.ravel()[inside]
    d, armor, device_l, device_r, skin, feet = suit_layers(p3)
    base = np.where(armor[:, None], ARMOR, SUIT)
    line = np.clip(1.0 - (d - LINE_HALF_WIDTH) / LINE_SOFTNESS, 0.0, 1.0)[:, None]
    color = base * (1 - line) + LINE * line
    glow = LINE_GLOW * line
    color = np.where(device_l[:, None], GREEN, color)
    glow = np.where(device_l[:, None], GREEN, glow)
    color = np.where(device_r[:, None], CYAN, color)
    glow = np.where(device_r[:, None], CYAN, glow)
    keep = skin[:, None]
    # Pés descalços: a textura original tinha meias pintadas; usa o tom de pele com sombra suave.
    sole = np.clip((p3[:, 1] - 0.0) / ANKLE_Y, 0.0, 1.0)[:, None]
    skin_color = np.where(feet[:, None], FOOT_SKIN * (0.88 + 0.12 * sole), src[yi, xi, :3])
    albedo[yi, xi, :3] = np.where(keep, skin_color, color)
    albedo[yi, xi, 3] = 1.0
    emission[yi, xi] = np.where(keep, 0.0, glow)
    painted[yi, xi] = True


# --- Cores do cabelo e dos olhos --------------------------------------------------------------

def to_white_hair(image):
    a = np.asarray(image, np.float32) / 255.0
    lum = a[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)
    lo, hi = np.percentile(lum[a[..., 3] > 0.5], [5, 95]) if np.any(a[..., 3] > 0.5) else (0.0, 1.0)
    t = np.clip((lum - lo) / max(hi - lo, 1e-3), 0, 1)[..., None]
    dark = np.array([0.55, 0.57, 0.67], np.float32)
    light = np.array([0.95, 0.95, 0.99], np.float32)
    a[..., :3] = dark * (1 - t) + light * t
    return Image.fromarray((a * 255).astype(np.uint8), "RGBA")


def to_green_iris(image):
    rgba = np.asarray(image).copy()
    hsv = np.asarray(Image.fromarray(rgba[..., :3]).convert("HSV")).copy()
    hsv[..., 0] = 95  # verde (0–255)
    hsv[..., 1] = np.clip(hsv[..., 1].astype(np.int32) * 1.15, 0, 255).astype(np.uint8)
    rgb = np.asarray(Image.fromarray(hsv, "HSV").convert("RGB"))
    rgba[..., :3] = rgb
    return Image.fromarray(rgba, "RGBA")


def recolor(gltf, binary, images):
    names = {}
    for mat in gltf["materials"]:
        tex = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if tex:
            names.setdefault(gltf["textures"][tex["index"]]["source"], mat["name"])
    glow = None
    for i, name in names.items():
        if "Body_00_SKIN" in name:
            images[i], glow = bake_suit(gltf, binary, images[i])
        elif "HAIR" in name or "FaceBrow" in name:
            images[i] = to_white_hair(images[i])
        elif "EyeIris" in name:
            images[i] = to_green_iris(images[i])
    for mat in gltf["materials"]:
        mat.get("pbrMetallicRoughness", {})["baseColorFactor"] = [1, 1, 1, 1]
    return glow


def main():
    os.makedirs(CACHE, exist_ok=True)
    if not os.path.exists(SOURCE):
        print("baixando", SOURCE_URL)
        urllib.request.urlretrieve(SOURCE_URL, SOURCE)
    gltf, binary = load_glb(SOURCE)
    images = prune(gltf, binary)
    glow = recolor(gltf, binary, images)
    glow.save(OUT_EMISSION, optimize=True)
    save_glb(gltf, binary, images, OUT)
    print("ok", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main()
