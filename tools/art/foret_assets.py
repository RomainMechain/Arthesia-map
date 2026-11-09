"""Assets de la Forêt des Anciens (étage 1, niv. 4-6) : voûte d'arbres anciens, sous-bois clairs, mer de
fougères dorées, cercle de pierres moussues aux motifs géométriques (cyan à peine visible : les
Architectes), chênes morts aux branches trop droites, camp d'Isarn, chemin des ours, ressources.

Même palette, lumière haut-gauche, contour sélectif. Plus sombre que la Lisière : la lumière ne tombe
que par touches dorées. Usage : python tools/art/foret_assets.py
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P  # noqa: E402
import styleboard as sb  # noqa: E402
from lisiere_assets import canvas, blob, rect, put, line  # noqa: E402

O = P["outline"]


# --------------------------------------------------------------------------- arbres
def trunk(img, cx, base, top, half_top, half_base, seed, moss=True):
    """Tronc noueux qui s'évase en contreforts ; mousse sur le côté nord (haut-gauche)."""
    for y in range(top, base):
        t = (y - top) / max(1, base - top)
        half = half_top + (half_base - half_top) * t ** 2.5
        for x in range(int(cx - half), int(cx + half) + 1):
            rel = (x - (cx - half)) / max(1.0, 2 * half)
            c = P["earth2"] if rel < 0.28 else P["earth3"] if rel < 0.72 else P["earth4"]
            if sb.hash01(seed, x, y // 3) < 0.12:
                c = P["earth4"]                               # sillons de l'écorce
            if moss and rel < 0.35 and sb.hash01(seed + 1, x, y // 2) < 0.35:
                c = P["leaf3"] if sb.hash01(seed + 2, x, y) < 0.6 else P["leaf2"]
            img.putpixel((x, y), c)


def roots(img, cx, base, spread, seed, n=4):
    rng = random.Random(seed)
    for k in range(n):
        side = -1 if k % 2 == 0 else 1
        x0 = cx + side * rng.uniform(2, 5)
        line(img, x0, base - 5, x0 + side * spread * rng.uniform(0.6, 1.0), base - 1, P["earth3"], w=2)
        put(img, [(round(x0 + side * 2), base - 4)], P["earth2"])


def canopy(img, cx, cy, r, seed, ramp, n=10, light_seed=None):
    rng = random.Random(seed)
    blobs = [(cx, cy, r)]
    for _ in range(n):
        a = rng.uniform(math.pi * 0.85, math.pi * 2.15)
        blobs.append((cx + math.cos(a) * r * 0.8, cy + math.sin(a) * r * 0.55, r * rng.uniform(0.42, 0.6)))
    blobs += [(cx - r * 0.9, cy + r * 0.5, r * 0.45), (cx + r * 0.9, cy + r * 0.5, r * 0.45), (cx, cy + r * 0.7, r * 0.5)]
    blobs.sort(key=lambda b: b[1])
    for i, (bx, by, br) in enumerate(blobs):
        blob(img, bx, by, br, br * 0.9, ramp, seed=seed * 7 + i, jitter=0.4)
    px = img.load()
    ls = light_seed or seed
    for y in range(max(0, int(cy - r)), int(cy)):                # rares touches d'aube filtrée
        for x in range(max(0, int(cx - r)), min(img.width, int(cx + r))):
            if px[x, y][3] and px[x, y] == ramp[0] and sb.hash01(ls, x, y) < 0.18:
                px[x, y] = P["leaf1"] if sb.hash01(ls + 1, x, y) < 0.75 else P["sun1"]


DARK = [P["leaf3"], P["leaf4"], P["leaf4"], P["leaf5"]]


def arbre_ancien(seed, W=52, H=70):
    img = canvas(W, H)
    trunk(img, W // 2, H - 3, H - 34, 4, 9, seed)
    roots(img, W // 2, H - 1, 12, seed)
    canopy(img, W / 2, 24, 20, seed, DARK)
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=18, ry=3)


def arbre_geant():
    W, H = 84, 112
    img = canvas(W, H)
    trunk(img, W // 2, H - 3, H - 52, 7, 15, 301)
    roots(img, W // 2, H - 1, 20, 301, n=6)
    canopy(img, W / 2, 34, 32, 302, DARK, n=16)
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=30, ry=4)


def chene_mort(seed):
    """Chêne mort : gris, sans feuilles, branches trop droites (angles nets)."""
    rng = random.Random(seed)
    W, H = 44, 60
    img = canvas(W, H)
    grey = (P["stone2"], P["stone3"], P["stone4"])
    for y in range(18, H - 3):
        t = (y - 18) / (H - 21)
        half = 3 + 4 * t ** 2.5
        for x in range(int(W / 2 - half), int(W / 2 + half) + 1):
            rel = (x - (W / 2 - half)) / (2 * half)
            img.putpixel((x, y), grey[0] if rel < 0.3 else grey[1] if rel < 0.75 else grey[2])
    for k in range(5):                                        # branches : segments droits, angles à 45°
        y0 = rng.randint(14, 34)
        side = -1 if k % 2 else 1
        L = rng.randint(8, 14)
        x1, y1 = W / 2 + side * L, y0 - L
        line(img, W / 2, y0 + 4, x1, y1, grey[1], w=2)
        line(img, x1, y1, x1, y1 - rng.randint(4, 8), grey[1], w=1)
    line(img, W / 2, 18, W / 2, 4, grey[1], w=2)
    roots(img, W // 2, H - 1, 9, seed)
    for y in (30, 38):                                        # une ligne trop droite dans l'écorce
        put(img, [(W // 2 - 1, y), (W // 2, y), (W // 2 + 1, y)], P["rune2"] if seed % 2 else P["stone4"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=12, ry=2)


# --------------------------------------------------------------------------- sol, décor
def fougere_haute(seed):
    rng = random.Random(seed)
    img = canvas(24, 24)
    base = (12, 23)
    for k in range(9):
        a = math.radians(205 + k * 16 + rng.uniform(-6, 6))
        L = rng.uniform(11, 15)
        x1, y1 = base[0] + math.cos(a) * L, base[1] + math.sin(a) * L * 1.3
        col = [P["sun3"], P["leaf2"], P["sun2"]][k % 3]
        line(img, base[0], base[1] - 1, x1, y1, col)
        for t in (0.35, 0.55, 0.75):
            fx, fy = base[0] + (x1 - base[0]) * t, base[1] - 1 + (y1 - base[1] + 1) * t
            put(img, [(round(fx) + (1 if x1 > base[0] else -1), round(fy))], P["sun1"] if fy < 10 else col)
        put(img, [(round(x1), round(y1))], P["sun0"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=8, ry=2)


def racines():
    img = canvas(34, 12)
    for x0, x1, y in ((2, 16, 6), (10, 30, 8), (20, 33, 5)):
        line(img, x0, y, x1, y + 2, P["earth3"], w=2)
        line(img, x0, y - 1, x1, y + 1, P["earth2"], w=1)
    sb.outline(img)
    return img


def pierre_moussue(seed, lines=True):
    img = canvas(20, 16)
    blob(img, 10, 9, 8, 6, [P["stone1"], P["stone2"], P["stone3"]], seed=seed, jitter=0.15)
    blob(img, 8, 6, 6, 3, [P["leaf2"], P["leaf3"], P["leaf4"]], seed=seed + 1, jitter=0.35)   # mousse
    if lines:                                                 # motifs trop réguliers
        line(img, 6, 11, 14, 11, P["stone3"])
        put(img, [(10, 10), (10, 12)], P["rune2"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=8, ry=1.5)


def pierre_cercle(seed):
    """Pierre levée du cercle : moussue, une ligne droite et un cercle gravés, cyan presque éteint."""
    img = canvas(18, 26)
    rect(img, 4, 4, 10, 20, P["stone2"])
    rect(img, 4, 4, 3, 20, P["stone1"])
    rect(img, 12, 4, 2, 20, P["stone3"])
    rect(img, 5, 3, 8, 1, P["stone1"])
    blob(img, 8, 5, 5, 3, [P["leaf2"], P["leaf3"], P["leaf4"]], seed=seed, jitter=0.4)
    line(img, 7, 10, 7, 20, P["rune2"])
    for a in range(10):
        put(img, [(round(10 + math.cos(a * 0.63) * 2), round(15 + math.sin(a * 0.63) * 2))], P["rune2"])
    put(img, [(10, 15)], P["rune1"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=7, ry=1.5)


def terre_retournee():
    img = canvas(22, 10)
    for k in range(5):
        blob(img, 4 + k * 3.5, 5 + (k % 2), 3.2, 2, [P["earth2"], P["earth3"], P["earth4"]], seed=500 + k, jitter=0.3)
    return img


def ossements():
    img = canvas(20, 9)
    line(img, 2, 6, 12, 4, P["stone0"], w=2)
    put(img, [(1, 5), (1, 7), (13, 3), (13, 5)], P["stone0"])
    blob(img, 16, 5, 3, 2.5, [P["stone0"], P["stone1"], P["stone2"]], seed=511, jitter=0)
    put(img, [(15, 5), (17, 5)], O)
    sb.outline(img)
    return img


def tente():
    """Tente d'Isarn : toile tendue sur une perche, rabat ouvert, piquets."""
    W, H = 46, 36
    img = canvas(W, H)
    for y in range(6, H - 3):
        t = (y - 6) / (H - 9)
        half = 3 + t * 19
        for x in range(int(W / 2 - half), int(W / 2 + half) + 1):
            rel = (x - (W / 2 - half)) / (2 * half)
            img.putpixel((x, y), P["earth0"] if rel < 0.42 else P["earth1"] if rel < 0.8 else P["earth2"])
    for y in range(18, H - 3):                                # entrée sombre
        t = (y - 18) / (H - 21)
        for x in range(int(W / 2 - 1 - t * 5), int(W / 2 + 1 + t * 5)):
            img.putpixel((x, y), P["earth4"])
    line(img, W / 2, 2, W / 2, 7, P["earth3"], w=1)
    for x in (3, W - 4):
        line(img, x, H - 4, x + (3 if x < W / 2 else -3), H - 1, P["earth3"])
    put(img, [(W // 2 - 8, 20), (W // 2 - 7, 22), (W // 2 + 9, 24)], P["stone1"])   # pièces de toile
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=20, ry=2.5)


def billot_hache():
    img = canvas(20, 22)
    rect(img, 4, 12, 12, 8, P["earth3"])
    rect(img, 4, 12, 3, 8, P["earth2"])
    blob(img, 10, 12, 6, 2.2, [P["earth0"], P["earth1"], P["earth2"]], seed=521, jitter=0)
    line(img, 10, 11, 14, 1, P["earth2"], w=1)                # manche planté
    rect(img, 7, 9, 5, 3, P["stone1"])                        # fer
    put(img, [(7, 9), (7, 10)], P["stone0"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=8, ry=1.5)


def bois_empile():
    img = canvas(34, 18)
    for row, y in enumerate((12, 8, 4)):
        for k in range(4 - row):
            cx = 6 + row * 3.5 + k * 7
            blob(img, cx, y, 3.4, 3.4, [P["earth1"], P["earth2"], P["earth3"]], seed=530 + row * 5 + k, jitter=0)
            put(img, [(round(cx), y)], P["earth3"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=15, ry=2)


def pont_rondins():
    """Pont de rondins posés en travers d'un ru nord-sud (on le traverse d'ouest en est) : 48×64."""
    W, H = 48, 64
    img = canvas(W, H)
    for k in range(H // 6):
        y = 2 + k * 6
        rect(img, 1, y, W - 2, 5, P["earth2"])
        rect(img, 1, y, W - 2, 1, P["earth1"])
        rect(img, 1, y + 4, W - 2, 1, P["earth4"])
        for x in (1, W - 3):
            rect(img, x, y + 1, 2, 3, P["earth0"])            # bouts sciés
        if k % 3 == 1:
            put(img, [(W // 2 + 5, y + 2), (W // 2 + 6, y + 2)], P["leaf2"])
    sb.outline(img)
    return img


# --------------------------------------------------------------------------- ressources
def res_chene():
    """Chêne ancien à abattre : gros tronc entaillé, copeaux au pied."""
    img = canvas(30, 34)
    trunk(img, 15, 31, 4, 7, 10, 601, moss=True)
    for y in (16, 17, 18):                                    # entaille
        put(img, [(18, y), (19, y), (20, y), (21, y)], P["earth1"])
    put(img, [(19, 15), (19, 19)], P["earth4"])
    for x, y in ((4, 31), (25, 32), (7, 32), (23, 30)):
        put(img, [(x, y), (x + 1, y)], P["earth0"])           # copeaux
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=11, ry=2)


def res_fougeres():
    img = canvas(28, 26)
    img.alpha_composite(fougere_haute(611).crop((0, 0, 24, 24)), (0, 2))
    img.alpha_composite(fougere_haute(612).crop((0, 0, 24, 24)), (5, 0))
    return img


def res_tronc_grave():
    img = canvas(38, 16)
    rect(img, 3, 4, 32, 9, P["earth3"])
    rect(img, 3, 4, 32, 2, P["earth2"])
    rect(img, 3, 12, 32, 1, P["earth4"])
    blob(img, 4, 8, 2.5, 4.5, [P["earth0"], P["earth1"], P["earth2"]], seed=621, jitter=0)
    for k in range(3):                                        # cercles concentriques gravés, cyan éteint
        cx = 15 + k * 7
        for a in range(12):
            put(img, [(round(cx + math.cos(a * 0.52) * 2.4), round(8 + math.sin(a * 0.52) * 2.2))], P["rune2"] if k == 1 else P["earth4"])
    line(img, 11, 11, 31, 11, P["rune2"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=16, ry=2)


def res_traces():
    img = canvas(26, 14)
    blob(img, 13, 8, 12, 5, [P["leaf2"], P["leaf3"], P["leaf4"]], seed=631, jitter=0.3)   # mousse foulée
    for x, y in ((5, 9), (11, 6), (17, 9), (22, 6)):
        put(img, [(x, y), (x + 1, y), (x, y + 1), (x + 2, y + 1)], P["earth4"])          # sabots fendus
    for x, y in ((9, 3), (20, 4), (14, 11)):
        put(img, [(x, y), (x + 1, y - 1)], P["sun0"])                                       # poils blancs
    sb.outline(img)
    return img


def res_pierres():
    img = canvas(30, 18)
    img.alpha_composite(pierre_moussue(641), (0, 2))
    img.alpha_composite(pierre_moussue(642), (10, 0))
    return img


def res_affleurement():
    img = canvas(32, 22)
    blob(img, 16, 13, 14, 8, [P["stone1"], P["stone2"], P["stone3"]], seed=651, jitter=0.25)
    blob(img, 10, 9, 7, 6, [P["stone0"], P["stone1"], P["stone2"]], seed=652, jitter=0.2)
    for x0, y0 in ((8, 12), (16, 9), (21, 15)):                # veines dorées
        line(img, x0, y0, x0 + 5, y0 + 2, P["sun2"])
        put(img, [(x0 + 1, y0)], P["sun1"])
    sb.outline(img)
    return sb.with_ground_shadow(img, rx=13, ry=2)


ALL = {
    "props/anciens/arbre_ancien_a": lambda: arbre_ancien(201),
    "props/anciens/arbre_ancien_b": lambda: arbre_ancien(202, 48, 66),
    "props/anciens/arbre_ancien_c": lambda: arbre_ancien(203, 56, 74),
    "props/anciens/arbre_geant": arbre_geant,
    "props/anciens/chene_mort_a": lambda: chene_mort(211),
    "props/anciens/chene_mort_b": lambda: chene_mort(212),
    "props/anciens/fougere_haute_a": lambda: fougere_haute(221),
    "props/anciens/fougere_haute_b": lambda: fougere_haute(222),
    "props/anciens/fougere_haute_c": lambda: fougere_haute(223),
    "props/anciens/racines": racines,
    "props/anciens/pierre_moussue_a": lambda: pierre_moussue(231),
    "props/anciens/pierre_moussue_b": lambda: pierre_moussue(232, False),
    "props/anciens/pierre_cercle": lambda: pierre_cercle(241),
    "props/anciens/terre_retournee": terre_retournee,
    "props/anciens/ossements": ossements,
    "props/anciens/tente": tente,
    "props/anciens/billot_hache": billot_hache,
    "props/anciens/bois_empile": bois_empile,
    "props/anciens/pont_rondins": pont_rondins,
    "props/ressources/chene_ancien": res_chene,
    "props/ressources/fougeres_dorees": res_fougeres,
    "props/ressources/tronc_grave": res_tronc_grave,
    "props/ressources/traces_du_cerf_pale": res_traces,
    "props/ressources/pierres_moussues_gravees": res_pierres,
    "props/ressources/affleurement_rocheux": res_affleurement,
}


def main():
    for rel, fn in ALL.items():
        sb.save(fn(), f"{rel}.png")


def preview(out):
    imgs = [fn() for fn in ALL.values()]
    cols, cell = 7, 120
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (74, 128, 64, 255))
    for i, im in enumerate(imgs):
        s = 2 if im.height <= 56 else 1
        im = im.resize((im.width * s, im.height * s), Image.NEAREST)
        sheet.alpha_composite(im, ((i % cols) * cell + max(0, (cell - im.width) // 2), (i // cols) * cell + max(0, (cell - im.height) // 2)))
    sheet.save(out)


if __name__ == "__main__":
    main()
    preview(sb.PREVIEW / "foret_assets.png")
    print(sb.PREVIEW / "foret_assets.png")
