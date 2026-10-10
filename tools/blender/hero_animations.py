"""Animações do personagem como Actions do Blender (usadas por tools/blender/build_hero.py).

As poses são escritas no mesmo "esqueleto de referência" que o jogo usa (scenes/player/character_model.gd):
cada canal é um Euler (x, y, z) em radianos, ordem YXZ do Godot, com repouso = identidade e braços
ABAIXADOS. O script converte para os ossos do modelo (que têm repouso em T-pose) e grava keyframes.

No jogo, character_model.gd lê estas Actions do hero.glb e escolhe o quadro a partir do gameplay
(fase da passada, progresso do dash, fase do golpe...), então a animação fica sincronizada com a
física. Por isso cada clipe é "normalizado": o jogo amostra de 0 a 1 ao longo do clipe.

Clipes (nome → como o jogo amostra):
  idle         loop no tempo (respiração)
  walk, sprint loop pela fase da passada (um ciclo = dois passos)
  air          0 = subindo rápido, 0,5 = ápice, 1 = caindo rápido
  air_sprint   loop no tempo (pernas pedalando)
  jump_flip    progresso do mortal para frente do pulo
  wall_stick   pose colada na parede
  wall_flip    progresso do mortal para trás do wall jump
  roll         progresso da cambalhota ao aterrissar
  cartwheel    progresso do dash (estrela)
  hurt         pose ao apanhar
  sword_rest   braço direito com a lâmina no ombro (sobreposto a idle/walk)
  atk_<golpe>  0 → 0,35 preparação → 0,6 acerto → 1 acompanhamento (fases do golpe)

O osso "Root" só serve de prévia no Blender (giros dos mortais, estrela, golpe giratório): o jogo ignora o
Root e aplica esses giros por código, no ritmo da física.
"""
import math

import bpy  # noqa: F401  (garante mathutils no python do pip)
from mathutils import Matrix, Quaternion, Vector

FPS = 60
TAU = math.tau
PI = math.pi

# Escala do modelo no jogo (altura de referência / altura do modelo): converte hips_y (m) ↔ unidades.
REFERENCE_HEIGHT = 1.8
MODEL_HEIGHT = 1.91
RIG_SCALE = REFERENCE_HEIGHT / MODEL_HEIGHT
HIPS_REST_Y = None  # preenchido em build()

# --- Parâmetros da locomoção (antes ficavam no menu F2; agora a pose vive no Blender) -------------
LEG_SWING_DEG = 42.0
KNEE_BEND_DEG = 85.0
ARM_SWING_DEG = 38.0
RUN_LEAN_DEG = 26.0          # corpo inteiro inclinado andando
NINJA_RUN_LEAN_DEG = 45.0    # no sprint
NINJA_ARM_PITCH_DEG = 0.0    # braços do sprint em relação ao chão (0 = horizontal)
RUN_BOB_HEIGHT = 0.05
BREATH_PERIOD = 4.2
BREATH_DEPTH_DEG = 2.2
IDLE_WEIGHT_SHIFT_DEG = 2.5
IDLE_STANCE_WIDTH_DEG = 10.0
STANCE_FRACTION_WALK = 0.32
STANCE_FRACTION_RUN = 0.38
STANCE_KNEE_WALK_DEG = 20.0
STANCE_KNEE_RUN_DEG = 32.0
KNEE_LIFT_WALK_DEG = 34.0
KNEE_LIFT_RUN_DEG = 55.0
WALK_HOP_HEIGHT = 0.07
# Durações de referência (prévia no Blender; no jogo o ritmo vem do gameplay).
WALK_SPEED, SPRINT_SPEED = 6.0, 10.0
STRIDE_WALK, STRIDE_SPRINT = 3.4, 4.4
JUMP_FLIP_DURATION = 0.62
WALL_FLIP_DURATION = 0.5
ROLL_DURATION = 0.7
DASH_DURATION = 0.65
ROLL_BALL_HEIGHT = 0.36
CARTWHEEL_LIFT = 0.2
# Dedos (prévia; no jogo vêm de grip_curl / relaxed_curl).
GRIP_CURL = 1.25
RELAXED_CURL = 0.4

JOINTS = ["hips", "spine", "chest", "head", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r",
          "wrist_l", "wrist_r", "thigh_l", "thigh_r", "knee_l", "knee_r", "foot_l", "foot_r"]
BONE_MAP = {
    "hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "chest": "J_Bip_C_Chest", "head": "J_Bip_C_Head",
    "shoulder_l": "J_Bip_L_UpperArm", "elbow_l": "J_Bip_L_LowerArm", "wrist_l": "J_Bip_L_Hand",
    "shoulder_r": "J_Bip_R_UpperArm", "elbow_r": "J_Bip_R_LowerArm", "wrist_r": "J_Bip_R_Hand",
    "thigh_l": "J_Bip_L_UpperLeg", "knee_l": "J_Bip_L_LowerLeg", "foot_l": "J_Bip_L_Foot",
    "thigh_r": "J_Bip_R_UpperLeg", "knee_r": "J_Bip_R_LowerLeg", "foot_r": "J_Bip_R_Foot",
}
SHOULDER_REST = {"shoulder_r": (0.25, 0.07, 0.1), "elbow_r": (1.2, 0, 0), "wrist_r": (1.1, -0.1, -0.39)}


# --- Pequena álgebra de poses ----------------------------------------------------------------------

def v3(x=0.0, y=0.0, z=0.0):
    return [float(x), float(y), float(z)]


def lerp(a, b, t):
    return a + (b - a) * t


def vlerp(a, b, t):
    return [lerp(a[i], b[i], t) for i in range(3)]


def vadd(a, b):
    return [a[i] + b[i] for i in range(3)]


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def smooth(t):
    return t * t * (3.0 - 2.0 * t)


def rad(d):
    return math.radians(d)


def rest_pose():
    pose = {j: v3() for j in JOINTS}
    pose["hips_y"] = 0.0
    # Prontidão: arma baixa à frente, braço livre relaxado.
    pose["shoulder_r"] = v3(0.35, 0.05, 0.18)
    pose["elbow_r"] = v3(0.75)
    pose["wrist_r"] = v3(-0.35)
    pose["shoulder_l"] = v3(0.1, 0, -0.16)
    pose["elbow_l"] = v3(0.35)
    return pose


def blend_pose(a, b, t):
    out = dict(a)
    for key, value in b.items():
        if key not in out:
            out[key] = value
        elif isinstance(value, list):
            out[key] = vlerp(out[key], value, t)
        else:
            out[key] = lerp(out[key], value, t)
    return out


# --- Locomoção (porte da animação procedural aprovada no jogo) --------------------------------------

def ground_pose(phase, time, amount, run_k, sprint):
    pose = rest_pose()
    calm = 1.0 - amount
    arm_swing = rad(ARM_SWING_DEG) * amount
    breath = math.sin(time * TAU / BREATH_PERIOD)
    depth = rad(BREATH_DEPTH_DEG)
    shift = rad(IDLE_WEIGHT_SHIFT_DEG) * calm
    stance = rad(IDLE_STANCE_WIDTH_DEG) * calm
    lean = lerp(rad(RUN_LEAN_DEG) * amount, rad(NINJA_RUN_LEAN_DEG), sprint)
    legs(pose, phase, amount, run_k, sprint, lean, stance, shift, calm)
    lift = breath * depth * 0.8 * calm
    pose["shoulder_l"] = v3(-math.sin(phase) * arm_swing + 0.1 + lean * 0.5, 0, -0.16 - 0.1 * amount - lift)
    pose["elbow_l"] = v3(0.35 + 0.9 * amount)
    pose["shoulder_r"] = v3(lerp(0.35, -0.45, amount) + math.sin(phase) * arm_swing * 0.25 + lean * 0.5,
                            0.05, 0.18 + 0.12 * amount + lift)
    pose["elbow_r"] = v3(lerp(0.75, 0.35, amount))
    pose["wrist_r"] = v3(lerp(-0.35, 3.3, amount))
    pose["hips"] = v3(-lean, 0, -shift * 0.6)
    pose["spine"] = v3(-lean * 0.1 + breath * depth * 0.3 * calm, 0, shift * 0.3)
    pose["chest"] = v3(breath * depth * calm, -math.sin(phase) * 0.05 * amount, shift * 0.2)
    pose["head"] = v3(lean * 0.75 - breath * depth * 0.5 * calm, math.sin(time * TAU / (BREATH_PERIOD * 2)) * 0.07 * calm, 0)
    if sprint > 0.0:
        ninja_run(pose, phase, sprint)
    return pose


def legs(pose, phase, amount, run_k, sprint, lean, stance, shift, calm):
    """Passada por perna: apoio (calcanhar → carga → impulso na ponta) e balanço (joelho alto)."""
    stance_frac = lerp(STANCE_FRACTION_WALK, STANCE_FRACTION_RUN, run_k)
    swing_range = rad(LEG_SWING_DEG) * amount * lerp(1.0, 1.3, run_k)
    front, back = swing_range * 0.58, swing_range * 0.42
    knee_swing = rad(KNEE_BEND_DEG) * amount * lerp(0.9, 1.6, run_k)
    knee_load = rad(lerp(STANCE_KNEE_WALK_DEG, STANCE_KNEE_RUN_DEG, run_k)) * amount
    knee_lift = rad(lerp(KNEE_LIFT_WALK_DEG, KNEE_LIFT_RUN_DEG, run_k)) * amount
    compensate = lean * 0.8
    for i, side in enumerate(("l", "r")):
        u = ((phase + PI * i) / TAU) % 1.0
        if u < stance_frac:
            t = u / stance_frac
            thigh = lerp(front, -back, t)
            knee = -knee_load * math.sin(PI * t)
            ankle = (0.18 * max(0.0, 1.0 - t * 4.0) - 0.55 * max(0.0, (t - 0.65) / 0.35) ** 2) * amount
        else:
            t = (u - stance_frac) / (1.0 - stance_frac)
            thigh = -back + (front + back) * (0.5 - 0.5 * math.cos(PI * t)) \
                + knee_lift * math.sin(PI * min(t / 0.85, 1.0))
            knee = -(knee_swing + knee_lift * 0.8) * math.sin(PI * min(t / 0.8, 1.0))
            ankle = (-0.5 * (1.0 - t) ** 3 + 0.15 * math.sin(PI * t)) * amount
        relaxed = 1.0 if i == 1 else 0.0
        out = -stance if i == 0 else stance
        thigh += compensate + 0.08 * relaxed * calm
        knee -= (0.06 + 0.14 * relaxed) * calm
        pose["thigh_" + side] = v3(thigh, 0, out + shift)
        pose["knee_" + side] = v3(knee)
        flat = lean - thigh - knee
        pose["foot_" + side] = v3(flat + ankle + 0.05 * relaxed * calm, 0, -out - shift)
    mid = math.cos(2.0 * (phase - PI * stance_frac))
    flight = clamp((0.55 - stance_frac) / 0.15, 0.0, 1.0)
    bob = RUN_BOB_HEIGHT * amount * lerp(mid, -mid, flight) * 0.5
    hop = WALK_HOP_HEIGHT * amount * (1.0 - run_k) * (1.0 - sprint) * abs(math.sin(phase))
    pose["hips_y"] = bob + hop - 0.02 * calm - 0.03 * amount


def ninja_run(pose, phase, weight):
    """Sprint: corpo mergulhado, cabeça erguida, braços esticados para trás NA HORIZONTAL."""
    bounce = math.sin(phase * 2.0) * 0.04
    torso_forward = -(pose["hips"][0] + pose["spine"][0] + pose["chest"][0])
    back = -(PI * 0.5 - torso_forward + rad(NINJA_ARM_PITCH_DEG))
    target = {
        "head": v3(torso_forward * 0.85), "shoulder_l": v3(back + bounce, 0, -0.18),
        "shoulder_r": v3(back - bounce, 0, 0.18), "elbow_l": v3(0.05), "elbow_r": v3(0.05),
        "wrist_l": v3(-0.2), "wrist_r": v3(-1.4),
    }
    for key, value in target.items():
        pose[key] = vlerp(pose[key], value, weight)


def air_pose(k):
    """k = 1 subindo rápido, 0 ápice, -1 caindo rápido."""
    pose = rest_pose()
    rise, fall = clamp(k, 0.0, 1.0), clamp(-k, 0.0, 1.0)
    pose["thigh_l"] = v3(lerp(0.5, 1.1, rise) - 0.15 * fall, 0, 0.05)
    pose["thigh_r"] = v3(lerp(0.1, -0.2, rise) + 0.25 * fall, 0, -0.05)
    pose["knee_l"] = v3(lerp(-0.8, -1.6, rise) + 0.3 * fall)
    pose["knee_r"] = v3(lerp(-0.6, -0.8, rise) + 0.2 * fall)
    pose["shoulder_l"] = v3(lerp(0.4, 0.9, rise) - 0.2 * fall, 0, lerp(-0.6, -0.35, rise) - 0.5 * fall)
    pose["elbow_l"] = v3(0.7)
    pose["shoulder_r"] = v3(lerp(0.3, -0.3, rise) + 0.2 * fall, 0.1, 0.45 + 0.4 * fall)
    pose["elbow_r"] = v3(0.7)
    pose["wrist_r"] = v3(-0.6)
    pose["spine"] = v3(-0.15 * rise + 0.08 * fall)
    pose["head"] = v3(0.1 * rise - 0.1 * fall)
    return pose


def air_sprint_pose(u):
    pose = rest_pose()
    cycle = math.sin(u * TAU)
    pose["hips"] = v3(-0.5)
    pose["spine"] = v3(-0.1)
    pose["thigh_l"] = v3(0.3 + cycle * 0.6)
    pose["thigh_r"] = v3(0.3 - cycle * 0.6)
    pose["knee_l"] = v3(-0.9 - max(cycle, 0.0) * 0.6)
    pose["knee_r"] = v3(-0.9 - max(-cycle, 0.0) * 0.6)
    ninja_run(pose, u * TAU, 1.0)
    return pose


TUCK = {
    "spine": v3(-0.5), "chest": v3(-0.3), "head": v3(-0.3), "thigh_l": v3(1.9, 0, 0.1),
    "thigh_r": v3(1.9, 0, -0.1), "knee_l": v3(-2.3), "knee_r": v3(-2.3), "shoulder_l": v3(1.0, 0, 0.1),
    "elbow_l": v3(1.5),
}


def jump_flip_pose(t):
    # Sobe encolhendo, joelhos no peito no meio do giro, abre de novo para cair.
    pose = air_pose(lerp(1.0, -0.4, t))
    return blend_pose(pose, TUCK, math.sin(PI * clamp(t, 0.0, 1.0)))


def wall_kick_pose():
    pose = rest_pose()
    pose.update({
        "hips_y": -0.28, "thigh_l": v3(1.75, 0, 0.1), "thigh_r": v3(1.35, 0, -0.1), "knee_l": v3(-2.3),
        "knee_r": v3(-2.0), "foot_l": v3(0.5), "foot_r": v3(0.4), "spine": v3(-0.35), "chest": v3(-0.2),
        "head": v3(0.35), "shoulder_l": v3(1.6, 0, -0.6), "shoulder_r": v3(1.4, 0, 0.6), "elbow_l": v3(0.5),
        "elbow_r": v3(0.5),
    })
    return pose


def wall_flip_pose(t):
    # Primeiro quarto: ainda encolhido saindo da parede; depois abre no ar (subindo).
    kick = 1.0 - smooth(clamp((t - 0.15) / 0.2, 0.0, 1.0))
    return blend_pose(air_pose(lerp(1.0, 0.2, t)), wall_kick_pose(), kick)


def roll_pose(t):
    pose = rest_pose()
    pose.update({
        "spine": v3(-0.9), "chest": v3(-0.5), "head": v3(-0.55), "thigh_l": v3(2.1, 0, 0.12),
        "thigh_r": v3(2.1, 0, -0.12), "knee_l": v3(-2.4), "knee_r": v3(-2.4), "shoulder_l": v3(1.2, 0, 0.1),
        "shoulder_r": v3(1.0, 0, -0.1), "elbow_l": v3(1.4), "elbow_r": v3(1.2),
    })
    # Abre o corpo no fim para levantar.
    return blend_pose(pose, ground_pose(0.0, 0.0, 0.0, 0.0, 0.0), smooth(clamp((t - 0.8) / 0.2, 0.0, 1.0)))


def cartwheel_pose(_t):
    pose = rest_pose()
    pose.update({
        "spine": v3(0.05), "head": v3(0.1), "shoulder_l": v3(0.15, 0, -2.5), "shoulder_r": v3(0.15, 0, 2.5),
        "elbow_l": v3(0.1), "elbow_r": v3(0.1), "thigh_l": v3(0.05, 0, -0.6), "thigh_r": v3(0.05, 0, 0.6),
        "knee_l": v3(-0.15), "knee_r": v3(-0.15),
    })
    return pose


def hurt_pose(_t):
    pose = rest_pose()
    pose.update({
        "spine": v3(0.45, 0.15, 0), "chest": v3(0.2), "head": v3(0.35), "shoulder_l": v3(0.6, 0, -0.9),
        "shoulder_r": v3(0.5, 0, 0.9), "knee_l": v3(-0.5), "knee_r": v3(-0.3), "hips_y": -0.08,
    })
    return pose


def sword_rest_pose(_t):
    pose = ground_pose(0.0, 0.0, 0.0, 0.0, 0.0)
    for key, value in SHOULDER_REST.items():
        pose[key] = list(value)
    return pose


# --- Golpes: 3 poses-chave (preparação, acerto, acompanhamento) --------------------------------------

ATTACKS = {
    "slash_r": [
        {"spine": (0.05, -0.55, 0), "chest": (0, -0.35, 0), "shoulder_r": (1.25, -1.35, 0.25), "elbow_r": (0.7, 0, 0),
         "wrist_r": (-1.0, 0, 0.3), "shoulder_l": (0.6, 0, -0.35), "elbow_l": (1.3, 0, 0), "thigh_l": (0.35, 0, 0),
         "knee_l": (-0.45, 0, 0), "thigh_r": (-0.25, 0, 0), "knee_r": (-0.35, 0, 0), "hips": (0, -0.3, 0)},
        {"spine": (-0.15, 0.55, 0), "chest": (0, 0.4, 0), "shoulder_r": (1.45, 1.0, 0), "elbow_r": (0.1, 0, 0),
         "wrist_r": (-1.4, 0, -0.2), "shoulder_l": (0.2, 0, -0.7), "elbow_l": (0.6, 0, 0), "thigh_l": (0.55, 0, 0),
         "knee_l": (-0.6, 0, 0), "thigh_r": (-0.35, 0, 0), "knee_r": (-0.2, 0, 0), "hips": (0, 0.35, 0)},
        {"spine": (-0.1, 0.75, 0), "chest": (0, 0.45, 0), "shoulder_r": (1.05, 1.45, 0), "elbow_r": (0.45, 0, 0),
         "wrist_r": (-1.0, 0, 0), "shoulder_l": (0.3, 0, -0.5), "elbow_l": (0.9, 0, 0)},
    ],
    "slash_l": [
        {"spine": (0.05, 0.6, 0), "chest": (0, 0.35, 0), "shoulder_r": (1.2, 1.25, 0), "elbow_r": (1.2, 0, 0),
         "wrist_r": (-0.8, 0, -0.4), "shoulder_l": (0.3, 0, -0.6), "elbow_l": (0.8, 0, 0), "thigh_r": (0.35, 0, 0),
         "knee_r": (-0.45, 0, 0), "thigh_l": (-0.25, 0, 0), "knee_l": (-0.35, 0, 0), "hips": (0, 0.3, 0)},
        {"spine": (-0.15, -0.6, 0), "chest": (0, -0.4, 0), "shoulder_r": (1.45, -1.2, 0.1), "elbow_r": (0.12, 0, 0),
         "wrist_r": (-1.4, 0, 0.3), "shoulder_l": (0.7, 0, -0.3), "elbow_l": (1.2, 0, 0), "thigh_r": (0.5, 0, 0),
         "knee_r": (-0.55, 0, 0), "thigh_l": (-0.35, 0, 0), "knee_l": (-0.2, 0, 0), "hips": (0, -0.35, 0)},
        {"spine": (-0.1, -0.8, 0), "chest": (0, -0.45, 0), "shoulder_r": (1.0, -1.55, 0.2), "elbow_r": (0.5, 0, 0),
         "wrist_r": (-1.0, 0, 0.2)},
    ],
    "overhead": [
        {"spine": (0.25, -0.2, 0), "chest": (0.15, 0, 0), "shoulder_r": (2.75, 0.1, 0.15), "elbow_r": (1.3, 0, 0),
         "wrist_r": (-0.5, 0, 0), "shoulder_l": (2.4, 0, -0.2), "elbow_l": (1.4, 0, 0), "thigh_l": (0.3, 0, 0),
         "knee_l": (-0.3, 0, 0), "thigh_r": (-0.2, 0, 0)},
        {"spine": (-0.55, 0.1, 0), "chest": (-0.25, 0, 0), "shoulder_r": (0.95, 0.15, 0), "elbow_r": (0.05, 0, 0),
         "wrist_r": (-1.45, 0, 0), "shoulder_l": (0.5, 0, -0.4), "elbow_l": (0.7, 0, 0), "thigh_l": (0.75, 0, 0),
         "knee_l": (-0.9, 0, 0), "thigh_r": (-0.45, 0, 0), "knee_r": (-0.5, 0, 0), "hips_y": -0.12},
        {"spine": (-0.45, 0.1, 0), "shoulder_r": (0.55, 0.2, 0), "elbow_r": (0.3, 0, 0), "wrist_r": (-1.3, 0, 0),
         "hips_y": -0.1},
    ],
    "thrust": [
        {"spine": (0.05, -0.5, 0), "shoulder_r": (0.9, -0.5, 0.35), "elbow_r": (1.9, 0, 0), "wrist_r": (-1.55, 0, 0),
         "shoulder_l": (1.0, 0, -0.2), "elbow_l": (0.4, 0, 0), "thigh_l": (0.3, 0, 0), "knee_l": (-0.5, 0, 0),
         "thigh_r": (-0.3, 0, 0), "knee_r": (-0.4, 0, 0)},
        {"spine": (-0.3, 0.35, 0), "shoulder_r": (1.5, 0.15, 0), "elbow_r": (0.0, 0, 0), "wrist_r": (-1.57, 0, 0),
         "shoulder_l": (0.2, 0, -0.9), "elbow_l": (0.3, 0, 0), "thigh_l": (0.75, 0, 0), "knee_l": (-0.7, 0, 0),
         "thigh_r": (-0.55, 0, 0), "knee_r": (-0.1, 0, 0), "hips_y": -0.1},
        {"spine": (-0.2, 0.3, 0), "shoulder_r": (1.2, 0.1, 0), "elbow_r": (0.4, 0, 0)},
    ],
    "spin": [
        # Gira para a DIREITA: prepara torcendo o tronco para a esquerda.
        {"spine": (0.1, 0.7, 0), "chest": (0, 0.3, 0), "shoulder_r": (0.4, 0.6, 0.9), "elbow_r": (0.6, 0, 0),
         "wrist_r": (-1.2, 0, 0), "shoulder_l": (0.5, 0, -1.0), "elbow_l": (0.6, 0, 0), "thigh_l": (0.4, 0, -0.25),
         "knee_l": (-0.8, 0, 0), "thigh_r": (0.1, 0, 0.3), "knee_r": (-0.8, 0, 0), "hips_y": -0.2},
        {"spine": (-0.1, 0.2, 0), "shoulder_r": (0.15, 0, 1.45), "elbow_r": (0.05, 0, 0), "wrist_r": (-1.5, 0, 0),
         "shoulder_l": (0.1, 0, -1.3), "elbow_l": (0.2, 0, 0), "thigh_l": (0.2, 0, -0.35), "knee_l": (-0.5, 0, 0),
         "thigh_r": (0.2, 0, 0.35), "knee_r": (-0.5, 0, 0), "hips_y": -0.15},
        {"spine": (-0.15, -0.4, 0), "shoulder_r": (0.8, -0.8, 0.6), "elbow_r": (0.4, 0, 0), "hips_y": -0.1},
    ],
    "rising": [
        {"spine": (-0.3, -0.3, 0), "shoulder_r": (-0.3, -0.3, 0.4), "elbow_r": (0.4, 0, 0), "wrist_r": (-1.2, 0, 0),
         "shoulder_l": (0.8, 0, -0.3), "elbow_l": (1.2, 0, 0), "thigh_l": (0.7, 0, 0), "knee_l": (-1.2, 0, 0),
         "thigh_r": (0.1, 0, 0), "knee_r": (-1.1, 0, 0), "hips_y": -0.25},
        {"spine": (0.3, 0.3, 0), "chest": (0.2, 0, 0), "shoulder_r": (2.9, 0.2, 0.1), "elbow_r": (0.1, 0, 0),
         "wrist_r": (-1.5, 0, 0), "shoulder_l": (0.3, 0, -0.9), "thigh_l": (0.9, 0, 0), "knee_l": (-1.4, 0, 0),
         "thigh_r": (-0.2, 0, 0), "knee_r": (-0.2, 0, 0), "hips_y": 0.05},
        {"spine": (0.15, 0.2, 0), "shoulder_r": (2.4, 0.2, 0.1), "elbow_r": (0.4, 0, 0)},
    ],
    "air_slam": [
        {"spine": (0.35, 0, 0), "chest": (0.2, 0, 0), "shoulder_r": (3.0, 0, 0.1), "elbow_r": (1.0, 0, 0),
         "wrist_r": (-0.6, 0, 0), "shoulder_l": (2.8, 0, -0.1), "elbow_l": (1.1, 0, 0), "thigh_l": (1.2, 0, 0),
         "knee_l": (-1.8, 0, 0), "thigh_r": (0.9, 0, 0), "knee_r": (-1.6, 0, 0)},
        {"spine": (-0.7, 0, 0), "chest": (-0.3, 0, 0), "shoulder_r": (0.7, 0.1, 0), "elbow_r": (0.05, 0, 0),
         "wrist_r": (-1.55, 0, 0), "shoulder_l": (0.4, 0, -0.8), "thigh_l": (1.4, 0, 0), "knee_l": (-1.9, 0, 0),
         "thigh_r": (0.6, 0, 0), "knee_r": (-1.2, 0, 0)},
        {"spine": (-0.6, 0, 0), "shoulder_r": (0.5, 0.1, 0), "elbow_r": (0.2, 0, 0)},
    ],
    "dash_thrust": [
        {"spine": (-0.2, -0.4, 0), "shoulder_r": (0.6, -0.4, 0.3), "elbow_r": (1.8, 0, 0), "wrist_r": (-1.55, 0, 0),
         "shoulder_l": (1.3, 0, -0.1), "elbow_l": (0.3, 0, 0), "thigh_l": (0.6, 0, 0), "knee_l": (-0.8, 0, 0),
         "thigh_r": (-0.5, 0, 0), "knee_r": (-0.6, 0, 0), "hips_y": -0.18},
        {"spine": (-0.6, 0.25, 0), "chest": (-0.15, 0, 0), "shoulder_r": (1.55, 0.1, 0), "elbow_r": (0.0, 0, 0),
         "wrist_r": (-1.57, 0, 0), "shoulder_l": (-0.5, 0, -0.5), "elbow_l": (0.2, 0, 0), "thigh_l": (0.9, 0, 0),
         "knee_l": (-0.9, 0, 0), "thigh_r": (-0.8, 0, 0), "knee_r": (-0.15, 0, 0), "hips_y": -0.22},
        {"spine": (-0.4, 0.2, 0), "shoulder_r": (1.2, 0.1, 0), "elbow_r": (0.3, 0, 0), "hips_y": -0.12},
    ],
    "jab": [
        {"spine": (0, -0.35, 0), "shoulder_r": (0.9, -0.3, 0.3), "elbow_r": (1.7, 0, 0), "wrist_r": (-1.5, 0, 0),
         "shoulder_l": (1.0, 0, -0.2), "elbow_l": (1.4, 0, 0), "thigh_l": (0.25, 0, 0), "knee_l": (-0.4, 0, 0),
         "thigh_r": (-0.2, 0, 0), "knee_r": (-0.35, 0, 0)},
        {"spine": (-0.15, 0.3, 0), "shoulder_r": (1.5, 0.12, 0), "elbow_r": (0.05, 0, 0), "wrist_r": (-1.5, 0, 0),
         "shoulder_l": (0.6, 0, -0.4), "elbow_l": (1.5, 0, 0), "thigh_l": (0.45, 0, 0), "knee_l": (-0.5, 0, 0)},
        {"spine": (-0.1, 0.2, 0), "shoulder_r": (1.2, 0.1, 0), "elbow_r": (0.5, 0, 0)},
    ],
    "backhand": [
        {"spine": (0, 0.5, 0), "shoulder_r": (1.0, 1.1, 0), "elbow_r": (1.6, 0, 0), "wrist_r": (-0.9, 0, -0.4),
         "shoulder_l": (0.5, 0, -0.5), "elbow_l": (1.0, 0, 0), "thigh_r": (0.3, 0, 0), "knee_r": (-0.4, 0, 0)},
        {"spine": (-0.1, -0.5, 0), "shoulder_r": (1.35, -1.1, 0.2), "elbow_r": (0.2, 0, 0), "wrist_r": (-1.3, 0, 0.3),
         "shoulder_l": (0.8, 0, -0.2), "elbow_l": (1.3, 0, 0), "thigh_r": (0.45, 0, 0), "knee_r": (-0.5, 0, 0)},
        {"spine": (-0.05, -0.6, 0), "shoulder_r": (1.0, -1.4, 0.2), "elbow_r": (0.5, 0, 0)},
    ],
}
# Tempos normalizados das 3 poses no clipe (o 0 é a postura de prontidão).
ATTACK_KEY_TIMES = (0.35, 0.6, 1.0)
# Giro total do corpo no acerto (só prévia; no jogo vem de AttackPoses.SPIN).
ATTACK_SPIN = {"spin": -TAU}


def attack_keys(name):
    """Poses completas nos tempos (0, 0,35, 0,6, 1): cada chave herda os canais da anterior."""
    keys = [rest_pose()]
    for key in ATTACKS[name]:
        pose = dict(keys[-1])
        for channel, value in key.items():
            pose[channel] = list(value) if isinstance(value, tuple) else value
        keys.append(pose)
    return keys


# --- Prévia do Root (giros que o jogo faz por código) ------------------------------------------------

def _q_axis(axis, angle):
    return Quaternion(Vector(axis), angle)


def root_none(_u):
    return None


def root_jump_flip(u):
    return (0.0, _q_axis((1, 0, 0), -TAU * smooth(u)))  # Godot: Basis(RIGHT, -TAU·t)


def root_wall_flip(u):
    t = smooth(u)
    yaw = _q_axis((0, 1, 0), PI * (1.0 - t))  # começa de frente para a parede
    return (0.0, yaw @ _q_axis((1, 0, 0), TAU * t))


def root_roll(u):
    down = clamp(min(u / 0.18, (1.0 - u) / 0.25), 0.0, 1.0)
    return (lerp(0.0, ROLL_BALL_HEIGHT - HIPS_REST_Y * RIG_SCALE, smooth(down)),
            _q_axis((1, 0, 0), -TAU * smooth(u)))


def root_cartwheel(u):
    t = smooth(u)
    return (CARTWHEEL_LIFT * math.sin(PI * t), _q_axis((0, 0, 1), -TAU * t))  # estrela para a direita


def root_spin(u):
    # Giro no acerto (entre 0,35 e 0,6), mantido no fim.
    p = clamp((u - ATTACK_KEY_TIMES[0]) / (ATTACK_KEY_TIMES[1] - ATTACK_KEY_TIMES[0]), 0.0, 1.0)
    return (0.0, _q_axis((0, 1, 0), ATTACK_SPIN["spin"] * (1.0 - (1.0 - p) ** 2)))


# --- Lista de clipes ---------------------------------------------------------------------------------

def _frames(seconds):
    return max(2, int(round(seconds * FPS)))


def _every(frames, step=2):
    return [i / frames for i in range(0, frames + 1, step)] + ([1.0] if frames % step else [])


def clips():
    walk_frames = _frames(STRIDE_WALK / WALK_SPEED)
    sprint_frames = _frames(STRIDE_SPRINT / SPRINT_SPEED)
    idle_frames = _frames(BREATH_PERIOD * 2)
    air_sprint_frames = _frames(TAU / 14.0)
    out = [
        ("idle", idle_frames, _every(idle_frames, 12),
         lambda u: ground_pose(0.0, u * BREATH_PERIOD * 2, 0.0, 0.0, 0.0), root_none),
        ("walk", walk_frames, _every(walk_frames, 2),
         lambda u: ground_pose(u * TAU, 0.0, 1.0, 0.0, 0.0), root_none),
        ("sprint", sprint_frames, _every(sprint_frames, 2),
         lambda u: ground_pose(u * TAU, 0.0, 1.0, 1.0, 1.0), root_none),
        ("air", 30, [0.0, 0.5, 1.0], lambda u: air_pose(1.0 - 2.0 * u), root_none),
        ("air_sprint", air_sprint_frames, _every(air_sprint_frames, 3), air_sprint_pose, root_none),
        ("jump_flip", _frames(JUMP_FLIP_DURATION), _every(_frames(JUMP_FLIP_DURATION), 3), jump_flip_pose,
         root_jump_flip),
        ("wall_stick", 12, [0.0, 1.0], lambda u: wall_kick_pose(), root_none),
        ("wall_flip", _frames(WALL_FLIP_DURATION), _every(_frames(WALL_FLIP_DURATION), 3), wall_flip_pose,
         root_wall_flip),
        ("roll", _frames(ROLL_DURATION), _every(_frames(ROLL_DURATION), 3), roll_pose, root_roll),
        ("cartwheel", _frames(DASH_DURATION), _every(_frames(DASH_DURATION), 3), cartwheel_pose, root_cartwheel),
        ("hurt", 20, [0.0, 1.0], hurt_pose, root_none),
        ("sword_rest", 12, [0.0, 1.0], sword_rest_pose, root_none),
    ]
    for name in ATTACKS:
        keys = attack_keys(name)
        times = (0.0,) + ATTACK_KEY_TIMES
        root = root_spin if name == "spin" else root_none

        def pose_at(u, keys=keys, times=times):
            for i in range(len(times) - 1):
                if u <= times[i + 1] + 1e-6:
                    return blend_pose(keys[i], keys[i + 1], smooth((u - times[i]) / (times[i + 1] - times[i])))
            return keys[-1]

        key_times = list(times) if root is root_none else sorted(set(list(times) + _every(48, 3)))
        out.append(("atk_" + name, 48, key_times, pose_at, root))
    return out


# --- Conversão referência → ossos do Blender ---------------------------------------------------------

def godot_euler_to_quat(e):
    """Quaternion.from_euler do Godot (ordem YXZ) no espaço do glTF/Godot."""
    qx = _q_axis((1, 0, 0), e[0])
    qy = _q_axis((0, 1, 0), e[1])
    qz = _q_axis((0, 0, 1), e[2])
    return qy @ qx @ qz


ARM_REF = {"l": _q_axis((0, 0, 1), PI * 0.5), "r": _q_axis((0, 0, 1), -PI * 0.5)}


def joint_to_bone_local(joint, q):
    """Mesmo cálculo de CharacterModel._set_joint (braços: conversão da T-pose)."""
    if joint.startswith(("shoulder", "elbow", "wrist")):
        ref = ARM_REF[joint[-1]]
        return q @ ref if joint.startswith("shoulder") else ref.inverted() @ q @ ref
    return q


def to_blender(q):
    """Rotação no espaço Y-up do glTF/Godot → espaço Z-up do Blender ((x, y, z) → (x, -z, y))."""
    return Quaternion((q.w, q.x, -q.z, q.y))


def finger_rotations():
    out = {}
    for side, curl in (("L", RELAXED_CURL), ("R", -GRIP_CURL)):
        for finger in ("Index", "Middle", "Ring", "Little"):
            for i, k in enumerate((1.0, 1.1, 0.8)):
                out["J_Bip_%s_%s%d" % (side, finger, i + 1)] = _q_axis((0, 0, 1), curl * k)
        out["J_Bip_%s_Thumb2" % side] = _q_axis((0, 1, 0), curl * 0.5)
    return out


class Rig:
    def __init__(self, arm):
        self.arm = arm
        self.bones = arm.data.bones
        self.order = []

        def visit(bone):
            self.order.append(bone)
            for child in bone.children:
                visit(child)

        for bone in self.bones:
            if bone.parent is None:
                visit(bone)
        self.joint_of = {v: k for k, v in BONE_MAP.items()}
        self.fingers = finger_rotations()

    def basis(self, pose, root):
        """Pose (canais de referência) → {osso: (location, rotation)} no espaço do pose bone."""
        world = {}
        bases = {}
        hips = self.bones[BONE_MAP["hips"]]
        for bone in self.order:
            head = bone.head_local
            q = Quaternion()
            offset = Vector()
            joint = self.joint_of.get(bone.name)
            if joint is not None:
                q = to_blender(joint_to_bone_local(joint, godot_euler_to_quat(pose[joint])))
            elif bone.name in self.fingers:
                q = to_blender(self.fingers[bone.name])
            if bone == hips:
                offset = Vector((0, 0, pose.get("hips_y", 0.0) / RIG_SCALE))
            if bone.parent is None:
                g = Matrix.Translation(head + offset) @ q.to_matrix().to_4x4()
                if root is not None and bone.name == "Root":
                    lift, rot = root
                    pivot = hips.head_local + Vector((0, 0, lift / RIG_SCALE))
                    g = Matrix.Translation(pivot) @ to_blender(rot).to_matrix().to_4x4() \
                        @ Matrix.Translation(-hips.head_local) @ g
            else:
                g = world[bone.parent.name] @ Matrix.Translation(head - bone.parent.head_local + offset) \
                    @ q.to_matrix().to_4x4()
            world[bone.name] = g
            pose_matrix = g @ Matrix.Translation(-head) @ bone.matrix_local
            if bone.parent is None:
                basis = bone.matrix_local.inverted() @ pose_matrix
            else:
                parent = bone.parent
                parent_pose = world[parent.name] @ Matrix.Translation(-parent.head_local) @ parent.matrix_local
                basis = (parent_pose @ parent.matrix_local.inverted() @ bone.matrix_local).inverted() @ pose_matrix
            loc, rot, _scale = basis.decompose()
            bases[bone.name] = (loc, rot)
        return bases


def build(arm):
    global HIPS_REST_Y
    rig = Rig(arm)
    HIPS_REST_Y = arm.data.bones[BONE_MAP["hips"]].head_local.z
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    if arm.animation_data is None:
        arm.animation_data_create()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    first = None
    for name, frames, times, pose_fn, root_fn in clips():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        action.use_frame_range = True
        action.frame_start = 0
        action.frame_end = frames
        arm.animation_data.action = action
        previous = {}
        for u in times:
            bases = rig.basis(pose_fn(u), root_fn(u))
            frame = u * frames
            for bone_name, (loc, rot) in bases.items():
                pb = arm.pose.bones[bone_name]
                if bone_name in previous:
                    rot.make_compatible(previous[bone_name])
                previous[bone_name] = rot
                pb.rotation_quaternion = rot
                pb.keyframe_insert("rotation_quaternion", frame=frame, group=bone_name)
                if bone_name in ("Root", BONE_MAP["hips"]):
                    pb.location = loc
                    pb.keyframe_insert("location", frame=frame, group=bone_name)
        if first is None:
            first = action
    arm.animation_data.action = first
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = int(first.frame_end)
