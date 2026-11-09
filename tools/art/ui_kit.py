"""Kit d'interface « laiton d'aube » (étage 1) : cadres 9-slice, barres, chatons, icônes, marqueurs.

Direction (docs/art_direction.md, section Interface) :
  - panneaux de jeu : pierre de crépuscule (prune sombre) sertie de laiton doré biseauté,
    rivets en disque solaire — la lumière d'aube qui ne bouge jamais ;
  - dialogues : parchemin du village, encre brune ;
  - Carnet : carnet relié de cuir, pages de parchemin, onglets en rubans ;
  - compétences : chatons de pierre architecte cerclés d'or ; le cyan reste réservé aux runes.
Tout est dessiné au pixel, palette verrouillée, lumière haut-gauche.
Usage : python tools/art/ui_kit.py   (sorties : assets/art/ui/, aperçu art/preview/ui_kit.png)
"""
import math
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, CLEAR  # noqa: E402
import styleboard as sb  # noqa: E402

O = P["outline"]
PLUM = (42, 26, 46, 238)        # intérieur des panneaux (contour, légèrement transparent)
PLUM2 = (58, 38, 62, 245)


def img(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def rect(im, x, y, w, h, c):
    px = im.load()
    for yy in range(max(0, y), min(im.height, y + h)):
        for xx in range(max(0, x), min(im.width, x + w)):
            px[xx, yy] = c


def put(im, pts, c):
    for x, y in pts:
        if 0 <= x < im.width and 0 <= y < im.height:
            im.putpixel((x, y), c)


def bevel(im, x, y, w, h, light, mid, dark, width=1):
    """Cadre biseauté : haut/gauche clair, bas/droite sombre."""
    for i in range(width):
        rect(im, x + i, y + i, w - 2 * i, 1, light)
        rect(im, x + i, y + i, 1, h - 2 * i, light)
        rect(im, x + i, y + h - 1 - i, w - 2 * i, 1, dark)
        rect(im, x + w - 1 - i, y + i, 1, h - 2 * i, dark)
    put(im, [(x + w - 1, y), (x, y + h - 1)], mid)


def sun_rivet(im, cx, cy):
    put(im, [(cx, cy - 2), (cx - 2, cy), (cx + 2, cy), (cx, cy + 2)], P["sun3"])     # rayons
    rect(im, cx - 1, cy - 1, 3, 3, P["sun2"])
    put(im, [(cx - 1, cy - 1), (cx, cy - 1), (cx - 1, cy)], P["sun0"])
    put(im, [(cx + 1, cy + 1)], P["sun3"])


# --------------------------------------------------------------------------- cadres 9-slice
def frame_dark(w=32, h=32):
    """Panneau principal : pierre de crépuscule sertie de laiton. Marge 9-slice : 8."""
    im = img(w, h)
    rect(im, 0, 0, w, h, O)
    rect(im, 1, 1, w - 2, h - 2, P["sun3"])
    bevel(im, 1, 1, w - 2, h - 2, P["sun1"], P["sun2"], P["earth3"])
    bevel(im, 2, 2, w - 4, h - 4, P["sun2"], P["sun2"], P["sun3"])
    rect(im, 3, 3, w - 6, h - 6, O)
    rect(im, 4, 4, w - 8, h - 8, PLUM)
    rect(im, 4, 4, w - 8, 1, PLUM2)                       # reflet intérieur haut
    for cx, cy in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):
        rect(im, cx - 2, cy - 2, 5, 5, O)
        sun_rivet(im, cx, cy)
    return im


def plate(w=16, h=16):
    """Plaque fine (cadre de cible, bandeau de zone). Marge : 4."""
    im = img(w, h)
    rect(im, 0, 0, w, h, O)
    bevel(im, 1, 1, w - 2, h - 2, P["sun1"], P["sun2"], P["sun3"])
    rect(im, 2, 2, w - 4, h - 4, PLUM)
    return im


def parchment(w=32, h=32):
    """Parchemin de dialogue, bords teintés, coins roulés. Marge : 8."""
    im = img(w, h)
    rect(im, 1, 0, w - 2, h, O)
    rect(im, 0, 1, w, h - 2, O)
    rect(im, 1, 1, w - 2, h - 2, P["earth1"])
    rect(im, 2, 2, w - 4, h - 4, P["earth0"])
    rect(im, 3, 3, w - 6, h - 6, P["sun0"])
    rect(im, 3, 3, w - 6, 1, P["earth0"])
    # coins roulés
    for cx, cy, sx, sy in ((2, 2, 1, 1), (w - 3, 2, -1, 1), (2, h - 3, 1, -1), (w - 3, h - 3, -1, -1)):
        put(im, [(cx, cy), (cx + sx, cy), (cx, cy + sy)], P["earth2"])
        put(im, [(cx + sx, cy + sy)], P["earth1"])
    return im


def book(w=40, h=40):
    """Carnet relié : cuir cousu, pages de parchemin. Marge : 11."""
    im = img(w, h)
    rect(im, 0, 0, w, h, O)
    rect(im, 1, 1, w - 2, h - 2, P["earth3"])
    bevel(im, 1, 1, w - 2, h - 2, P["earth2"], P["earth3"], P["earth4"])
    for i in range(4, w - 4, 3):                            # couture dorée
        put(im, [(i, 3), (i, h - 4)], P["sun3"])
    for i in range(4, h - 4, 3):
        put(im, [(3, i), (w - 4, i)], P["sun3"])
    rect(im, 5, 5, w - 10, h - 10, O)
    rect(im, 6, 6, w - 12, h - 12, P["earth1"])
    rect(im, 7, 7, w - 14, h - 14, P["sun0"])
    rect(im, 7, 7, w - 14, 1, P["earth0"])
    for cx, cy in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):   # coins de laiton
        rect(im, cx - 2, cy - 2, 5, 5, O)
        sun_rivet(im, cx, cy)
    return im


def button(state="normal", w=16, h=14):
    """Bouton de laiton. Marge : 4."""
    im = img(w, h)
    rect(im, 1, 0, w - 2, h, O)
    rect(im, 0, 1, w, h - 2, O)
    face = {"normal": (P["sun1"], P["sun2"], P["sun3"]), "hover": (P["sun0"], P["sun1"], P["sun2"]),
            "pressed": (P["sun3"], P["sun2"], P["sun1"]), "disabled": (P["stone1"], P["stone2"], P["stone3"])}[state]
    rect(im, 1, 1, w - 2, h - 2, face[1])
    rect(im, 1, 1, w - 2, 1, face[0])
    rect(im, 1, h - 2, w - 2, 1, face[2])
    rect(im, 1, 1, 1, h - 2, face[0] if state != "pressed" else face[2])
    rect(im, w - 2, 1, 1, h - 2, face[2] if state != "pressed" else face[0])
    return im


def tab(active, w=16, h=14):
    """Onglet ruban. Actif : parchemin qui prolonge la page. Inactif : cuir sombre. Marge : 4."""
    im = img(w, h)
    rect(im, 1, 0, w - 2, h, O)
    rect(im, 0, 1, w, h - 1, O)
    if active:
        rect(im, 1, 1, w - 2, h - 1, P["sun0"])
        rect(im, 1, 1, w - 2, 1, P["sun1"])
        rect(im, 1, 2, w - 2, 1, P["sun2"])
    else:
        rect(im, 1, 1, w - 2, h - 2, P["earth3"])
        rect(im, 1, 1, w - 2, 1, P["earth2"])
        rect(im, 1, h - 2, w - 2, 1, P["earth4"])
    return im


# --------------------------------------------------------------------------- barres
def bar_frame(w=12, h=9):
    im = img(w, h)
    rect(im, 0, 0, w, h, O)
    rect(im, 1, 1, w - 2, h - 2, (74, 52, 80, 255))
    rect(im, 1, 1, w - 2, 1, (42, 26, 46, 255))
    return im


def bar_fill(kind, h=7):
    ramps = {"hp": (P["red0"], P["red0"], P["red1"]), "mana": (P["blue0"], P["blue0"], P["blue1"]),
             "xp": (P["sun1"], P["sun2"], P["sun3"]), "foe": (P["red0"], P["red1"], P["wine"])}[kind]
    im = img(4, h)
    for y in range(h):
        c = ramps[0] if y < h * 0.35 else ramps[1] if y < h * 0.7 else ramps[2]
        rect(im, 0, y, 4, 1, c)
    hi = {"hp": (255, 160, 140, 255), "mana": (150, 168, 240, 255), "xp": P["sun0"], "foe": (240, 130, 115, 255)}[kind]
    rect(im, 0, 0, 4, 1, hi)                                 # filet de lumière
    return im


# --------------------------------------------------------------------------- chatons & médaillon
def slot(size=30, big=False):
    """Chaton de compétence : pierre architecte octogonale, cercle d'or."""
    im = img(size, size)
    cut = 6 if big else 4

    def inside(x, y, m):
        return (m <= x < size - m and m <= y < size - m
                and x + y >= cut + 2 * m - 1 and (size - 1 - x) + y >= cut + 2 * m - 1
                and x + (size - 1 - y) >= cut + 2 * m - 1 and (size - 1 - x) + (size - 1 - y) >= cut + 2 * m - 1)

    px = im.load()
    for y in range(size):
        for x in range(size):
            if inside(x, y, 0):
                px[x, y] = O
            if inside(x, y, 1):
                d = (x + y) / (2 * size)
                px[x, y] = P["sun1"] if d < 0.42 else P["sun2"] if d < 0.6 else P["sun3"]
            if inside(x, y, 2):
                px[x, y] = O
            if inside(x, y, 3):
                d = (x + y) / (2 * size)
                px[x, y] = P["stone3"] if d < 0.45 else P["stone4"]
            if inside(x, y, 4):
                px[x, y] = PLUM2[:3] + (255,)
    if big:
        for cx, cy in ((size // 2, 2), (size // 2, size - 3), (2, size // 2), (size - 3, size // 2)):
            put(im, [(cx, cy)], P["sun0"])
    return im


def medallion():
    """Disque solaire du niveau : rayons d'or, centre de crépuscule."""
    s = 28
    im = img(s, s)
    c = (s - 1) / 2
    px = im.load()
    for y in range(s):
        for x in range(s):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            ray = 12.5 + 1.5 * (1 if int((a + math.pi) / (math.tau / 16)) % 2 == 0 else 0)
            if r <= ray:
                px[x, y] = O
            if r <= ray - 1:
                light = (dx + dy) / (2 * c)
                px[x, y] = P["sun1"] if light < -0.15 else P["sun2"] if light < 0.25 else P["sun3"]
            if r <= 9.5:
                px[x, y] = O
            if r <= 8.5:
                px[x, y] = PLUM2[:3] + (255,)
    put(im, [(9, 7), (10, 6), (11, 6)], P["sun0"])
    return im


# --------------------------------------------------------------------------- icônes 16x16
ICON_KEYS = {"O": O, "Y": P["sun0"], "y": P["sun1"], "o": P["sun2"], "h": P["sun3"],
             "S": P["skin0"], "s": P["skin1"], "w": P["earth1"], "W": P["earth2"], "d": P["earth3"],
             "D": P["earth4"], "l": P["leaf1"], "g": P["leaf2"], "G": P["leaf3"], "x": P["red0"],
             "X": P["red1"], "1": P["stone0"], "2": P["stone1"], "3": P["stone2"], "c": P["blue0"],
             "C": P["blue1"], "L": P["leaf0"]}

ICONS = {
    "frappe": [            # poing serré
        "................",
        "................",
        "....OOOOOOO.....",
        "...OSSOSSOSO....",
        "..OSSSOSSOSSO...",
        "..OSSSOSSOSsO...",
        "..OSSSSSSSSsOO..",
        "..OsSSSSSSSsSsO.",
        "..OsSSSSSSSSSsO.",
        "..OssSSSSSSSssO.",
        "...OssSSSSsssO..",
        "....OOssssOOO...",
        ".....OCCCCO.....",
        ".....OCcCCO.....",
        ".....OOOOOO.....",
        "................",
    ],
    "attaque": [           # poing de face, plus gros (bouton A, mains nues)
        "................",
        "...OOOOOOOOO....",
        "..OSSOSSOSSOO...",
        ".OSSSOSSOSSOSO..",
        ".OSSSOSSOSSOSO..",
        ".OSSSSSSSSSSsO..",
        ".OsSSSSSSSSSsOO.",
        ".OsSSSSSSSSSsSsO",
        ".OssSSSSSSSSSSsO",
        "..OssSSSSSSSssO.",
        "...OssssssssOO..",
        "....OOOOOOOO....",
        "....OCCCCCCO....",
        "....OCcCCCCO....",
        "....OOOOOOOO....",
        "................",
    ],
    "trait_de_lumiere": [  # trait d'or lancé en diagonale
        "................",
        "............OOO.",
        "...........OYYO.",
        "..........OYyO..",
        ".........OYyO...",
        "........OYyO....",
        ".......OYyO.....",
        "......OYyO......",
        ".....OYyO.......",
        "....OyyO........",
        "...OyoO..O......",
        "..OooO..OyO.....",
        ".OohO....O..O...",
        ".OhO.......OyO..",
        "..O.........O...",
        "................",
    ],
    "premiers_soins": [    # feuille de soin et étincelle
        "................",
        "..........O.....",
        ".........OYO....",
        "....OOO...O.....",
        "...OllgOO.......",
        "..OlLlgggO......",
        "..OlllgggGO.....",
        ".OlllggggGO.....",
        ".OllgggggGO.....",
        ".OlggggGGGO.....",
        "..OgggGGGO......",
        "..OGgGGGO.......",
        "...OOGOO........",
        ".....OdO........",
        "......OdO.......",
        ".......OO.......",
    ],
    "coup_puissant": [     # poing + éclats d'impact rouges
        "...x.......x....",
        "....x.....x.....",
        "................",
        "x...OOOOOOO...x.",
        "...OSSOSSOSO....",
        "..OSSSOSSOSSO...",
        "..OSSSSSSSSsOO..",
        "..OsSSSSSSSsSsO.",
        "..OsSSSSSSSSSsO.",
        "..OssSSSSSSSssO.",
        "...OssSSSSsssO..",
        "....OOssssOOO...",
        ".....OXXXXO.....",
        ".....OXxXXO.....",
        ".....OOOOOO.....",
        "................",
    ],
    "eclat_d_aube": [      # soleil qui éclate
        ".......O........",
        ".......y........",
        "..y....y....y...",
        "...y..OOO..y....",
        "....OOyyyOO.....",
        "...OyYYYyyoO....",
        "...OyYYyyyoO....",
        "OyyOyYyyyooOyyO.",
        "...OyyyyoooO....",
        "...OoyyooohO....",
        "....OOoohOO.....",
        "...y..OOO..y....",
        "..y....y....y...",
        ".......y........",
        ".......O........",
        "................",
    ],
    "croc_dore": [         # croc d'ivoire serti d'une bague d'or
        "................",
        "....OOOOOOO.....",
        "...OyYyyyooO....",
        "...OhhhhhhhO....",
        "....O11112O.....",
        "....O11112O.....",
        ".....O1112O.....",
        ".....O1112O.....",
        "......O112O.....",
        "......O112O.....",
        ".......O12O.....",
        ".......O12O.....",
        "........O2O.....",
        "........OO......",
        "................",
        "................",
    ],    "lame_d_aube": [       # lame courte enveloppée de lumière
        "............OO..",
        "...........OYYO.",
        "..........OY1YO.",
        ".........OY12O..",
        "........OY12O...",
        ".......OY12O....",
        "......OY12O.....",
        "..O..OY12O......",
        "..OOOY12O.......",
        "...OhO2O........",
        "...OohOO........",
        "..OdOOhO........",
        ".OdO..OO........",
        "OdO.............",
        "OO..............",
        "................",
    ],
    "carnet": [            # carnet relié
        "................",
        "..OOOOOOOOOOO...",
        "..OdWWWWWWWWdO..",
        "..OdWWWWWWWWdO..",
        "..OdWoooooWWdO..",
        "..OdWoYYYoWWdO..",
        "..OdWoooooWWdO..",
        "..OdWWWWWWWWdO..",
        "..OdWWWWWWWWdO..",
        "..OdWWWWWWWWdO..",
        "..OdWWWWWWWWdO..",
        "..OdddddddddhO..",
        "..OYYYYYYYYYYO..",
        "..OOOOOOOOOOOX..",
        ".............X..",
        "................",
    ],
    "or": [                # pièce
        "................",
        ".....OOOOO......",
        "....OyYYyoO.....",
        "...OyYyyyooO....",
        "...OYyoooohO....",
        "...OyyoyoohO....",
        "...OyoooohhO....",
        "....OoohhhO.....",
        ".....OOOOO......",
        "................",
    ],
    "menu": [              # trois barres de laiton
        "................",
        "................",
        "...OOOOOOOOOO...",
        "..OyYYYYYYYyoO..",
        "...OOOOOOOOOO...",
        "................",
        "...OOOOOOOOOO...",
        "..OyYYYYYYYyoO..",
        "...OOOOOOOOOO...",
        "................",
        "...OOOOOOOOOO...",
        "..OyYYYYYYYyoO..",
        "...OOOOOOOOOO...",
        "................",
    ],
    "quete": [             # parchemin roulé
        "................",
        "...OOOOOOOOO....",
        "..OwYYYYYYYwO...",
        "..OwYDDDDDYwO...",
        "...OYYYYYYYO....",
        "...OYDDDDYYO....",
        "...OYYYYYYYO....",
        "..OwYYYYYYYwO...",
        "..OOOOOOOOOOO...",
        "................",
    ],
}


def icon(name):
    rows = ICONS[name]
    w = max(len(r) for r in rows)
    out = img(16, 16)
    out.alpha_composite(sb.from_ascii([r.ljust(w, ".") for r in rows], ICON_KEYS), (0, (16 - len(rows)) // 2))
    return out


# icônes de caractéristiques (12x12) pour la fiche du Carnet
STAT_ICONS = {
    "hp": [                # coeur
        "............",
        "..OO...OO...",
        ".OxxO.OxxO..",
        "OxYxxOxxxXO.",
        "OxxxxxxxxXO.",
        "OxxxxxxxXXO.",
        ".OxxxxxXXO..",
        "..OxxxXXO...",
        "...OxXXO....",
        "....OXO.....",
        ".....O......",
        "............",
    ],
    "atk": [               # épée
        "..........OO",
        ".........O1O",
        "........O12O",
        ".......O12O.",
        "......O12O..",
        "..O..O12O...",
        "..OOO12O....",
        "...OhO2O....",
        "...OohO.....",
        "..OdOOhO....",
        ".OdO..O.....",
        "OdO.........",
    ],
    "def": [               # bouclier de pierre cerclé d'or
        "............",
        ".OOOOOOOOO..",
        ".Oy11122hO..",
        ".Oy12223hO..",
        ".Oy12233hO..",
        ".Oy22233hO..",
        "..Oy2233O...",
        "..Oy2333O...",
        "...Oy33O....",
        "....OyO.....",
        ".....O......",
        "............",
    ],
    "agi": [               # plume
        "..........O.",
        ".........OlO",
        "........OllO",
        ".......OlLlO",
        "......OlLlO.",
        ".....OlLlgO.",
        "....OlLlgO..",
        "...OlLggO...",
        "...OlggO....",
        "..OOggO.....",
        ".OO.OO......",
        "OO..........",
    ],
    "int": [               # étoile de savoir
        ".....O......",
        "....OcO.....",
        "....OcO.....",
        "OOOOOcOOOOO.",
        ".OccYccccCO.",
        "..OcccccCO..",
        "..OccCccCO..",
        ".OcCO.OCcO..",
        ".OCO...OCO..",
        ".OO.....OO..",
        "............",
        "............",
    ],
    "sag": [               # goutte de source (soins, régénération)
        ".....O......",
        "....ObO.....",
        "....ObO.....",
        "...ObbBO....",
        "..ObbbBBO...",
        ".ObYbbBBnO..",
        ".ObbbbBBnO..",
        ".ObbbBBnnO..",
        "..ObBBnnO...",
        "...OOOOO....",
        "............",
        "............",
    ],
}


def stat_icon(name):
    keys = dict(ICON_KEYS)
    keys.update({"b": P["water1"], "B": P["water2"], "n": P["water3"]})
    return sb.from_ascii(STAT_ICONS[name], keys)


# --------------------------------------------------------------------------- marqueurs (au-dessus des PNJ)
def marker(kind):
    rows = {
        "quest": ["OOOO", "OYyO", "OyoO", "OyoO", "OyoO", "OyhO", "OOOO", "....", "OOOO", "OyhO", "OOOO"],
        "turnin": [".OOOO.", "OyYYyO", "OyOOyO", "OOOyoO", "..OyoO", ".OyoO.", ".OoO..", ".OOO..", ".OOO..", "OyyoO.", ".OOO.."],
        "active": ["............", ".OO..OO..OO.", "O12OO12OO12O", "O23OO23OO23O", ".OO..OO..OO."],
        "alert": ["OOOOO", "OxYxO", "OxxXO", "OxxXO", "OxxXO", ".OxO.", ".OOO.", ".....", ".OOO.", ".OxO.", ".OOO."],
    }[kind if kind != "locked" else "quest"]
    keys = dict(ICON_KEYS)
    if kind == "alert":
        keys.update({"Y": P["skin0"], "x": P["red0"], "X": P["red1"]})
    if kind == "locked":
        keys.update({"Y": P["stone0"], "y": P["stone1"], "o": P["stone2"]})
    return sb.from_ascii([r.ljust(max(len(x) for x in rows), ".") for r in rows], keys)


ALL = {
    "ui/frame_dark": frame_dark, "ui/plate": plate, "ui/parchment": parchment, "ui/book": book,
    "ui/button": lambda: button("normal"), "ui/button_hover": lambda: button("hover"),
    "ui/button_pressed": lambda: button("pressed"), "ui/button_disabled": lambda: button("disabled"),
    "ui/tab_active": lambda: tab(True), "ui/tab_inactive": lambda: tab(False),
    "ui/bar_frame": bar_frame, "ui/bar_hp": lambda: bar_fill("hp"), "ui/bar_mana": lambda: bar_fill("mana"),
    "ui/bar_xp": lambda: bar_fill("xp", 4), "ui/bar_foe": lambda: bar_fill("foe", 5),
    "ui/slot": lambda: slot(30), "ui/slot_big": lambda: slot(42, big=True), "ui/medallion": medallion,
    "ui/marker_quest": lambda: marker("quest"), "ui/marker_turnin": lambda: marker("turnin"),
    "ui/marker_active": lambda: marker("active"), "ui/marker_locked": lambda: marker("locked"),
    "ui/marker_alert": lambda: marker("alert"),
}
for _n in ICONS:
    ALL[f"ui/icons/{_n}"] = (lambda n=_n: icon(n))
for _n in STAT_ICONS:
    ALL[f"ui/icons/stat_{_n}"] = (lambda n=_n: stat_icon(n))


def preview(out):
    imgs = [(k, fn()) for k, fn in ALL.items()]
    cols, cell = 8, 56
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), P["leaf3"])
    for i, (_, im) in enumerate(imgs):
        s = 1 if im.width > 40 else 2 if im.width > 20 else 3
        im = im.resize((im.width * s, im.height * s), Image.NEAREST)
        sheet.alpha_composite(im, ((i % cols) * cell + (cell - im.width) // 2, (i // cols) * cell + (cell - im.height) // 2))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)


def main():
    for rel, fn in ALL.items():
        sb.save(fn(), f"{rel}.png")


if __name__ == "__main__":
    main()
    preview(sb.PREVIEW / "ui_kit.png")
    print(sb.PREVIEW / "ui_kit.png")
