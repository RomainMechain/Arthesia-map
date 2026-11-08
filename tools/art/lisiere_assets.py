"""Assets du Sentier de la Lisière (étage 1) : faune, ressources, abri d'Aurin, grand chêne, sous-bois.

Même palette, même lumière (haut-gauche), même contour que la planche de style.
Usage : python tools/art/lisiere_assets.py   (appelé aussi par village_assets.main)
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, CLEAR, GROUND_SHADOW  # noqa: E402
import styleboard as sb  # noqa: E402

O = P["outline"]


# --------------------------------------------------------------------------- outils
def canvas(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def blob(img, cx, cy, rx, ry, ramp, seed=0, jitter=0.25, light=(1.0, 1.0)):
    """Ellipse ombrée (lumière haut-gauche). ramp : couleurs claire -> sombre (3 ou 4)."""
    px = img.load()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not (0 <= x < img.width and 0 <= y < img.height):
                continue
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy > 1:
                continue
            d = (dx * light[0] + dy * light[1]) / 1.3 + (sb.hash01(seed, x, y) - 0.5) * jitter
            if len(ramp) == 4:
                c = ramp[0] if d < -0.5 else ramp[1] if d < 0.1 else ramp[2] if d < 0.55 else ramp[3]
            else:
                c = ramp[0] if d < -0.35 else ramp[1] if d < 0.35 else ramp[2]
            px[x, y] = c


def rect(img, x, y, w, h, c):
    px = img.load()
    for yy in range(int(y), int(y + h)):
        for xx in range(int(x), int(x + w)):
            if 0 <= xx < img.width and 0 <= yy < img.height:
                px[xx, yy] = c


def put(img, pts, c):
    px = img.load()
    for x, y in pts:
        if 0 <= x < img.width and 0 <= y < img.height:
            px[x, y] = c


def line(img, x0, y0, x1, y1, c, w=1):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(1, n)
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        rect(img, round(x - (w - 1) / 2), round(y - (w - 1) / 2), w, w, c)


def keys(**extra):
    k = {"O": O, "1": P["stone0"], "2": P["stone1"], "3": P["stone2"], "4": P["stone3"],
         "e": P["earth0"], "w": P["earth1"], "W": P["earth2"], "d": P["earth3"], "D": P["earth4"],
         "L": P["leaf0"], "l": P["leaf1"], "g": P["leaf2"], "G": P["leaf3"], "f": P["leaf4"], "F": P["leaf5"],
         "Y": P["sun0"], "y": P["sun1"], "o": P["sun2"], "h": P["sun3"], "x": P["red0"], "X": P["red1"],
         "s": P["shade1"], "S": P["shade0"]}
    k.update(extra)
    return k


def frames(make, n=4):
    """Bande de n images (make(i) -> sprite de même taille), ombre au sol fixe."""
    imgs = [make(i) for i in range(n)]
    w, h = imgs[0].size
    strip = canvas(w * n, h + 1)
    for i, im in enumerate(imgs):
        f = canvas(w, h + 1)
        sb.ellipse(f, w / 2 + 1, h - 1, w * 0.34, 1.6, GROUND_SHADOW)
        f.alpha_composite(im, (0, 0))
        strip.alpha_composite(f, (i * w, 0))
    return strip


# --------------------------------------------------------------------------- faune
def loup_dore():
    """Loup doré de profil (vers la droite), 26x18 par image : pas de marche sur 4 images."""
    fur = [P["sun1"], P["sun2"], P["sun3"], P["earth3"]]

    def make(i):
        img = canvas(26, 18)
        bob = (0, -1, 0, -1)[i]
        leg = (0, 1, 0, -1)[i]
        # pattes du fond (plus sombres)
        for x, ph in ((8, -leg), (17, leg)):
            rect(img, x, 11 + bob, 2, 5 - bob, P["sun3"])
            put(img, [(x + 1 + ph, 16)], P["earth3"])
        blob(img, 4.5, 8.5 + bob, 4, 1.8, fur, seed=3)                 # queue en panache
        put(img, [(1, 8 + bob), (2, 7 + bob)], P["sun0"])
        blob(img, 12, 10 + bob, 7.5, 3.6, fur, seed=1)                 # corps
        blob(img, 17.5, 9 + bob, 3.6, 3.8, fur, seed=2)                # poitrail
        blob(img, 21, 6 + bob, 3.2, 2.8, fur, seed=4)                  # tête
        blob(img, 24, 7.5 + bob, 1.8, 1.3, [P["sun1"], P["sun2"], P["sun3"]], seed=5)  # museau
        put(img, [(19, 2 + bob), (20, 2 + bob), (19, 3 + bob), (20, 3 + bob), (21, 3 + bob),
                  (22, 3 + bob), (22, 2 + bob)], P["sun2"])          # oreilles
        put(img, [(20, 2 + bob), (22, 2 + bob)], P["sun3"])
        # pattes avant (claires)
        for x, ph in ((10, leg), (19, -leg)):
            rect(img, x, 12 + bob, 2, 4 - bob, P["sun2"])
            put(img, [(x + ph if ph > 0 else x, 16)], P["sun3"])
        rect(img, 9, 12 + bob, 9, 1, P["sun0"])                        # ventre clair
        put(img, [(21, 5 + bob)], O)                                    # oeil
        put(img, [(22, 5 + bob)], P["sun0"])                            # reflet doré, trop calme
        put(img, [(25, 7 + bob)], O)                                    # truffe
        sb.outline(img)
        return img
    return frames(make)


def renardeau():
    """Renardeau curieux, 20x15 par image : grandes oreilles, bout de queue blanc."""
    fur = [P["sun2"], P["sun3"], P["red1"]]

    def make(i):
        img = canvas(20, 15)
        bob = (0, -1, 0, -1)[i]
        leg = (0, 1, 0, -1)[i]
        for x, ph in ((6, -leg), (13, leg)):
            rect(img, x, 10 + bob, 2, 4 - bob, P["earth4"])
        blob(img, 3.5, 7 + bob, 3.3, 2.0, fur, seed=7)                 # queue
        put(img, [(1, 6 + bob), (1, 7 + bob), (2, 6 + bob)], P["sun0"])
        blob(img, 9.5, 9 + bob, 5.5, 3.0, fur, seed=8)                 # corps
        blob(img, 15, 6 + bob, 3.0, 2.7, fur, seed=9)                  # tête
        blob(img, 17.8, 7.4 + bob, 1.6, 1.1, [P["sun1"], P["sun2"], P["sun3"]], seed=10)
        put(img, [(13, 1 + bob), (13, 2 + bob), (14, 2 + bob), (16, 1 + bob), (16, 2 + bob),
                  (15, 2 + bob), (13, 3 + bob), (16, 3 + bob)], P["sun3"])   # grandes oreilles
        put(img, [(13, 2 + bob), (16, 2 + bob)], P["outline"])
        rect(img, 12, 8 + bob, 4, 2, P["sun0"])                        # poitrail blanc
        for x, ph in ((8, leg), (14, -leg)):
            rect(img, x, 11 + bob, 2, 3 - bob, P["earth4"])
        put(img, [(15, 5 + bob)], O)
        put(img, [(19, 7 + bob)], O)
        sb.outline(img)
        return img
    return frames(make)


def oiseau():
    """Oiseau chanteur au plumage clair, 12x11 par image : sautille et bat des ailes."""
    def make(i):
        img = canvas(12, 11)
        bob = (0, -2, 0, 0)[i]
        flap = i == 1
        rect(img, 4, 8 + bob, 1, 2 - bob, P["sun3"])                    # pattes
        rect(img, 6, 8 + bob, 1, 2 - bob, P["sun3"])
        put(img, [(0, 4 + bob), (1, 5 + bob), (1, 4 + bob)], P["stone1"])   # queue
        blob(img, 5, 5.5 + bob, 3.6, 2.8, [P["sun0"], P["stone0"], P["stone1"]], seed=11)
        blob(img, 6.5, 6.6 + bob, 2.0, 1.4, [P["sun1"], P["sun1"], P["sun2"]], seed=12)   # gorge dorée
        blob(img, 8.3, 3.5 + bob, 2.1, 2.0, [P["sun0"], P["stone0"], P["stone1"]], seed=13)
        put(img, [(10, 4 + bob), (11, 4 + bob)], P["sun3"])            # bec
        put(img, [(9, 3 + bob)], O)
        if flap:
            put(img, [(3, 1 + bob), (4, 1 + bob), (4, 2 + bob), (5, 2 + bob), (3, 2 + bob)], P["stone1"])
        else:
            put(img, [(3, 5 + bob), (4, 5 + bob), (5, 6 + bob), (4, 6 + bob)], P["stone2"])
        sb.outline(img)
        return img
    return frames(make)


# --------------------------------------------------------------------------- Aurin
AURIN = [
    "................",
    "................",
    "................",
    ".....OOOOOO.....",
    "....OHHHHHHO....",
    "...OHLLHHHHHO...",
    "...OHHHHHHHhO...",
    "...OHSSSSSShO...",
    "...OSSOSSOSsO...",
    "...OHSSSSSShO...",
    "...OHYYYYYYhO...",
    "....OYYYYYyO....",
    "....OTYYYyTO....",
    "...OTTTYyTTtO...",
    ".OTOTTTTTTTtOtO.",
    ".OTOTTTTTTTtOtO.",
    ".OSOBBBGBBBBOsO.",
    ".OOOTTTTTTTtOOO.",
    "...OTTTTTTTtO...",
    "...OTTTTTTTtO...",
    "...OTTTOOTTtO...",
    "...OKKKOOKKkO...",
    "...OOOOOOOOOO...",
    "................",
]


def aurin():
    k = dict(sb.KEYS_CHAR)
    k.update({"H": P["stone0"], "L": P["sun0"], "h": P["stone1"], "Y": P["stone0"], "y": P["stone1"],
              "T": P["leaf3"], "t": P["leaf4"], "B": P["earth3"], "G": P["sun2"]})
    return sb.bounce_frames(sb.from_ascii(AURIN, k), (0, 0, -1, -1))


# --------------------------------------------------------------------------- ressources (une par entrée)
def mousse_lumineuse():
    img = canvas(22, 14)
    blob(img, 11, 9, 9.5, 4.5, [P["stone1"], P["stone2"], P["stone3"], P["stone4"]], seed=21)
    blob(img, 9, 6.5, 7.5, 3.0, [P["leaf1"], P["leaf2"], P["leaf3"]], seed=22)     # coussin de mousse
    blob(img, 15, 8, 3.5, 2.0, [P["leaf1"], P["leaf2"], P["leaf3"]], seed=23)
    rng = random.Random(24)
    px = img.load()
    for _ in range(9):                                    # points de lumière captée
        x, y = rng.randint(3, 17), rng.randint(4, 9)
        if px[x, y][3] == 255 and px[x, y] in (P["leaf1"], P["leaf2"], P["leaf3"]):
            px[x, y] = P["sun0"] if rng.random() < 0.5 else P["sun1"]
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=9, ry=2)


def champignons():
    img = canvas(16, 14)
    for cx, cy, r, h in ((5, 6, 3.6, 5), (11, 8, 3.0, 4), (8, 10, 2.2, 3)):
        rect(img, cx - 1, cy, 2, h, P["stone0"])
        put(img, [(cx, cy + h - 1)], P["stone1"])
        blob(img, cx, cy, r, r * 0.7, [P["sun2"], P["sun3"], P["red1"]], seed=int(cx * 7))
        put(img, [(int(cx - r / 2), int(cy - 1)), (int(cx + 1), int(cy - 1))], P["sun0"])
    put(img, [(2, 12), (3, 13), (13, 12), (14, 13)], P["leaf3"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=6, ry=1.6)


def racine_doree():
    img = canvas(26, 12)
    # racine noueuse qui sort du sol et y replonge
    pts = [(1, 10), (4, 6), (8, 4), (13, 5), (17, 3), (21, 5), (24, 10)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        line(img, x0, y0, x1, y1, P["earth3"], w=3)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        line(img, x0, y0 - 1, x1, y1 - 1, P["earth2"], w=1)
    line(img, 9, 5, 11, 10, P["earth3"], w=2)              # radicelle
    for x, y in ((5, 6), (6, 5), (10, 4), (14, 5), (15, 4), (18, 3), (19, 4), (22, 6)):
        put(img, [(x, y)], P["sun1"])                       # veines dorées
    put(img, [(10, 5), (18, 4)], P["sun0"])
    rect(img, 0, 10, 4, 2, P["earth4"])
    rect(img, 22, 10, 4, 2, P["earth4"])
    for x in (3, 7, 16, 20):
        put(img, [(x, 9), (x + 1, 8)], P["leaf2"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=11, ry=1.6)


def bois_mort():
    img = canvas(24, 12)
    for (x0, y0, x1, y1) in ((2, 9, 21, 6), (4, 5, 20, 10), (6, 8, 23, 8), (1, 7, 12, 4)):
        line(img, x0, y0, x1, y1, P["earth2"], w=2)
        line(img, x0, y0 + 1, x1, y1 + 1, P["earth3"], w=1)
    put(img, [(21, 6), (20, 10), (23, 8), (12, 4)], P["earth1"])   # bouts coupés clairs
    put(img, [(9, 4), (10, 3), (16, 5), (17, 4)], P["earth3"])     # rameaux
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=10, ry=1.8)


def pierres_taillees():
    img = canvas(26, 14)
    for x, y, w, h in ((2, 6, 9, 6), (12, 4, 10, 7), (18, 9, 7, 4)):
        rect(img, x, y, w, h, P["stone1"])
        rect(img, x, y, w, 2, P["stone0"])                  # dessus éclairé, arêtes droites
        rect(img, x + w - 1, y + 2, 1, h - 2, P["stone2"])
        rect(img, x, y + h - 1, w, 1, P["stone3"])
    rect(img, 0, 11, 26, 3, P["earth2"])                    # à moitié enterrées
    put(img, [(1, 11), (5, 11), (9, 10), (14, 10), (19, 12), (24, 12)], P["earth3"])
    put(img, [(3, 6), (4, 6), (13, 4), (21, 4), (14, 5)], P["leaf2"])   # mousse
    put(img, [(16, 7), (17, 7), (18, 7)], P["stone2"])                  # trait gravé, presque effacé
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=11, ry=1.6)


def terriers():
    img = canvas(26, 12)
    blob(img, 13, 8, 12, 4, [P["earth1"], P["earth2"], P["earth3"]], seed=31)
    for cx in (8, 17):
        blob(img, cx, 8, 2.6, 1.8, [P["outline"], P["shade1"], P["outline"]], seed=cx, jitter=0)
        put(img, [(cx - 2, 6), (cx - 1, 6), (cx, 6), (cx + 1, 6)], P["earth0"])
    for x in (2, 4, 12, 22, 24):
        put(img, [(x, 5), (x, 4), (x + 1, 5)], P["leaf2"])
        put(img, [(x - 1, 3)], P["leaf1"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=11, ry=1.6)


# --------------------------------------------------------------------------- sous-bois
def fougere(seed):
    rng = random.Random(seed)
    img = canvas(18, 13)
    base = (9, 12)
    for k in range(7):
        a = math.radians(200 + k * 23 + rng.uniform(-6, 6))
        L = rng.uniform(6, 8.5)
        x1, y1 = base[0] + math.cos(a) * L, base[1] + math.sin(a) * L * 1.15
        col = P["leaf2"] if k % 2 else P["leaf3"]
        line(img, base[0], base[1] - 1, x1, y1, col, w=1)
        # folioles de part et d'autre
        for t in (0.4, 0.6, 0.8):
            fx, fy = base[0] + (x1 - base[0]) * t, base[1] - 1 + (y1 - base[1] + 1) * t
            put(img, [(round(fx), round(fy) - 1), (round(fx) + (1 if x1 > base[0] else -1), round(fy))],
                P["leaf1"] if fy < 7 else col)
        put(img, [(round(x1), round(y1))], P["leaf0"])        # pointe dorée par l'aube
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=6, ry=1.6)


def souche():
    img = canvas(16, 13)
    rect(img, 3, 4, 10, 8, P["earth3"])
    rect(img, 3, 4, 3, 8, P["earth2"])
    blob(img, 8, 4, 5, 2, [P["earth0"], P["earth1"], P["earth2"]], seed=41, jitter=0)
    put(img, [(7, 4), (8, 4), (9, 3)], P["earth2"])         # cernes
    put(img, [(1, 11), (2, 11), (13, 11), (14, 11), (2, 10), (13, 10)], P["earth3"])   # racines
    put(img, [(4, 6), (4, 7), (5, 9), (12, 8)], P["leaf2"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=7, ry=1.6)


def tronc_couche():
    img = canvas(36, 14)
    rect(img, 4, 3, 28, 8, P["earth3"])
    rect(img, 4, 3, 28, 2, P["earth2"])
    rect(img, 4, 10, 28, 1, P["earth4"])
    for x in range(6, 31, 4):
        put(img, [(x, 6), (x + 1, 7), (x + 2, 8)], P["earth4"])          # écorce
    blob(img, 4, 7, 2.5, 4.5, [P["earth0"], P["earth1"], P["earth2"]], seed=43, jitter=0)   # bout scié
    put(img, [(4, 6), (4, 7), (4, 8)], P["earth2"])
    for x in range(10, 30, 3):                                              # mousse sur le dessus
        put(img, [(x, 3), (x + 1, 3), (x + 1, 2)], P["leaf2"] if x % 2 else P["leaf1"])
    line(img, 32, 4, 35, 1, P["earth3"], w=2)                              # branche cassée
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=16, ry=2)


def champignons_deco():
    img = canvas(10, 8)
    for cx, cy in ((3, 3), (7, 5)):
        rect(img, cx, cy, 1, 3, P["stone0"])
        put(img, [(cx - 1, cy), (cx, cy - 1), (cx + 1, cy), (cx, cy)], P["sun3"])
        put(img, [(cx, cy - 1)], P["sun2"])
    sb.outline(img)
    return img


# --------------------------------------------------------------------------- grands éléments
def chene_ancien():
    """Grand chêne de la Lisière (repère) : 72x88, tronc massif, racines, couronne sombre dorée par l'aube."""
    W, H = 72, 88
    img = canvas(W, H)
    rng = random.Random(51)
    # tronc + contreforts
    for y in range(H - 34, H - 3):
        t = (y - (H - 34)) / 31
        half = 6 + int(t ** 3 * 9)
        for x in range(W // 2 - half, W // 2 + half):
            rel = (x - (W // 2 - half)) / (2 * half)
            c = P["earth2"] if rel < 0.3 else P["earth3"] if rel < 0.75 else P["earth4"]
            if sb.hash01(52, x, y // 3) < 0.12:
                c = P["earth4"]
            img.putpixel((x, y), c)
    for x0, dx in ((W // 2 - 14, -6), (W // 2 + 12, 7), (W // 2 - 4, -3)):
        line(img, x0, H - 6, x0 + dx, H - 2, P["earth3"], w=3)
    put(img, [(W // 2 - 2, H - 22), (W // 2 - 1, H - 22), (W // 2 - 2, H - 21)], O)   # creux
    # couronne
    blobs = [(W / 2, 26, 22)]
    for _ in range(12):
        a = rng.uniform(math.pi * 0.9, math.pi * 2.1)
        blobs.append((W / 2 + math.cos(a) * 18, 30 + math.sin(a) * 12, rng.uniform(9, 13)))
    blobs += [(W / 2 - 22, 38, 10), (W / 2 + 22, 38, 10), (W / 2, 42, 12)]
    blobs.sort(key=lambda b: b[1])
    ramp = [P["leaf2"], P["leaf3"], P["leaf4"], P["leaf5"]]
    for i, (cx, cy, r) in enumerate(blobs):
        blob(img, cx, cy, r, r * 0.92, ramp, seed=60 + i, jitter=0.4)
    # touches de lumière d'aube sur le haut-gauche
    px = img.load()
    for y in range(4, 40):
        for x in range(6, W - 6):
            if px[x, y] == P["leaf2"] and sb.hash01(70, x, y) < 0.22:
                px[x, y] = P["leaf1"] if sb.hash01(71, x, y) < 0.7 else P["sun1"]
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=26, ry=4)


def auvent_aurin():
    """Abri d'Aurin : auvent de branches tressées, couche, caisse. 52x40."""
    W, H = 56, 42
    img = canvas(W, H)
    rng = random.Random(81)
    # pénombre sous l'appentis : le fond est plus haut que l'avant (toit incliné)
    for y in range(14, 38):
        for x in range(9, 47):
            c = P["shade1"] if y < 30 else P["earth4"]
            if y >= 34 and (x < 12 or x > 43):
                continue
            img.putpixel((x, y), c)
    line(img, 9, 14, 9, 37, P["earth3"], w=2)               # poteaux du fond
    line(img, 46, 14, 46, 37, P["earth3"], w=2)
    rect(img, 12, 30, 17, 5, P["red1"])                     # couche : couverture
    rect(img, 12, 30, 17, 1, P["red0"])
    rect(img, 12, 29, 5, 3, P["stone0"])                    # oreiller de laine
    rect(img, 34, 27, 9, 8, P["earth2"])                    # caisse
    rect(img, 34, 27, 9, 1, P["earth1"])
    rect(img, 38, 28, 1, 7, P["earth3"])
    put(img, [(31, 33), (32, 33), (31, 34), (32, 34)], P["stone2"])   # gobelet
    # toit en appentis : branches tressées, avant-toit qui déborde
    for row in range(7):
        y = 3 + row * 2
        inset = max(0, 4 - row)
        for x in range(2 + inset, W - 2 - inset):
            weave = (x // 3 + row) % 2
            img.putpixel((x, y), (P["earth2"], P["earth3"])[weave])
            img.putpixel((x, y + 1), (P["earth3"], P["earth4"])[weave])
    for x in range(2, W - 2):                                # frange de brindilles sous l'avant-toit
        n = rng.choice((1, 1, 2, 3))
        for k in range(n):
            img.putpixel((x, 17 + k), P["earth3"] if k == 0 else P["earth2"])
    # feuillage posé sur le toit, débordant
    for i in range(15):
        cx = 4 + i * 3.4 + rng.uniform(-1, 1)
        blob(img, cx, 3 + rng.uniform(0, 3), rng.uniform(2.6, 3.6), 2.2,
             [P["leaf1"], P["leaf2"], P["leaf3"]], seed=80 + i)
    # poteaux de façade, un peu tordus
    line(img, 5, 39, 6, 15, P["earth2"], w=3)
    line(img, 50, 39, 49, 15, P["earth2"], w=3)
    line(img, 7, 39, 8, 15, P["earth3"], w=1)
    line(img, 52, 39, 51, 15, P["earth3"], w=1)
    # lanterne suspendue (or chaud)
    rect(img, 15, 19, 1, 3, P["earth4"])
    rect(img, 14, 22, 3, 3, P["sun1"])
    put(img, [(15, 23)], P["sun0"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=24, ry=3)


def feu_camp():
    img = canvas(18, 14)
    for a in range(0, 360, 40):                             # cercle de pierres
        x, y = 9 + math.cos(math.radians(a)) * 7, 10 + math.sin(math.radians(a)) * 3
        blob(img, x, y, 1.6, 1.3, [P["stone1"], P["stone2"], P["stone3"]], seed=a, jitter=0)
    line(img, 5, 10, 13, 8, P["earth3"], w=2)               # bûches croisées
    line(img, 5, 8, 13, 10, P["earth2"], w=2)
    put(img, [(8, 7), (9, 6), (10, 7), (9, 7), (8, 8), (10, 8)], P["sun2"])
    put(img, [(9, 4), (9, 5), (8, 6), (10, 6), (11, 5)], P["sun1"])
    put(img, [(9, 3), (9, 6)], P["sun0"])
    put(img, [(7, 8), (11, 8)], P["red0"])
    sb.outline(img)
    return img


def panneau():
    """Poteau indicateur à l'entrée du sentier : deux flèches de bois (sans texte)."""
    img = canvas(22, 28)
    rect(img, 10, 4, 3, 23, P["earth3"])
    rect(img, 10, 4, 1, 23, P["earth2"])
    # flèche vers le haut-droite (forêt), flèche vers le bas-gauche (village)
    rect(img, 6, 7, 13, 5, P["earth1"])
    put(img, [(19, 8), (19, 9), (19, 10), (20, 9)], P["earth1"])
    rect(img, 6, 11, 13, 1, P["earth2"])
    rect(img, 3, 15, 13, 5, P["earth1"])
    put(img, [(2, 16), (2, 17), (2, 18), (1, 17)], P["earth1"])
    rect(img, 3, 19, 13, 1, P["earth2"])
    for x in range(8, 17, 2):                               # gravure (pas de texte lisible)
        put(img, [(x, 9)], P["earth2"])
    for x in range(5, 14, 2):
        put(img, [(x, 17)], P["earth2"])
    put(img, [(8, 7), (13, 7)], P["leaf2"])                 # lierre
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=5, ry=1.6)


def brume():
    """Nappe de brume dorée (texture de particule, alpha doux et tramé)."""
    W, H = 48, 20
    img = canvas(W, H)
    px = img.load()
    base = P["sun0"][:3]
    for y in range(H):
        for x in range(W):
            d = ((x + 0.5 - W / 2) / (W / 2)) ** 2 + ((y + 0.5 - H / 2) / (H / 2)) ** 2
            if d < 1:
                a = (1 - d) ** 1.5
                lv = 3 if a > 0.6 else 2 if a > 0.3 else 1 if a > 0.1 else 0
                if lv and not (lv == 1 and (x + y) % 2):
                    px[x, y] = base + ((0, 40, 70, 100)[lv],)
    return img


ALL = {
    "characters/npcs/aurin_ermite_idle": aurin,
    "props/ressources/mousse_lumineuse": mousse_lumineuse,
    "props/ressources/champignons_lisiere": champignons,
    "props/ressources/racine_doree": racine_doree,
    "props/ressources/bois_mort_de_lisiere": bois_mort,
    "props/ressources/pierres_taillees_enfouies": pierres_taillees,
    "props/ressources/terriers_de_lapins": terriers,
    "props/foret/fougere_a": lambda: fougere(1),
    "props/foret/fougere_b": lambda: fougere(2),
    "props/foret/fougere_c": lambda: fougere(3),
    "props/foret/souche": souche,
    "props/foret/tronc_couche": tronc_couche,
    "props/foret/champignons_deco": champignons_deco,
    "props/foret/chene_ancien": chene_ancien,
    "props/foret/auvent_aurin": auvent_aurin,
    "props/foret/feu_camp": feu_camp,
    "props/foret/panneau": panneau,
    "fx/brume": brume,
}


def contact_sheet(out):
    imgs = [(k, fn()) for k, fn in ALL.items()]
    cols, cell = 6, 96
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), P["leaf2"])
    for i, (k, im) in enumerate(imgs):
        if k.startswith(("monsters", "characters")):     # bande d'animation : première image
            im = im.crop((0, 0, im.width // 4, im.height))
        s = 3 if im.width <= 30 else 2 if im.width <= 50 else 1
        im = im.resize((im.width * s, im.height * s), Image.NEAREST)
        x = (i % cols) * cell + (cell - im.width) // 2
        y = (i // cols) * cell + (cell - im.height) // 2
        sheet.alpha_composite(im, (max(0, x), max(0, y)))
    sheet.save(out)


def main(standalone=True):
    for rel, fn in ALL.items():
        sb.save(fn(), f"{rel}.png")
    import fauna                    # faune v2 (lore : lumière d'aube, yeux pâles, motif du mécanisme)
    fauna.main()
    contact_sheet(sb.PREVIEW / "lisiere_assets.png")
    if standalone:
        print("OK -", len(ALL), "assets lisière")


if __name__ == "__main__":
    main()
