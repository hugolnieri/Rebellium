"""Exporta o personagem do hero.blend para o jogo (assets/character/hero.glb).

Três jeitos de rodar:
  - Dentro do Blender: aba Scripting → texto "exportar_para_o_jogo.py" (já vem no hero.blend) → Run Script.
  - Linha de comando:  blender -b art/character/hero.blend -P tools/blender/export_hero.py
  - Com o bpy do pip:  python3 tools/blender/export_hero.py

Exporta a malha, o esqueleto e TODAS as Actions (cada uma vira um clipe que o jogo lê pelo nome).
"""
import os

import bpy

SETTINGS = dict(
    export_format="GLB", use_selection=True, export_yup=True, export_apply=False, export_skins=True,
    export_morph=True, export_animations=True, export_animation_mode="ACTIONS",
    export_force_sampling=True, export_frame_step=1, export_reset_pose_bones=True, export_def_bones=False,
    export_optimize_animation_size=True, export_anim_single_armature=True, export_extras=False,
)


def default_paths():
    here = bpy.data.filepath
    if not here:
        root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
        here = os.path.join(root, "art", "character", "hero.blend")
    root = os.path.normpath(os.path.join(os.path.dirname(here), "..", ".."))
    return here, os.path.join(root, "assets", "character", "hero.glb")


def export(path):
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    action = arm.animation_data.action if arm.animation_data else None
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for child in arm.children_recursive:
        child.select_set(True)
    # Versões diferentes do Blender têm opções diferentes: passa só as que existem.
    known = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(filepath=path, **{k: v for k, v in SETTINGS.items() if k in known})
    if arm.animation_data:
        arm.animation_data.action = action
    print("[export_hero] ok", path, os.path.getsize(path) // 1024, "KB")


def main():
    blend, glb = default_paths()
    if not bpy.data.filepath:
        bpy.ops.wm.open_mainfile(filepath=blend)
    export(glb)


if __name__ == "__main__":
    main()
