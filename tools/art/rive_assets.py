"""Assets de Rive Paisible (étage 1) : sols de rive, hameau de pêcheurs, eau, ressources, découverte.

Même palette, même lumière (haut-gauche), même contour que le reste.
Sols : galets, eaux basses (anse, marais praticable), eau profonde immobile (« trop calme »), vase,
planches de ponton. Usage : python tools/art/rive_assets.py
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, CLEAR  # noqa: E402
import styleboard as sb  # noqa: E402
import buildings as bk  # noqa: E402
from lisiere_assets import canvas, blob, rect, put, line  # noqa: E402

T = 16
O = P["outline"]


# --------------------------------------------------------------------------- sols
def fill_pebbles(seed, variant=0):
    vs = seed * 10 + variant

    def f(x, y):
        cx, cy = (x // 4) * 4 + 2, (y // 3) * 3 + 1.5 + ((x // 4) % 2) * 1.5
        r = sb.hash01(vs, x // 4, y // 3)
        dx, dy = (x + 0.5 - cx) / (1.6 + r * 0.6), (y + 0.5 - cy) / 1.3
        if dx * dx + dy * dy <= 1.0:
            if dx + dy < -0.6:
                return P["stone0"]
            return P["stone2"] if dx + dy > 0.6 else (P["stone1"] if r > 0.25 else P["earth0"])
        return P["earth1"] if sb.hash01(vs + 3, x, y) > 0.6 else P["earth0"]
    return f


def fill_shallow(seed, variant=0):
    n = sb.periodic_noise(seed * 10 + variant, cell=4, border_seed=seed)
    vs = seed * 10 + variant

    def f(x, y):
        r = sb.hash01(vs, x, y)
        xs, ys = x % T, y % T
        for k in range(2):
            if 1 <= xs - k <= 13 and 1 <= ys <= 14 and sb.hash01(vs + 5, x - k, y) > 0.978:
                return P["water0"]                       # vaguelette claire
        if r < 0.06:
            return P["stone1"] if r < 0.03 else P["water2"]   # galets du fond
        return P["water1"] if n(x, y) > 0.35 else P["water2"]
    return f


def fill_deep(seed, variant=0):
    vs = seed * 10 + variant

    def f(x, y):
        # eau sombre et immobile : presque unie, quelques reflets froids figés, aucun mouvement
        r = sb.hash01(vs, x, y)
        if r > 0.992:
            return P["water3"]
        return P["water4"]
    return f


def fill_mud(seed, variant=0):
    n = sb.periodic_noise(seed * 10 + variant, cell=4, border_seed=seed)
    vs = seed * 10 + variant

    def f(x, y):
        r = sb.hash01(vs, x, y)
        if r < 0.04:
            return P["water2"]
        return P["earth3"] if n(x, y) < 0.45 else P["earth2"]
    return f


def plank(vertical, variant):
    """Planches de ponton (tuile pleine) : lames perpendiculaires au sens de marche."""
    img = Image.new("RGBA", (T, T))
    px = img.load()
    rng = random.Random(variant * 7 + (3 if vertical else 0))
    missing = 2 if variant == 3 else -1
    for y in range(T):
        for x in range(T):
            a, b = (y, x) if vertical else (x, y)     # a : le long des lames, b : à travers
            lame = b // 4
            if lame == missing:
                c = P["water4"] if (a + b) % 3 else P["water3"]   # planche manquante : l'eau dessous
            elif b % 4 == 3:
                c = P["earth4"]
            elif b % 4 == 0:
                c = P["earth0"]
            else:
                c = P["earth1"] if sb.hash01(variant * 31 + lame, a // 3, b) > 0.2 else P["earth2"]
            if (a in (2, 13)) and b % 4 == 1 and lame != missing:
                c = P["earth4"]                        # clous
            px[x, y] = c
    return img


def ground_atlas():
    rows = [lambda v: sb.tile_from_fill(fill_pebbles(71, v)),
            lambda v: sb.tile_from_fill(fill_shallow(72, v)),
            lambda v: sb.tile_from_fill(fill_deep(73, v)),
            lambda v: sb.tile_from_fill(fill_mud(74, v)),
            lambda v: plank(False, v),
            lambda v: plank(True, v)]
    img = Image.new("RGBA", (T * 4, T * len(rows)))
    for r, mk in enumerate(rows):
        for v in range(4):
            img.alpha_composite(mk(v), (v * T, r * T))
    return img


def overlays():
    return {
        "galets": sb.Overlay("galets", sb.varied(fill_pebbles, 71), seed=81, rim=P["stone3"], amp=0.3),
        "basses": sb.Overlay("basses", sb.varied(fill_shallow, 72), seed=82, inner=(0.05, P["water0"]), amp=0.3),
        "profonde": sb.Overlay("profonde", sb.varied(fill_deep, 73), seed=83, amp=0.4),
        "marais": sb.Overlay("marais", sb.varied(fill_shallow, 72), seed=84, outer=(0.34, fill_mud(74)),
                             inner=(0.05, P["water0"]), amp=0.35),
    }


# --------------------------------------------------------------------------- hameau
def cabane(seed, wt=4, roof="chaume"):
    img = bk.maison_croupe(roof=roof, wmat="bois", wt=wt, ht=3, seed=seed, door_at=0.35,
                           shutters=("water2", "water3"), chimney_at=0.75, braces=False)
    # filet suspendu sous l'avant-toit et deux pilotis apparents
    out = canvas(img.width, img.height + 3)
    out.alpha_composite(img)
    for x in (6, img.width - 8):
        rect(out, x, img.height - 2, 2, 5, P["earth3"])
    for k in range(9):
        put(out, [(img.width - 22 + k, img.height - 22 + (k % 3)), (img.width - 22 + k, img.height - 18 + ((k + 1) % 3))],
            P["stone2"])
    sb.outline(out)
    return out


def fumoir():
    img = bk.maison_croupe(roof="ardoise", wmat="pierre", wt=3, ht=3, seed=91, door_at=0.5,
                           chimney_at=0.5, braces=False)
    # poissons qui sèchent à la perche
    out = canvas(img.width + 14, img.height)
    out.alpha_composite(img, (0, 0))
    W = img.width
    rect(out, W + 2, img.height - 22, 2, 22, P["earth3"])
    rect(out, W + 11, img.height - 22, 2, 22, P["earth3"])
    rect(out, W + 2, img.height - 22, 11, 1, P["earth2"])
    for k, x in enumerate((W + 5, W + 9)):
        rect(out, x, img.height - 21, 2, 6, P["stone2"] if k else P["sun2"])
    sb.outline(out)
    return out


def filets():
    img = canvas(52, 34)
    for x in (3, 25, 47):
        rect(img, x, 6, 2, 27, P["earth2"])
        rect(img, x + 1, 6, 1, 27, P["earth3"])
    for seg in ((4, 26), (26, 48)):
        for x in range(seg[0], seg[1]):
            sag = int(5 * math.sin((x - seg[0]) / (seg[1] - seg[0]) * math.pi))
            for y in range(8, 22 + sag):
                if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                    put(img, [(x, y)], P["stone1"] if y < 14 else P["stone2"])
            put(img, [(x, 7)], P["earth1"])
    for x, y in ((10, 18), (36, 20)):                   # flotteurs de liège
        rect(img, x, y, 3, 2, P["red0"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=22, ry=2)


def nasse():
    img = canvas(18, 12)
    blob(img, 9, 6, 8, 4.5, [P["earth1"], P["earth2"], P["earth3"]], seed=5, jitter=0)
    for x in range(3, 16, 3):
        line(img, x, 2, x + 1, 10, P["earth3"])
    blob(img, 15, 6, 2, 3, [P["outline"], P["shade1"], P["outline"]], seed=6, jitter=0)
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=8, ry=1.5)


def barque_retournee():
    img = canvas(38, 14)
    blob(img, 19, 8, 18, 5, [P["earth1"], P["earth2"], P["earth3"]], seed=11, jitter=0.1)
    line(img, 2, 7, 36, 7, P["earth3"])                  # quille
    for x in range(6, 34, 5):
        put(img, [(x, 9), (x, 10)], P["earth3"])         # bordages
    rect(img, 6, 11, 26, 2, P["earth4"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=17, ry=2)


def barque(seed=0, oar=True):
    """Barque à flot vue de 3/4 : coque, bancs, rides autour (posée sur l'eau)."""
    img = canvas(44, 20)
    for x in range(1, 43):                              # rides
        if (x + seed) % 5 < 3:
            put(img, [(x, 17)], P["water0"] if x % 2 else P["water1"])
    blob(img, 22, 10, 20, 7, [P["earth1"], P["earth2"], P["earth3"]], seed=21 + seed, jitter=0.1)
    blob(img, 22, 9, 16, 4.5, [P["earth3"], P["earth4"], P["earth4"]], seed=22, jitter=0)   # creux
    for x in (14, 22, 30):
        rect(img, x, 6, 2, 7, P["earth1"])              # bancs
    if oar:
        line(img, 18, 4, 34, 15, P["earth2"], w=1)
        rect(img, 33, 14, 4, 2, P["earth2"])
    sb.outline(img)
    return img


def poteau():
    img = canvas(6, 16)
    rect(img, 1, 1, 4, 15, P["earth2"])
    rect(img, 3, 1, 2, 15, P["earth3"])
    put(img, [(1, 1), (2, 1)], P["earth1"])
    put(img, [(1, 8), (2, 8), (3, 8), (4, 8)], P["stone2"])   # corde
    sb.outline(img)
    return img


def roseaux_grand(seed):
    rng = random.Random(seed)
    img = canvas(26, 28)
    for k in range(13):
        x0 = 3 + k * 1.6 + rng.uniform(-0.5, 0.5)
        hgt = rng.randint(14, 25)
        lean = rng.uniform(-3, 3)
        col = P["leaf2"] if k % 3 else P["leaf3"]
        line(img, x0, 27, x0 + lean, 27 - hgt, col)
        put(img, [(round(x0 + lean), 27 - hgt)], P["sun2"] if k % 2 else P["leaf1"])
        if k % 4 == 1:                                   # massette
            rect(img, round(x0 + lean * 0.7), 27 - int(hgt * 0.75), 2, 4, P["earth3"])
    sb.outline(img)
    return img


def nenuphars(seed):
    rng = random.Random(seed)
    img = canvas(18, 12)
    for cx, cy, r in ((6, 6, 4.5), (13, 7, 3.5)):
        blob(img, cx, cy, r, r * 0.6, [P["leaf1"], P["leaf2"], P["leaf3"]], seed=seed + int(cx), jitter=0.1)
        put(img, [(int(cx + r * 0.3), int(cy - 1)), (int(cx + r * 0.6), int(cy))], P["water2"])   # encoche
    if rng.random() < 0.5:
        put(img, [(6, 4), (5, 5), (7, 5), (6, 5)], P["sun0"])
    sb.outline(img)
    return img


def canard():
    img = canvas(14, 11)
    for x in range(1, 13):
        if x % 3:
            put(img, [(x, 9)], P["water0"])
    blob(img, 6, 6, 5, 3, [P["earth1"], P["earth2"], P["earth3"]], seed=31, jitter=0)
    blob(img, 10, 3, 2.2, 2, [P["leaf2"], P["leaf3"], P["leaf4"]], seed=32, jitter=0)
    put(img, [(12, 3), (13, 3)], P["sun2"])
    put(img, [(10, 2)], O)
    put(img, [(9, 5), (10, 5)], P["sun0"])               # collier blanc
    sb.outline(img)
    return img


def saule(seed):
    """Saule : tronc court, rideau de feuillage qui retombe en mèches."""
    rng = random.Random(seed)
    W, H = 44, 58
    img = canvas(W, H)
    rect(img, W // 2 - 3, H - 22, 6, 20, P["earth3"])
    rect(img, W // 2 - 3, H - 22, 2, 20, P["earth2"])
    blob(img, W / 2, 18, 18, 13, [P["leaf1"], P["leaf2"], P["leaf3"], P["leaf4"]], seed=seed, jitter=0.35)
    for k in range(22):                                  # mèches qui pendent
        x = 5 + k * 1.6 + rng.uniform(-0.5, 0.5)
        y0 = 16 + rng.uniform(0, 8)
        L = rng.uniform(14, 30)
        col = P["leaf2"] if k % 3 else (P["leaf1"] if k % 2 else P["leaf3"])
        line(img, x, y0, x + rng.uniform(-1, 1), y0 + L, col)
        if L > 24:
            put(img, [(round(x), round(y0 + L))], P["leaf0"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=16, ry=3)


def bois_flotte():
    img = canvas(26, 8)
    line(img, 1, 5, 24, 3, P["stone0"], w=2)
    line(img, 2, 6, 24, 4, P["stone1"])
    line(img, 16, 3, 20, 0, P["stone0"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=11, ry=1.5)


def cercle_immerge():
    """Sous l'eau claire : sept pierres taillées en cercle parfait, runes cyan presque éteintes.
    Posé sur l'eau (sol), en teintes d'eau pour paraître immergé."""
    W, H = 64, 36
    img = canvas(W, H)
    cx, cy = W / 2, H / 2
    for k in range(7):
        a = k * math.tau / 7 - math.pi / 2
        x, y = cx + math.cos(a) * 25, cy + math.sin(a) * 13
        # pierre taillée vue à travers l'eau : gris-bleu, arête claire, ombre portée sombre
        rect(img, round(x) - 4, round(y) - 3, 8, 6, P["stone2"])
        rect(img, round(x) - 4, round(y) - 3, 8, 1, P["stone1"])
        rect(img, round(x) - 4, round(y) + 2, 8, 1, P["water3"])
        rect(img, round(x) + 4, round(y) - 2, 1, 5, P["water3"])
        put(img, [(round(x) - 1, round(y)), (round(x), round(y) - 1), (round(x) + 1, round(y))],
            P["rune2"] if k % 2 else P["rune1"])
    for k in range(48):                                  # dalle du centre, à peine visible
        a = k * math.tau / 48
        put(img, [(round(cx + math.cos(a) * 9), round(cy + math.sin(a) * 5))], P["stone2"] if k % 3 else P["water3"])
    put(img, [(round(cx), round(cy))], P["rune1"])
    return img


# --------------------------------------------------------------------------- ressources
def poste_peche():
    img = canvas(26, 22)
    for r in (8, 5):                                     # rides du poste
        for k in range(24):
            a = k * math.tau / 24
            if k % 2:
                put(img, [(round(18 + math.cos(a) * r), round(16 + math.sin(a) * r * 0.45))], P["water0"])
    rect(img, 3, 6, 3, 15, P["earth2"])                  # piquet
    line(img, 5, 7, 22, 2, P["earth1"])                  # canne
    line(img, 22, 2, 19, 15, P["stone0"])                # ligne
    put(img, [(19, 15), (19, 16)], P["red0"])            # bouchon
    blob(img, 8, 18, 3.5, 3, [P["stone1"], P["stone2"], P["stone3"]], seed=41, jitter=0)   # seau
    sb.outline(img)
    return img


def roseaux_dores():
    img = roseaux_grand(55)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y] == P["leaf2"] and (x + y) % 3 == 0:
                px[x, y] = P["sun2"]
            elif px[x, y] == P["leaf1"]:
                px[x, y] = P["sun1"]
    return img


def nenuphar_pale():
    img = canvas(22, 14)
    blob(img, 11, 9, 9, 4, [P["leaf1"], P["leaf2"], P["leaf3"]], seed=61, jitter=0.1)
    for k in range(6):                                   # fleur blanche, pétales ouverts vers l'aube
        a = k * math.tau / 6
        blob(img, 11 + math.cos(a) * 3, 6 + math.sin(a) * 1.8, 2.2, 1.6, [P["sun0"], P["stone0"], P["stone1"]], seed=62 + k, jitter=0)
    put(img, [(11, 6), (10, 6)], P["sun1"])
    sb.outline(img)
    return img


def galets_veines():
    img = canvas(22, 12)
    for cx, cy, r in ((6, 7, 4.5), (13, 6, 5), (17, 9, 3.5), (9, 9, 3)):
        blob(img, cx, cy, r, r * 0.7, [P["stone0"], P["stone1"], P["stone2"]], seed=int(cx * 3), jitter=0.1)
        line(img, cx - r * 0.5, cy - 1, cx + r * 0.6, cy + 1, P["stone3"])   # veine sombre
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=10, ry=1.5)


def affut():
    img = canvas(30, 26)
    for x in range(2, 28):                               # mur de roseaux tressés
        h = 18 + (x * 7) % 5
        line(img, x, 25, x, 25 - h, P["sun3"] if x % 2 else P["earth2"])
    rect(img, 4, 12, 22, 3, P["outline"])                # fente de guet
    rect(img, 1, 6, 28, 2, P["earth3"])                  # toit de branchages
    for x in range(1, 29, 3):
        put(img, [(x, 5), (x + 1, 4)], P["leaf2"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=13, ry=2)


ALL = {
    "props/rive/cabane_a": lambda: cabane(101, 4),
    "props/rive/cabane_b": lambda: cabane(102, 3, "lie"),
    "props/rive/fumoir": fumoir,
    "props/rive/filets": filets,
    "props/rive/nasse": nasse,
    "props/rive/barque_retournee": barque_retournee,
    "props/rive/barque": lambda: barque(0, True),
    "props/rive/barque_vide": lambda: barque(2, False),
    "props/rive/poteau": poteau,
    "props/rive/roseaux_a": lambda: roseaux_grand(1),
    "props/rive/roseaux_b": lambda: roseaux_grand(2),
    "props/rive/nenuphars_a": lambda: nenuphars(1),
    "props/rive/nenuphars_b": lambda: nenuphars(2),
    "props/rive/canard": canard,
    "props/rive/saule_a": lambda: saule(7),
    "props/rive/saule_b": lambda: saule(8),
    "props/rive/bois_flotte": bois_flotte,
    "props/rive/cercle_immerge": cercle_immerge,
    "props/ressources/eaux_basses_de_la_rive": poste_peche,
    "props/ressources/roseaux_dores": roseaux_dores,
    "props/ressources/nenuphar_pale": nenuphar_pale,
    "props/ressources/galets_veines": galets_veines,
    "props/ressources/affut_des_berges": affut,
}


def main():
    for rel, fn in ALL.items():
        sb.save(fn(), f"{rel}.png")
    sb.save(ground_atlas(), "tiles/floor_1/ground_rive.png")
    for name, ov in overlays().items():
        sb.save(ov.atlas(), f"tiles/floor_1/overlay_{name}.png")


def preview(out):
    imgs = [fn() for fn in ALL.values()] + [ground_atlas()] + [ov.atlas() for ov in overlays().values()]
    cols, cell = 6, 110
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), P["leaf2"])
    for i, im in enumerate(imgs):
        s = 2 if im.width <= 52 else 1
        im = im.resize((im.width * s, im.height * s), Image.NEAREST)
        sheet.alpha_composite(im, ((i % cols) * cell + max(0, (cell - im.width) // 2), (i // cols) * cell + max(0, (cell - im.height) // 2)))
    sheet.save(out)


if __name__ == "__main__":
    main()
    preview(sb.PREVIEW / "rive_assets.png")
    print(sb.PREVIEW / "rive_assets.png")
