"""Prepara a espada enviada pelo jogador (art/weapons/arc_blade_source.usdz) para o jogo.

Gera assets/weapons/arc_blade.glb no espaço da arma do jogo (scenes/player/weapon_visual.gd):
empunhadura no centro da origem, lâmina para -Z, largura em X, espessura em Y. Reduz a malha e as
texturas para ficar leve.

Uso:  python3 tools/blender/build_sword.py    (ou blender -b -P tools/blender/build_sword.py)
"""
import os

import bpy  # noqa: I001
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SOURCE = os.path.join(ROOT, "art", "weapons", "arc_blade_source.usdz")
OUT = os.path.join(ROOT, "assets", "weapons", "arc_blade.glb")

LENGTH = 1.25          # comprimento total da espada no jogo (m)
DECIMATE = 0.3         # fração dos triângulos mantida
TEXTURE_SIZE = 1024
GRIP_RANGE = (0.36, 0.46)  # trecho do cabo no modelo original (eixo X, de -0,5 a 0,5)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.usd_import(filepath=SOURCE)
    obj = next(o for o in bpy.data.objects if o.type == "MESH")
    mesh = obj.data
    mesh.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    # Centro do cabo.
    grip = [v.co for v in mesh.vertices if GRIP_RANGE[0] <= v.co.x <= GRIP_RANGE[1]]
    center = sum(grip, Vector()) / len(grip)
    center.x = sum(GRIP_RANGE) / 2
    length = max(v.co.x for v in mesh.vertices) - min(v.co.x for v in mesh.vertices)
    scale = LENGTH / length
    # Modelo: comprimento em X (cabo em +X), largura em Y, espessura em Z.
    # Arma no jogo (Godot, Y-up): lâmina para -Z, largura em X, espessura em Y. No Blender (Z-up), o
    # exportador troca (x, y, z) → (x, z, -y); então queremos Blender: x = largura, y = -(comprimento),
    # z = espessura... com a lâmina indo para +Y do Blender (= -Z do Godot).
    to_weapon = Matrix(((0, 1, 0, 0), (-1, 0, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
    mesh.transform(Matrix.Scale(scale, 4) @ to_weapon @ Matrix.Translation(-center))
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.ratio = DECIMATE
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for img in bpy.data.images:
        if img.size[0] > TEXTURE_SIZE:
            img.scale(TEXTURE_SIZE, TEXTURE_SIZE)
            img.pack()
    obj.name = "ArcBlade"
    ys = [v.co.y for v in mesh.vertices]
    print("[sword] lâmina do cabo até a ponta (m):", round(max(ys), 3), "triângulos:",
          sum(len(p.vertices) - 2 for p in mesh.polygons))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True,
                              export_image_format="JPEG", export_extras=False)
    print("[sword] ok", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main()
