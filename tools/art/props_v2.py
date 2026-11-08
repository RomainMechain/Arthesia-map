"""Mobilier v2 (même kit que les bâtiments) : étal de Thessaly, puits, pont."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, GROUND_SHADOW  # noqa: E402
import styleboard as sb  # noqa: E402
from buildings import Canvas, ROOF, roof_level, _h  # noqa: E402


def etal():
    """Étal : poteaux, auvent rayé festonné, comptoir en planches, marchandises.
    Zone entre l'auvent et le comptoir laissée vide : la marchande s'y tient (dessinée derrière)."""
    W, H = 64, 48
    cv = Canvas(W, H, seed=81)
    for px_ in (3, W - 6):                                             # poteaux
        cv.rect(px_, 10, px_ + 3, H - 2, P["earth3"])
        cv.rect(px_ + 2, 10, px_ + 3, H - 2, P["earth4"])
        cv.set(px_, 10, P["earth1"])
    # auvent : bandes alternées, haut éclairé, bord festonné
    for x in range(0, W):
        stripe = (x // 8) % 2
        sc = 12 + round(2 * math.sin(math.pi * ((x % 8) + 0.5) / 8))
        for y in range(1, sc + 1):
            light, mid, dark = ((P["red0"], P["red0"], P["red1"]) if stripe == 0
                                else (P["sun0"], P["earth0"], P["earth1"]))
            c = light if y <= 3 else mid
            if x > W * 0.72:
                c = dark if c != light else mid
            if y == sc:
                c = P["red1"] if stripe == 0 else P["earth1"]
            if x % 8 == 0 and 3 < y < sc:
                c = P["red1"] if stripe == 0 else P["earth1"]        # pli du tissu
            cv.set(x, y, c)
    cv.rect(0, 0, W, 1, P["earth4"])                                    # barre d'auvent
    # comptoir
    top = H - 18
    for y in range(top, H - 1):
        for x in range(1, W - 1):
            if y < top + 3:
                c = P["earth1"] if y == top else P["earth2"]
            else:
                c = P["earth2"] if (x - 1) % 6 else P["earth3"]
                if x > W * 0.72:
                    c = P["earth3"] if c == P["earth2"] else P["earth4"]
                if _h(x // 6, 0, 8) < 0.3 and (x - 1) % 6 == 3 and y == top + 8:
                    c = P["earth4"]
            cv.set(x, y, c)
    cv.rect(1, H - 2, W - 1, H - 1, P["earth4"])
    for x in range(1, W - 1):                                          # ombre de l'auvent
        cv.darken(x, top, 1)
    # marchandises sur le comptoir
    # panier de pommes
    cv.rect(5, top - 4, 15, top, P["earth3"])
    for (x, y) in [(6, top - 6), (8, top - 6), (10, top - 6), (12, top - 6), (7, top - 7), (11, top - 7), (9, top - 7)]:
        cv.rect(x, y, x + 2, y + 2, P["red0"])
        cv.set(x, y, P["sun0"])
    # pains
    for bx in (19, 26):
        for y in range(top - 4, top):
            for x in range(bx, bx + 6):
                if ((x + 0.5 - bx - 3) / 3) ** 2 + ((y + 0.5 - top + 1) / 3) ** 2 <= 1:
                    cv.set(x, y, P["sun2"] if y < top - 2 else P["sun3"])
        cv.set(bx + 1, top - 3, P["sun1"])
    # fioles
    for i, (k1, k2) in enumerate((("blue0", "blue1"), ("leaf1", "leaf3"), ("shade0", "wine"), ("rune1", "rune2"))):
        x = 35 + i * 4
        cv.rect(x + 1, top - 7, x + 2, top - 5, P["stone1"])
        cv.rect(x, top - 5, x + 3, top, P[k1])
        cv.rect(x + 2, top - 5, x + 3, top, P[k2])
        cv.set(x, top - 5, P["sun0"])
    # rouleaux d'étoffe
    for i, (k1, k2) in enumerate((("blue0", "blue1"), ("red0", "red1"))):
        y = top - 3 - i * 3
        cv.rect(51, y, 60, y + 3, P[k1])
        cv.rect(51, y + 2, 60, y + 3, P[k2])
        cv.rect(59, y, 60, y + 3, P["earth1"])
    sb.outline(cv.img)
    return cv.img


def puits():
    """Puits : margelle cylindrique en pierre, potence à toit de tuiles, treuil, seau."""
    W, H = 32, 47
    cv = Canvas(W, H, seed=82)
    cx, ry_top = 16, 31
    # dessus de la margelle + eau
    for y in range(ry_top - 7, ry_top + 8):
        for x in range(2, W - 2):
            d = ((x + 0.5 - cx) / 14) ** 2 + ((y + 0.5 - ry_top) / 7) ** 2
            if d <= 1:
                cv.set(x, y, P["stone0"] if (x < cx and y < ry_top) else P["stone1"])
    for y in range(ry_top - 5, ry_top + 5):
        for x in range(5, W - 5):
            d = ((x + 0.5 - cx) / 10) ** 2 + ((y + 0.5 - ry_top) / 4.2) ** 2
            if d <= 1:
                c = P["water4"] if y < ry_top - 1 else P["water3"]
                if 0.55 < d < 0.8 and y > ry_top and x > cx:
                    c = P["water1"]                                    # reflet
                cv.set(x, y, c)
    # potence (derrière le mur avant)
    for px_ in (4, W - 7):
        cv.rect(px_, 9, px_ + 3, ry_top + 2, P["earth3"])
        cv.rect(px_ + 2, 9, px_ + 3, ry_top + 2, P["earth4"])
        cv.set(px_, 9, P["earth1"])
    cv.rect(6, 15, W - 5, 18, P["earth2"])                              # treuil
    cv.rect(6, 17, W - 5, 18, P["earth3"])
    cv.rect(W - 4, 14, W - 2, 15, P["earth4"])                          # manivelle
    cv.rect(W - 3, 15, W - 2, 19, P["earth4"])
    cv.rect(cx, 18, cx + 1, 23, P["earth1"])                            # corde
    cv.rect(cx - 3, 23, cx + 4, 28, P["earth2"])                        # seau
    cv.rect(cx - 3, 24, cx + 4, 25, P["stone2"])
    cv.rect(cx + 2, 23, cx + 4, 28, P["earth3"])
    # petit toit à deux pans
    lv = ROOF["tuile"]
    for y in range(1, 12):
        hw = 4 + (y - 1) * 1.15
        for x in range(int(cx - hw), int(cx + hw) + 1):
            if not 0 <= x < W:
                continue
            left = x < cx
            lvl = roof_level("tuile", x, y, 1 if left else 0)
            if abs(x + 0.5 - cx) < 1:
                lvl = 3 if left else 1
            if y >= 10:
                lvl = 1 if y == 10 else 0
            cv.set(x, y, lv[max(0, min(4, lvl))])
    for x in range(5, W - 5):                                           # ombre du toit
        cv.darken(x, 12, 2)
    # flanc avant du cylindre : de la courbe basse de la margelle, 8 px vers le bas
    wall_h = 8
    for x in range(2, W - 2):
        u = (x + 0.5 - cx) / 14
        if abs(u) >= 1:
            continue
        y_edge = ry_top + int(7 * math.sqrt(1 - u * u))
        for y in range(y_edge - 1, min(H - 1, y_edge + wall_h)):
            k = y - (y_edge - 1)
            row = k // 3
            c = P["stone0"] if u < -0.55 else (P["stone1"] if u < 0.35 else P["stone2"])
            if k == 0:
                c = P["stone0"] if u < 0.35 else P["stone1"]          # arête de la margelle
            elif k % 3 == 0 or (x + row * 3) % 6 == 0:
                c = P["stone3"] if c == P["stone2"] else P["stone2"]
            if k >= wall_h - 1 and _h(x, y, 9) < 0.5:
                c = P["leaf3"]                                         # mousse au pied
            cv.set(x, y, c)
    sb.outline(cv.img)
    return cv.img


def pont():
    """Pont de bois : planches individuelles, clous, garde-corps à poteaux, ombre des rambardes."""
    W, H = 64, 80
    cv = Canvas(W, H, seed=83)
    deck0, deck1 = 8, W - 8
    for y in range(0, H):
        plank, k = divmod(y, 4)
        tone = _h(plank, 0, 10)
        for x in range(deck0, deck1):
            if k == 3:
                c = P["earth4"]                                       # jour entre planches
            elif k == 0:
                c = P["earth1"]
            else:
                c = P["earth2"]
            if tone < 0.25 and k in (1, 2):
                c = P["earth3"]
            elif tone > 0.85 and k in (0, 1):
                c = P["earth1"]
            if x > W * 0.74 and k != 3:
                c = P["earth3"] if c != P["earth3"] else P["earth4"]
            if k == 1 and x in (deck0 + 3, deck1 - 4):
                c = P["stone2"]                                       # clous
            cv.set(x, y, c)
        for x in (deck0, deck0 + 1):                                  # ombre de la rambarde gauche
            cv.darken(x, y, 1)
    for x0 in (2, W - 8):                                              # rambardes
        for y in range(0, H):
            for x in range(x0, x0 + 6):
                u = x - x0
                c = P["earth2"] if u < 2 else (P["earth3"] if u < 5 else P["earth4"])
                if x0 > W / 2:
                    c = P["earth3"] if u < 3 else P["earth4"]
                cv.set(x, y, c)
        for py in range(2, H, 19):                                     # poteaux (chapeaux)
            cv.rect(x0 - 1, py, x0 + 7, py + 6, P["earth3"])
            cv.rect(x0 - 1, py, x0 + 5, py + 2, P["earth1"])
            cv.rect(x0 + 5, py, x0 + 7, py + 6, P["earth4"])
    sb.outline(cv.img)
    for y in range(0, H):                                              # ombre portée sur l'eau
        for x in (W - 2, W - 1):
            if cv.get(x, y)[3] == 0:
                cv.set(x, y, GROUND_SHADOW)
    return cv.img


ALL = {"village/etal_thessaly": etal, "village/puits": puits, "village/pont": pont}
