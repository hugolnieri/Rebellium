"""Renderiza do .blend a miniatura fiel do mapa para o menu inicial.

Uso: blender --background --python tools/blender/render_relay_preview.py
"""
import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND = os.path.join(ROOT, "art", "arena", "relay_arena.blend")
OUT = os.path.join(ROOT, "assets", "ui", "relay_arena_preview.png")

bpy.ops.wm.open_mainfile(filepath=BLEND)
scene = bpy.context.scene
for obj in scene.objects:
    if obj.name.endswith("-convcolonly"):
        obj.hide_render = True  # colisores duplicam as superfícies visíveis
camera_data = bpy.data.cameras.new("Menu preview camera")
camera_data.type = "ORTHO"
camera_data.ortho_scale = 112.0
camera = bpy.data.objects.new("Menu preview camera", camera_data)
scene.collection.objects.link(camera)
camera.location = (14.0, -78.0, 66.0)
direction = Vector((0.0, 0.0, 0.0)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
scene.camera = camera

for name, location, color, energy in (
    ("Cool key", (3, -22, 45), (0.60, 0.80, 1.0), 8500),
    ("Blue base", (-30, 4, 22), (0.12, 0.55, 1.0), 5000),
    ("Red base", (30, 4, 22), (1.0, 0.18, 0.25), 5000),
):
    light_data = bpy.data.lights.new(name, "AREA")
    light_data.energy = energy
    light_data.color = color
    light_data.shape = "DISK"
    light_data.size = 35.0
    light = bpy.data.objects.new(name, light_data)
    scene.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (Vector((0, 0, 0)) - light.location).to_track_quat("-Z", "Y").to_euler()

sun_data = bpy.data.lights.new("Key sun", "SUN")
sun_data.energy = 3.2
sun_data.angle = math.radians(8)
sun_data.color = (0.86, 0.92, 1.0)
sun = bpy.data.objects.new("Key sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(42), math.radians(-18), math.radians(28))

world = bpy.data.worlds.new("Deep cobalt")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.015, 0.035, 0.075, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.6
scene.world = world
# Cycles na CPU: renderiza mesmo sem GPU/OpenGL (o bpy do pip em servidor não abre o EEVEE).
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x = 1200
scene.render.resolution_y = 675
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = OUT
scene.render.film_transparent = False
scene.view_settings.view_transform = "AgX"
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.render.render(write_still=True)
print("[relay_preview]", OUT, flush=True)
