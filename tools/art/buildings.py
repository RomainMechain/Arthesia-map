"""Kit de construction de bâtiments (vue 3/4, lumière haut-gauche) — v2.

Remplace le bâtiment « boîte + couvercle » par de vrais éléments d'architecture :
toits en volume (rangs, faîtage, débord, ombre portée), pignons, étage en encorbellement,
lucarnes, porche, volets, jardinières, lierre, soubassement en pierre.
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, CLEAR  # noqa: E402
import styleboard as sb  # noqa: E402

T = 16

# matériaux de toit : 5 niveaux (très sombre -> reflet)
ROOF = {
    "tuile": [P["shade1"], P["wine"], P["red1"], P["red0"], P["red0"]],
    "chaume": [P["earth3"], P["earth2"], P["sun3"], P["sun2"], P["sun1"]],
    "ardoise": [P["outline"], P["stone4"], P["stone3"], P["stone2"], P["stone1"]],
    "ardoise_bleue": [P["outline"], P["shade1"], P["blue1"], P["blue0"], P["blue0"]],
    "lie": [P["outline"], P["shade1"], P["wine"], P["shade0"], P["shade0"]],
    "dalle": [P["stone3"], P["stone2"], P["stone1"], P["stone0"], P["stone0"]],
}
# matériaux de mur : base, clair, ombre, colombage, colombage sombre
WALL = {
    "torchis": [P["earth0"], P["sun0"], P["earth1"], P["earth3"], P["earth4"]],
    "pierre": [P["stone1"], P["stone0"], P["stone2"], P["stone3"], P["stone4"]],
    "bois": [P["earth2"], P["earth1"], P["earth3"], P["earth4"], P["outline"]],
}
DARKER = {}
for chain in (ROOF["chaume"], ROOF["tuile"], ROOF["ardoise"],
              [P["outline"], P["shade1"], P["blue1"], P["blue0"]],
              [P["outline"], P["shade1"], P["wine"], P["shade0"]],
              [P["earth4"], P["earth3"], P["earth2"], P["earth1"], P["earth0"], P["sun0"]],
              [P["stone4"], P["stone3"], P["stone2"], P["stone1"], P["stone0"]],
              [P["leaf5"], P["leaf4"], P["leaf3"], P["leaf2"], P["leaf1"]]):
    for i in range(1, len(chain)):
        DARKER.setdefault(chain[i], chain[i - 1])


class Canvas:
    def __init__(self, w, h, seed=0):
        self.img = Image.new("RGBA", (w, h), CLEAR)
        self.px = self.img.load()
        self.w, self.h = w, h
        self.rng = random.Random(seed)

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        return self.px[x, y] if 0 <= x < self.w and 0 <= y < self.h else CLEAR

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.set(x, y, c)

    def darken(self, x, y, steps=1):
        c = self.get(x, y)
        for _ in range(steps):
            c = DARKER.get(c, c)
        if c[3]:
            self.set(x, y, c)


# --------------------------------------------------------------------------- murs
def wall(cv, x0, x1, y0, y1, mat="torchis", timber=True, braces=True, foundation=4):
    base, lite, shade, tim, tim_d = WALL[mat]
    w = x1 - x0
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = base if x < x0 + w * 0.72 else shade
            r = cv.rng.random()
            if mat == "torchis" and r < 0.03:
                c = lite if c == base else base
            if mat == "bois":
                if (x - x0) % 5 == 4:
                    c = tim                                  # joint entre planches
                elif _h(x // 5, y // 9, 4) < 0.15 and (x - x0) % 5 == 2 and (y % 9) == 4:
                    c = tim_d                                # nœud du bois
            if mat == "pierre":
                row = (y - y0) // 5
                if (y - y0) % 5 == 4 or (x + row * 4) % 9 == 0:
                    c = tim
                elif (y - y0) % 5 == 0 and c == base:
                    c = lite
            cv.set(x, y, c)
    if timber and mat == "torchis":
        posts = [x0, x1 - 2] + list(range(x0 + 22, x1 - 12, 22))
        for px_ in posts:
            cv.rect(px_, y0, px_ + 2, y1 - foundation, tim)
            cv.rect(px_ + 1, y0, px_ + 2, y1 - foundation, tim_d)
        cv.rect(x0, y0, x1, y0 + 2, tim)                    # sablière
        cv.rect(x0, y0 + 1, x1, y0 + 2, tim_d)
        if braces:                                           # croix de Saint-André
            for a, b in zip(posts[:-1], posts[1:]):
                if b - a < 14 or cv.rng.random() < 0.4:
                    continue
                span = y1 - foundation - (y0 + 2)
                for i in range(span):
                    xa = a + 2 + int(i * (b - a - 2) / span)
                    xb = b - 1 - int(i * (b - a - 2) / span)
                    cv.set(xa, y0 + 2 + i, tim)
                    cv.set(xb, y0 + 2 + i, tim)
    # soubassement en pierre
    for y in range(y1 - foundation, y1):
        for x in range(x0, x1):
            k = (y - (y1 - foundation))
            c = P["stone1"] if x < x0 + w * 0.72 else P["stone2"]
            if k == 0:
                c = P["stone0"] if x < x0 + w * 0.72 else P["stone1"]
            if (x + (k // 2) * 3) % 7 == 0 or k == foundation - 1:
                c = P["stone3"]
            cv.set(x, y, c)


def eave_shadow(cv, x0, x1, y, depth=3):
    """Ombre du débord de toit sur le haut du mur."""
    for d in range(depth):
        for x in range(x0, x1):
            if (d < depth - 1) or (x + y) % 2 == 0:
                cv.darken(x, y + d, 2 if d == 0 else 1)


def window(cv, x, y, w=8, h=8, shutters=None, box=True, glow=("sun1", "sun2")):
    cv.rect(x - 1, y - 1, x + w + 1, y + h + 1, P["earth4"])
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            c = P[glow[0]] if (xx - x) + (yy - y) < (w + h) // 2 else P[glow[1]]
            cv.set(xx, yy, c)
    cv.rect(x + w // 2, y, x + w // 2 + 1, y + h, P["earth3"])          # meneau
    cv.rect(x, y + h // 2, x + w, y + h // 2 + 1, P["earth3"])          # traverse
    cv.set(x + 1, y + 1, P["sun0"])                                      # reflet
    cv.rect(x - 2, y + h + 1, x + w + 2, y + h + 2, P["stone0"])        # appui
    if shutters:
        light, dark = shutters
        for sx in (x - 4, x + w + 1):
            cv.rect(sx, y - 1, sx + 3, y + h + 1, light)
            cv.rect(sx + 2 if sx < x else sx, y - 1, (sx + 3) if sx < x else sx + 1, y + h + 1, dark)
            for yy in (y + 1, y + h - 2):
                cv.rect(sx, yy, sx + 3, yy + 1, dark)
    if box:
        cv.rect(x - 1, y + h + 2, x + w + 1, y + h + 5, P["earth3"])
        cv.rect(x - 1, y + h + 4, x + w + 1, y + h + 5, P["earth4"])
        for xx in range(x - 1, x + w + 1):
            cv.set(xx, y + h + 1, P["leaf2"] if xx % 2 else P["leaf3"])
            if xx % 3 == 0:
                cv.set(xx, y + h, P["red0"] if (xx // 3) % 2 else P["sun1"])


def door(cv, cx, y_bot, w=10, h=15, open_=False, double=False):
    x0 = cx - w // 2
    y0 = y_bot - h
    for y in range(y0, y_bot):
        inset = 2 if y == y0 else (1 if y == y0 + 1 else 0)
        for x in range(x0 + inset, x0 + w - inset):
            edge = x in (x0 + inset, x0 + w - inset - 1) or y == y0
            if edge:
                c = P["earth4"]
            elif open_:
                c = P["wine"] if y < y0 + h * 0.45 else (P["red1"] if y < y0 + h * 0.75 else P["sun3"])
            else:
                c = P["earth3"] if (x - x0) % 3 else P["earth4"]
                if double and x == cx:
                    c = P["earth4"]
            cv.set(x, y, c)
    if not open_:
        cv.set(x0 + w - 3, y0 + h // 2 + 1, P["sun1"])
        if double:
            cv.set(cx - 2, y0 + h // 2 + 1, P["sun1"])
    cv.rect(x0 - 2, y_bot, x0 + w + 2, y_bot + 2, P["stone1"])            # marche
    cv.rect(x0 - 2, y_bot + 1, x0 + w + 2, y_bot + 2, P["stone2"])


def wall_lantern(cv, x, y):
    cv.rect(x, y, x + 3, y + 1, P["earth4"])
    cv.rect(x - 1, y + 1, x + 4, y + 5, P["outline"])
    cv.rect(x, y + 2, x + 3, y + 4, P["sun1"])
    cv.set(x, y + 2, P["sun0"])


def ivy(cv, x, y0, y1, seed=0):
    rng = random.Random(seed)
    for y in range(y0, y1):
        spread = int((y - y0) / max(1, y1 - y0) * 5) + 1
        for _ in range(2):
            xx = x + rng.randint(-spread, spread)
            cv.set(xx, y, P["leaf3"] if rng.random() < 0.6 else P["leaf2"])
            if rng.random() < 0.25:
                cv.set(xx, y - 1, P["leaf1"])


def hanging_sign(cv, x, y, icon="chope"):
    cv.rect(x, y, x + 12, y + 1, P["earth4"])                            # potence
    cv.set(x + 2, y + 1, P["earth4"])
    cv.set(x + 9, y + 1, P["earth4"])
    cv.rect(x + 1, y + 2, x + 11, y + 11, P["earth4"])
    cv.rect(x + 2, y + 3, x + 10, y + 10, P["earth2"])
    cv.rect(x + 2, y + 9, x + 10, y + 10, P["earth3"])
    if icon == "chope":
        for (dx, dy) in [(3, 2), (4, 2), (5, 2), (3, 3), (5, 3), (6, 3), (6, 4), (3, 4), (4, 4),
                         (5, 4), (3, 5), (4, 5), (5, 5)]:
            cv.set(x + 2 + dx, y + 2 + dy, P["sun1"])
        cv.set(x + 5, y + 4, P["sun0"])


# --------------------------------------------------------------------------- toits
def _h(x, y, s=0):
    return random.Random(x * 7349 + y * 3571 + s * 911).random()


def roof_level(mat, x, ry, bias=0):
    """Niveau de teinte (0..4) d'un pixel de couverture. ry = ligne depuis le haut du pan."""
    if mat == "chaume":
        # bottes de chaume : rangs de 6 px au bord ondulé, brins verticaux irréguliers
        row_h = 6
        wave = round(math.sin(x / 4.0 + (ry // row_h) * 1.7))   # bord de botte arrondi
        r, k = divmod(ry + wave, row_h)
        lvl = 3 if k == 0 else (1 if k == row_h - 1 else 2)
        n = _h(x, r, 1)
        if 1 <= k <= 4 and n < 0.2:
            lvl -= 1                                   # brin dans l'ombre
        elif k <= 2 and n > 0.86:
            lvl += 1                                   # brin éclairé
        if _h(x // 4, r, 2) < 0.04 and k in (2, 3):
            lvl = 1                                    # touffe de mousse sombre
    else:
        # tuiles écailles de 4 px, rangs décalés, chaque tuile légèrement différente
        r, k = divmod(ry, 4)
        tx = (x + (r % 2) * 2) % 4
        lvl = 2
        if k == 0 and tx in (1, 2):
            lvl = 3                                    # bombé éclairé
        if k == 3 and tx in (0, 3):
            lvl = 1                                    # bord arrondi de la tuile
        if k in (1, 2) and tx == 0:
            lvl = 1                                    # joint
        tile_id = ((x + (r % 2) * 2) // 4, r)
        v = _h(*tile_id, 3)
        if v < 0.12 and lvl == 2:
            lvl = 1
        elif v > 0.9 and lvl == 2:
            lvl = 3
    return lvl + bias


def side_gable_roof(cv, x0, x1, y_top, y_eave, mat="tuile", hip=10):
    """Toit en croupe vu en 3/4 : pan avant, faîtage, croupes coupées aux deux bouts."""
    lv = ROOF[mat]
    w = x1 - x0
    for y in range(y_top, y_eave):
        inset = max(0, hip - (y - y_top))             # croupe : coins supérieurs coupés
        for x in range(x0 + inset, x1 - inset):
            ry = y - (y_top + 3)
            if ry < 0:                                 # faîtage (couvre-joint)
                c = [lv[1], lv[4], lv[2]][y - y_top]
            else:
                rel = (x - x0) / w
                bias = 1 if rel < 0.2 else (-1 if rel > 0.8 else 0)
                # croupes : triangles latéraux, l'un au soleil, l'autre à l'ombre
                in_hip_l = x - x0 < (hip + 2) - (y - y_top) * 0.15 and y - y_top < hip + 6
                in_hip_r = x1 - x <= (hip + 2) - (y - y_top) * 0.15 and y - y_top < hip + 6
                if in_hip_l:
                    bias = 2
                elif in_hip_r:
                    bias = -2
                c = lv[max(0, min(4, roof_level(mat, x, ry, bias)))]
            cv.set(x, y, c)
        if inset < w // 2:                             # arêtiers / rives
            cv.set(x0 + inset, y, lv[0])
            cv.set(x1 - inset - 1, y, lv[0])
    cv.rect(x0, y_eave - 2, x1, y_eave - 1, lv[1])     # bord d'égout
    cv.rect(x0, y_eave - 1, x1, y_eave, lv[0])


def front_gable_roof(cv, x0, x1, y_top, y_wall, apex_h, mat="tuile", gable_mat="torchis"):
    """Toit à pignon sur rue : triangle de pignon en façade, deux pans qui fuient vers l'arrière."""
    lv = ROOF[mat]
    cx = (x0 + x1) // 2
    half = (x1 - x0) // 2
    apex_y = y_wall - apex_h
    s = (half - 3) / apex_h
    hip = 6
    for y in range(y_top, y_wall + 1):
        inset = max(0, hip - (y - y_top))                          # croupe arrière
        for x in range(x0 + inset, x1 - inset):
            left = x < cx
            ry = y - y_top
            lvl = roof_level(mat, x, ry, 1 if left else 0)
            if abs(x + 0.5 - cx) < 1.0:
                lvl = 3 if x < cx else 1                           # arête du faîtage
            cv.set(x, y, lv[max(0, min(4, lvl))])
        if inset:
            cv.set(x0 + inset, y, lv[0])
            cv.set(x1 - inset - 1, y, lv[0])
    # pignon : triangle de mur en façade, bordé de planches de rive
    base, lite, shade, tim, tim_d = WALL[gable_mat]
    for y in range(apex_y, y_wall + 1):
        hw = (y - apex_y) * s
        for x in range(x0 + 3, x1 - 3):
            d = abs(x + 0.5 - cx)
            if d < hw - 2:
                c = base if x < cx + half * 0.3 else shade
                if gable_mat == "torchis" and (abs(x + 0.5 - cx) < 1 or y == y_wall - 6):
                    c = tim
                cv.set(x, y, c)
            elif d < hw + 0.5:
                cv.set(x, y, P["earth3"] if x < cx else P["earth4"])  # planche de rive
            elif d < hw + 1.5:
                cv.set(x, y, P["outline"])
    # oculus dans le pignon
    oy = apex_y + int(apex_h * 0.55)
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx * dx + dy * dy <= 5:
                cv.set(cx + dx, oy + dy, P["earth4"] if dx * dx + dy * dy > 2 else P["sun1"])
    cv.set(cx - 1, oy - 1, P["sun0"])


def chimney(cv, x, y_top, y_bot, w=7, shadow_len=3):
    for y in range(y_top, y_bot):
        for xx in range(x, x + w):
            c = P["stone1"] if xx < x + w - 3 else P["stone2"]
            if (y - y_top) % 4 == 3 or (xx + ((y - y_top) // 4) * 2) % 5 == 0:
                c = P["stone3"]
            cv.set(xx, y, c)
    cv.rect(x - 1, y_top, x + w + 1, y_top + 2, P["stone0"])
    cv.rect(x - 1, y_top + 1, x + w + 1, y_top + 2, P["stone2"])
    for y in range(y_top + 3, y_bot + shadow_len):                    # ombre portée sur le toit
        for d in range(shadow_len):
            cv.darken(x + w + d, y, 1)


def dormer(cv, cx, y_bot, w=14, h=12, mat="chaume"):
    """Lucarne : petit pignon sur le pan de toit, avec fenêtre."""
    x0 = cx - w // 2
    lv = ROOF[mat]
    for x in range(x0 - 1, x0 + w + 3):                                # ombre portée sur le toit
        for y in range(y_bot - h + 4, y_bot + 3):
            if x >= x0 + w - 1 or y >= y_bot:
                cv.darken(x, y, 2)
    cv.rect(x0 + 1, y_bot - 9, x0 + w - 1, y_bot + 1, P["outline"])   # jouées
    wall(cv, x0 + 2, x0 + w - 2, y_bot - 8, y_bot, timber=False, foundation=0)
    window(cv, cx - 3, y_bot - 7, w=6, h=5, box=False)
    top = y_bot - h
    for y in range(top - 1, y_bot - 7):                                 # petit toit à pignon
        hw = (y - top) * (w / 2 + 1) / (h - 8) + 1
        for x in range(x0 - 1, x0 + w + 1):
            d = abs(x + 0.5 - cx)
            if d < hw - 1:
                cv.set(x, y, lv[3] if x < cx else lv[2])
            elif d < hw:
                cv.set(x, y, P["outline"])
    cv.rect(x0 - 1, y_bot - 8, x0 + w + 1, y_bot - 7, P["outline"])


def porch(cv, cx, y_roof, y_ground, w=30, mat="chaume"):
    """Auvent sur poteaux au-dessus de l'entrée."""
    lv = ROOF[mat]
    x0, x1 = cx - w // 2, cx + w // 2
    for y in range(y_roof, y_roof + 7):
        for x in range(x0 - (y - y_roof) // 2, x1 + (y - y_roof) // 2):
            k = (y - y_roof)
            c = lv[4] if k == 0 else (lv[1] if k >= 5 else (lv[3] if x < cx else lv[2]))
            if k in (2, 3) and x % 4 == 0:
                c = lv[1]
            cv.set(x, y, c)
    for px_ in (x0 - 1, x1 - 1):
        cv.rect(px_, y_roof + 7, px_ + 2, y_ground, P["earth3"])
        cv.rect(px_ + 1, y_roof + 7, px_ + 2, y_ground, P["earth4"])
    for x in range(x0 - 3, x1 + 3):
        cv.darken(x, y_roof + 7, 2)


# --------------------------------------------------------------------------- bâtiments
def auberge():
    """Auberge d'Aldric : deux niveaux, étage en encorbellement, chaume, lucarnes, porche, enseigne."""
    W, FOOT_H, EXTRA = 11 * T, 7 * T, 14
    H = FOOT_H + EXTRA
    cv = Canvas(W, H, seed=11)
    gf_top, up_top, roof_eave = H - 30, H - 30 - 24, H - 30 - 24 + 4
    # rez-de-chaussée (pierre) puis étage à colombages légèrement en saillie
    wall(cv, 6, W - 6, gf_top, H - 1, mat="pierre", timber=False, foundation=3)
    wall(cv, 3, W - 3, up_top, gf_top + 1, mat="torchis", foundation=0)
    for x in range(6, W - 6):                                          # ombre de l'encorbellement
        cv.darken(x, gf_top + 1, 2)
        cv.darken(x, gf_top + 2, 1)
    cv.rect(3, gf_top - 1, W - 3, gf_top + 1, P["earth4"])             # poutre de plancher
    side_gable_roof(cv, 0, W, 4, roof_eave, mat="chaume", hip=12)
    eave_shadow(cv, 3, W - 3, roof_eave)
    for cx in (40, W - 40):
        dormer(cv, cx, roof_eave - 10, mat="chaume")
    chimney(cv, 26, 0, 22)
    chimney(cv, W - 36, 2, 20)
    # étage : 5 fenêtres à volets bleus
    for i in range(5):
        x = 16 + i * ((W - 40) // 4)
        window(cv, x, up_top + 8, w=8, h=8, shutters=(P["blue0"], P["blue1"]), box=(i % 2 == 0))
    # rez-de-chaussée : grande porte ouverte sous porche, 4 fenêtres
    cx = W // 2
    for x in (14, 40, W - 48, W - 22):
        window(cv, x, gf_top + 8, w=8, h=8, box=False)
    porch(cv, cx, gf_top + 1, H - 2, w=30)
    door(cv, cx, H - 3, w=14, h=18, open_=True)
    wall_lantern(cv, cx - 14, gf_top + 10)
    wall_lantern(cv, cx + 12, gf_top + 10)
    hanging_sign(cv, cx + 20, gf_top + 2)
    ivy(cv, 9, up_top + 4, H - 4, seed=3)
    sb.outline(cv.img)
    return cv.img


def maison_pignon(roof="tuile", wt=5, ht=4, seed=5, shutters=("leaf2", "leaf3"), door_left=True):
    """Chaumière à pignon sur rue : silhouette triangulaire, porte décalée, jardinière."""
    W, FOOT_H, EXTRA = wt * T, ht * T, 14
    H = FOOT_H + EXTRA
    cv = Canvas(W, H, seed=seed)
    wall_top = H - 28
    front_gable_roof(cv, 0, W, 2, wall_top + 2, apex_h=22, mat=roof)
    wall(cv, 4, W - 4, wall_top, H - 1, mat="torchis", braces=False)
    eave_shadow(cv, 4, W - 4, wall_top, depth=2)
    chimney(cv, W - 22, 0, 16)
    dx = 22 if door_left else W - 22
    door(cv, dx, H - 3, w=10, h=15)
    window(cv, (W - 30) if door_left else 18, wall_top + 7, w=9, h=8,
           shutters=(P[shutters[0]], P[shutters[1]]))
    wall_lantern(cv, dx + 7 if door_left else dx - 10, wall_top + 6)
    ivy(cv, W - 7 if door_left else 7, wall_top + 2, H - 4, seed=seed)
    sb.outline(cv.img)
    return cv.img


def maison_croupe(roof="chaume", wmat="torchis", wt=5, ht=4, seed=1, door_at=0.3,
                  shutters=("blue0", "blue1"), chimney_at=0.68, ivy_x=None, braces=True):
    """Maison à toit en croupe (faîtage parallèle à la rue)."""
    W, H = wt * T, ht * T + 14
    cv = Canvas(W, H, seed=seed)
    wall_top = H - 28
    wall(cv, 4, W - 4, wall_top, H - 1, mat=wmat, braces=braces)
    side_gable_roof(cv, 0, W, 6, wall_top + 4, mat=roof, hip=9)
    eave_shadow(cv, 4, W - 4, wall_top + 4)
    chimney(cv, int(W * chimney_at), 0, 16)
    dx = int(W * door_at)
    door(cv, dx, H - 3, w=10, h=15)
    wx = W - 26 if door_at < 0.5 else 14
    window(cv, wx, wall_top + 9, w=9, h=7, shutters=(P[shutters[0]], P[shutters[1]]))
    wall_lantern(cv, dx + 7 if door_at < 0.5 else dx - 10, wall_top + 8)
    if ivy_x is not None:
        ivy(cv, ivy_x, wall_top + 5, H - 4, seed=seed)
    sb.outline(cv.img)
    return cv.img


# --------------------------------------------------------------------------- ateliers
def forge():
    """Forge du Ruisseau : halle ouverte sur le foyer, grande cheminée, ardoise."""
    W, H = 7 * T, 5 * T + 16
    cv = Canvas(W, H, seed=21)
    wall_top = H - 36
    wall(cv, 4, W - 4, wall_top, H - 1, mat="pierre", timber=False, foundation=3)
    # halle ouverte : intérieur sombre, foyer rougeoyant
    hx0, hx1 = int(W * 0.42), W - 10
    for y in range(wall_top + 9, H - 3):
        for x in range(hx0, hx1):
            t = (y - wall_top - 9) / (H - 3 - wall_top - 9)
            cv.set(x, y, P["outline"] if t < 0.35 else (P["shade1"] if t < 0.7 else P["wine"]))
    for y in range(H - 14, H - 3):                                    # foyer
        for x in range(hx1 - 22, hx1 - 4):
            d = abs(x - (hx1 - 13)) / 9 + (H - 3 - y) / 14
            cv.set(x, y, P["sun0"] if d < 0.35 else (P["sun1"] if d < 0.6 else (P["sun2"] if d < 0.85 else P["red1"])))
    for x in range(hx0, hx1):                                          # lueur sur le sol
        if (x + H) % 2 == 0:
            cv.set(x, H - 4, P["sun3"])
    cv.rect(hx0 - 2, wall_top + 7, hx1 + 2, wall_top + 10, P["earth3"])   # linteau
    cv.rect(hx0 - 2, wall_top + 9, hx1 + 2, wall_top + 10, P["earth4"])
    for px_ in (hx0 - 2, hx1):
        cv.rect(px_, wall_top + 10, px_ + 2, H - 2, P["earth3"])
        cv.rect(px_ + 1, wall_top + 10, px_ + 2, H - 2, P["earth4"])
    side_gable_roof(cv, 0, W, 10, wall_top + 4, mat="ardoise", hip=10)
    eave_shadow(cv, 4, W - 4, wall_top + 4)
    chimney(cv, int(W * 0.72), 0, 30, w=10, shadow_len=4)
    door(cv, 22, H - 3, w=10, h=15)
    window(cv, 8, wall_top + 12, w=7, h=7, box=False, glow=("sun2", "sun3"))
    window(cv, 34, wall_top + 12, w=7, h=7, box=False, glow=("sun2", "sun3"))
    sb.outline(cv.img)
    return cv.img


def alchimie():
    """Alchimie : maison lie-de-vin et petite tour ronde au toit pointu, lueurs vertes."""
    W, H = 6 * T, 4 * T + 24
    cv = Canvas(W, H, seed=31)
    wall_top = H - 28
    green = ("leaf0", "leaf1")
    wall(cv, 24, W - 4, wall_top, H - 1, mat="torchis")
    side_gable_roof(cv, 20, W, 20, wall_top + 4, mat="lie", hip=8)
    eave_shadow(cv, 24, W - 4, wall_top + 4)
    chimney(cv, W - 22, 12, 26, w=6)
    door(cv, 56, H - 3, w=10, h=15)
    window(cv, 72, wall_top + 9, w=8, h=7, shutters=(P["shade0"], P["wine"]), glow=green)
    # tour ronde (devant, à gauche)
    tx0, tx1, t_top = 2, 30, H - 46
    cx = (tx0 + tx1) / 2
    for y in range(t_top, H - 1):
        for x in range(tx0, tx1):
            u = (x + 0.5 - cx) / ((tx1 - tx0) / 2)                     # -1..1 : ombrage cylindrique
            c = P["stone0"] if u < -0.45 else (P["stone1"] if u < 0.35 else P["stone2"])
            if (y - t_top) % 6 == 5 or ((x * 3 + ((y - t_top) // 6) * 5) % 11 == 0):
                c = P["stone2"] if c != P["stone2"] else P["stone3"]
            cv.set(x, y, c)
    for y in range(t_top + 10, t_top + 20):                            # meurtrière lumineuse
        cv.rect(int(cx) - 2, y, int(cx) + 2, y + 1, P["earth4"])
        cv.rect(int(cx) - 1, y, int(cx) + 1, y + 1, P["leaf0"] if y < t_top + 15 else P["leaf1"])
    window(cv, int(cx) - 3, H - 22, w=6, h=6, box=False, glow=green)
    lv = ROOF["lie"]
    apex = 0
    for y in range(apex, t_top + 3):                                   # toit conique
        hw = (y - apex) / (t_top + 3 - apex) * ((tx1 - tx0) / 2 + 3) + 0.5
        for x in range(int(cx - hw), int(cx + hw) + 1):
            u = (x + 0.5 - cx) / max(1, hw)
            lvl = roof_level("tuile", x, y - apex, 1 if u < -0.3 else (-1 if u > 0.4 else 0))
            cv.set(x, y, lv[max(0, min(4, lvl))])
    cv.set(int(cx), 0, P["sun1"])                                      # épi de faîtage
    for x in range(tx0 - 2, tx1 + 2):
        cv.darken(x, t_top + 3, 2)
        cv.darken(x, t_top + 4, 1)
    sb.outline(cv.img)
    return cv.img


def couture():
    """Couture : maison de bois, ardoise bleue, galerie où sèchent les étoffes."""
    W, H = 6 * T, 4 * T + 14
    cv = Canvas(W, H, seed=41)
    wall_top = H - 30
    wall(cv, 4, W - 4, wall_top, H - 1, mat="bois", timber=False)
    side_gable_roof(cv, 0, W, 6, wall_top + 4, mat="ardoise_bleue", hip=9)
    eave_shadow(cv, 4, W - 4, wall_top + 4)
    window(cv, 12, wall_top + 8, w=8, h=7, box=False)
    window(cv, W - 21, wall_top + 8, w=8, h=7, box=False)
    door(cv, W // 2, H - 3, w=10, h=15)
    # galerie : auvent + étoffes suspendues
    gy = wall_top + 18
    lv = ROOF["ardoise_bleue"]
    for y in range(gy, gy + 4):
        for x in range(2, W - 2):
            cv.set(x, y, lv[3] if y == gy else (lv[1] if y == gy + 3 else lv[2]))
    for px_ in (3, W - 5):
        cv.rect(px_, gy + 4, px_ + 2, H - 2, P["earth3"])
    colors = ["red0", "sun1", "blue0", "leaf1", "shade0", "red0", "sun0"]
    for i, x in enumerate(range(8, W - 8, 9)):
        if abs(x + 2 - W // 2) < 9:
            continue                                                    # dégage la porte
        ln = 9 + (i % 3) * 2
        c = P[colors[i % len(colors)]]
        cv.rect(x, gy + 4, x + 5, gy + 4 + ln, c)
        cv.rect(x + 4, gy + 4, x + 5, gy + 4 + ln, DARKER.get(c, P["shade1"]))
        for xx in range(x, x + 5, 2):
            cv.set(xx, gy + 4 + ln, c)                                  # franges
    sb.outline(cv.img)
    return cv.img


def sculpture():
    """Sculpture : atelier de pierre brute et appentis ouvert où attendent les blocs."""
    W, H = 6 * T, 4 * T + 14
    cv = Canvas(W, H, seed=51)
    wall_top = H - 28
    main_x1 = 62
    # appentis (derrière à droite, plus bas)
    lx0 = main_x1 - 4
    for y in range(wall_top + 2, H - 2):
        for x in range(lx0, W - 3):
            cv.set(x, y, P["outline"] if y < wall_top + 12 else P["shade1"])
    for bx, by, bw, bh in ((lx0 + 6, H - 12, 10, 9), (lx0 + 18, H - 9, 8, 6), (lx0 + 13, H - 18, 8, 6)):
        cv.rect(bx, by, bx + bw, by + bh, P["stone1"])
        cv.rect(bx, by, bx + bw, by + 1, P["stone0"])
        cv.rect(bx + bw - 2, by, bx + bw, by + bh, P["stone2"])
    lv = ROOF["ardoise"]
    for y in range(wall_top - 6, wall_top + 3):                         # toit en appentis
        for x in range(lx0, W - 1):
            k = y - (wall_top - 6)
            cv.set(x, y, lv[3] if k < 2 else (lv[1] if k > 6 else lv[2]))
    cv.rect(W - 4, wall_top + 3, W - 2, H - 2, P["earth3"])              # poteau
    wall(cv, 4, main_x1, wall_top, H - 1, mat="pierre", timber=False)
    side_gable_roof(cv, 0, main_x1 + 4, 6, wall_top + 4, mat="ardoise", hip=9)
    eave_shadow(cv, 4, main_x1, wall_top + 4)
    door(cv, 22, H - 3, w=10, h=15)
    window(cv, 40, wall_top + 9, w=8, h=7, box=False)
    chimney(cv, 12, 0, 16)
    sb.outline(cv.img)
    return cv.img


def cuisine():
    """Cuisine : pignon en tuiles, porte ouverte et four à pain en saillie."""
    img = maison_pignon(roof="chaume", seed=61, shutters=("red0", "red1"), door_left=False)
    cv = Canvas(img.width, img.height, seed=61)
    cv.img = img
    cv.px = img.load()
    H = img.height
    door(cv, img.width - 22, H - 3, w=10, h=15, open_=True)
    # four : dôme de pierre devant à gauche, bouche rougeoyante
    cx, cy = 14, H - 9
    for y in range(cy - 10, H - 1):
        for x in range(cx - 12, cx + 12):
            if ((x + 0.5 - cx) / 12) ** 2 + ((y + 0.5 - cy) / 10) ** 2 <= 1 or y >= cy:
                if abs(x + 0.5 - cx) > 12:
                    continue
                u = (x + 0.5 - cx) / 12
                c = P["stone0"] if u < -0.4 and y < cy - 3 else (P["stone1"] if u < 0.4 else P["stone2"])
                if (x + y) % 5 == 0:
                    c = P["stone2"] if c != P["stone2"] else P["stone3"]
                cv.set(x, y, c)
    for y in range(cy - 3, H - 2):
        for x in range(cx - 4, cx + 4):
            cv.set(x, y, P["outline"] if y < cy - 1 else (P["sun2"] if abs(x + 0.5 - cx) < 2 else P["red1"]))
    sb.outline(cv.img)
    return cv.img


def enchantement():
    """Enchantement : pavillon architecte à colonnes, frise et orbe de runes cyan."""
    W, H = 5 * T, 4 * T + 16
    cv = Canvas(W, H, seed=71)
    base = H - 6
    for k in range(3):                                                  # degrés
        y0, inset = H - 2 * (k + 1), 2 + k * 2
        for y in range(y0, y0 + 2):
            for x in range(inset, W - inset):
                cv.set(x, y, P["stone0"] if y == y0 else (P["stone1"] if x < W * 0.75 else P["stone2"]))
    top = H - 44
    for y in range(top, base):                                          # fond intérieur
        for x in range(8, W - 8):
            cv.set(x, y, P["shade1"] if y > top + 6 else P["outline"])
    for (gx, gy) in [(0, 0), (1, 0), (2, 0), (1, 1), (1, 2), (0, 3), (2, 3), (1, 4), (0, 5), (1, 5), (2, 5)]:
        cv.set(W // 2 - 1 + gx, top + 14 + gy * 2, P["rune1"])         # glyphe au fond
        cv.set(W // 2 - 1 + gx, top + 15 + gy * 2, P["rune2"])
    for colx in (6, 24, W - 30, W - 12):                                # colonnes
        for y in range(top, base):
            for x in range(colx, colx + 6):
                u = x - colx
                cv.set(x, y, P["stone0"] if u < 2 else (P["stone1"] if u < 4 else P["stone2"]))
        cv.rect(colx - 1, top, colx + 7, top + 2, P["stone0"])
        cv.rect(colx - 1, base - 2, colx + 7, base, P["stone2"])
    for y in range(top - 6, top):                                       # entablement + frise
        for x in range(3, W - 3):
            c = P["stone1"] if x < W * 0.75 else P["stone2"]
            if y == top - 3 and x % 4 in (0, 1):
                c = P["rune1"] if (x // 4) % 3 else P["rune0"]
            if y == top - 6:
                c = P["stone0"]
            cv.set(x, y, c)
    lv = ROOF["dalle"]
    for k, (h, inset) in enumerate(((6, 1), (5, 10), (5, 20))):          # toit à gradins
        y1 = top - 6 - sum(hh for hh, _ in ((6, 1), (5, 10), (5, 20))[:k])
        for y in range(y1 - h, y1):
            for x in range(inset, W - inset):
                c = lv[3] if y == y1 - h else (lv[2] if x < W * 0.7 else lv[1])
                cv.set(x, y, c)
    oy = top - 6 - 16 - 6
    for dy in range(-4, 5):                                             # orbe runique
        for dx in range(-4, 5):
            if abs(dx) + abs(dy) <= 4:
                cv.set(W // 2 + dx, oy + dy, P["rune0"] if abs(dx) + abs(dy) <= 1 else
                       (P["rune1"] if abs(dx) + abs(dy) <= 3 else P["rune2"]))
    sb.outline(cv.img)
    return cv.img


ALL = {
    "village/auberge": auberge,
    "village/maison_chaume_a": lambda: maison_croupe("chaume", "torchis", seed=1, door_at=0.3, ivy_x=72),
    "village/maison_tuile_a": lambda: maison_pignon("tuile", seed=5),
    "village/maison_bois_a": lambda: maison_pignon("ardoise", seed=7, shutters=("red0", "red1"), door_left=False),
    "village/maison_chaume_b": lambda: maison_croupe("chaume", "bois", seed=3, door_at=0.68,
                                                     shutters=("leaf2", "leaf3"), chimney_at=0.18, braces=False),
    "village/maison_tuile_b": lambda: maison_croupe("tuile", "torchis", seed=9, door_at=0.5,
                                                    shutters=("sun2", "sun3"), chimney_at=0.75, ivy_x=8),
    "ateliers/forge": forge,
    "ateliers/alchimie": alchimie,
    "ateliers/couture": couture,
    "ateliers/sculpture": sculpture,
    "ateliers/cuisine": cuisine,
    "ateliers/enchantement": enchantement,
}


def main():
    for rel, fn in ALL.items():
        fn().save(sb.OUT / "props" / f"{rel}.png")
    print("OK")


if __name__ == "__main__":
    main()
