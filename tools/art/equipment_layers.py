"""Calques d'équipement du joueur, alignés sur la planche player_8dir.png (12 colonnes × 5 lignes).

Les calques de corps (tête, torse, mains, pieds) sont dérivés de la planche elle-même : on la
redessine avec une couleur-repère unique par partie (cheveux, peau, tunique, bottes…), ce qui donne,
image par image, exactement les pixels à recouvrir (marche, attaque, touché, KO compris).
L'arme est dessinée dans la main, avec une tenue par pose. Ses images sont plus grandes (40×34)
pour qu'une lance ou une lame tendue ne soient pas coupées.

Tout ce qui doit prendre la couleur de la matière est en gris (3 niveaux) : le shader
game/fx/equip_tint.gdshader remplace ces gris par la teinte de l'objet (or, fer, os, bois…).
Le reste (manche en bois, gemme, contour) garde sa vraie couleur.
Usage : python tools/art/equipment_layers.py
"""
import math
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, CLEAR  # noqa: E402
import styleboard as sb  # noqa: E402
import player_sheet as ps  # noqa: E402

FW, FH, COLS = ps.FW, ps.FH, ps.COLS
DIRS = ("S", "SE", "E", "NE", "N")
LIGHT, MID, DARK = (232, 232, 232, 255), (164, 164, 164, 255), (96, 96, 96, 255)
O = P["outline"]
WOOD, WOOD_D = P["earth2"], P["earth3"]
# images de l'arme : plus grandes, le personnage placé à (WX, WY)
WW, WH, WX, WY = 40, 34, 8, 4

# longueur des armes (px) ; equipment_layers_pl.py la règle pour le joueur en 32 px
LENGTHS = {"dague": 5, "lame": 8, "hachette": 7, "masse": 6, "lance": 11}

CHARS = "OHLhSsTtBGPpKk"


def tag(ch):
    i = CHARS.index(ch)
    return (20 + i * 15, 201, 7, 255)


TAGS = {tag(c): c for c in CHARS}


def class_sheet():
    """La planche dessinée avec une couleur-repère par partie."""
    real = ps.keys
    ps.keys = lambda: {c: tag(c) for c in CHARS}
    try:
        return ps.sheet()
    finally:
        ps.keys = real


def cells(sheet):
    for row, d in enumerate(DIRS):
        for col in range(COLS):
            yield row, col, d, sheet.crop((col * FW, row * FH, (col + 1) * FW, (row + 1) * FH))


def char_at(px, x, y):
    return TAGS.get(px[x, y])


# --------------------------------------------------------------------------- calques de corps
HAND_Y = ps.OY + 14          # sous cette ligne, la peau est une main (au-dessus : le visage)


def body_layer(kind, cmap, col):
    """Un calque (24×26) pour une image, en gris, à partir de la carte des parties."""
    px = cmap.load()
    out = Image.new("RGBA", (FW, FH), CLEAR)
    o = out.load()
    ko = col >= 10
    hair = [(x, y) for y in range(FH) for x in range(FW) if char_at(px, x, y) in ("H", "L", "h")]
    skin_face = [(x, y) for y in range(FH) for x in range(FW)
                 if char_at(px, x, y) in ("S", "s") and (y < HAND_Y or ko)]
    lvl = {"L": LIGHT, "H": MID, "h": DARK, "T": MID, "t": DARK, "S": MID, "s": DARK, "K": MID, "k": DARK,
           "B": DARK, "G": MID}
    if kind in ("chest_tunique", "chest_plastron"):
        for y in range(FH):
            for x in range(FW):
                c = char_at(px, x, y)
                if c in ("T", "t"):
                    o[x, y] = lvl[c]
                elif kind == "chest_plastron" and c == "B":
                    o[x, y] = DARK                        # le plastron couvre la ceinture
        if kind == "chest_plastron":                      # plaques : un reflet sur le haut, une ligne au milieu
            rows = sorted({y for y in range(FH) for x in range(FW) if o[x, y][3]})
            if rows:
                for x in range(FW):
                    if o[x, rows[0]][3]:
                        o[x, rows[0]] = LIGHT
                mid_row = rows[len(rows) // 2]
                for x in range(FW):
                    if o[x, mid_row][3] and o[x, mid_row] != LIGHT:
                        o[x, mid_row] = DARK
    elif kind == "boots":
        for y in range(FH):
            for x in range(FW):
                c = char_at(px, x, y)
                if c in ("K", "k"):
                    o[x, y] = lvl[c]
    elif kind == "gloves" and not ko:
        for y in range(HAND_Y, FH):
            for x in range(FW):
                c = char_at(px, x, y)
                if c in ("S", "s"):
                    o[x, y] = lvl[c]
    elif kind.startswith("head_") and hair:
        top = min(y for _, y in hair)
        for x, y in hair:
            o[x, y] = lvl[char_at(px, x, y)]
        face_rows = sorted({y for _, y in skin_face})
        if kind == "head_casque":
            for x, y in hair:                             # métal : reflet sur le dessus
                o[x, y] = LIGHT if y == top else (MID if char_at(px, x, y) != "h" else DARK)
            if face_rows:                                 # bord du casque sur le front
                for x, y in skin_face:
                    if y == face_rows[0]:
                        o[x, y] = DARK
        elif kind == "head_capuche":
            for y in face_rows:                           # l'étoffe encadre le visage
                xs = sorted(x for x, yy in skin_face if yy == y)
                for x in (xs[0], xs[-1]) if len(xs) > 2 else ():
                    o[x, y] = DARK
            for x, y in hair:
                if y == top:
                    o[x, y] = MID
        elif kind == "head_diademe":
            out2 = Image.new("RGBA", (FW, FH), CLEAR)      # seulement un bandeau, les cheveux restent
            o2 = out2.load()
            band = top + 3
            xs = sorted(x for x, y in hair if y == band)
            for i, x in enumerate(xs):
                o2[x, band] = LIGHT if i % 2 == 0 else MID
            if xs and DIRS_OF[id(cmap)] in ("S", "SE"):
                o2[xs[len(xs) // 2], band] = P["red0"]    # gemme (vraie couleur)
            return out2
    return out


DIRS_OF = {}


# --------------------------------------------------------------------------- arme
FACE = {"S": (0.0, 1.0), "SE": (0.7071, 0.7071), "E": (1.0, 0.0), "NE": (0.7071, -0.7071), "N": (0.0, -1.0)}


def _norm(v):
    n = math.hypot(*v) or 1.0
    return (v[0] / n, v[1] / n)


def hand_and_dir(cmap, d, col, style=""):
    """Point de prise (dans l'image 24×26) et direction de l'arme pour cette pose."""
    px = cmap.load()
    hands = [(x, y) for y in range(HAND_Y, FH) for x in range(FW) if char_at(px, x, y) in ("S", "s")]
    f = FACE[d]
    if col >= 10:                                          # KO : l'arme est tombée au sol
        return (FW // 2 + 3, FH - 3), (1.0, 0.0)
    if not hands:
        return (FW // 2 + 5, 18), (0.0, 1.0)
    if col == 7:                                           # frappe : le poing le plus en avant
        h = max(hands, key=lambda p: p[0] * f[0] + p[1] * f[1])
        return h, f
    if col == 6:                                           # élan : bras ramené, arme levée en arrière
        h = max(hands, key=lambda p: -(p[0] * f[0] + p[1] * f[1]) - p[1] * 0.3)
        return h, _norm((-f[0] * 0.8, -1.0 - f[1] * 0.4))
    h = max(hands, key=lambda p: (p[0], p[1]))             # tenue au côté : pointe vers le bas, un peu devant
    if style == "lance":                                   # la lance se tient droite, pointe en l'air
        return h, _norm((f[0] * 0.15, -1.0))
    return h, _norm((f[0] * 0.55, 1.0))


def _line(o, x0, y0, x1, y1, color, w=WW, h=WH):
    n = int(max(abs(x1 - x0), abs(y1 - y0)))
    for i in range(n + 1):
        t = i / max(n, 1)
        x, y = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
        if 0 <= x < w and 0 <= y < h:
            o[x, y] = color


def _put(o, x, y, color):
    x, y = round(x), round(y)
    if 0 <= x < WW and 0 <= y < WH:
        o[x, y] = color


def weapon_frame(style, hand, v):
    img = Image.new("RGBA", (WW, WH), CLEAR)
    o = img.load()
    hx, hy = hand[0] + WX, hand[1] + WY
    vx, vy = v
    px_, py_ = -vy, vx                                    # perpendiculaire
    if px_ + py_ > 0:                                     # côté « lumière » : vers le haut-gauche
        px_, py_ = -px_, -py_
    L = LENGTHS[style]
    if style in ("dague", "lame"):
        _put(o, hx - vx, hy - vy, WOOD_D)                 # pommeau
        _put(o, hx, hy, WOOD)                             # poignée
        gx, gy = hx + vx * 1.2, hy + vy * 1.2             # garde
        for s in (-1, 0, 1):
            _put(o, gx + px_ * s, gy + py_ * s, DARK)
        for i in range(2, L + 2):
            bx, by = hx + vx * i, hy + vy * i
            _put(o, bx, by, MID if i < L + 1 else LIGHT)
            if style == "lame" and i < L:
                _put(o, bx + px_, by + py_, LIGHT)
    elif style in ("hachette", "masse"):
        _put(o, hx - vx, hy - vy, WOOD_D)
        _line(o, hx, hy, hx + vx * L, hy + vy * L, WOOD)
        ex, ey = hx + vx * L, hy + vy * L
        if style == "hachette":                           # fer d'un seul côté du manche
            for a in range(-1, 2):
                for b in range(1, 4):
                    _put(o, ex + vx * a - px_ * b, ey + vy * a - py_ * b, LIGHT if b == 3 else MID)
            _put(o, ex - px_, ey - py_, DARK)
        else:                                             # tête ronde
            for a in range(-1, 2):
                for b in range(-1, 2):
                    if a * a + b * b <= 2:
                        c = LIGHT if (a + b) < 0 else (DARK if a + b > 0 else MID)
                        _put(o, ex + vx * (a + 1) + px_ * b, ey + vy * (a + 1) + py_ * b, c)
    elif style == "lance":
        _line(o, hx - vx * 3, hy - vy * 3, hx + vx * L, hy + vy * L, WOOD)
        tx, ty = hx + vx * (L + 1), hy + vy * (L + 1)
        _put(o, tx, ty, MID)
        _put(o, tx + vx, ty + vy, LIGHT)
        _put(o, tx + px_, ty + py_, MID)
        _put(o, tx - px_, ty - py_, DARK)
        _put(o, tx + vx * 2, ty + vy * 2, LIGHT)
    sb.outline(img)
    return img


# --------------------------------------------------------------------------- planches
BODY_KINDS = ["chest_tunique", "chest_plastron", "head_capuche", "head_casque", "head_diademe", "gloves", "boots"]
STYLES = ["dague", "lame", "hachette", "masse", "lance"]


def build():
    cm = class_sheet()
    out = {k: Image.new("RGBA", (FW * COLS, FH * 5), CLEAR) for k in BODY_KINDS}
    out.update({f"weapon_{s}": Image.new("RGBA", (WW * COLS, WH * 5), CLEAR) for s in STYLES})
    for row, col, d, cell in cells(cm):
        DIRS_OF[id(cell)] = d
        for k in BODY_KINDS:
            out[k].alpha_composite(body_layer(k, cell, col), (col * FW, row * FH))
        for s in STYLES:
            hand, v = hand_and_dir(cell, d, col, s)
            out[f"weapon_{s}"].alpha_composite(weapon_frame(s, hand, v), (col * WW, row * WH))
    return out


def main():
    for k, img in build().items():
        sb.save(img, f"characters/player/equip/{k}.png")


def preview(out_path):
    """Planche de contrôle : le joueur avec plusieurs tenues teintées, dans 3 directions."""
    sheets = build()
    base = Image.open(sb.OUT / "characters/player/player_8dir.png").convert("RGBA")
    ramps = {"or": (P["sun0"], P["sun1"], P["sun3"]), "fer": (P["stone0"], P["stone1"], P["stone3"]),
             "cuir": (P["earth1"], P["earth2"], P["earth4"]), "écaille": (P["water0"], P["water2"], P["water3"])}

    def tint(img, ramp):
        img = img.copy()
        p = img.load()
        for y in range(img.height):
            for x in range(img.width):
                c = p[x, y]
                if c[3] and c[0] == c[1] == c[2]:
                    p[x, y] = ramp[0] if c[0] > 200 else ramp[1] if c[0] > 130 else ramp[2]
        return img

    outfits = [
        {"weapon_lame": "fer", "head_casque": "fer", "chest_plastron": "fer", "gloves": "cuir", "boots": "cuir"},
        {"weapon_dague": "or", "head_capuche": "cuir", "chest_tunique": "cuir", "boots": "cuir"},
        {"weapon_lance": "écaille", "head_diademe": "or", "chest_plastron": "écaille", "gloves": "écaille"},
        {"weapon_hachette": "fer", "head_capuche": "écaille"},
        {"weapon_masse": "or", "chest_plastron": "or", "head_casque": "or", "boots": "fer"},
    ]
    cols = [0, 3, 6, 7, 11]
    s = 4
    sheet = Image.new("RGBA", (WW * len(cols) * s, WH * 5 * len(outfits) * s // 5 * 5 // 5), P["leaf2"])
    sheet = Image.new("RGBA", (WW * len(cols) * s, WH * len(outfits) * 3 * s), P["leaf2"])
    y0 = 0
    for outfit in outfits:
        for row in (0, 2, 4):
            for i, col in enumerate(cols):
                cell = Image.new("RGBA", (WW, WH), CLEAR)
                back = row in (3, 4)
                wk = next((k for k in outfit if k.startswith("weapon_")), None)
                wcell = tint(sheets[wk].crop((col * WW, row * WH, (col + 1) * WW, (row + 1) * WH)), ramps[outfit[wk]]) if wk else None
                if wcell and back:
                    cell.alpha_composite(wcell)
                cell.alpha_composite(base.crop((col * FW, row * FH, (col + 1) * FW, (row + 1) * FH)), (WX, WY))
                for k, m in outfit.items():
                    if not k.startswith("weapon_"):
                        cell.alpha_composite(tint(sheets[k].crop((col * FW, row * FH, (col + 1) * FW, (row + 1) * FH)), ramps[m]), (WX, WY))
                if wcell and not back:
                    cell.alpha_composite(wcell)
                sheet.alpha_composite(cell.resize((WW * s, WH * s), Image.NEAREST), (i * WW * s, y0))
            y0 += WH * s
    sheet.save(out_path)


if __name__ == "__main__":
    main()
    preview(sb.PREVIEW / "equipement_visible.png")
    print(sb.PREVIEW / "equipement_visible.png")
