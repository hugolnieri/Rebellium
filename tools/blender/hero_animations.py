"""Animações do personagem, feitas por poses-chave (keyframes) no Blender. Usado por build_hero.py.

Cada clipe é uma Action do Blender com poses-chave em quadros específicos (60 fps) e interpolação
Bezier entre elas; os ciclos (idle, walk, sprint, air_sprint) dão a volta sem emenda. O jogo toca
estas Actions DIRETO nos ossos (scenes/player/hero_clips.gd); só os giros de corpo inteiro (mortais,
estrela, giro do golpe) são aplicados por código, no ritmo da física. O osso "Root" mostra esses giros
aqui no Blender, como prévia (o jogo ignora o Root).

Como as poses são escritas (para editar este arquivo): cada canal é uma rotação Euler em GRAUS
(x, y, z; ordem YXZ, eixos do Godot: x = direita, y = cima, frente = -z), relativa a uma postura de
referência em pé com os braços ABAIXADOS. O script converte para os ossos do modelo (que estão em
T-pose). Convenções úteis:
  hips/spine/chest x < 0 inclina para frente     y > 0 gira o tronco para a esquerda
  head/neck x > 0 levanta o queixo
  thigh x > 0 leva a perna à frente              thigh_l z < 0 / thigh_r z > 0 abre a perna
  knee x < 0 dobra o joelho                      foot x > 0 levanta a ponta do pé; toe x > 0 dobra os dedos
  shoulder x > 0 levanta o braço à frente        shoulder_l z < 0 / shoulder_r z > 0 abre o braço
  elbow x > 0 dobra o cotovelo                   wrist_r x ≈ -90 deixa a lâmina na linha do braço
  hips_pos: deslocamento do quadril em metros (x, y, z); y < 0 agacha
  grip_l / grip_r: quanto os dedos fecham (radianos por falange)

Mas o jeito normal de mexer é no próprio Blender: abra art/character/hero.blend, escolha a Action no
Dope Sheet → Action Editor, ajuste as poses e exporte (ver export_hero.py).

Clipes e como o jogo os amostra (tempo normalizado 0–1):
  idle, walk, sprint, air_sprint   ciclos (walk/sprint pela fase da passada, os outros pelo tempo)
  air          0 subindo · 0,5 ápice · 1 caindo (pela velocidade vertical)
  jump_flip, wall_flip, roll, cartwheel   pelo progresso do movimento
  wall_stick, dash, hurt, land, sword_rest   poses (sword_rest só vale no braço direito)
  atk_<golpe>  0 prontidão · 0,35 preparação · 0,6 acerto · 1 acompanhamento
"""
import math

import bpy  # noqa: F401  (garante mathutils no python do pip)
from mathutils import Matrix, Quaternion, Vector

FPS = 60
TAU = math.tau
PI = math.pi

REFERENCE_HEIGHT = 1.8
MODEL_HEIGHT = 1.91
RIG_SCALE = REFERENCE_HEIGHT / MODEL_HEIGHT

ROLL_BALL_HEIGHT = 0.36
CARTWHEEL_LIFT = 0.2

BONE_MAP = {
    "hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "chest": "J_Bip_C_Chest",
    "upper_chest": "J_Bip_C_UpperChest", "neck": "J_Bip_C_Neck", "head": "J_Bip_C_Head",
    "clavicle_l": "J_Bip_L_Shoulder", "clavicle_r": "J_Bip_R_Shoulder",
    "shoulder_l": "J_Bip_L_UpperArm", "elbow_l": "J_Bip_L_LowerArm", "wrist_l": "J_Bip_L_Hand",
    "shoulder_r": "J_Bip_R_UpperArm", "elbow_r": "J_Bip_R_LowerArm", "wrist_r": "J_Bip_R_Hand",
    "thigh_l": "J_Bip_L_UpperLeg", "knee_l": "J_Bip_L_LowerLeg", "foot_l": "J_Bip_L_Foot",
    "toe_l": "J_Bip_L_ToeBase",
    "thigh_r": "J_Bip_R_UpperLeg", "knee_r": "J_Bip_R_LowerLeg", "foot_r": "J_Bip_R_Foot",
    "toe_r": "J_Bip_R_ToeBase",
}
JOINTS = list(BONE_MAP)
ARM_JOINTS = ("shoulder", "elbow", "wrist")
FINGERS = ("Index", "Middle", "Ring", "Little")
PHALANX_CURL = (1.0, 1.1, 0.8)


# --- Poses ----------------------------------------------------------------------------------------

def pose(**channels):
    out = {}
    for key, value in channels.items():
        out[key] = tuple(float(v) for v in value) if isinstance(value, (tuple, list)) else float(value)
    return out


def over(base, *layers):
    out = dict(base)
    for layer in layers:
        out.update(layer)
    return out


def lerp_pose(a, b, t):
    out = dict(a)
    for key, value in b.items():
        if key not in out:
            out[key] = value
        elif isinstance(value, tuple):
            out[key] = tuple(out[key][i] + (value[i] - out[key][i]) * t for i in range(3))
        else:
            out[key] = out[key] + (value - out[key]) * t
    return out


def mirror(p):
    """Espelha a pose (esquerda ↔ direita): troca _l/_r e inverte y/z das rotações e x da posição."""
    out = {}
    for key, value in p.items():
        if key.endswith("_l"):
            target = key[:-2] + "_r"
        elif key.endswith("_r"):
            target = key[:-2] + "_l"
        else:
            target = key
        if key == "hips_pos":
            out[target] = (-value[0], value[1], value[2])
        elif isinstance(value, tuple):
            out[target] = (value[0], -value[1], -value[2])
        else:
            out[target] = value
    return out


def legs_torso(p):
    return {k: v for k, v in p.items() if not k.startswith(("shoulder", "elbow", "wrist", "clavicle", "grip"))}


# Postura de prontidão (base de todas as poses): peso nas duas pernas, lâmina baixa à frente.
READY = pose(
    hips=(0, 0, 0), hips_pos=(0, -0.025, 0),
    spine=(-3, 0, 0), chest=(4, 0, 0), upper_chest=(1, 0, 0), neck=(-3, 0, 0), head=(3, 0, 0),
    clavicle_l=(0, 0, 0), clavicle_r=(0, 0, 0),
    shoulder_l=(8, 0, -12), elbow_l=(22, 0, 0), wrist_l=(0, 0, -5),
    shoulder_r=(20, 3, 10), elbow_r=(43, 0, 0), wrist_r=(-20, 0, 0),
    thigh_l=(4, 0, -9), knee_l=(-7, 0, 0), foot_l=(3, 0, 9), toe_l=(0, 0, 0),
    thigh_r=(-3, 0, 8), knee_r=(-12, 0, 0), foot_r=(15, 0, -8), toe_r=(0, 0, 0),
    grip_l=0.35, grip_r=1.25,
)


# --- Ciclos ---------------------------------------------------------------------------------------

def idle_keys():
    inhale = pose(chest=(6.5, 0, 0), upper_chest=(2, 0, 0), spine=(-2, 0, 0), neck=(-4.5, 0, 0),
                  clavicle_l=(0, 0, -2), clavicle_r=(0, 0, 2), hips_pos=(0, -0.02, 0))
    exhale = pose(chest=(3, 0, 0), spine=(-3.5, 0, 0), hips_pos=(0, -0.03, 0))
    left = pose(hips=(0, 0, -2.5), hips_pos=(-0.018, -0.028, 0), spine=(-3, 0, 1.5), head=(3, -7, 0),
                thigh_l=(4, 0, -7), thigh_r=(-1, 0, 10), knee_r=(-16, 0, 0), foot_r=(17, 0, -10))
    right = pose(hips=(0, 0, 1.5), hips_pos=(0.012, -0.028, 0), spine=(-3, 0, -1), head=(2, 6, 0),
                 thigh_l=(2, 0, -11), knee_l=(-10, 0, 0), foot_l=(8, 0, 11), thigh_r=(-3, 0, 6))
    return [
        (0, over(READY, exhale)),
        (63, over(READY, left, inhale)),
        (126, over(READY, left, exhale)),
        (189, over(READY, right, inhale)),
        (252, over(READY, exhale)),
    ]


def _arm_swing(phase, amp_l, amp_r, base_r):
    c = math.cos(phase - 0.3)  # braços atrasam um pouco em relação às pernas
    return pose(
        shoulder_l=(6 - amp_l * c, 0, -14), elbow_l=(85 - 12 * c, 0, 0), wrist_l=(-5, 0, -8),
        shoulder_r=(base_r + amp_r * c, 4, 14), elbow_r=(52 + 8 * c, 0, 0), wrist_r=(-18, 0, 0),
        clavicle_l=(0, 3 * c, 0), clavicle_r=(0, 3 * c, 0),
    )


def walk_keys():
    """Trote leve (6 m/s): contato → carga → impulso → voo curto, com um pulinho a cada passo."""
    frames = 34
    half = [
        (0, pose(hips=(-10, -7, 0), hips_pos=(0, -0.03, 0), spine=(-4, 0, 1), chest=(-2, 7, 0),
                 upper_chest=(0, 2, 0), neck=(2, -1, 0), head=(14, -1, 0),
                 thigh_l=(38, 0, -2), knee_l=(-10, 0, 0), foot_l=(-6, 0, 0), toe_l=(0, 0, 0),
                 thigh_r=(-10, 0, 2), knee_r=(-75, 0, 0), foot_r=(-25, 0, 0), toe_r=(0, 0, 0))),
        (5, pose(hips=(-11, -3, -4), hips_pos=(-0.015, -0.07, 0), spine=(-5, 0, 2), chest=(-3, 3, 1),
                 upper_chest=(0, 1, 0), neck=(2, 0, 0), head=(15, 0, 0),
                 thigh_l=(15, 0, -2), knee_l=(-32, 0, 0), foot_l=(27, 0, 0), toe_l=(0, 0, 0),
                 thigh_r=(20, 0, 2), knee_r=(-112, 0, 0), foot_r=(-15, 0, 0), toe_r=(0, 0, 0))),
        (11, pose(hips=(-10, 4, -1), hips_pos=(-0.005, -0.01, 0), spine=(-4, 0, 1), chest=(-2, -3, 0),
                  upper_chest=(0, -1, 0), neck=(2, 0, 0), head=(14, 0, 0),
                  thigh_l=(-12, 0, -2), knee_l=(-12, 0, 0), foot_l=(-2, 0, 0), toe_l=(32, 0, 0),
                  thigh_r=(50, 0, 2), knee_r=(-72, 0, 0), foot_r=(-5, 0, 0), toe_r=(0, 0, 0))),
        (14, pose(hips=(-10, 6, 0), hips_pos=(0, 0.045, 0), spine=(-4, 0, 0), chest=(-2, -6, 0),
                  upper_chest=(0, -2, 0), neck=(2, 1, 0), head=(14, 1, 0),
                  thigh_l=(-15, 0, -2), knee_l=(-48, 0, 0), foot_l=(-25, 0, 0), toe_l=(5, 0, 0),
                  thigh_r=(47, 0, 2), knee_r=(-35, 0, 0), foot_r=(2, 0, 0), toe_r=(0, 0, 0))),
    ]
    return _cycle(frames, half, lambda ph: _arm_swing(ph, 32, 16, 16))


def sprint_keys():
    """Sprint ninja (10 m/s): corpo bem mergulhado, braços esticados para trás na horizontal."""
    frames = 26
    half = [
        (0, pose(hips=(-40, -5, 0), hips_pos=(0, -0.1, 0), spine=(-6, 0, 0), chest=(-2, 5, 0),
                 upper_chest=(0, 1, 0), neck=(10, 0, 0), head=(32, -1, 0),
                 thigh_l=(75, 0, -2), knee_l=(-18, 0, 0), foot_l=(-12, 0, 0), toe_l=(0, 0, 0),
                 thigh_r=(10, 0, 2), knee_r=(-100, 0, 0), foot_r=(-30, 0, 0), toe_r=(0, 0, 0))),
        (4, pose(hips=(-41, -2, -3), hips_pos=(-0.01, -0.15, 0), spine=(-7, 0, 1), chest=(-3, 2, 0),
                 upper_chest=(0, 0, 0), neck=(10, 0, 0), head=(33, 0, 0),
                 thigh_l=(52, 0, -2), knee_l=(-42, 0, 0), foot_l=(30, 0, 0), toe_l=(0, 0, 0),
                 thigh_r=(62, 0, 2), knee_r=(-138, 0, 0), foot_r=(-20, 0, 0), toe_r=(0, 0, 0))),
        (8, pose(hips=(-40, 3, 0), hips_pos=(0, -0.08, 0), spine=(-6, 0, 0), chest=(-2, -2, 0),
                 upper_chest=(0, 0, 0), neck=(10, 0, 0), head=(32, 0, 0),
                 thigh_l=(10, 0, -2), knee_l=(-10, 0, 0), foot_l=(0, 0, 0), toe_l=(35, 0, 0),
                 thigh_r=(100, 0, 2), knee_r=(-95, 0, 0), foot_r=(-8, 0, 0), toe_r=(0, 0, 0))),
        (11, pose(hips=(-40, 5, 0), hips_pos=(0, -0.05, 0), spine=(-6, 0, 0), chest=(-2, -5, 0),
                  upper_chest=(0, -1, 0), neck=(10, 0, 0), head=(32, 1, 0),
                  thigh_l=(2, 0, -2), knee_l=(-58, 0, 0), foot_l=(-30, 0, 0), toe_l=(5, 0, 0),
                  thigh_r=(96, 0, 2), knee_r=(-48, 0, 0), foot_r=(0, 0, 0), toe_r=(0, 0, 0))),
    ]

    def arms(ph):
        bounce = 4 * math.sin(2 * ph)
        return pose(shoulder_l=(-42 + bounce, 0, -10), elbow_l=(4, 0, 0), wrist_l=(-12, 0, 0),
                    shoulder_r=(-42 - bounce, 0, 10), elbow_r=(4, 0, 0), wrist_r=(-80, 0, 0),
                    clavicle_l=(0, -6, 0), clavicle_r=(0, 6, 0), grip_l=0.15)
    return _cycle(frames, half, arms)


def air_sprint_keys():
    frames = 26
    half = [
        (0, pose(hips=(-30, -4, 0), hips_pos=(0, 0, 0), spine=(-5, 0, 0), chest=(-2, 4, 0), neck=(8, 0, 0),
                 head=(26, 0, 0), thigh_l=(70, 0, -3), knee_l=(-55, 0, 0), foot_l=(-15, 0, 0),
                 thigh_r=(0, 0, 3), knee_r=(-100, 0, 0), foot_r=(-35, 0, 0))),
        (6, pose(hips=(-30, 0, 0), hips_pos=(0, 0.01, 0), spine=(-5, 0, 0), chest=(-2, 0, 0), neck=(8, 0, 0),
                 head=(26, 0, 0), thigh_l=(40, 0, -3), knee_l=(-100, 0, 0), foot_l=(-25, 0, 0),
                 thigh_r=(45, 0, 3), knee_r=(-120, 0, 0), foot_r=(-25, 0, 0))),
    ]

    def arms(ph):
        bounce = 3 * math.sin(2 * ph)
        return pose(shoulder_l=(-58 + bounce, 0, -10), elbow_l=(4, 0, 0), wrist_l=(-12, 0, 0),
                    shoulder_r=(-58 - bounce, 0, 10), elbow_r=(4, 0, 0), wrist_r=(-80, 0, 0),
                    clavicle_l=(0, -6, 0), clavicle_r=(0, 6, 0), grip_l=0.15)
    return _cycle(frames, half, arms)


def _cycle(frames, half, arms):
    """Meio ciclo (perna esquerda) + espelho na outra metade; braços por função da fase."""
    keys = []
    for frame, p in half:
        keys.append((frame, p))
    for frame, p in half:
        keys.append((frame + frames // 2, mirror(legs_torso(p))))
    keys.append((frames, half[0][1]))
    out = []
    for frame, p in sorted(keys, key=lambda k: k[0]):
        phase = TAU * frame / frames
        out.append((frame, over(READY, p, arms(phase))))
    return out


# --- Ar -------------------------------------------------------------------------------------------

RISE = over(READY, pose(
    hips=(-5, 0, 0), hips_pos=(0, 0, 0), spine=(-8, 0, 0), chest=(-2, 0, 0), head=(8, 0, 0),
    thigh_l=(75, 0, -4), knee_l=(-105, 0, 0), foot_l=(-15, 0, 0),
    thigh_r=(-8, 0, 4), knee_r=(-45, 0, 0), foot_r=(-35, 0, 0), toe_r=(10, 0, 0),
    shoulder_l=(55, 0, -15), elbow_l=(65, 0, 0), shoulder_r=(-15, 5, 25), elbow_r=(55, 0, 0),
    wrist_r=(-30, 0, 0)))
APEX = over(READY, pose(
    hips=(0, 0, 0), hips_pos=(0, 0, 0), spine=(-4, 0, 0), head=(4, 0, 0),
    thigh_l=(50, 0, -6), knee_l=(-80, 0, 0), foot_l=(-10, 0, 0),
    thigh_r=(18, 0, 6), knee_r=(-60, 0, 0), foot_r=(-20, 0, 0),
    shoulder_l=(30, 0, -40), elbow_l=(45, 0, 0), shoulder_r=(5, 5, 45), elbow_r=(40, 0, 0),
    wrist_r=(-35, 0, 0)))
FALL = over(READY, pose(
    hips=(4, 0, 0), hips_pos=(0, 0, 0), spine=(4, 0, 0), chest=(2, 0, 0), head=(-10, 0, 0),
    thigh_l=(28, 0, -6), knee_l=(-35, 0, 0), foot_l=(8, 0, 0),
    thigh_r=(12, 0, 6), knee_r=(-22, 0, 0), foot_r=(5, 0, 0),
    shoulder_l=(25, 0, -70), elbow_l=(25, 0, 0), shoulder_r=(20, 5, 65), elbow_r=(25, 0, 0),
    wrist_r=(-35, 0, 0), grip_l=0.2))
TUCK = over(READY, pose(
    hips=(0, 0, 0), hips_pos=(0, 0, 0), spine=(-32, 0, 0), chest=(-15, 0, 0), neck=(-10, 0, 0),
    head=(-15, 0, 0), thigh_l=(120, 0, -6), knee_l=(-140, 0, 0), foot_l=(-20, 0, 0),
    thigh_r=(120, 0, 6), knee_r=(-140, 0, 0), foot_r=(-20, 0, 0),
    shoulder_l=(75, 0, 5), elbow_l=(100, 0, 0), shoulder_r=(35, 0, 35), elbow_r=(80, 0, 0),
    wrist_r=(-40, 0, 0), grip_l=1.0))
OPEN = over(READY, pose(
    hips=(0, 0, 0), hips_pos=(0, 0, 0), spine=(-6, 0, 0), head=(-4, 0, 0),
    thigh_l=(45, 0, -8), knee_l=(-55, 0, 0), thigh_r=(22, 0, 8), knee_r=(-35, 0, 0),
    shoulder_l=(30, 0, -60), elbow_l=(30, 0, 0), shoulder_r=(25, 5, 60), elbow_r=(30, 0, 0)))
WALL_STICK = over(READY, pose(
    hips_pos=(0, -0.28, 0), thigh_l=(100, 0, 6), thigh_r=(77, 0, -6), knee_l=(-132, 0, 0),
    knee_r=(-115, 0, 0), foot_l=(29, 0, 0), foot_r=(23, 0, 0), toe_l=(20, 0, 0), toe_r=(20, 0, 0),
    spine=(-20, 0, 0), chest=(-11, 0, 0), neck=(6, 0, 0), head=(18, 0, 0),
    shoulder_l=(92, 0, -34), shoulder_r=(80, 0, 34), elbow_l=(29, 0, 0), elbow_r=(29, 0, 0),
    clavicle_l=(0, 0, -6), clavicle_r=(0, 0, 6)))


def air_keys():
    return [(0, RISE), (15, APEX), (30, FALL)]


def jump_flip_keys():
    begin = over(READY, pose(
        hips_pos=(0, 0, 0), spine=(-20, 0, 0), chest=(-10, 0, 0), head=(-10, 0, 0),
        thigh_l=(95, 0, -6), knee_l=(-120, 0, 0), thigh_r=(95, 0, 6), knee_r=(-120, 0, 0),
        foot_l=(-20, 0, 0), foot_r=(-20, 0, 0),
        shoulder_l=(70, 0, -5), elbow_l=(80, 0, 0), shoulder_r=(30, 0, 30), elbow_r=(70, 0, 0)))
    return [(0, RISE), (8, begin), (14, TUCK), (22, TUCK), (30, OPEN), (37, FALL)]


def wall_stick_keys():
    breathe = pose(chest=(-9, 0, 0), hips_pos=(0, -0.27, 0))
    return [(0, WALL_STICK), (6, over(WALL_STICK, breathe)), (12, WALL_STICK)]


def wall_flip_keys():
    push = over(READY, pose(
        hips_pos=(0, 0, 0), hips=(8, 0, 0), spine=(12, 0, 0), chest=(6, 0, 0), head=(20, 0, 0),
        thigh_l=(30, 0, -4), knee_l=(-15, 0, 0), foot_l=(-30, 0, 0), toe_l=(-10, 0, 0),
        thigh_r=(20, 0, 4), knee_r=(-25, 0, 0), foot_r=(-30, 0, 0),
        shoulder_l=(160, 0, -20), elbow_l=(15, 0, 0), shoulder_r=(150, 0, 25), elbow_r=(20, 0, 0),
        clavicle_l=(0, 0, -12), clavicle_r=(0, 0, 12), grip_l=0.1))
    tuck = over(TUCK, pose(shoulder_l=(70, 0, -10), shoulder_r=(60, 0, 20)))
    return [(0, WALL_STICK), (5, push), (11, tuck), (20, tuck), (26, OPEN), (30, FALL)]


# --- Chão: cambalhota, estrela, dash, pouso, dano ---------------------------------------------------

def roll_keys():
    reach = over(READY, pose(
        hips_pos=(0, -0.15, 0), hips=(-10, 0, 0), spine=(-35, 0, 0), chest=(-15, 0, 0), head=(-10, 0, 0),
        thigh_l=(80, 0, -6), knee_l=(-110, 0, 0), foot_l=(30, 0, 0),
        thigh_r=(70, 0, 6), knee_r=(-105, 0, 0), foot_r=(30, 0, 0),
        shoulder_l=(75, 0, -15), elbow_l=(25, 0, 0), shoulder_r=(70, 0, 20), elbow_r=(30, 0, 0)))
    ball = over(READY, pose(
        hips_pos=(0, 0, 0), spine=(-52, 0, 0), chest=(-29, 0, 0), neck=(-12, 0, 0), head=(-30, 0, 0),
        thigh_l=(120, 0, 7), knee_l=(-138, 0, 0), foot_l=(-20, 0, 0),
        thigh_r=(120, 0, -7), knee_r=(-138, 0, 0), foot_r=(-20, 0, 0),
        shoulder_l=(69, 0, 6), elbow_l=(80, 0, 0), shoulder_r=(57, 0, -6), elbow_r=(69, 0, 0),
        grip_l=1.1))
    unfold = over(READY, pose(
        hips_pos=(0, -0.2, 0), hips=(-8, 0, 0), spine=(-25, 0, 0), chest=(-10, 0, 0), head=(5, 0, 0),
        thigh_l=(85, 0, -6), knee_l=(-125, 0, 0), foot_l=(40, 0, 0),
        thigh_r=(75, 0, 6), knee_r=(-120, 0, 0), foot_r=(40, 0, 0),
        shoulder_l=(40, 0, -25), elbow_l=(40, 0, 0), shoulder_r=(35, 0, 30), elbow_r=(45, 0, 0)))
    rise = over(READY, pose(
        hips_pos=(0, -0.09, 0), spine=(-8, 0, 0), head=(6, 0, 0),
        thigh_l=(30, 0, -9), knee_l=(-45, 0, 0), foot_l=(15, 0, 9),
        thigh_r=(22, 0, 8), knee_r=(-45, 0, 0), foot_r=(23, 0, -8)))
    return [(0, reach), (7, ball), (30, over(ball, pose(spine=(-48, 0, 0)))), (37, unfold), (42, rise)]


def cartwheel_keys():
    up = over(READY, pose(
        hips_pos=(0, -0.05, 0), shoulder_l=(10, 0, -100), shoulder_r=(10, 0, 100), elbow_l=(15, 0, 0),
        elbow_r=(15, 0, 0), thigh_l=(10, 0, -12), thigh_r=(5, 0, 12), knee_l=(-15, 0, 0), knee_r=(-10, 0, 0),
        grip_l=0.1))
    star = over(READY, pose(
        hips_pos=(0, 0, 0), spine=(3, 0, 0), chest=(2, 0, 0), head=(10, 0, 0),
        shoulder_l=(8, 0, -165), shoulder_r=(8, 0, 165), elbow_l=(6, 0, 0), elbow_r=(6, 0, 0),
        clavicle_l=(0, 0, -15), clavicle_r=(0, 0, 15),
        thigh_l=(3, 0, -45), thigh_r=(3, 0, 45), knee_l=(-8, 0, 0), knee_r=(-8, 0, 0),
        foot_l=(-20, 0, 0), foot_r=(-20, 0, 0), grip_l=0.05))
    closing = over(star, pose(thigh_l=(10, 0, -25), thigh_r=(10, 0, 25), shoulder_l=(10, 0, -145),
                              shoulder_r=(10, 0, 145), knee_l=(-20, 0, 0), knee_r=(-20, 0, 0)))
    land = over(READY, pose(
        hips_pos=(0, -0.1, 0), spine=(-8, 0, 0), thigh_l=(25, 0, -14), knee_l=(-45, 0, 0), foot_l=(20, 0, 14),
        thigh_r=(15, 0, 14), knee_r=(-40, 0, 0), foot_r=(25, 0, -14),
        shoulder_l=(15, 0, -60), shoulder_r=(15, 0, 60), elbow_l=(20, 0, 0), elbow_r=(25, 0, 0)))
    return [(0, up), (8, star), (20, star), (31, closing), (39, land)]


def dash_keys():
    crouch = over(READY, pose(
        hips_pos=(0, -0.2, 0), hips=(-8, 0, 0), spine=(-15, 0, 0), head=(12, 0, 0),
        thigh_l=(35, 0, -17), knee_l=(-70, 0, 0), foot_l=(43, 0, 17),
        thigh_r=(35, 0, 17), knee_r=(-70, 0, 0), foot_r=(43, 0, -17),
        shoulder_l=(30, 0, -45), elbow_l=(50, 0, 0), shoulder_r=(30, 0, 45), elbow_r=(50, 0, 0)))
    return [(0, crouch), (20, crouch)]


def land_keys():
    impact = over(READY, pose(
        hips_pos=(0, -0.22, 0), hips=(-8, 0, 0), spine=(-18, 0, 0), chest=(-6, 0, 0), head=(15, 0, 0),
        thigh_l=(60, 0, -10), knee_l=(-100, 0, 0), foot_l=(40, 0, 10),
        thigh_r=(55, 0, 10), knee_r=(-100, 0, 0), foot_r=(45, 0, -10),
        shoulder_l=(35, 0, -40), elbow_l=(40, 0, 0), shoulder_r=(30, 3, 40), elbow_r=(45, 0, 0)))
    return [(0, impact), (15, READY)]


def hurt_keys():
    recoil = over(READY, pose(
        hips_pos=(0, -0.08, 0.03), hips=(6, 0, 0), spine=(25, 8, 0), chest=(12, 0, 0), neck=(8, 0, 0),
        head=(20, 0, 0), shoulder_l=(35, 0, -50), shoulder_r=(30, 0, 50), elbow_l=(45, 0, 0),
        knee_l=(-28, 0, 0), knee_r=(-18, 0, 0), grip_l=0.8))
    return [(0, READY), (4, recoil), (20, lerp_pose(recoil, READY, 0.5))]


def sword_rest_keys():
    rest = over(READY, pose(shoulder_r=(14.3, 4.0, 5.7), elbow_r=(68.8, 0, 0), wrist_r=(63.0, -5.7, -22.3)))
    return [(0, rest), (12, rest)]


# --- Golpes ----------------------------------------------------------------------------------------
# Três poses por golpe (graus): preparação, acerto e acompanhamento. O script acrescenta a
# antecipação (saindo da prontidão), o meio do arco (lâmina passando à frente) e a acomodação.

ATTACKS = {
    "slash_r": [
        pose(spine=(3, -32, 0), chest=(0, -20, 0), shoulder_r=(72, -77, 14), elbow_r=(40, 0, 0),
             wrist_r=(-57, 0, 17), shoulder_l=(34, 0, -20), elbow_l=(74, 0, 0), thigh_l=(20, 0, 0),
             knee_l=(-26, 0, 0), thigh_r=(-14, 0, 0), knee_r=(-20, 0, 0), hips=(0, -17, 0)),
        pose(spine=(-9, 32, 0), chest=(0, 23, 0), shoulder_r=(83, 57, 0), elbow_r=(6, 0, 0),
             wrist_r=(-80, 0, -11), shoulder_l=(11, 0, -40), elbow_l=(34, 0, 0), thigh_l=(32, 0, 0),
             knee_l=(-34, 0, 0), thigh_r=(-20, 0, 0), knee_r=(-11, 0, 0), hips=(0, 20, 0), hips_pos=(0, -0.06, 0)),
        pose(spine=(-6, 43, 0), chest=(0, 26, 0), shoulder_r=(60, 83, 0), elbow_r=(26, 0, 0),
             wrist_r=(-57, 0, 0), shoulder_l=(17, 0, -29), elbow_l=(52, 0, 0)),
    ],
    "slash_l": [
        pose(spine=(3, 34, 0), chest=(0, 20, 0), shoulder_r=(69, 72, 0), elbow_r=(69, 0, 0),
             wrist_r=(-46, 0, -23), shoulder_l=(17, 0, -34), elbow_l=(46, 0, 0), thigh_r=(20, 0, 0),
             knee_r=(-26, 0, 0), thigh_l=(-14, 0, 0), knee_l=(-20, 0, 0), hips=(0, 17, 0)),
        pose(spine=(-9, -34, 0), chest=(0, -23, 0), shoulder_r=(83, -69, 6), elbow_r=(7, 0, 0),
             wrist_r=(-80, 0, 17), shoulder_l=(40, 0, -17), elbow_l=(69, 0, 0), thigh_r=(29, 0, 0),
             knee_r=(-32, 0, 0), thigh_l=(-20, 0, 0), knee_l=(-11, 0, 0), hips=(0, -20, 0), hips_pos=(0, -0.06, 0)),
        pose(spine=(-6, -46, 0), chest=(0, -26, 0), shoulder_r=(57, -89, 11), elbow_r=(29, 0, 0),
             wrist_r=(-57, 0, 11)),
    ],
    "overhead": [
        pose(spine=(14, -11, 0), chest=(9, 0, 0), shoulder_r=(158, 6, 9), elbow_r=(74, 0, 0),
             wrist_r=(-29, 0, 0), shoulder_l=(138, 0, -11), elbow_l=(80, 0, 0), thigh_l=(17, 0, 0),
             knee_l=(-17, 0, 0), thigh_r=(-11, 0, 0), hips_pos=(0, 0.02, 0)),
        pose(spine=(-32, 6, 0), chest=(-14, 0, 0), shoulder_r=(54, 9, 0), elbow_r=(3, 0, 0),
             wrist_r=(-83, 0, 0), shoulder_l=(29, 0, -23), elbow_l=(40, 0, 0), thigh_l=(43, 0, 0),
             knee_l=(-52, 0, 0), thigh_r=(-26, 0, 0), knee_r=(-29, 0, 0), hips_pos=(0, -0.12, 0)),
        pose(spine=(-26, 6, 0), shoulder_r=(32, 11, 0), elbow_r=(17, 0, 0), wrist_r=(-74, 0, 0),
             hips_pos=(0, -0.1, 0)),
    ],
    "thrust": [
        pose(spine=(3, -29, 0), shoulder_r=(52, -29, 20), elbow_r=(109, 0, 0), wrist_r=(-89, 0, 0),
             shoulder_l=(57, 0, -11), elbow_l=(23, 0, 0), thigh_l=(17, 0, 0), knee_l=(-29, 0, 0),
             thigh_r=(-17, 0, 0), knee_r=(-23, 0, 0)),
        pose(spine=(-17, 20, 0), shoulder_r=(86, 9, 0), elbow_r=(0, 0, 0), wrist_r=(-90, 0, 0),
             shoulder_l=(11, 0, -52), elbow_l=(17, 0, 0), thigh_l=(43, 0, 0), knee_l=(-40, 0, 0),
             thigh_r=(-32, 0, 0), knee_r=(-6, 0, 0), hips_pos=(0, -0.1, 0)),
        pose(spine=(-11, 17, 0), shoulder_r=(69, 6, 0), elbow_r=(23, 0, 0)),
    ],
    "spin": [
        # Gira para a DIREITA: prepara torcendo o tronco para a esquerda.
        pose(spine=(6, 40, 0), chest=(0, 17, 0), shoulder_r=(23, 34, 52), elbow_r=(34, 0, 0),
             wrist_r=(-69, 0, 0), shoulder_l=(29, 0, -57), elbow_l=(34, 0, 0), thigh_l=(23, 0, -14),
             knee_l=(-46, 0, 0), thigh_r=(6, 0, 17), knee_r=(-46, 0, 0), hips_pos=(0, -0.2, 0)),
        pose(spine=(-6, 11, 0), shoulder_r=(9, 0, 83), elbow_r=(3, 0, 0), wrist_r=(-86, 0, 0),
             shoulder_l=(6, 0, -74), elbow_l=(11, 0, 0), thigh_l=(11, 0, -20), knee_l=(-29, 0, 0),
             thigh_r=(11, 0, 20), knee_r=(-29, 0, 0), hips_pos=(0, -0.15, 0)),
        pose(spine=(-9, -23, 0), shoulder_r=(46, -46, 34), elbow_r=(23, 0, 0), hips_pos=(0, -0.1, 0)),
    ],
    "rising": [
        pose(spine=(-17, -17, 0), shoulder_r=(-17, -17, 23), elbow_r=(23, 0, 0), wrist_r=(-69, 0, 0),
             shoulder_l=(46, 0, -17), elbow_l=(69, 0, 0), thigh_l=(40, 0, 0), knee_l=(-69, 0, 0),
             thigh_r=(6, 0, 0), knee_r=(-63, 0, 0), hips_pos=(0, -0.25, 0)),
        pose(spine=(17, 17, 0), chest=(11, 0, 0), shoulder_r=(166, 11, 6), elbow_r=(6, 0, 0),
             wrist_r=(-86, 0, 0), shoulder_l=(17, 0, -52), thigh_l=(52, 0, 0), knee_l=(-80, 0, 0),
             thigh_r=(-11, 0, 0), knee_r=(-11, 0, 0), hips_pos=(0, 0.05, 0)),
        pose(spine=(9, 11, 0), shoulder_r=(138, 11, 6), elbow_r=(23, 0, 0)),
    ],
    "air_slam": [
        pose(spine=(20, 0, 0), chest=(11, 0, 0), shoulder_r=(172, 0, 6), elbow_r=(57, 0, 0),
             wrist_r=(-34, 0, 0), shoulder_l=(160, 0, -6), elbow_l=(63, 0, 0), thigh_l=(69, 0, 0),
             knee_l=(-103, 0, 0), thigh_r=(52, 0, 0), knee_r=(-92, 0, 0)),
        pose(spine=(-40, 0, 0), chest=(-17, 0, 0), shoulder_r=(40, 6, 0), elbow_r=(3, 0, 0),
             wrist_r=(-89, 0, 0), shoulder_l=(23, 0, -46), thigh_l=(80, 0, 0), knee_l=(-109, 0, 0),
             thigh_r=(34, 0, 0), knee_r=(-69, 0, 0)),
        pose(spine=(-34, 0, 0), shoulder_r=(29, 6, 0), elbow_r=(11, 0, 0)),
    ],
    "dash_thrust": [
        pose(spine=(-11, -23, 0), shoulder_r=(34, -23, 17), elbow_r=(103, 0, 0), wrist_r=(-89, 0, 0),
             shoulder_l=(74, 0, -6), elbow_l=(17, 0, 0), thigh_l=(34, 0, 0), knee_l=(-46, 0, 0),
             thigh_r=(-29, 0, 0), knee_r=(-34, 0, 0), hips_pos=(0, -0.18, 0)),
        pose(spine=(-34, 14, 0), chest=(-9, 0, 0), shoulder_r=(89, 6, 0), elbow_r=(0, 0, 0),
             wrist_r=(-90, 0, 0), shoulder_l=(-29, 0, -29), elbow_l=(11, 0, 0), thigh_l=(52, 0, 0),
             knee_l=(-52, 0, 0), thigh_r=(-46, 0, 0), knee_r=(-9, 0, 0), hips_pos=(0, -0.22, 0)),
        pose(spine=(-23, 11, 0), shoulder_r=(69, 6, 0), elbow_r=(17, 0, 0), hips_pos=(0, -0.12, 0)),
    ],
    "jab": [
        pose(spine=(0, -20, 0), shoulder_r=(52, -17, 17), elbow_r=(97, 0, 0), wrist_r=(-86, 0, 0),
             shoulder_l=(57, 0, -11), elbow_l=(80, 0, 0), thigh_l=(14, 0, 0), knee_l=(-23, 0, 0),
             thigh_r=(-11, 0, 0), knee_r=(-20, 0, 0)),
        pose(spine=(-9, 17, 0), shoulder_r=(86, 7, 0), elbow_r=(3, 0, 0), wrist_r=(-86, 0, 0),
             shoulder_l=(34, 0, -23), elbow_l=(86, 0, 0), thigh_l=(26, 0, 0), knee_l=(-29, 0, 0),
             hips_pos=(0, -0.05, 0)),
        pose(spine=(-6, 11, 0), shoulder_r=(69, 6, 0), elbow_r=(29, 0, 0)),
    ],
    "backhand": [
        pose(spine=(0, 29, 0), shoulder_r=(57, 63, 0), elbow_r=(92, 0, 0), wrist_r=(-52, 0, -23),
             shoulder_l=(29, 0, -29), elbow_l=(57, 0, 0), thigh_r=(17, 0, 0), knee_r=(-23, 0, 0)),
        pose(spine=(-6, -29, 0), shoulder_r=(77, -63, 11), elbow_r=(11, 0, 0), wrist_r=(-74, 0, 17),
             shoulder_l=(46, 0, -11), elbow_l=(74, 0, 0), thigh_r=(26, 0, 0), knee_r=(-29, 0, 0),
             hips_pos=(0, -0.05, 0)),
        pose(spine=(-3, -34, 0), shoulder_r=(57, -80, 11), elbow_r=(29, 0, 0)),
    ],
}
ATTACK_FRAMES = 48
# Tempos normalizados (0–1) das poses de preparação, acerto e fim no clipe.
ATTACK_KEY_TIMES = (0.35, 0.6, 1.0)
# Giro total do corpo no acerto (só prévia; no jogo vem de AttackPoses.SPIN).
ATTACK_SPIN = {"spin": -TAU}


def attack_keys(name):
    windup_p, hit_p, follow_p = ATTACKS[name]
    windup = over(READY, windup_p)
    hit = over(windup, hit_p)
    follow = over(hit, follow_p)
    # Antecipação: recua um pouco além da preparação; meio do arco: lâmina passando à frente.
    anticipation = lerp_pose(READY, windup, 0.45)
    overshoot = lerp_pose(hit, windup, -0.12)  # passa um pouco do acerto (chicote)
    mid = lerp_pose(windup, hit, 0.5)
    rs = mid.get("shoulder_r", (0, 0, 0))
    mid["shoulder_r"] = (rs[0] + 10, rs[1], rs[2])
    settle = lerp_pose(hit, follow, 0.6)
    f = ATTACK_FRAMES
    t0, t1, t2 = ATTACK_KEY_TIMES
    return [
        (0, READY), (round(f * 0.15), anticipation), (round(f * t0), windup),
        (round(f * (t0 + t1) / 2), mid), (round(f * t1), hit), (round(f * (t1 + 0.06)), overshoot),
        (round(f * 0.8), settle), (round(f * t2), follow),
    ]


# --- Prévia do Root (giros que o jogo faz por código) ---------------------------------------------

def smooth(t):
    return t * t * (3.0 - 2.0 * t)


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def _q_axis(axis, angle):
    return Quaternion(Vector(axis), angle)


def root_jump_flip(u):
    return (0.0, _q_axis((1, 0, 0), -TAU * smooth(u)))


def root_wall_flip(u):
    t = smooth(u)
    return (0.0, _q_axis((0, 1, 0), PI * (1.0 - t)) @ _q_axis((1, 0, 0), TAU * t))


def make_root_roll(hips_rest_y):
    def root_roll(u):
        down = clamp(min(u / 0.18, (1.0 - u) / 0.25), 0.0, 1.0)
        return ((ROLL_BALL_HEIGHT - hips_rest_y * RIG_SCALE) * smooth(down), _q_axis((1, 0, 0), -TAU * smooth(u)))
    return root_roll


def root_cartwheel(u):
    t = smooth(u)
    return (CARTWHEEL_LIFT * math.sin(PI * t), _q_axis((0, 0, 1), -TAU * t))


def root_spin(u):
    t0, t1, _ = ATTACK_KEY_TIMES
    p = clamp((u - t0) / (t1 - t0), 0.0, 1.0)
    return (0.0, _q_axis((0, 1, 0), ATTACK_SPIN["spin"] * (1.0 - (1.0 - p) ** 2)))


def clips(hips_rest_y):
    """(nome, quadros, loop, poses-chave, prévia do Root)."""
    out = [
        ("idle", 252, True, idle_keys(), None),
        ("walk", 34, True, walk_keys(), None),
        ("sprint", 26, True, sprint_keys(), None),
        ("air_sprint", 26, True, air_sprint_keys(), None),
        ("air", 30, False, air_keys(), None),
        ("jump_flip", 37, False, jump_flip_keys(), root_jump_flip),
        ("wall_stick", 12, True, wall_stick_keys(), None),
        ("wall_flip", 30, False, wall_flip_keys(), root_wall_flip),
        ("roll", 42, False, roll_keys(), make_root_roll(hips_rest_y)),
        ("cartwheel", 39, False, cartwheel_keys(), root_cartwheel),
        ("dash", 20, False, dash_keys(), None),
        ("land", 15, False, land_keys(), None),
        ("hurt", 20, False, hurt_keys(), None),
        ("sword_rest", 12, False, sword_rest_keys(), None),
    ]
    for name in ATTACKS:
        out.append(("atk_" + name, ATTACK_FRAMES, False, attack_keys(name), root_spin if name == "spin" else None))
    return out


# --- Conversão: pose de referência → ossos do Blender ---------------------------------------------

def godot_euler_to_quat(e_deg):
    """Quaternion.from_euler do Godot (ordem YXZ), recebendo graus."""
    x, y, z = (math.radians(v) for v in e_deg)
    return _q_axis((0, 1, 0), y) @ _q_axis((1, 0, 0), x) @ _q_axis((0, 0, 1), z)


ARM_REF = {"l": _q_axis((0, 0, 1), PI * 0.5), "r": _q_axis((0, 0, 1), -PI * 0.5)}


def joint_to_bone_local(joint, q):
    """Braços: a referência tem o braço abaixado; o osso do modelo está em T-pose."""
    if joint.startswith(ARM_JOINTS):
        ref = ARM_REF[joint[-1]]
        return q @ ref if joint.startswith("shoulder") else ref.inverted() @ q @ ref
    return q


def to_blender(q):
    """Rotação no espaço Y-up do glTF/Godot → Z-up do Blender ((x, y, z) → (x, -z, y))."""
    return Quaternion((q.w, q.x, -q.z, q.y))


def finger_rotations(p):
    out = {}
    for side, curl in (("L", p.get("grip_l", 0.35)), ("R", -p.get("grip_r", 1.25))):
        for finger in FINGERS:
            for i, k in enumerate(PHALANX_CURL):
                out["J_Bip_%s_%s%d" % (side, finger, i + 1)] = _q_axis((0, 0, 1), curl * k)
        out["J_Bip_%s_Thumb2" % side] = _q_axis((0, 1, 0), curl * 0.5)
    return out


class Rig:
    def __init__(self, arm):
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
        self.hips = self.bones[BONE_MAP["hips"]]

    def basis(self, p, root):
        """Pose → {osso: (location, rotation)} no espaço do pose bone do Blender."""
        fingers = finger_rotations(p)
        world = {}
        out = {}
        for bone in self.order:
            head = bone.head_local
            q = Quaternion()
            offset = Vector()
            joint = self.joint_of.get(bone.name)
            if joint is not None:
                q = to_blender(joint_to_bone_local(joint, godot_euler_to_quat(p.get(joint, (0, 0, 0)))))
            elif bone.name in fingers:
                q = to_blender(fingers[bone.name])
            if bone == self.hips:
                hx, hy, hz = p.get("hips_pos", (0, 0, 0))
                offset = Vector((hx, -hz, hy)) / RIG_SCALE
            if bone.parent is None:
                g = Matrix.Translation(head + offset) @ q.to_matrix().to_4x4()
                if root is not None and bone.name == "Root":
                    lift, rot = root
                    pivot = self.hips.head_local + Vector((0, 0, lift / RIG_SCALE))
                    g = Matrix.Translation(pivot) @ to_blender(rot).to_matrix().to_4x4() \
                        @ Matrix.Translation(-self.hips.head_local) @ g
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
            out[bone.name] = (loc, rot)
        return out


ANIMATED_PREFIXES = ("J_Bip_", "Root")


def build(arm):
    rig = Rig(arm)
    hips_rest_y = rig.hips.head_local.z
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    if arm.animation_data is None:
        arm.animation_data_create()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    first = None
    for name, frames, loop, keys, root_fn in clips(hips_rest_y):
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        action.use_frame_range = True
        action.use_cyclic = loop
        action.frame_start = 0
        action.frame_end = frames
        arm.animation_data.action = action
        # Prévia do Root: giros precisam de chaves densas (o quaternion pega o caminho curto).
        times = sorted({frame for frame, _ in keys} | (set(range(0, frames + 1, 2)) | {frames} if root_fn else set()))
        key_frames = {frame for frame, _ in keys}
        previous = {}
        for frame in times:
            u = frame / frames
            p = _pose_at(keys, frame)
            bases = rig.basis(p, root_fn(u) if root_fn else None)
            for bone_name, (loc, rot) in bases.items():
                if not bone_name.startswith(ANIMATED_PREFIXES):
                    continue
                if frame not in key_frames and bone_name != "Root":
                    continue  # corpo só nas poses-chave; o Root ganha chaves densas
                pb = arm.pose.bones[bone_name]
                if bone_name in previous:
                    rot.make_compatible(previous[bone_name])
                previous[bone_name] = rot
                pb.rotation_quaternion = rot
                pb.keyframe_insert("rotation_quaternion", frame=frame, group=bone_name)
                if bone_name in ("Root", BONE_MAP["hips"]):
                    pb.location = loc
                    pb.keyframe_insert("location", frame=frame, group=bone_name)
        _finish_curves(action, loop)
        if first is None:
            first = action
    arm.animation_data.action = first
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = int(first.frame_end)


def _pose_at(keys, frame):
    """Pose numa chave (exata); entre chaves só importa o Root (o corpo não é gravado)."""
    for i, (f, p) in enumerate(keys):
        if f == frame:
            return p
        if f > frame:
            f0, p0 = keys[i - 1]
            return lerp_pose(p0, p, (frame - f0) / (f - f0))
    return keys[-1][1]


def _finish_curves(action, loop):
    """Bezier com alças automáticas; ciclos dão a volta sem emenda (modificador Cycles)."""
    for fcurve in _fcurves(action):
        for key in fcurve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
        if loop:
            fcurve.modifiers.new("CYCLES")
        fcurve.update()


def _fcurves(action):
    if hasattr(action, "fcurves"):
        return list(action.fcurves)
    # Blender 4.4+: Actions em camadas (slots).
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out
