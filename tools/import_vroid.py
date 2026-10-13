"""Traz um personagem exportado do VRoid Studio (.vrm) para o jogo.

Uso:
  python3 tools/import_vroid.py caminho/do/personagem.vrm [nome] [--max-texture=1024]

Gera assets/character/models/<nome>.glb (o Godot importa sozinho ao abrir o projeto). Ele aparece no menu de
personagem do jogo (F4) e usa as MESMAS animações do herói (feitas no Blender): todo modelo do VRoid tem os
mesmos ossos (J_Bip_*), e o jogo aplica os clipes pelo nome do osso.

O que o script faz (só Python + Pillow, sem Blender):
  - reduz as texturas maiores que --max-texture (padrão 1024 px) para o arquivo ficar leve;
  - copia os nomes das expressões (piscar etc.) para onde o importador do Godot procura;
  - tira as extensões próprias do VRM (o Godot não usa; o glTF padrão continua igual).

No VRoid Studio: Exportar → VRM (0.0 ou 1.0). Licença: confira as condições do modelo/das peças usadas
(os modelos de exemplo "HairSample" do VRoid são CC0) e registre em assets/character/CREDITS.md.
"""
import io
import json
import os
import re
import struct
import sys

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT_DIR = os.path.join(ROOT, "assets", "character", "models")
GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942
# Texturas que o jogo não usa (normal, brilho, sombra do MToon): ficam com este tamanho máximo.
UNUSED_TEXTURE_SIZE = 64


def read_glb(path):
    data = open(path, "rb").read()
    magic, version, _length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC or version != 2:
        sys.exit(f"{path}: não é um glb/vrm (glTF 2.0 binário)")
    offset = 12
    gltf, binary = None, b""
    while offset < len(data):
        size, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8:offset + 8 + size]
        if kind == CHUNK_JSON:
            gltf = json.loads(chunk)
        elif kind == CHUNK_BIN:
            binary = chunk
        offset += 8 + size
    return gltf, binary


def write_glb(path, gltf, binary):
    js = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    binary += b"\0" * ((4 - len(binary) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binary)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", GLB_MAGIC, 2, total))
        f.write(struct.pack("<II", len(js), CHUNK_JSON))
        f.write(js)
        f.write(struct.pack("<II", len(binary), CHUNK_BIN))
        f.write(binary)


def shrink_image(raw, mime, max_size):
    img = Image.open(io.BytesIO(raw))
    if max(img.size) <= max_size:
        return raw, mime
    scale = max_size / max(img.size)
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    out = io.BytesIO()
    if mime == "image/jpeg":
        img.convert("RGB").save(out, "JPEG", quality=90)
    else:
        img.save(out, "PNG", optimize=True)
        mime = "image/png"
    return out.getvalue(), mime


def convert(src, name, max_size):
    gltf, binary = read_glb(src)
    views = gltf.get("bufferViews", [])
    # O jogo só usa a cor (baseColorTexture) com o shader toon dele: as outras texturas (normal, brilho,
    # sombra do MToon...) ficam minúsculas.
    color_images = set()
    for material in gltf.get("materials", []):
        tex = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if tex is not None:
            color_images.add(gltf["textures"][tex["index"]].get("source"))
    # Texturas: reduz e marca as bufferViews substituídas.
    replaced = {}
    for index, image in enumerate(gltf.get("images", [])):
        view = image.get("bufferView")
        if view is None:
            continue
        bv = views[view]
        start = bv.get("byteOffset", 0)
        raw = binary[start:start + bv["byteLength"]]
        limit = max_size if index in color_images else UNUSED_TEXTURE_SIZE
        new, mime = shrink_image(raw, image.get("mimeType", "image/png"), limit)
        image["mimeType"] = mime
        replaced[view] = new
    # Nomes das expressões: o VRoid guarda em primitives[].extras.targetNames; o Godot lê mesh.extras.
    for mesh in gltf.get("meshes", []):
        prims = mesh.get("primitives", [])
        names = prims[0].get("extras", {}).get("targetNames") if prims else None
        if names and "targetNames" not in mesh.get("extras", {}):
            mesh.setdefault("extras", {})["targetNames"] = names
    # Extensões do VRM (o glTF padrão fica intacto).
    def is_vrm(ext):
        return ext == "VRM" or ext.startswith("VRMC_")
    for key in ("extensionsUsed", "extensionsRequired"):
        if key in gltf:
            gltf[key] = [e for e in gltf[key] if not is_vrm(e)]
            if not gltf[key]:
                del gltf[key]
    if "extensions" in gltf:
        gltf["extensions"] = {k: v for k, v in gltf["extensions"].items() if not is_vrm(k)}
        if not gltf["extensions"]:
            del gltf["extensions"]
    for material in gltf.get("materials", []):
        if "extensions" in material:
            material["extensions"] = {k: v for k, v in material["extensions"].items() if not is_vrm(k)}
            if not material["extensions"]:
                del material["extensions"]
    # Remonta o buffer binário (alinhado em 4 bytes).
    out = bytearray()
    for i, bv in enumerate(views):
        start = bv.get("byteOffset", 0)
        chunk = replaced.get(i, binary[start:start + bv["byteLength"]])
        out += b"\0" * ((4 - len(out) % 4) % 4)
        bv["byteOffset"] = len(out)
        bv["byteLength"] = len(chunk)
        bv["buffer"] = 0
        out += chunk
    gltf["buffers"] = [{"byteLength": len(out)}]
    os.makedirs(OUT_DIR, exist_ok=True)
    dest = os.path.join(OUT_DIR, f"{name}.glb")
    write_glb(dest, gltf, bytes(out))
    print(f"[import_vroid] ok {dest}  ({os.path.getsize(src) // 1024} KB → {os.path.getsize(dest) // 1024} KB)")
    return dest


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    if not args:
        sys.exit(__doc__)
    src = args[0]
    name = args[1] if len(args) > 1 else os.path.splitext(os.path.basename(src))[0]
    name = re.sub(r"[^a-zA-Z0-9_]+", "_", name).strip("_").lower() or "personagem"
    convert(src, name, int(opts.get("max-texture", "1024")))


if __name__ == "__main__":
    main(sys.argv[1:])
