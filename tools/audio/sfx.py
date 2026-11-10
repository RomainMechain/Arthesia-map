"""Bruitages et ambiances d'Arthesia, entièrement synthétisés (libres de droits, reproductibles).

Style « doux et organique », accordé au lore de l'étage 1 (aube éternelle, mélancolique) :
cordes pincées (Karplus-Strong), cloches et carillons (partiels inharmoniques), bois, souffles d'air
(bruit filtré), eau. Une petite réverbération donne de l'espace. Rien de criard : attaques
adoucies, aigus filtrés.

Sorties : assets/audio/sfx/<nom>.wav, assets/audio/ambience/<zone>.wav (boucles sans couture).
Usage : python tools/audio/sfx.py
"""
import math
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SR = 32000
RNG = np.random.default_rng(7)

# gamme : ré mineur dorien (mélancolique sans être triste), quelques hauteurs nommées
NOTE = {"D3": 146.83, "F3": 174.61, "A3": 220.0, "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23,
        "G4": 392.0, "A4": 440.0, "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46,
        "A5": 880.0, "D6": 1174.66}


# --------------------------------------------------------------------------- briques
def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, a=0.005, d=0.3, curve=4.0):
    """Attaque linéaire courte puis décroissance exponentielle sur toute la longueur."""
    x = np.arange(n) / SR
    att = np.clip(x / max(a, 1e-4), 0, 1)
    dec = np.exp(-curve * np.maximum(x - a, 0) / max(d, 1e-4))
    return att * dec


def lowpass(x, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def noise(sec):
    return RNG.uniform(-1, 1, int(SR * sec))


def pluck(freq, sec, bright=0.5, decay=0.996):
    """Corde pincée (Karplus-Strong) : chaleureuse, naturelle."""
    n = int(SR * sec)
    p = max(2, int(SR / freq))
    buf = lowpass(RNG.uniform(-1, 1, p), 2000 + 6000 * bright)
    out = np.empty(n)
    b = list(buf)
    for i in range(n):
        v = b[i % p]
        nxt = b[(i + 1) % p]
        b[i % p] = decay * 0.5 * (v + nxt)
        out[i] = v
    return out * env(n, 0.002, sec, 2.5)


def bell(freq, sec, bright=0.6):
    """Cloche / carillon : partiels inharmoniques qui s'éteignent à des vitesses différentes."""
    x = t(sec)
    out = np.zeros_like(x)
    for ratio, amp, dk in ((1.0, 1.0, 1.0), (2.76, 0.5 * bright, 1.8), (5.4, 0.25 * bright, 3.0),
                           (8.93, 0.12 * bright, 4.5), (0.5, 0.25, 0.7)):
        out += amp * np.sin(2 * math.pi * freq * ratio * x) * np.exp(-dk * 3.0 * x / sec)
    return out * np.clip(x / 0.003, 0, 1)


def wood(freq, sec=0.12):
    """Bois frappé : court, mat."""
    x = t(sec)
    tone = np.sin(2 * math.pi * freq * x) * np.exp(-x * 45)
    click = bandpass(noise(sec), 800, 4000) * np.exp(-x * 120) * 0.6
    return tone + click


def whoosh(sec, lo=300, hi=2500, rise=True):
    """Souffle d'air (coup d'arme, page) : bruit filtré dont la brillance monte puis retombe."""
    n = int(SR * sec)
    x = np.linspace(0, 1, n)
    shape = np.sin(np.pi * x) ** 2
    nb = noise(sec)
    a = bandpass(nb, lo, hi)
    b = bandpass(nb, lo * 2, hi * 2)
    mix = (x if rise else 1 - x)
    return (a * (1 - mix) + b * mix) * shape


def reverb(x, wet=0.25, size=1.0):
    """Petite salle : quelques peignes en parallèle, adoucis."""
    out = np.copy(x)
    tail = np.zeros(len(x) + int(SR * 0.6 * size))
    tail[:len(x)] = x
    acc = np.zeros_like(tail)
    for d, g in ((0.0297, 0.62), (0.0371, 0.58), (0.0411, 0.55), (0.0437, 0.52)):
        dn = int(SR * d * size)
        y = np.copy(tail)
        for i in range(dn, len(y)):
            y[i] += g * y[i - dn]
        acc += y
    acc = lowpass(acc / 4.0, 4500)
    res = np.zeros(len(tail))
    res[:len(out)] += out * (1 - wet)
    res += acc * wet
    return res


def mix(*parts):
    n = max(len(p[1]) + int(p[0] * SR) for p in parts)
    out = np.zeros(n)
    for start, sig, *g in parts:
        s = int(start * SR)
        out[s:s + len(sig)] += sig * (g[0] if g else 1.0)
    return out


def norm(x, peak=0.7):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def fade(x, a=0.004, b=0.02):
    n = len(x)
    e = np.ones(n)
    na, nb = int(SR * a), int(SR * b)
    e[:na] = np.linspace(0, 1, na)
    e[n - nb:] = np.linspace(1, 0, nb)
    return x * e


def save(x, rel, peak=0.7):
    x = fade(norm(x, peak))
    path = ROOT / "assets/audio" / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# --------------------------------------------------------------------------- bruitages
def sfx():
    S = {}
    # combat
    S["swing"] = whoosh(0.22, 400, 2200)
    S["swing_heavy"] = whoosh(0.32, 200, 1400)
    thud = lowpass(noise(0.18), 900) * env(int(SR * 0.18), 0.002, 0.08, 3)
    body = np.sin(2 * math.pi * 95 * t(0.18)) * env(int(SR * 0.18), 0.002, 0.07, 3)
    S["hit"] = reverb(mix((0, thud, 0.8), (0, body, 0.9), (0, wood(420, 0.08), 0.3)), 0.12)
    S["crit"] = reverb(mix((0, S["hit"]), (0.01, bell(NOTE["A5"], 0.5, 0.8), 0.45),
                           (0.03, bell(NOTE["E5"], 0.5, 0.6), 0.3)), 0.25)
    S["dodge"] = whoosh(0.2, 900, 4000, rise=True) * 0.8
    S["hurt"] = reverb(mix((0, lowpass(noise(0.22), 500) * env(int(SR * 0.22), 0.002, 0.1, 3), 0.9),
                           (0, np.sin(2 * math.pi * 70 * t(0.22)) * env(int(SR * 0.22), 0.002, 0.12, 3))), 0.1)
    S["mob_death"] = reverb(mix((0, pluck(NOTE["A4"], 0.5, 0.4), 0.6), (0.07, pluck(NOTE["F4"], 0.5, 0.4), 0.5),
                                (0.14, pluck(NOTE["D4"], 0.7, 0.4), 0.5),
                                (0.1, bell(NOTE["D6"], 0.6, 0.4), 0.12)), 0.3)
    S["telegraph"] = reverb(mix((0, wood(180, 0.2), 0.8), (0.12, wood(220, 0.2), 0.6)), 0.15)
    S["alert"] = reverb(pluck(NOTE["E5"], 0.25, 0.8) * 0.8, 0.15)
    S["dive"] = mix((0, bandpass(noise(0.35), 300, 1800) * env(int(SR * 0.35), 0.01, 0.2, 3), 0.8),
                    (0.05, np.sin(2 * math.pi * np.linspace(500, 180, int(SR * 0.2)) * t(0.2)) * env(int(SR * 0.2), 0.002, 0.1, 3), 0.4))
    S["splash"] = mix((0, bandpass(noise(0.4), 600, 4000) * env(int(SR * 0.4), 0.003, 0.18, 3), 0.9),
                      *[(0.04 + i * 0.05, np.sin(2 * math.pi * (700 + 200 * i) * t(0.06)) * env(int(SR * 0.06), 0.001, 0.03, 3), 0.25)
                        for i in range(4)])
    # compétences (une signature par compétence, docs : game/combat/skill_fx.gd)
    S["sk_frappe"] = reverb(mix((0, whoosh(0.3, 150, 1100), 0.8),
                                (0.07, lowpass(noise(0.2), 600) * env(int(SR * 0.2), 0.002, 0.09, 3), 0.9),
                                (0.07, np.sin(2 * math.pi * 70 * t(0.22)) * env(int(SR * 0.22), 0.002, 0.12, 3), 0.8)), 0.15)
    S["sk_trait"] = reverb(mix((0, np.sin(2 * math.pi * np.linspace(700, 1900, int(SR * 0.12)) * t(0.12)) * env(int(SR * 0.12), 0.03, 0.08, 2), 0.35),
                               (0.08, whoosh(0.22, 1500, 6000), 0.6),
                               (0.09, bell(NOTE["A5"], 0.6, 0.9), 0.4), (0.11, bell(NOTE["E5"] * 2, 0.5, 0.8), 0.25)), 0.3)
    S["sk_croc"] = reverb(mix((0, whoosh(0.12, 900, 4000), 0.6), (0.06, wood(1100, 0.04), 0.7),
                              (0.075, wood(800, 0.05), 0.8),
                              (0.075, lowpass(noise(0.1), 1200) * env(int(SR * 0.1), 0.001, 0.04, 3), 0.6)), 0.1)
    S["sk_soins"] = reverb(mix((0, bandpass(noise(0.7), 300, 1500) * env(int(SR * 0.7), 0.25, 0.4, 2), 0.35),
                               (0.15, bell(NOTE["D5"], 1.2, 0.3), 0.3), (0.35, bell(NOTE["A5"], 1.2, 0.3), 0.25),
                               (0.55, bell(NOTE["F5"], 1.4, 0.3), 0.22)), 0.45, 1.3)
    # compétences : communes
    S["sk_lourd"] = reverb(mix((0, whoosh(0.25, 120, 600, rise=True), 0.5), (0.2, whoosh(0.3, 150, 1000), 0.8),
                               (0.26, lowpass(noise(0.25), 500) * env(int(SR * 0.25), 0.002, 0.12, 3), 1.0),
                               (0.26, np.sin(2 * math.pi * 55 * t(0.3)) * env(int(SR * 0.3), 0.002, 0.16, 3), 0.9)), 0.2)
    S["sk_eclat"] = reverb(mix((0, np.sin(2 * math.pi * np.linspace(400, 1400, int(SR * 0.16)) * t(0.16)) * env(int(SR * 0.16), 0.08, 0.06, 2), 0.35),
                               (0.15, bandpass(noise(0.3), 800, 5000) * env(int(SR * 0.3), 0.002, 0.12, 3), 0.8),
                               (0.15, bell(NOTE["D5"], 0.6, 0.9), 0.35)), 0.3)
    S["sk_lame"] = reverb(mix((0, whoosh(0.24, 700, 5000), 0.7), (0.02, bell(NOTE["A5"], 0.5, 0.7), 0.25),
                              (0.06, bell(NOTE["D5"] * 2, 0.4, 0.7), 0.15)), 0.25)
    S["sk_carapace"] = reverb(mix(*[(i * 0.045, wood(260 + 40 * i, 0.07), 0.6) for i in range(5)],
                                  (0.2, lowpass(noise(0.2), 700) * env(int(SR * 0.2), 0.002, 0.08, 3), 0.5)), 0.15)
    # compétences : peu communes
    S["sk_lynx"] = reverb(mix((0, bandpass(noise(0.18), 3000, 9000) * env(int(SR * 0.18), 0.06, 0.05, 2), 0.3),
                              (0.16, whoosh(0.14, 1200, 6000), 0.7), (0.24, wood(1300, 0.03), 0.6),
                              (0.27, wood(1000, 0.03), 0.6), (0.27, bandpass(noise(0.12), 2000, 7000) * env(int(SR * 0.12), 0.001, 0.05, 3), 0.5)), 0.2)
    S["sk_chant"] = reverb(mix((0, np.sin(2 * math.pi * 82 * t(1.0)) * env(int(SR * 1.0), 0.05, 0.6, 2), 0.9),
                               (0, np.sin(2 * math.pi * 123 * t(1.0)) * env(int(SR * 1.0), 0.1, 0.5, 2), 0.4),
                               (0.1, bell(NOTE["D4"], 1.2, 0.2), 0.3), (0.3, bandpass(noise(0.6), 200, 900) * env(int(SR * 0.6), 0.1, 0.3, 2), 0.3)), 0.5, 1.4)
    S["sk_estoc"] = reverb(mix((0, bell(NOTE["E5"] * 2, 0.3, 1.0), 0.3), (0.08, whoosh(0.1, 2000, 8000), 0.6),
                               (0.12, wood(1500, 0.03), 0.7), (0.13, bell(NOTE["A5"], 0.4, 1.0), 0.3)), 0.2)
    S["sk_rupture"] = reverb(mix(*[(i * 0.08, bell(f, 0.3, 1.0), 0.22) for i, f in enumerate((NOTE["D5"], NOTE["A5"], NOTE["F5"]))],
                                 (0.3, bandpass(noise(0.4), 300, 3000) * env(int(SR * 0.4), 0.002, 0.15, 3), 0.9),
                                 *[(0.32 + i * 0.05, wood(500 - 60 * i, 0.05), 0.5) for i in range(4)]), 0.25)
    S["sk_tranchante"] = reverb(mix((0, whoosh(0.22, 400, 3000), 0.7),
                                    (0.05, bandpass(noise(0.2), 2500, 9000) * env(int(SR * 0.2), 0.001, 0.03, 1.5), 0.6),
                                    (0.07, bell(1180, 0.4, 0.4), 0.4), (0.1, wood(900, 0.04), 0.4)), 0.2)
    S["sk_secousse"] = reverb(mix((0, whoosh(0.35, 80, 400, rise=True), 0.4),
                                  (0.32, lowpass(noise(0.6), 300) * env(int(SR * 0.6), 0.002, 0.3, 2), 1.0),
                                  (0.32, np.sin(2 * math.pi * np.linspace(60, 35, int(SR * 0.6)) * t(0.6)) * env(int(SR * 0.6), 0.002, 0.35, 2), 1.0),
                                  *[(0.4 + i * 0.06, wood(300 + 50 * i, 0.06), 0.3) for i in range(4)]), 0.3, 1.3)
    S["sk_seve"] = reverb(mix((0, bandpass(noise(0.9), 1500, 5000) * env(int(SR * 0.9), 0.3, 0.4, 2), 0.25),
                              *[(0.1 + i * 0.12, pluck(f, 0.6, 0.4), 0.35) for i, f in enumerate((NOTE["D4"], NOTE["F4"], NOTE["A4"], NOTE["D5"]))]), 0.4, 1.2)
    S["sk_toile"] = reverb(mix((0, whoosh(0.3, 1500, 7000), 0.5),
                               *[(0.12 + i * 0.05, bell(2400 + 300 * i, 0.15, 1.0), 0.15) for i in range(6)],
                               (0.4, pluck(NOTE["A4"], 0.5, 0.8), 0.4)), 0.3)
    # compétences : rares
    S["sk_consignes"] = reverb(mix(*[(i * 0.15, wood(1600, 0.03), 0.6) for i in range(3)],
                                   *[(i * 0.15, bell(NOTE["A5"] if i < 2 else NOTE["D5"] * 2, 0.3, 1.0), 0.2) for i in range(3)],
                                   (0.45, whoosh(0.14, 1000, 7000), 0.8), (0.5, bell(NOTE["D5"], 0.9, 0.8), 0.45),
                                   (0.5, lowpass(noise(0.2), 900) * env(int(SR * 0.2), 0.002, 0.08, 3), 0.7)), 0.35, 1.2)
    S["sk_figee"] = reverb(mix((0, np.sin(2 * math.pi * np.linspace(1800, 300, int(SR * 0.4)) * t(0.4)) * env(int(SR * 0.4), 0.002, 0.3, 2), 0.3),
                               *[(0.25 + i * 0.07, bell(f, 1.4, 0.9), 0.3) for i, f in enumerate((NOTE["D5"], NOTE["A5"], NOTE["F5"] * 2, NOTE["D5"] * 2))],
                               (0.25, bandpass(noise(0.15), 3000, 9000) * env(int(SR * 0.15), 0.001, 0.05, 3), 0.5)), 0.5, 1.5)
    # compétence légendaire
    S["sk_verdict"] = reverb(mix((0, np.sin(2 * math.pi * 73 * t(1.6)) * env(int(SR * 1.6), 0.4, 0.8, 2), 0.5),
                                 *[(0.05 + i * 0.1, bell(NOTE[n], 1.6, 0.6), 0.18) for i, n in enumerate(("D4", "A4", "D5", "F5"))],
                                 (0.6, whoosh(0.3, 200, 5000, rise=False), 0.6),
                                 (0.72, lowpass(noise(0.8), 400) * env(int(SR * 0.8), 0.002, 0.4, 2), 1.0),
                                 (0.72, np.sin(2 * math.pi * np.linspace(70, 30, int(SR * 0.8)) * t(0.8)) * env(int(SR * 0.8), 0.002, 0.4, 2), 0.9),
                                 *[(0.74 + i * 0.03, bell(f, 2.0, 0.8), 0.3) for i, f in enumerate((NOTE["D5"], NOTE["F5"], NOTE["A5"], NOTE["D5"] * 2))]), 0.55, 1.6)
    # passives : discrets
    S["pv_ambre"] = reverb(mix((0, lowpass(noise(0.15), 700) * env(int(SR * 0.15), 0.01, 0.08, 3), 0.6),
                               (0.02, np.sin(2 * math.pi * np.linspace(300, 180, int(SR * 0.15)) * t(0.15)) * env(int(SR * 0.15), 0.005, 0.08, 3), 0.4)), 0.2)
    S["pv_instinct"] = reverb(mix((0, whoosh(0.16, 2000, 8000), 0.6), (0.04, bell(NOTE["E5"] * 2, 0.4, 1.0), 0.18)), 0.3)
    S["pv_halvard"] = reverb(mix(*[(i * 0.12, bell(f, 1.8, 0.4), 0.3) for i, f in enumerate((NOTE["D4"], NOTE["A4"], NOTE["D5"]))],
                                 (0, bandpass(noise(1.0), 300, 1200) * env(int(SR * 1.0), 0.3, 0.5, 2), 0.25)), 0.5, 1.4)
    # butin, or, potions
    S["loot"] = reverb(mix((0, pluck(NOTE["A4"], 0.35, 0.7), 0.7), (0.07, pluck(NOTE["D5"], 0.45, 0.7), 0.7)), 0.25)
    S["gold"] = reverb(mix(*[(i * 0.045, bell(f, 0.25, 0.9), 0.4) for i, f in enumerate((2100, 2600, 2350, 2900))]), 0.2)
    S["potion"] = reverb(mix(*[(i * 0.05, np.sin(2 * math.pi * (300 + 160 * i) * t(0.07)) * env(int(SR * 0.07), 0.002, 0.04, 3), 0.35)
                               for i in range(6)], (0.25, bell(NOTE["A5"], 0.6, 0.5), 0.35)), 0.3)
    # récolte, pêche, artisanat
    S["gather"] = mix((0, bandpass(noise(0.25), 1500, 6000) * env(int(SR * 0.25), 0.01, 0.12, 3), 0.5),
                      (0.02, wood(650, 0.06), 0.25))
    S["gather_done"] = reverb(mix((0, pluck(NOTE["D5"], 0.3, 0.6), 0.7), (0.06, pluck(NOTE["A5"], 0.4, 0.6), 0.5)), 0.2)
    S["fish"] = reverb(mix((0, S["splash"], 0.6), (0.18, pluck(NOTE["G4"], 0.4, 0.5), 0.5)), 0.2)
    S["anvil"] = reverb(mix((0, bell(1320, 0.4, 0.5), 0.6), (0, wood(300, 0.08), 0.5)), 0.2)
    S["craft_done"] = reverb(mix((0, bell(NOTE["D5"], 0.9, 0.6), 0.5), (0.09, bell(NOTE["F5"], 0.9, 0.6), 0.4),
                                 (0.18, bell(NOTE["A5"], 1.2, 0.6), 0.45)), 0.35)
    # progression
    S["level_up"] = reverb(mix(*[(i * 0.09, bell(NOTE[n], 1.4, 0.7), 0.45) for i, n in enumerate(("D4", "F4", "A4", "D5", "F5", "A5"))],
                               (0.5, pluck(NOTE["D3"], 1.2, 0.3), 0.4)), 0.4, 1.3)
    S["unlock"] = reverb(mix(*[(i * 0.06, bell(NOTE[n], 1.0, 0.8), 0.4) for i, n in enumerate(("A4", "E5", "A5", "D6"))]), 0.4, 1.2)
    S["quest_accept"] = reverb(mix((0, pluck(NOTE["D4"], 0.6, 0.5), 0.6), (0.0, pluck(NOTE["A4"], 0.6, 0.5), 0.5)), 0.3)
    S["quest_done"] = reverb(mix((0, pluck(NOTE["D4"], 0.8, 0.5), 0.5), (0.1, pluck(NOTE["F4"], 0.8, 0.5), 0.5),
                                 (0.2, pluck(NOTE["A4"], 1.0, 0.5), 0.5), (0.3, bell(NOTE["D5"], 1.0, 0.5), 0.35)), 0.35)
    S["discovery"] = reverb(mix(*[(i * 0.14, bell(f, 1.6, 0.5), 0.35) for i, f in enumerate((NOTE["E5"], NOTE["B4"], NOTE["G4"], NOTE["E5"] * 1.5))]), 0.5, 1.4)
    # interface
    S["ui_click"] = wood(880, 0.05) * 0.7
    S["ui_page"] = whoosh(0.18, 1200, 6000) * 0.6
    S["ui_open"] = reverb(mix((0, whoosh(0.2, 800, 5000), 0.5), (0.04, pluck(NOTE["A4"], 0.25, 0.6), 0.35)), 0.15)
    S["ui_close"] = mix((0, whoosh(0.16, 800, 4000, rise=False), 0.5), (0.02, pluck(NOTE["D4"], 0.2, 0.6), 0.3))
    S["ui_deny"] = mix((0, wood(200, 0.1), 0.6), (0.07, wood(170, 0.1), 0.5))
    # pas, voyage
    S["step"] = bandpass(noise(0.07), 300, 2500) * env(int(SR * 0.07), 0.004, 0.03, 3)
    S["step_water"] = bandpass(noise(0.14), 500, 3500) * env(int(SR * 0.14), 0.005, 0.06, 3)
    S["oars"] = reverb(mix((0, S["splash"], 0.5), (0.5, S["splash"], 0.4), (0, wood(260, 0.1), 0.4)), 0.25)
    for name, x in S.items():
        peak = {"step": 0.35, "step_water": 0.4, "ui_click": 0.45, "ui_page": 0.45, "gather": 0.5}.get(name, 0.7)
        save(x, f"sfx/{name}.wav", peak)
    return S


# --------------------------------------------------------------------------- ambiances (boucles)
def loop_seamless(x, xf=1.5):
    """Fond enchaîné : la fin se fond dans le début (boucle sans couture)."""
    n = int(SR * xf)
    head, body = x[:n], x[n:]
    ramp = np.linspace(0, 1, n)
    body[-n:] = body[-n:] * (1 - ramp) + head * ramp
    return body


def wind(sec, lo=150, hi=900, depth=0.6):
    n = int(SR * sec)
    x = np.linspace(0, 1, n)
    swell = 1 - depth + depth * (0.5 + 0.5 * np.sin(2 * math.pi * (x * sec / 7.0) + 1.0)) \
        * (0.5 + 0.5 * np.sin(2 * math.pi * (x * sec / 3.1)))
    return bandpass(noise(sec), lo, hi) * swell


def birds(sec, count, pitch=2600):
    out = np.zeros(int(SR * sec))
    for _ in range(count):
        s = RNG.uniform(0, sec - 1.0)
        f0 = pitch * RNG.uniform(0.8, 1.3)
        for k in range(RNG.integers(2, 5)):
            d = 0.06 + RNG.uniform(0, 0.05)
            x = t(d)
            sweep = f0 * (1 + 0.25 * np.sin(2 * math.pi * 18 * x)) * (1 + RNG.uniform(-0.15, 0.15))
            chirp = np.sin(2 * math.pi * np.cumsum(sweep) / SR) * np.sin(np.pi * x / d)
            i = int((s + k * 0.11) * SR)
            out[i:i + len(chirp)] += chirp * RNG.uniform(0.3, 0.6)
    return out


def chimes(sec, count):
    out = np.zeros(int(SR * sec))
    for _ in range(count):
        s = RNG.uniform(0, sec - 2.5)
        f = NOTE[RNG.choice(["D5", "F5", "A5", "D6", "E5"])]
        b = bell(f, 2.2, 0.5)
        i = int(s * SR)
        out[i:i + len(b)] += b * RNG.uniform(0.15, 0.3)
    return out


def water(sec, lap_rate=0.35):
    n = int(SR * sec)
    x = np.arange(n) / SR
    base = bandpass(noise(sec), 200, 1200) * (0.6 + 0.4 * np.sin(2 * math.pi * lap_rate * x) ** 2)
    out = base * 0.7
    for _ in range(int(sec * 2)):                         # petites bulles et clapotis
        s = RNG.uniform(0, sec - 0.2)
        d = 0.05
        f = RNG.uniform(500, 1100)
        bub = np.sin(2 * math.pi * np.linspace(f, f * 1.6, int(SR * d)) * t(d)) * env(int(SR * d), 0.002, 0.03, 3)
        i = int(s * SR)
        out[i:i + len(bub)] += bub * 0.18
    return out


def creaks(sec, count):
    """Craquements de bois : branches qui travaillent, très bas, espacés."""
    out = np.zeros(int(SR * sec))
    for _ in range(count):
        s0 = RNG.uniform(0, sec - 1.0)
        d = RNG.uniform(0.35, 0.7)
        n = int(SR * d)
        f = np.linspace(RNG.uniform(90, 140), RNG.uniform(60, 90), n)
        grain = (RNG.uniform(0, 1, n) < 0.08).astype(float) * RNG.uniform(-1, 1, n)
        tone = np.sin(2 * math.pi * np.cumsum(f) / SR) * 0.4 + lowpass(grain, 900) * 2.0
        e = np.sin(np.pi * np.arange(n) / n)
        i = int(s0 * SR)
        out[i:i + n] += tone * e * RNG.uniform(0.25, 0.45)
    return out


def ambiences():
    sec = 24.0
    A = {
        # village : brise douce, quelques oiseaux, un carillon au loin de temps en temps
        "village": mix((0, wind(sec + 1.5, 120, 700, 0.5), 0.5), (0, birds(sec + 1.5, 7), 0.22),
                       (0, chimes(sec + 1.5, 3), 1.0)),
        # forêt (Lisière) : feuillage plus présent, plus d'oiseaux, plus aigus
        "foret": mix((0, wind(sec + 1.5, 300, 2400, 0.7), 0.45), (0, birds(sec + 1.5, 12, 3100), 0.25)),
        # forêt des Anciens : vent grave sous la voûte, craquements de bois, rares oiseaux, ru lointain
        "foret_profonde": mix((0, wind(sec + 1.5, 80, 450, 0.75), 0.6), (0, creaks(sec + 1.5, 5), 1.0),
                              (0, birds(sec + 1.5, 3, 1900), 0.12), (0, water(sec + 1.5, 0.2), 0.12)),
        # rive : l'eau qui lèche les galets, roseaux, rares oiseaux d'eau
        "rive": mix((0, water(sec + 1.5), 0.8), (0, wind(sec + 1.5, 600, 3000, 0.6), 0.18),
                    (0, birds(sec + 1.5, 3, 1700), 0.15)),
    }
    for name, x in A.items():
        save(loop_seamless(x), f"ambience/{name}.wav", 0.5)


if __name__ == "__main__":
    s = sfx()
    print(len(s), "bruitages")
    ambiences()
    print("ambiances : village, foret, rive")
