#!/usr/bin/env python3
"""Gera os efeitos sonoros do REBELLIUM por síntese (sem assets externos).

Uso: python3 tools/gen_sfx.py   (requer numpy)  ->  assets/sfx/*.wav (16 bits, mono, 44,1 kHz)
Cada função abaixo é um "instrumento": mexa nos números e rode de novo para ajustar o som.
"""
import os
import wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.linspace(0.0, dur, int(SR * dur), endpoint=False)


def env(n, attack, release, curve=2.0):
    """Envelope ataque linear + decaimento exponencial (frações da duração)."""
    x = np.linspace(0.0, 1.0, n)
    a = np.clip(x / max(attack, 1e-4), 0.0, 1.0)
    r = np.clip((1.0 - x) / max(release, 1e-4), 0.0, 1.0) ** curve
    return a * r


def noise(n):
    return rng.uniform(-1.0, 1.0, n)


def lowpass(x, cutoff):
    """Passa-baixa de 1 polo com corte variável (array ou escalar, em Hz)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def bandpass(x, low, high):
    return lowpass(x, high) - lowpass(x, low)


def sweep_sine(f0, f1, dur, shape=1.0):
    t = t_axis(dur)
    f = f0 + (f1 - f0) * (t / dur) ** shape
    return np.sin(2.0 * np.pi * np.cumsum(f) / SR)


def saw(freq, dur):
    t = t_axis(dur)
    phase = np.cumsum(np.broadcast_to(freq, t.shape)) / SR
    return 2.0 * (phase - np.floor(phase + 0.5))


def whoosh(dur, f_lo, f_hi, peak=0.45):
    n = int(SR * dur)
    x = np.linspace(0, 1, n)
    cutoff = f_lo + (f_hi - f_lo) * np.sin(np.pi * np.clip(x / peak * 0.5, 0, 1)) ** 2
    cutoff = np.where(x > peak, f_hi - (f_hi - f_lo) * (x - peak) / (1 - peak), cutoff)
    return bandpass(noise(n), cutoff * 0.35, cutoff) * env(n, peak, 1 - peak, 1.5)


def thump(dur, f0, f1):
    n = int(SR * dur)
    return sweep_sine(f0, f1, dur, 0.5) * env(n, 0.01, 0.99, 3.0)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=float)
    peak = np.max(np.abs(x)) or 1.0
    x = np.tanh(x / peak * 1.2) / np.tanh(1.2) * gain
    fade = min(len(x), int(0.005 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("ok", name, f"{len(x) / SR:.2f}s")


# --- Golpes --------------------------------------------------------------------------

def plasma_swing(dur, f0, f1, air_hi):
    n = int(SR * dur)
    hum = saw(np.linspace(f0, f1, n), dur) * 0.35 + sweep_sine(f0 * 2, f1 * 2, dur) * 0.25
    hum = lowpass(hum, 2500) * env(n, 0.25, 0.75, 1.5)
    return mix(hum, whoosh(dur, 500, air_hi) * 0.9)


def blade_swing():
    return plasma_swing(0.32, 160, 90, 5200)


def blade_swing_heavy():
    return mix(plasma_swing(0.55, 110, 60, 3800), whoosh(0.55, 300, 2400, 0.6) * 0.6)


def fang_swing():
    n = int(SR * 0.18)
    ring = sweep_sine(2400, 1600, 0.18) * env(n, 0.05, 0.95, 3.0) * 0.25
    return mix(whoosh(0.18, 1200, 8000, 0.35), ring)


def hit_blade():
    n = int(SR * 0.35)
    zap = saw(np.linspace(900, 120, n), 0.35) * env(n, 0.002, 0.998, 4.0) * 0.6
    crackle = bandpass(noise(n), 1500, 7000) * env(n, 0.001, 0.4, 2.0) * (rng.random(n) > 0.6)
    return mix(thump(0.25, 140, 45) * 1.2, lowpass(zap, 3500), crackle * 0.8)


def hit_fang():
    n = int(SR * 0.2)
    slice_ = bandpass(noise(n), 2500, 9000) * env(n, 0.001, 0.5, 3.0)
    click = sweep_sine(3200, 1800, 0.2) * env(n, 0.001, 0.3, 4.0) * 0.5
    return mix(slice_, click, thump(0.15, 220, 90) * 0.8)


def hit_heavy():
    n = int(SR * 0.6)
    crunch = lowpass(noise(n), np.linspace(6000, 300, n)) * env(n, 0.002, 0.6, 2.0)
    return mix(thump(0.6, 90, 30) * 1.6, crunch * 0.9, hit_blade() * 0.5)


# --- Movimento ------------------------------------------------------------------------

def footstep(seed):
    local = np.random.default_rng(seed)
    n = int(SR * 0.09)
    tap = lowpass(local.uniform(-1, 1, n), 1800) * env(n, 0.005, 0.995, 6.0)
    return mix(thump(0.08, 120 + seed * 7, 60) * 0.7, tap * 0.8)


def jump():
    return mix(whoosh(0.25, 300, 2200, 0.3) * 0.8, thump(0.1, 160, 90) * 0.5)


def land():
    n = int(SR * 0.25)
    dust = lowpass(noise(n), 900) * env(n, 0.005, 0.6, 2.0)
    return mix(thump(0.25, 110, 40) * 1.3, dust * 0.6)


def wall_jump():
    return mix(thump(0.18, 180, 70) * 1.1, whoosh(0.3, 600, 4500, 0.25) * 0.8)


def dash():
    n = int(SR * 0.28)
    burst = bandpass(noise(n), 400, np.linspace(6000, 1500, n)) * env(n, 0.03, 0.97, 2.0)
    tone = sweep_sine(500, 1400, 0.28) * env(n, 0.05, 0.9, 2.0) * 0.15
    return mix(burst, tone)


# --- Interface / técnicas -----------------------------------------------------------

def weapon_swap():
    n = int(SR * 0.35)
    click = bandpass(noise(int(SR * 0.03)), 2000, 8000) * env(int(SR * 0.03), 0.01, 0.9, 3.0)
    charge = sweep_sine(300, 1500, 0.35, 2.0) * env(n, 0.1, 0.5, 1.5) * 0.45
    return mix(click, np.concatenate([np.zeros(int(SR * 0.04)), charge]))


def technique():
    parts = []
    for i, f in enumerate([880, 1175, 1568]):
        n = int(SR * 0.35)
        tone = (np.sin(2 * np.pi * f * t_axis(0.35)) + 0.3 * np.sin(4 * np.pi * f * t_axis(0.35)))
        parts.append(np.concatenate([np.zeros(int(SR * 0.05 * i)), tone * env(n, 0.01, 0.99, 3.0) * 0.4]))
    return mix(*parts)


def perfect_dodge():
    n = int(SR * 0.6)
    shimmer = sum(np.sin(2 * np.pi * f * t_axis(0.6)) for f in (1320, 1980, 2640)) * env(n, 0.02, 0.98, 2.0)
    whum = sweep_sine(220, 80, 0.6) * env(n, 0.05, 0.95, 1.5)
    return mix(shimmer * 0.3, whum * 0.7)


def hurt():
    n = int(SR * 0.35)
    buzz = saw(np.linspace(180, 90, n), 0.35) * (np.sin(2 * np.pi * 30 * t_axis(0.35)) > 0) * env(n, 0.005, 0.99, 2.0)
    return mix(thump(0.3, 130, 50) * 1.2, lowpass(buzz, 2200) * 0.5)


def sp_empty():
    n = int(SR * 0.4)
    return lowpass(saw(np.linspace(200, 110, n), 0.4), 1200) * env(n, 0.01, 0.99, 1.5) * 0.8


def dummy_warning():
    parts = []
    for i in range(3):
        n = int(SR * 0.09)
        beep = np.sign(np.sin(2 * np.pi * (700 + i * 180) * t_axis(0.09))) * env(n, 0.01, 0.9, 1.0) * 0.35
        parts.append(np.concatenate([np.zeros(int(SR * 0.13 * i)), lowpass(beep, 4000)]))
    return mix(*parts)


def dummy_swing():
    return mix(whoosh(0.4, 200, 1800, 0.5), thump(0.2, 90, 50) * 0.5)


# --- Voz -----------------------------------------------------------------------------

def voice_grunt(f0_start, f0_end, dur, formants, breath=0.15):
    """Gritinho curto ("hah!"): trem de pulsos glóticos com tom caindo, filtrado por formantes."""
    n = int(SR * dur)
    f0 = np.linspace(f0_start, f0_end, n) * (1.0 + 0.02 * np.sin(2 * np.pi * 6 * t_axis(dur)))
    phase = np.cumsum(f0) / SR
    pulse = (phase - np.floor(phase)) ** 3  # pulso glótico assimétrico
    pulse = np.diff(pulse, prepend=0.0) * SR / np.maximum(f0, 1.0)
    source = pulse + noise(n) * breath
    out = np.zeros(n)
    for freq, bw, gain in formants:
        out += bandpass(source, freq - bw * 0.5, freq + bw * 0.5) * gain
    shape = env(n, 0.08, 0.92, 1.6)
    return out * shape


def voice_sprint_1():
    return voice_grunt(330, 250, 0.22, [(800, 160, 1.0), (1250, 200, 0.7), (2600, 300, 0.25)])


def voice_sprint_2():
    return voice_grunt(300, 230, 0.2, [(720, 150, 1.0), (1150, 200, 0.6), (2500, 300, 0.25)], 0.2)


SOUNDS = {
    "voice_sprint_1": voice_sprint_1, "voice_sprint_2": voice_sprint_2,
    "blade_swing": blade_swing, "blade_swing_heavy": blade_swing_heavy, "fang_swing": fang_swing,
    "hit_blade": hit_blade, "hit_fang": hit_fang, "hit_heavy": hit_heavy,
    "footstep_1": lambda: footstep(1), "footstep_2": lambda: footstep(2), "footstep_3": lambda: footstep(3),
    "jump": jump, "land": land, "wall_jump": wall_jump, "dash": dash,
    "weapon_swap": weapon_swap, "technique": technique, "perfect_dodge": perfect_dodge,
    "hurt": hurt, "sp_empty": sp_empty, "dummy_warning": dummy_warning, "dummy_swing": dummy_swing,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        save(name, fn())
