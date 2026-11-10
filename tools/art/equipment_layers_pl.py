"""Calques d'équipement pour le joueur PixelLab (planche 32×32, tools/art/pixellab_player.py).

Le sprite n'est plus dessiné par nos couleurs-clés : on reconnaît les parties par la teinte et la
position dans la silhouette de chaque image (tunique bleue, peau, cheveux en haut, bottes en bas).
Les calques sont en gris (3 niveaux) comme avant ; game/fx/equip_tint.gdshader les teinte.
L'arme est dessinée dans la main avec le code de tools/art/equipment_layers.py, à l'échelle 32 px.
Usage : python tools/art/equipment_layers_pl.py
"""
import colorsys
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import CLEAR  # noqa: E402
import styleboard as sb  # noqa: E402
import equipment_layers as el  # noqa: E402
import pixellab_player as pp  # noqa: E402

FW = FH = 32
COLS = 12
DIRS = ("S", "SE", "E", "NE", "N")
LIGHT, MID, DARK = el.LIGHT, el.MID, el.DARK
# images de l'arme : le personnage à (8, 6) dans une case de 48×42
el.WW, el.WH, el.WX, el.WY = 48, 42, 8, 6
el.LENGTHS = {"dague": 6, "lame": 10, "hachette": 9, "masse": 7, "lance": 13}


def frames():
    """Les 60 images de la planche, sans ombre au sol (on reprend les sources)."""
    src = {}
    for row, d in enumerate(pp.DIRS):
        fr = [pp.frame("repos", d, 0), pp.frame("repos", d, 2)]
        fr += [pp.frame("marche", d, k) for k in range(4)]
        fr += [pp.frame("attaque", d, k) for k in range(3)]
        fr += [pp.hurt(pp.frame("repos", d, 0)), pp.frame("ko", "south", 3), pp.frame("ko", "south", 6)]
        for col, f in enumerate(fr):
            src[(row, col)] = f
    return src


def classify(im, ko):
    """Partie de chaque pixel : 'chest', 'face', 'hand', 'hair', 'boot' ou None."""
    px = im.load()
    pts = [(x, y) for y in range(im.height) for x in range(im.width) if px[x, y][3] > 0]
    if not pts:
        return {}
    top = min(y for _, y in pts)
    bot = max(y for _, y in pts)
    H = max(1, bot - top)
    out = {}
    for x, y in pts:
        r, g, b, _ = px[x, y]
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        h *= 360
        rel = (y - top) / H
        if v < 0.11:
            continue                                          # contour : on le garde
        if 185 <= h <= 230 and s > 0.08 and v > 0.35:
            out[(x, y)] = "chest"
        elif ko:
            continue
        elif 5 <= h <= 32 and 0.3 <= s <= 0.66 and v > 0.55:
            out[(x, y)] = "face" if rel < 0.42 else "hand"
        elif rel < 0.38 and 10 <= h <= 48 and 0.12 <= v <= 0.85:
            out[(x, y)] = "hair"
        elif rel > 0.8 and v < 0.48:
            out[(x, y)] = "boot"
    return out


def levels(px, pts):
    """Trois niveaux de gris selon la luminosité, relative à la partie."""
    if not pts:
        return {}
    lum = sorted(pts, key=lambda p: sum(px[p[0], p[1]][:3]))
    n = len(lum)
    res = {}
    for i, p in enumerate(lum):
        res[p] = DARK if i < n * 0.3 else (MID if i < n * 0.78 else LIGHT)
    return res


def body_layer(kind, im, cls, d):
    px = im.load()
    out = Image.new("RGBA", (FW, FH), CLEAR)
    o = out.load()
    part = {"chest_tunique": "chest", "chest_plastron": "chest", "gloves": "hand", "boots": "boot"}.get(kind)
    if part:
        pts = [p for p, c in cls.items() if c == part]
        for p, lv in levels(px, pts).items():
            o[p] = lv
        if kind == "chest_plastron" and pts:                  # plaques : reflet en haut, ligne au milieu
            ys = sorted({y for _, y in pts})
            for p in pts:
                if p[1] == ys[0]:
                    o[p] = LIGHT
                elif p[1] == ys[len(ys) // 2]:
                    o[p] = DARK
        return out
    hair = [p for p, c in cls.items() if c == "hair"]
    face = [p for p, c in cls.items() if c == "face"]
    if not hair:
        return out
    top = min(y for _, y in hair)
    lv = levels(px, hair)
    if kind == "head_casque":
        for p in hair:
            o[p] = LIGHT if p[1] <= top + 1 else (MID if lv[p] != DARK else DARK)
        if face:                                              # bord du casque sur le front
            fy = min(y for _, y in face)
            for p in face:
                if p[1] == fy:
                    o[p] = DARK
    elif kind == "head_capuche":
        for p, l in lv.items():
            o[p] = l
        rows = sorted({y for _, y in face})
        for y in rows:                                        # l'étoffe encadre le visage
            xs = sorted(x for x, yy in face if yy == y)
            if len(xs) > 2:
                o[xs[0], y] = DARK
                o[xs[-1], y] = DARK
    elif kind == "head_diademe":
        band = top + 4
        xs = sorted(x for x, y in hair if y == band)
        for i, x in enumerate(xs):
            o[x, band] = LIGHT if i % 2 == 0 else MID
        if xs and d in ("S", "SE"):
            o[xs[len(xs) // 2], band] = (224, 90, 72, 255)    # gemme (vraie couleur)
    return out


def hand_and_dir(cls, d, col, style):
    hands = [p for p, c in cls.items() if c == "hand"]
    f = el.FACE[d]
    if col >= 10:
        return (FW // 2 + 4, FH - 4), (1.0, 0.0)
    if not hands:
        return (FW // 2 + 6, 22), (0.0, 1.0)
    if col == 7:
        return max(hands, key=lambda p: p[0] * f[0] + p[1] * f[1]), f
    if col == 6:
        h = max(hands, key=lambda p: -(p[0] * f[0] + p[1] * f[1]) - p[1] * 0.3)
        return h, el._norm((-f[0] * 0.8, -1.0 - f[1] * 0.4))
    h = max(hands, key=lambda p: (p[0], p[1]))
    if style == "lance":
        return h, el._norm((f[0] * 0.15, -1.0))
    return h, el._norm((f[0] * 0.55, 1.0))


KINDS = ["chest_tunique", "chest_plastron", "head_capuche", "head_casque", "head_diademe", "gloves", "boots"]
STYLES = ["dague", "lame", "hachette", "masse", "lance"]


def build():
    src = frames()
    out = {k: Image.new("RGBA", (FW * COLS, FH * 5), CLEAR) for k in KINDS}
    out.update({f"weapon_{s}": Image.new("RGBA", (el.WW * COLS, el.WH * 5), CLEAR) for s in STYLES})
    real_len = None
    for (row, col), im in src.items():
        d = DIRS[row]
        cls = classify(im, col >= 10)
        for k in KINDS:
            out[k].alpha_composite(body_layer(k, im, cls, d), (col * FW, row * FH))
        for s in STYLES:
            hand, v = hand_and_dir(cls, d, col, s)
            out[f"weapon_{s}"].alpha_composite(_weapon(s, hand, v), (col * el.WW, row * el.WH))
    return out


def _weapon(style, hand, v):
    return el.weapon_frame(style, hand, v)


def main():
    for k, img in build().items():
        sb.save(img, f"characters/player/equip/{k}.png")


if __name__ == "__main__":
    main()
    print("ok")
