"""Assets du village (étage 1) : bâtiments, ateliers, mobilier, PNJ, tuiles de champs.

Même palette, même lumière (haut-gauche) et même contour que la planche de style.
Usage : python tools/art/village_assets.py
"""
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, CLEAR, GROUND_SHADOW  # noqa: E402
import styleboard as sb  # noqa: E402

T = 16
O = P["outline"]

ROOFS = {
    "chaume": ("sun2", "sun3", "earth2"),
    "tuile_rouge": ("red0", "red1", "wine"),
    "ardoise_bleue": ("blue0", "blue1", "shade1"),
    "ardoise": ("stone2", "stone3", "stone4"),
    "lie_de_vin": ("shade0", "wine", "shade1"),
    "dalle_runique": ("stone0", "stone1", "stone2"),
}
WALLS = {
    "torchis": ("earth0", "earth1", "earth3"),     # clair, ombre, colombage
    "bois": ("earth2", "earth3", "earth4"),
    "pierre": ("stone1", "stone2", "stone3"),
    "architecte": ("stone0", "stone1", "rune2"),
}


# --------------------------------------------------------------------------- bâtiments
def building(wt, ht, roof="chaume", walls="torchis", chimney=None, windows=2, sign=False,
             glow="sun1", door_open=False, seed=0, runes=False):
    """Bâtiment vu en 3/4 : toit sur ~60 % du haut, façade sud visible en bas.
    Le sprite couvre exactement l'emprise (wt x ht tuiles) ; pied = bas du sprite."""
    w, h = wt * T, ht * T
    img = Image.new("RGBA", (w, h + 8), CLEAR)          # +8 : cheminée qui dépasse
    px = img.load()
    top = 8
    wall_h = max(22, int(h * 0.42))
    wall_y = top + h - wall_h
    lite, shade, trim = (P[k] for k in WALLS[walls])

    # façade
    for y in range(wall_y, top + h - 1):
        for x in range(3, w - 3):
            c = lite if x < w * 0.7 else shade
            if walls == "torchis" and (x in (3, w - 4) or (x - 3) % 24 == 0 or y == wall_y + 1):
                c = trim
            if walls == "pierre" and ((y - wall_y) % 5 == 0 or ((x + ((y - wall_y) // 5) * 3) % 8 == 0)):
                c = trim
            if walls == "bois" and (x - 3) % 4 == 0:
                c = trim
            if walls == "architecte" and (y == wall_y + 2 or y == top + h - 4):
                c = P["rune1"] if (x // 2) % 3 else P["rune0"]
            px[x, y] = c
    # soubassement
    for x in range(3, w - 3):
        px[x, top + h - 2] = P["stone3"] if walls != "architecte" else P["stone2"]

    # porte (centrée)
    dw, dh = 8, min(14, wall_h - 6)
    dx0 = w // 2 - dw // 2
    for y in range(top + h - 1 - dh, top + h - 1):
        for x in range(dx0, dx0 + dw):
            edge = x in (dx0, dx0 + dw - 1) or y == top + h - 1 - dh
            if door_open:
                c = P["earth3"] if edge else (P["sun3"] if y > top + h - dh + 2 else P["red1"])
            else:
                c = P["earth4"] if edge else (P["earth3"] if (x - dx0) % 3 else P["earth4"])
            px[x, y] = c
    if not door_open:
        px[dx0 + dw - 3, top + h - dh // 2 - 1] = P["sun1"]

    # fenêtres allumées, symétriques
    slots = []
    if windows:
        span = (w // 2 - dw // 2 - 8)
        per_side = max(1, windows // 2)
        for i in range(per_side):
            off = 6 + (span - 8) * (i + 0.5) / per_side
            slots += [int(off), int(w - off - 8)]
    wy0 = wall_y + 6
    for sx in slots:
        for y in range(wy0, wy0 + 7):
            for x in range(sx, sx + 8):
                edge = x in (sx, sx + 7) or y in (wy0, wy0 + 6) or x == sx + 4
                px[x, y] = P["earth3"] if edge else (P[glow] if x < sx + 4 else P["sun2"])

    # toit : versant haut éclairé, faîtage, versant bas
    roof_top, roof_bot = top + 1, wall_y + 3
    ridge = roof_top + int((roof_bot - roof_top) * 0.35)
    r_lite, r_mid, r_dark = (P[k] for k in ROOFS[roof])
    for y in range(roof_top, roof_bot):
        inset = max(0, 4 - (y - roof_top)) if y < ridge else 0
        for x in range(inset, w - inset):
            rel = x / w
            if y < ridge:
                c = r_lite if rel < 0.75 else r_mid
            else:
                c = r_mid if rel < 0.7 else r_dark
            if roof in ("chaume",) and (y + (x // 4)) % 4 == 0:
                c = r_dark if c != r_dark else P["earth3"]
            elif roof != "chaume" and (y - ridge) % 4 == 0 and y > ridge:
                c = r_dark
            elif roof != "chaume" and y > ridge and (x + ((y - ridge) // 4) * 4) % 8 == 0:
                c = r_dark
            if y == ridge:
                c = r_dark
            if y == roof_bot - 1:
                c = r_dark
            px[x, y] = c
    if runes:
        for x in range(6, w - 6, 6):
            px[x, ridge + 3] = P["rune1"]
            px[x + 1, ridge + 3] = P["rune0"]

    # cheminée
    if chimney:
        cx = int(w * chimney)
        for y in range(1, ridge + 2):
            for x in range(cx, cx + 7):
                px[x, y] = P["stone1"] if x < cx + 4 else P["stone2"]
        for x in range(cx, cx + 7):
            px[x, 1] = P["stone3"]

    # enseigne suspendue (auberge)
    if sign:
        sx, sy = dx0 + dw + 4, wall_y + 4
        for x in range(sx, sx + 10):
            px[x, sy] = P["earth3"]
        for y in range(sy + 1, sy + 9):
            for x in range(sx + 1, sx + 9):
                edge = x in (sx + 1, sx + 8) or y in (sy + 1, sy + 8)
                px[x, y] = P["earth3"] if edge else P["earth2"]
        for (x, y) in [(3, 3), (4, 3), (5, 3), (3, 4), (5, 4), (6, 4), (3, 5), (4, 5), (5, 5), (4, 6)]:
            px[sx + x, sy + y] = P["sun1"]                      # chope dorée

    sb.outline(img)
    return img


def stall():
    """Étal de Thessaly : comptoir en bois, auvent rayé."""
    w, h = 4 * T, 2 * T + 14
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    for y in range(2, 14):                                       # auvent
        for x in range(1, w - 1):
            c = P["red0"] if (x // 6) % 2 == 0 else P["sun0"]
            if x > w * 0.75:
                c = P["red1"] if c == P["red0"] else P["earth0"]
            if y >= 12:
                c = P["red1"] if (x // 6) % 2 == 0 else P["earth1"]
            px[x, y] = c
    for y in range(14, h - 10):                                  # poteaux
        for x in (3, 4, w - 5, w - 4):
            px[x, y] = P["earth3"]
    for y in range(h - 12, h - 1):                               # comptoir
        for x in range(2, w - 2):
            px[x, y] = P["earth2"] if y < h - 9 else (P["earth3"] if x < w * 0.7 else P["earth4"])
    for i, k in enumerate(["red0", "sun1", "leaf1", "blue0", "red0", "sun0"]):   # marchandises
        x = 8 + i * 8
        for dx in range(3):
            for dy in range(3):
                px[x + dx, h - 15 + dy] = P[k]
    sb.outline(img)
    return img


# --------------------------------------------------------------------------- mobilier et repères
def sprite_ascii(rows, extra=None):
    keys = {"O": O, "1": P["stone0"], "2": P["stone1"], "3": P["stone2"], "4": P["stone3"],
            "w": P["earth1"], "W": P["earth2"], "d": P["earth3"], "D": P["earth4"],
            "b": P["water2"], "B": P["water3"], "r": P["rune1"], "R": P["rune0"],
            "y": P["sun1"], "Y": P["sun0"], "o": P["sun2"], "x": P["red0"], "X": P["red1"],
            "g": P["leaf2"], "G": P["leaf3"], "l": P["leaf1"], "e": P["earth0"],
            "s": P["shade1"], "k": P["stone4"], "c": P["blue0"], "C": P["blue1"], "v": P["wine"]}
    if extra:
        keys.update(extra)
    return sb.from_ascii(rows, keys)


def well():
    img = Image.new("RGBA", (32, 36), CLEAR)
    px = img.load()
    for y in range(4, 10):                                       # petit toit
        for x in range(4 + max(0, 9 - y), 28 - max(0, 9 - y)):
            px[x, y] = P["red0"] if x < 20 else P["red1"]
    for y in range(10, 22):                                      # poteaux
        px[7, y] = px[8, y] = P["earth3"]
        px[23, y] = px[24, y] = P["earth4"]
    for x in range(9, 23):
        px[x, 13] = P["earth3"]                                   # treuil
    px[16, 14] = px[16, 15] = P["earth4"]
    for y in range(16, 19):
        for x in range(14, 19):
            px[x, y] = P["earth2"]                                # seau
    sb.ellipse(img, 16, 27, 13, 7, P["stone1"])                   # margelle
    sb.ellipse(img, 16, 25.5, 9, 4, P["water3"])
    sb.ellipse(img, 15, 25, 6, 2.2, P["water2"])
    for y in range(27, 34):
        for x in range(3, 29):
            if ((x + 0.5 - 16) / 13) ** 2 + ((y + 0.5 - 27) / 7) ** 2 <= 1 and y > 28:
                px[x, y] = P["stone2"] if (x + (y // 3) * 2) % 6 else P["stone3"]
    sb.outline(img)
    return img


def autel():
    """Autel des Ventes : dalle architecte, runes cyan à moitié éteintes."""
    rows = [
        "..OOOOOOOOOOOOOOOOOOOOOOOOOOOO..",
        ".O1111111111111111111111111112O.",
        "O11111111111111111111111111223O",
        "O1122222222222222222222222222233O"[:31] + "O",
        "O12222r22222R2222222r22222222233O"[:31] + "O",
        "O1222rRr222rrr22222rRr2222222233"[:31] + "O",
        "O12222r22222r222222224222222223O"[:31] + "O",
        "O122222222222222222222222222233O",
        "OO3333333333333333333333333333OO",
        "O2223333333333333333333333444k4O",
        "O2222333r33333333333433334444k4O"[:31] + "O",
        "O2222333333333333333333334444kkO",
        "O2223333333333333333333334444kkO",
        "O2223333333333333333333334444kkO",
        ".O2233333333333333333333344444O.",
        "..OOOOOOOOOOOOOOOOOOOOOOOOOOOO..",
    ]
    rows = [r[:32].ljust(32, ".") for r in rows]
    img = sprite_ascii(rows)
    return sb.with_ground_shadow(img, rx=15, ry=3)


def lantern():
    rows = [
        "..OOOO..",
        ".OddddO.",
        "OYyyyooO",
        "OYyyyooO",
        "OyyyyooO",
        ".OddddO.",
        "..OdDO..",
        "..OdDO..",
        "..OdDO..",
        "..OdDO..",
        "..OdDO..",
        "..OdDO..",
        "..OdDO..",
        "..OdDO..",
        "..OdDO..",
        "..OdDO..",
        ".OddDDO.",
        ".OOOOOO.",
    ]
    return sb.with_ground_shadow(sprite_ascii(rows), rx=3, ry=1.5)


def fence_h():
    rows = [
        ".OO......OO.....",
        "OwdO....OwdO....",
        "OwdOOOOOOwdOOOOO",
        "OwdWWWWWOwdWWWWW",
        "OwdOOOOOOwdOOOOO",
        "OwdO....OwdO....",
        "OwdOOOOOOwdOOOOO",
        "OwdWWWWWOwdWWWWW",
        "OwdOOOOOOwdOOOOO",
        "OddO....OddO....",
        ".OO......OO.....",
    ]
    return sprite_ascii(rows)


def fence_v():
    rows = [".OO.", "OwdO", "OwdO", "OwdO", "OwdO", "OwdO", "OwdO", "OwdO", "OwdO",
            "OwdO", "OwdO", "OwdO", "OwdO", "OwdO", "OddO", ".OO."]
    return sprite_ascii(rows)


SMALL = {
    "tonneau": [
        ".OOOOOO.",
        "OWWWWWdO",
        "OddddddO",
        "OWwWWWdO",
        "OWwWWWdO",
        "OddddddO",
        "OWwWWWdO",
        "OWWWWWdO",
        "OddddddO",
        ".OOOOOO.",
    ],
    "caisse": [
        "OOOOOOOOOO",
        "OwwwwwwwdO",
        "OwdwwwwddO",
        "OwwdwwdwdO",
        "OwwwddwwdO",
        "OwwdwwdwdO",
        "OwdwwwwddO",
        "OddddddddO",
        "OOOOOOOOOO",
    ],
    "banc": [
        "OOOOOOOOOOOOOOOOOO",
        "OwwwwwwwwwwwwwwwdO",
        "OddddddddddddddddO",
        "OOdOOOOOOOOOOOOdOO",
        ".OdO..........OdO.",
        ".OOO..........OOO.",
    ],
    "bois_coupe": [
        "..OOOO..OOOO......",
        ".OewwdOOewwdOOOO..",
        ".OwddwOOwddwOewdO.",
        "OOOOOOOOOOOOOwddwO",
        "OewwdOewwdOewwdOO.",
        "OwddwOwddwOwddwO..",
        "OOOOOOOOOOOOOOOO..",
    ],
    "enclume": [
        "OOOOOOOOOOOOO.",
        "O22222222223kO",
        ".OOO2223kOOOO.",
        "...O2234kO....",
        "..OO3334kOO...",
        "..OddddddDO...",
        "..OOOOOOOOO...",
    ],
    "minerai": [
        "...OOO.....",
        "..O34kO.OO.",
        ".O3rk4kO4kO",
        "O34k44kO34O",
        "OkkkkkkkkkO",
        ".OOOOOOOOO.",
    ],
    "chaudron": [
        "..OOOOOOOOOO..",
        ".OkllllllllkO.",
        "OkGlllgllllGkO",
        "OkkkkkkkkkkkkO",
        "Ok4444444444kO",
        "Ok4444444444kO",
        ".Ok44444444kO.",
        "..OOkkkkkkOO..",
        "..OyoyoyoyoO..",
        "...OOOOOOOO...",
    ],
    "table_alambic": [
        "....OO..OO......",
        "...ObbOOxxO..OO.",
        "...ObbOOxxO.OlO.",
        "..OOOOOOOOOOOOOO",
        "..OWWWWWWWWWWWdO",
        "..OddddddddddddO",
        "..OdO.......OdO.",
        "..OOO.......OOO.",
    ],
    "metier_tisser": [
        "OOOOOOOOOOOOOOOOOO",
        "OdddddddddddddddDO",
        "OdOcccccccccccOdDO",
        "OdOcCcCcCcCcCcOdDO",
        "OdOcccccccccccOdDO",
        "OdOcCcCcCcCcCcOdDO",
        "OdOcccccccccccOdDO",
        "OdOOOOOOOOOOOOOdDO",
        "OdddddddddddddddDO",
        "OdO...........OdO.",
        "OOO...........OOO.",
    ],
    "corde_linge": [
        "OO............................OO",
        "OdOOOOOOOOOOOOOOOOOOOOOOOOOOOOdO",
        "OdOcccO..OxxxxO..OYYYYO..OcccOdO",
        "OdOcCcO..OxXxxO..OYeYYO..OcCcOdO",
        "OdOcccO..OxxxxO..OYYYYO..OcccOdO",
        "OdOOOOO..OxxxxO..OOOOOO..OOOOOdO",
        "OdO.......OOOO...............OdO",
        "OdO..........................OdO",
        "OdO..........................OdO",
        "OOO..........................OOO",
    ],
    "bloc_pierre": [
        "OOOOOOOOOOOOOO",
        "O111111111112O",
        "O122222222233O",
        "O222222222234O",
        "O222222222234O",
        "O222222222344O",
        "O333333333444O",
        "OOOOOOOOOOOOOO",
    ],
    "statue_inachevee": [
        "....OOOO......",
        "...O1122O.....",
        "...O1223O.....",
        "....O23O......",
        "..OO1223OO....",
        ".O112222233O..",
        ".O12O2223O3O..",
        ".O2OO2223OO...",
        "..O.O2233O....",
        "....O2233O....",
        "...O222333O...",
        "..O22223333O..",
        "..O22233334O..",
        ".O222223334kO.",
        ".O222233344kO.",
        "OO3333333444kOO",
        "O1111111111123O",
        "O2222222222334O",
        "OOOOOOOOOOOOOOO",
    ],
    "four": [
        "....OOOOOOOOOO....",
        "..OO1112222223OO..",
        ".O111222222223kkO.",
        "O11222222222233kkO",
        "O12222OOOOO2233kkO",
        "O1222OoyyyoO233kkO",
        "O1222OyYYyoO233kkO",
        "O1222OoyyyoO233kkO",
        "O33333333333334kkO",
        "OOOOOOOOOOOOOOOOOO",
    ],
    "pierre_runique": [
        "..OOOO..",
        ".O1122O.",
        "O112223O",
        "O12r223O",
        "O1rRr23O",
        "O12r223O",
        "O122234O",
        "O12r234O",
        "O1rr234O",
        "O122234O",
        "O222344O",
        "OOOOOOOO",
    ],
    "epouvantail": [
        "....OOOO......",
        "...OooooO.....",
        "..OOOOOOOO....",
        "...OeeeeO.....",
        "...OeOeOO.....",
        "....OeeO......",
        "OOOOOdOOOOOO..",
        "OxxxxdxxxxxO..",
        "OOOxxdxxxOOO..",
        "...OxdxxO.....",
        "...OcdccO.....",
        "....OdO.......",
        "....OdO.......",
        "....OdO.......",
        "....OdO.......",
        "....OOO.......",
    ],
}


def small(name):
    img = sprite_ascii([r.ljust(max(len(x) for x in SMALL[name]), ".") for r in SMALL[name]])
    return sb.with_ground_shadow(img, rx=img.width * 0.42, ry=1.6)


def arch():
    """Arche de la Lisière : deux poteaux, linteau, lanternes."""
    w, h = 64, 48
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    for x0 in (4, w - 10):
        for y in range(10, h - 1):
            for x in range(x0, x0 + 6):
                px[x, y] = P["earth2"] if x < x0 + 3 else P["earth3"]
    for y in range(6, 12):
        for x in range(0, w):
            px[x, y] = P["earth2"] if y < 9 else P["earth3"]
    for x in range(10, w - 10, 6):                               # guirlande
        sag = 2 if (x // 6) % 2 else 3
        px[x, 13 + sag] = P["sun1"]
        px[x + 1, 13 + sag] = P["sun0"]
    for x0 in (2, w - 8):                                        # lanternes
        for y in range(14, 20):
            for x in range(x0, x0 + 6):
                px[x, y] = P["sun1"] if y < 18 else P["sun2"]
    for x in range(14, w - 14):                                  # feuillage sur le linteau
        if (x * 7) % 5 < 3:
            px[x, 4] = P["leaf2"]
            px[x, 5] = P["leaf3"]
    sb.outline(img)
    return img


def bridge():
    """Pont en bois (posé au sol, sous les personnages), planches transversales."""
    w, h = 4 * T, 5 * T
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    for y in range(0, h):
        for x in range(6, w - 6):
            c = P["earth1"] if (y // 4) % 2 == 0 else P["earth2"]
            if y % 4 == 3:
                c = P["earth3"]
            if x > w - 14:
                c = P["earth2"] if c == P["earth1"] else P["earth3"]
            px[x, y] = c
    for y in range(0, h):                                        # garde-corps
        for x in (2, 3, 4, 5, w - 6, w - 5, w - 4, w - 3):
            px[x, y] = P["earth3"] if x < w // 2 else P["earth4"]
        if y % 16 in (0, 1, 2):
            for x in (1, 2, 3, 4, 5, 6, w - 7, w - 6, w - 5, w - 4, w - 3, w - 2):
                px[x, y] = P["earth4"]
    sb.outline(img)
    return img


# --------------------------------------------------------------------------- arbres
def tree_variants():
    out = {}
    for i, seed in enumerate((1, 2, 3)):
        out[f"arbre_aube_{'abc'[i]}"] = sb.tree(seed)
    for i, seed in enumerate((4, 5, 6)):
        out[f"arbre_sombre_{'abc'[i]}"] = sb.tree(seed, palette=("leaf2", "leaf3", "leaf4", "leaf5"))
    out["arbre_fruitier"] = fruit_tree(7)
    out["buisson_a"] = sb.bush(7)
    out["buisson_b"] = sb.bush(8)
    out["buisson_sombre"] = dark_bush(9)
    return out


def fruit_tree(seed):
    img = sb.tree(seed, w=24, h=32)
    px = img.load()
    rng = random.Random(seed)
    for _ in range(7):
        x, y = rng.randint(5, 18), rng.randint(5, 16)
        if px[x, y][3] == 255 and px[x, y] != O:
            px[x, y] = P["red0"]
    return img


def dark_bush(seed):
    img = sb.bush(seed)
    px = img.load()
    swap = {P["leaf1"]: P["leaf2"], P["leaf2"]: P["leaf3"], P["leaf3"]: P["leaf4"], P["red0"]: P["leaf3"]}
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y] in swap:
                px[x, y] = swap[px[x, y]]
    return img


# --------------------------------------------------------------------------- PNJ (variantes du joueur)
NPC_KEYS = {
    "yvenne_ancienne": {"H": P["stone1"], "L": P["stone0"], "h": P["stone2"],
                        "T": P["wine"], "t": P["shade1"], "B": P["sun2"], "G": P["sun1"],
                        "P": P["wine"], "p": P["shade1"]},
    "aldric_aubergiste": {"H": P["earth3"], "L": P["earth2"], "h": P["earth4"],
                          "T": P["sun0"], "t": P["earth1"], "B": P["red1"], "G": P["red0"]},
    "garin_pecheur": {"H": P["earth4"], "L": P["earth3"], "h": P["outline"],
                      "T": P["water3"], "t": P["water4"], "B": P["earth2"], "G": P["water1"]},
    "thessaly": {"H": P["red0"], "L": P["sun3"], "h": P["red1"],
                 "T": P["leaf2"], "t": P["leaf3"], "B": P["earth3"], "G": P["sun1"]},
}


def npc(template_id):
    keys = dict(sb.KEYS_CHAR)
    keys.update(NPC_KEYS[template_id])
    return sb.bounce_frames(sb.from_ascii(sb.PLAYER_DOWN, keys), (0, 0, -1, -1))


# --------------------------------------------------------------------------- tuiles de champs
def field_tiles():
    img = Image.new("RGBA", (T * 2, T * 2))
    px = img.load()
    for v in range(2):
        for y in range(T):
            for x in range(T):
                # blé : rangs de terre retournée + épis
                row = y % 4
                if row == 3:
                    c = P["earth2"]
                else:
                    c = P["sun2"] if (x + v * 3 + y) % 5 else P["sun1"]
                    if row == 0 and (x + v) % 3 == 0:
                        c = P["sun3"]
                px[v * T + x, y] = c
                # herbes médicinales : rangs verts sur terre
                if y % 4 == 3:
                    c = P["earth3"]
                elif y % 4 == 0:
                    c = P["earth2"]
                else:
                    c = P["leaf2"] if (x + v * 2) % 4 else (P["leaf0"] if y % 4 == 1 else P["leaf3"])
                    if (x * 5 + y * 3 + v) % 13 == 0:
                        c = P["shade0"]                      # fleur violette
                px[v * T + x, T + y] = c
    return img


# --------------------------------------------------------------------------- export
OUT = sb.OUT


def main():
    sb.main()                      # tuiles + planche de style (ajoutées au manifeste)
    sv = sb.save
    import buildings as bk                                       # kit de construction v2
    for rel, fn in bk.ALL.items():
        sv(fn(), f"props/{rel}.png")
    import props_v2                                              # étal, puits, pont v2
    for rel, fn in props_v2.ALL.items():
        sv(fn(), f"props/{rel}.png")
    sv(autel(), "props/ruines/autel_ventes.png")
    sv(lantern(), "props/village/lanterne.png")
    sv(fence_h(), "props/village/cloture_h.png")
    sv(fence_v(), "props/village/cloture_v.png")
    sv(arch(), "props/village/arche_lisiere.png")
    for name in SMALL:
        sv(small(name), f"props/objets/{name}.png")
    for name, img in tree_variants().items():
        sv(img, f"props/vegetation/{name}.png")
    sv(sb.reeds(9), "props/vegetation/roseaux_a.png")
    sv(sb.reeds(10), "props/vegetation/roseaux_b.png")
    for i, s in enumerate((12, 13, 14)):
        sv(sb.flowers(s), f"props/vegetation/fleurs_{'abc'[i]}.png")
    sv(sb.rock(), "props/commun/rocher.png")
    for tid in NPC_KEYS:
        sv(npc(tid), f"characters/npcs/{tid}_idle.png")
    sv(field_tiles(), "tiles/floor_1/ground_fields.png")
    import lisiere_assets                                        # Sentier de la Lisière
    lisiere_assets.main(standalone=False)
    sb.write_manifest()
    print(f"OK - {len(sb.SAVED)} assets au total")


if __name__ == "__main__":
    main()
