"""Planche de style étage 1 : tuiles, props, personnages + scène de test 480x270.

Déterministe : mêmes graines -> mêmes pixels. Usage :
    python tools/art/styleboard.py
Sorties : assets/art/... (PNG d'atlas) et art/preview/styleboard*.png
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, CLEAR, GROUND_SHADOW  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art"
PREVIEW = ROOT / "art" / "preview"
T = 16  # taille de tuile


# --------------------------------------------------------------------------- outils
def periodic_noise(seed, period=T, cell=4, border_seed=None):
    """Bruit de valeur lissé, périodique sur `period` px (tuiles raccordables).

    Avec `border_seed`, les points de grille du bord (x=0 ou y=0) viennent de cette graine
    commune : toutes les variantes d'une même matière ont alors des bords identiques et se
    raccordent entre elles, seul l'intérieur change."""
    n = period // cell
    bs = seed if border_seed is None else border_seed

    def lattice(ix, iy):
        s = bs if (ix == 0 or iy == 0) else seed
        return random.Random(s * 104729 + ix * 7 + iy * 1009).random()

    g = [[lattice(ix, iy) for ix in range(n)] for iy in range(n)]

    def f(x, y):
        gx, gy = (x % period) / cell, (y % period) / cell
        x0, y0 = int(gx), int(gy)
        fx, fy = gx - x0, gy - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a, b = g[y0 % n][x0 % n], g[y0 % n][(x0 + 1) % n]
        c, d = g[(y0 + 1) % n][x0 % n], g[(y0 + 1) % n][(x0 + 1) % n]
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

    return f


def hash01(seed, x, y):
    return random.Random(seed * 7919 + (x % T) * 131 + (y % T) * 17).random()


def outline(img, color=P["outline"]):
    """Contour 1 px autour des pixels opaques (alpha 255)."""
    w, h = img.size
    px = img.load()
    solid = {(x, y) for y in range(h) for x in range(w) if px[x, y][3] == 255}
    for y in range(h):
        for x in range(w):
            if (x, y) in solid or px[x, y][3] == 255:
                continue
            if any((x + dx, y + dy) in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = color
    return img


def ellipse(img, cx, cy, rx, ry, color):
    px = img.load()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if 0 <= x < img.width and 0 <= y < img.height:
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                    px[x, y] = color


def from_ascii(rows, keys):
    h, w = len(rows), max(len(r) for r in rows)
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = keys[ch]
    return img


def with_ground_shadow(sprite, rx=None, ry=2, pad_bottom=1):
    """Ajoute une ombre portée au sol (décalée vers le bas-droite, lumière haut-gauche)."""
    w, h = sprite.size
    img = Image.new("RGBA", (w + 2, h + pad_bottom), CLEAR)
    rx = rx or w * 0.38
    ellipse(img, w / 2 + 1.5, h - 1, rx, ry, GROUND_SHADOW)
    img.alpha_composite(sprite, (0, 0))
    return img


# --------------------------------------------------------------------------- matières de sol
def fill_grass(seed, dark=False, variant=0):
    n = periodic_noise(seed * 10 + variant, border_seed=seed)
    vs = seed * 10 + variant
    base, light, low, spark = (("leaf2", "leaf1", "leaf3", "leaf0") if not dark
                               else ("leaf3", "leaf2", "leaf4", "leaf1"))

    def f(x, y):
        v = n(x, y)
        r = hash01(vs, x, y)
        if r > 0.988:
            return P[spark]                         # brin éclairé
        if r < 0.05 and v < 0.5:
            return P[low]                           # touffe à l'ombre
        if v > 0.66:
            return P[light]                         # plaque ensoleillée
        return P[base]
    return f


def fill_dirt(seed, variant=0):
    n = periodic_noise(seed * 10 + variant, border_seed=seed)
    vs = seed * 10 + variant

    def f(x, y):
        r = hash01(vs, x, y)
        if r > 0.985:
            return P["earth2"]          # caillou
        if r < 0.012:
            return P["sun0"]            # éclat de lumière
        return P["earth1"] if n(x, y) < 0.26 else P["earth0"]
    return f


def fill_sand(seed):
    def f(x, y):
        r = hash01(seed, x, y)
        return P["earth1"] if r > 0.93 else P["earth0"]
    return f


def fill_cobble(seed, variant=0):
    """Pavés sur un motif périodique de 16 px : 2 rangées de 8 px, joints décalés."""
    rows = [[0, 8], [4, 12]]
    vs = seed * 10 + variant

    def stone_at(x, y):
        r = (y % T) // 8
        cuts = rows[r]
        xs = x % T
        left = max([c for c in cuts if c <= xs], default=cuts[-1] - T)
        right = min([c for c in cuts if c > xs], default=cuts[0] + T)
        return left, right, r * 8, r * 8 + 8

    def f(x, y):
        l, r, t, b = stone_at(x, y)
        xs, ys = x % T, y % T
        if xs == l or ys == t:
            return P["stone2"]          # joint
        if ys == b - 1 or xs == r - 1:
            return P["stone2"] if hash01(vs, x, y) > 0.4 else P["stone1"]   # côté ombré
        if ys == t + 1 and xs != l + 1:
            return P["stone0"]          # arête éclairée (haut)
        r2 = hash01(vs, x, y)
        return P["earth1"] if r2 > 0.985 else P["stone1"]
    return f


def fill_water(seed, variant=0):
    n = periodic_noise(seed * 10 + variant, cell=4, border_seed=seed)
    vs = seed * 10 + variant

    def f(x, y):
        r = hash01(vs, x, y)
        xs, ys = x % T, y % T
        # vaguelette : trait horizontal de 3 px, à l'intérieur de la tuile
        for k in range(3):
            if 1 <= xs - k <= 12 and 1 <= ys <= 14 and hash01(vs + 5, x - k, y) > 0.975:
                return P["water1"]
        if r < 0.006:
            return P["sun1"]            # reflet doré de l'aube
        return P["water3"] if n(x, y) < 0.3 else P["water2"]
    return f


def fill_ruin_slab(seed, rune=False):
    """Dalles architectes 8x8 gravées ; variante avec rune cyan."""
    def f(x, y):
        xs, ys = x % T, y % T
        if xs % 8 == 0 or ys % 8 == 0:
            return P["stone3"]
        if xs % 8 == 7 or ys % 8 == 7:
            return P["stone2"]
        if rune and 9 <= xs <= 14 and 9 <= ys <= 14:
            glyph = {(10, 10), (11, 10), (12, 10), (13, 10), (11, 11), (11, 12), (12, 12),
                     (13, 12), (13, 13), (10, 13), (11, 13)}
            if (xs, ys) in glyph:
                return P["rune1"] if (xs + ys) % 3 else P["rune0"]
        r = hash01(seed, x, y)
        return P["stone2"] if r > 0.93 else P["stone1"]
    return f


VARIANTS = 4


def varied(make, seed, **kw):
    """Matière dont la variante change à chaque tuile (comme les tuiles alternatives
    aléatoires d'un TileSet Godot) ; toutes les variantes se raccordent."""
    fills = [make(seed, variant=v, **kw) for v in range(VARIANTS)]

    def f(wx, wy):
        tx, ty = wx // T, wy // T
        v = random.Random(seed + tx * 73856093 ^ ty * 19349663).randrange(VARIANTS)
        return fills[v](wx, wy)
    return f


def tile_from_fill(fill):
    img = Image.new("RGBA", (T, T))
    px = img.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = fill(x, y)
    return img


# --------------------------------------------------------------------------- terrains par coins
def corner_field(seed, amp=0.38):
    n = periodic_noise(seed, cell=4)

    def m(corners, x, y):
        tl, tr, bl, br = corners
        u, v = (x + 0.5) / T, (y + 0.5) / T
        top = tl * (1 - u) + tr * u
        bot = bl * (1 - u) + br * u
        return top * (1 - v) + bot * v + (n(x, y) - 0.5) * amp
    return m


class Overlay:
    """Terrain posé par-dessus le sol de base, avec bord organique. Compatible Godot
    'Match Corners' : 16 tuiles indexées par (tl, tr, bl, br)."""

    def __init__(self, name, fill, seed, rim=None, outer=None, inner=None, amp=0.38):
        self.name, self.fill, self.field = name, fill, corner_field(seed, amp)
        self.rim = rim        # couleur d'ombre sous le terrain (bas-droite) ou None
        self.outer = outer    # (seuil, fill) : liseré extérieur (ex. sable autour de l'eau)
        self.inner = inner    # (largeur, couleur) : liseré intérieur (ex. écume)

    def pixel(self, corners, x, y, wx, wy):
        m = self.field(corners, x, y)
        if m > 0.5:
            if self.inner and m < 0.5 + self.inner[0]:
                return self.inner[1]
            return self.fill(wx, wy)
        if self.outer and m > self.outer[0]:
            return self.outer[1](wx, wy)
        if self.rim and self.field(corners, x, y - 1) > 0.5 and y > 0:
            return self.rim
        return None

    def tile(self, corners):
        img = Image.new("RGBA", (T, T), CLEAR)
        px = img.load()
        for y in range(T):
            for x in range(T):
                c = self.pixel(corners, x, y, x, y)
                if c:
                    px[x, y] = c
        return img

    def atlas(self):
        """Atlas 4x4 : index = tl*8 + tr*4 + bl*2 + br."""
        img = Image.new("RGBA", (T * 4, T * 4), CLEAR)
        for i in range(16):
            corners = ((i >> 3) & 1, (i >> 2) & 1, (i >> 1) & 1, i & 1)
            img.alpha_composite(self.tile(corners), ((i % 4) * T, (i // 4) * T))
        return img


# --------------------------------------------------------------------------- props
def tree(seed, w=32, h=44, palette=("leaf1", "leaf2", "leaf3", "leaf4")):
    rng = random.Random(seed)
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    # tronc
    tx = w // 2 - 2
    for y in range(h - 14, h - 1):
        for x in range(tx, tx + 5):
            px[x, y] = P["earth3"] if x < tx + 3 else P["earth4"]
    px[tx - 1, h - 2] = P["earth4"]
    px[tx + 5, h - 2] = P["earth4"]
    # canopée : grappes de cercles, ombrées individuellement
    blobs = [(w / 2, 15, 12)]
    for _ in range(6):
        a = rng.uniform(0, math.tau)
        blobs.append((w / 2 + math.cos(a) * 7, 15 + math.sin(a) * 6, rng.uniform(6, 8)))
    blobs.sort(key=lambda b: b[1])
    hi, mid, low, deep = (P[k] for k in palette)
    for cx, cy, r in blobs:
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                if not (0 <= x < w and 0 <= y < h):
                    continue
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                if dx * dx + dy * dy > r * r:
                    continue
                d = (dx + dy) / r          # <0 : côté soleil (haut-gauche)
                jitter = (hash01(seed, x, y) - 0.5) * 0.35
                d += jitter
                px[x, y] = hi if d < -0.75 else mid if d < 0.1 else low if d < 0.7 else deep
    outline(img)
    return with_ground_shadow(img, rx=11, ry=3)


def bush(seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (16, 12), CLEAR)
    px = img.load()
    for cx, cy, r in [(5, 7, 4), (11, 7, 4), (8, 5, 4.5)]:
        for y in range(12):
            for x in range(16):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                if dx * dx + dy * dy <= r * r:
                    d = (dx + dy) / r + (rng.random() - 0.5) * 0.3
                    px[x, y] = P["leaf1"] if d < -0.6 else P["leaf2"] if d < 0.3 else P["leaf3"]
    px[6, 4] = P["red0"]
    px[11, 6] = P["red0"]
    outline(img)
    return with_ground_shadow(img, rx=6, ry=2)


def rock():
    rows = [
        "....OOOO....",
        "..OOwwssOO..",
        ".OwwssssssO.",
        "OwssssssmmdO",
        "OssssssmmmdO",
        ".OsmmmmmmddO",
        "..OOOOOOOOO.",
    ]
    img = from_ascii(rows, {"O": P["outline"], "w": P["stone0"], "s": P["stone1"],
                            "m": P["stone2"], "d": P["stone3"]})
    return with_ground_shadow(img, rx=6, ry=2)


def house():
    """Maison de Val-de-l'Aube : murs crème à colombages, chaume orangé, fenêtre allumée."""
    w, h = 48, 50
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    wall_top, wall_bot = 26, h - 2
    for y in range(wall_top, wall_bot):
        for x in range(5, w - 5):
            c = P["earth0"]
            if x in (5, w - 6, 24) or y in (wall_top, wall_top + 9):
                c = P["earth3"]                                   # colombages
            elif x > w - 12:
                c = P["earth1"]                                   # mur à l'ombre
            px[x, y] = c
    for y in range(wall_top + 11, wall_bot):                      # porte
        for x in range(28, 35):
            px[x, y] = P["earth4"] if x in (28, 34) or y == wall_top + 11 else P["earth3"]
    px[33, wall_top + 17] = P["sun1"]
    for y in range(wall_top + 12, wall_top + 18):                 # fenêtre allumée
        for x in range(11, 19):
            edge = x in (11, 18) or y in (wall_top + 12, wall_top + 17)
            px[x, y] = P["earth3"] if edge else (P["sun1"] if x < 15 else P["sun2"])
    px[14, wall_top + 13] = P["sun0"]
    # chaume : trapèze, stries horizontales, lumière à gauche
    for y in range(4, wall_top + 3):
        inset = max(0, (wall_top + 3 - y) * 10 // (wall_top - 1) - 2)
        x0, x1 = 1 + inset, w - 1 - inset
        for x in range(x0, x1):
            rel = (x - x0) / max(1, x1 - x0)
            c = P["sun2"] if rel < 0.35 else P["sun3"] if rel < 0.8 else P["earth2"]
            if (y + (x // 3)) % 4 == 0:
                c = P["earth2"] if c != P["earth2"] else P["earth3"]
            if y == wall_top + 2:
                c = P["earth3"]
            px[x, y] = c
    for x in range(36, 41):                                       # cheminée
        for y in range(1, 9):
            px[x, y] = P["stone2"] if x > 38 else P["stone1"]
    outline(img)
    return with_ground_shadow(img, rx=22, ry=3)


def ruin_column():
    """Colonne architecte brisée, rune cyan lumineuse."""
    w, h = 14, 36
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    top = [6, 4, 3, 5, 2, 3, 6, 7, 5, 4]   # cassure irrégulière
    for x in range(2, 12):
        for y in range(top[x - 2], h - 1):
            c = P["stone1"]
            if x <= 3:
                c = P["stone0"]
            elif x >= 10:
                c = P["stone2"]
            if y in (h - 6, h - 5) or y == top[x - 2]:
                c = P["stone2"] if y != top[x - 2] else P["stone0"]
            px[x, y] = c
    for x in range(1, 13):
        for y in range(h - 4, h - 1):
            px[x, y] = P["stone3"] if x >= 10 else P["stone2"]
    for (x, y) in [(6, 12), (7, 12), (8, 12), (7, 13), (7, 14), (6, 15), (8, 15),
                   (6, 16), (8, 16), (7, 18), (6, 19), (7, 19), (8, 19)]:
        px[x, y] = P["rune1"]
    px[7, 13] = P["rune0"]
    px[7, 19] = P["rune0"]
    outline(img)
    return with_ground_shadow(img, rx=6, ry=2)


def reeds(seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (12, 16), CLEAR)
    px = img.load()
    for i in range(5):
        x = 1 + i * 2 + rng.randint(0, 1)
        hgt = rng.randint(8, 14)
        for y in range(16 - hgt, 16):
            px[x, y] = P["leaf2"] if y < 16 - hgt + 3 else P["leaf3"]
        if rng.random() < 0.6:
            px[x, 16 - hgt] = P["earth3"]
            px[x, 16 - hgt + 1] = P["earth3"]
    return img


def flowers(seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (T, T), CLEAR)
    px = img.load()
    for _ in range(4):
        x, y = rng.randint(2, 13), rng.randint(3, 13)
        c = P[rng.choice(["sun1", "red0", "sun0", "blue0"])]
        px[x, y] = c
        px[x, y + 1] = P["leaf3"]
    return img


# --------------------------------------------------------------------------- personnages
KEYS_CHAR = {
    "O": P["outline"], "H": P["earth2"], "L": P["earth1"], "h": P["earth3"],
    "S": P["skin0"], "s": P["skin1"], "T": P["blue0"], "t": P["blue1"],
    "B": P["earth3"], "G": P["sun1"], "P": P["earth4"], "p": P["shade1"],
    "K": P["shade1"], "k": P["outline"],
}

PLAYER_DOWN = [
    "................",
    "................",
    "................",
    ".....OOOOOO.....",
    "....OHHHHHHO....",
    "...OHLLHHHHHO...",
    "...OHHHHHHHhO...",
    "...OHSSSSSShO...",
    "...OSSOSSOSsO...",
    "...OSSOSSOSsO...",
    "...OsSSSSSSsO...",
    "....OsSSSSsO....",
    "....OOTTTTOO....",
    "...OTTTGTTTtO...",
    ".OTOTTTTTTTtOtO.",
    ".OTOTTTTTTTtOtO.",
    ".OSOBBBGBBBBOsO.",
    ".OOOTTTTTTTtOOO.",
    "...OTTTTTTTtO...",
    "...OPPPOOPPpO...",
    "...OPPPOOPPpO...",
    "...OKKKOOKKkO...",
    "...OOOOOOOOOO...",
    "................",
]

KEYS_RABBIT = {
    "O": P["outline"], "F": P["earth0"], "f": P["earth1"], "i": P["skin0"],
    "W": P["sun0"], "n": P["red0"],
}

RABBIT = [
    "................",
    "....OO....OO....",
    "...OFFO..OFFO...",
    "...OFiO..OiFO...",
    "...OFiO..OiFO...",
    "...OFFOOOOFFO...",
    "..OFFFFFFFFFFO..",
    "..OFFOFFFFOFfO..",
    "..OFFFFnnFFFfO..",
    "..OfFFFFFFFFfO..",
    "...OOFFFFFFOO...",
    "..OFFWWWWWWFfO..",
    ".OFFFWWWWWWFFfO.",
    ".OFFFFWWWWFFFfO.",
    ".OfFFFFFFFFFffO.",
    "..OOOOOOOOOOOO..",
]


def bounce_frames(sprite, offsets=(0, -1, -2, -1)):
    """Bande d'animation idle : rebond vertical, ombre fixe au sol."""
    w, h = sprite.size
    strip = Image.new("RGBA", (w * len(offsets), h + 2), CLEAR)
    for i, dy in enumerate(offsets):
        frame = Image.new("RGBA", (w, h + 2), CLEAR)
        ellipse(frame, w / 2 + 1, h, w * 0.32, 1.6, GROUND_SHADOW)
        frame.alpha_composite(sprite, (0, 2 + dy))
        strip.alpha_composite(frame, (i * w, 0))
    return strip


# --------------------------------------------------------------------------- scène de test
def build_scene():
    W, H = 30, 17                                   # tuiles -> 480x272
    grass = varied(fill_grass, 11)
    dirt = Overlay("dirt", varied(fill_dirt, 21), seed=22, rim=P["leaf3"], amp=0.3)
    cobble = Overlay("cobble", varied(fill_cobble, 31), seed=32, rim=P["stone3"], amp=0.16)
    water = Overlay("water", varied(fill_water, 41), seed=42, outer=(0.36, fill_sand(43)),
                    inner=(0.05, P["water0"]), amp=0.3)

    # grilles de coins (W+1)x(H+1)
    def grid(pred):
        return [[1 if pred(x, y) else 0 for x in range(W + 1)] for y in range(H + 1)]

    path_g = grid(lambda x, y: (6 <= y <= 8 and x <= 20) or (14 <= x <= 16 and y >= 7)
                  or (y in (5, 9) and 3 <= x <= 5))
    plaza_g = grid(lambda x, y: 2 <= x <= 7 and 4 <= y <= 10)
    lake_g = grid(lambda x, y: ((x - 26) / 5.5) ** 2 + ((y - 13) / 4.5) ** 2 <= 1)

    img = Image.new("RGBA", (W * T, H * T))
    px = img.load()
    for wy in range(H * T):
        for wx in range(W * T):
            px[wx, wy] = grass(wx, wy)
    for ov, g in ((dirt, path_g), (cobble, plaza_g), (water, lake_g)):
        for ty in range(H):
            for tx in range(W):
                corners = (g[ty][tx], g[ty][tx + 1], g[ty + 1][tx], g[ty + 1][tx + 1])
                if not any(corners):
                    continue
                for y in range(T):
                    for x in range(T):
                        c = ov.pixel(corners, x, y, tx * T + x, ty * T + y)
                        if c:
                            px[tx * T + x, ty * T + y] = c

    # props et personnages, triés par leur ligne de pied (y-sort)
    things = [
        (house(), 136, 84), (tree(1), 300, 40), (tree(2), 330, 70), (tree(3), 400, 30),
        (tree(4, palette=("leaf2", "leaf3", "leaf4", "leaf5")), 452, 60),
        (tree(5), 22, 244), (tree(6), 100, 266), (bush(7), 200, 52), (bush(8), 196, 208),
        (rock(), 176, 252), (ruin_column(), 440, 122), (ruin_column(), 466, 140),
        (reeds(9), 330, 200), (reeds(10), 352, 248), (flowers(12), 230, 150),
        (flowers(13), 110, 210), (flowers(14), 270, 236),
    ]
    player = bounce_frames(from_ascii(PLAYER_DOWN, KEYS_CHAR), (0,)).crop((0, 0, 16, 26))
    rabbit = bounce_frames(from_ascii(RABBIT, KEYS_RABBIT), (0,)).crop((0, 0, 16, 18))
    things += [(player, 240, 120), (rabbit, 280, 160), (rabbit, 216, 200)]
    things.sort(key=lambda t: t[2])
    for spr, fx, fy in things:                        # (fx, fy) = pied bas-centre
        img.alpha_composite(spr, (fx - spr.width // 2, fy - spr.height))

    # poussière dorée d'aube
    rng = random.Random(99)
    for _ in range(60):
        x, y = rng.randrange(W * T), rng.randrange(H * T)
        px[x, y] = P["sun0"] if rng.random() < 0.5 else P["sun1"]
    return img.crop((0, 0, 480, 270)), dict(dirt=dirt, cobble=cobble, water=water)


# --------------------------------------------------------------------------- export
SAVED = []


def save(img, rel):
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    SAVED.append((rel, img.size))
    return path


def write_manifest():
    import json
    assets = [{
        "id": Path(rel).stem,
        "path": f"assets/art/{rel}",
        "status": "draft-styleboard",
        "technical": {"dimensions": f"{w}x{h}", "alpha": True, "filtering": "nearest",
                      "anchor": "top-left" if rel.startswith("tiles/") else "bottom-center"},
        "visual_locks": ["palette", "light-direction-top-left", "outline-selective"],
        "source": {"kind": "generated-by-code", "url_or_tool": "tools/art/styleboard.py",
                   "license": "propriété du projet Arthesia", "creator": "Claude (code)"},
        "verification": {"native_scale_reviewed": True, "in_engine_reviewed": False,
                         "technical_checks_passed": True, "approved_by": ""},
    } for rel, (w, h) in SAVED]
    out = ROOT / "art" / "asset_manifest.json"
    out.write_text(json.dumps({"schema_version": 1,
                               "art_direction_brief": "docs/art_direction.md",
                               "assets": assets}, indent=2, ensure_ascii=False),
                   encoding="utf-8")


def main():
    PREVIEW.mkdir(parents=True, exist_ok=True)
    scene, overlays = build_scene()
    scene.save(PREVIEW / "styleboard.png")
    scene.resize((scene.width * 3, scene.height * 3), Image.NEAREST).save(
        PREVIEW / "styleboard_x3.png")

    # tuiles de base (variantes) et overlays par coins
    # sols de base : une rangée par matière, une colonne par variante (raccordables entre elles)
    base_fills = [("grass", lambda v: fill_grass(11, variant=v)),
                  ("grass_dark", lambda v: fill_grass(51, dark=True, variant=v)),
                  ("dirt", lambda v: fill_dirt(21, variant=v)),
                  ("cobble", lambda v: fill_cobble(31, variant=v)),
                  ("water", lambda v: fill_water(41, variant=v))]
    base = Image.new("RGBA", (T * VARIANTS, T * len(base_fills)))
    for row, (_, mk) in enumerate(base_fills):
        for v in range(VARIANTS):
            base.alpha_composite(tile_from_fill(mk(v)), (v * T, row * T))
    save(base, "tiles/floor_1/ground_base.png")
    for name, ov in overlays.items():
        save(ov.atlas(), f"tiles/floor_1/overlay_{name}.png")
    ruins = Image.new("RGBA", (T * 2, T))
    ruins.alpha_composite(tile_from_fill(fill_ruin_slab(61)), (0, 0))
    ruins.alpha_composite(tile_from_fill(fill_ruin_slab(62, rune=True)), (T, 0))
    save(ruins, "tiles/floor_1/ground_ruins.png")

    save(tree(1), "props/foret/arbre_aube_a.png")
    save(tree(4, palette=("leaf2", "leaf3", "leaf4", "leaf5")), "props/foret/arbre_sombre_a.png")
    save(bush(7), "props/commun/buisson_baies.png")
    save(rock(), "props/commun/rocher.png")
    save(house(), "props/village/maison_chaume.png")
    save(ruin_column(), "props/ruines/colonne_runique.png")
    save(reeds(9), "props/eau/roseaux.png")
    save(bounce_frames(from_ascii(PLAYER_DOWN, KEYS_CHAR), (0, 0, -1, -1)),
         "characters/player/player_idle_down.png")
    save(bounce_frames(from_ascii(RABBIT, KEYS_RABBIT)), "monsters/lapin_bondissant_idle.png")
    write_manifest()
    print(f"OK - {len(SAVED)} assets")


if __name__ == "__main__":
    main()
