"""Faune de l'étage 1 (v2) : silhouettes par polygones, ombrage par bords, détails posés à la main.

Lore commun (docs/art_direction.md + floor_1) : l'aube est fabriquée par un mécanisme architecte,
la faune en est « légèrement altérée ». Traduction visuelle, partagée par toutes les bêtes :
  - un liseré de lumière d'aube (or pâle) sur le haut de la silhouette : la lumière qui ne bouge jamais ;
  - des yeux pâles, sans pupille sombre : un regard « trop calme » ;
  - chez les plus touchées, une marque géométrique dorée dans la fourrure (comme les motifs de l'écorce).
Le cyan reste réservé aux runes et aux Architectes : aucune bête de la Lisière n'en porte.

Chaque planche : 8 images de profil (vers la droite, retournées en jeu)
  0-1 repos (1 = variante : clignement, oreille, note figée)   2-5 déplacement
  6 élan (ramassé, penché en arrière)   7 frappe (projeté vers l'avant).

Rendu v3 : contour sélectif (teinté côté lumière, sombre côté ombre), tramage au pixel entre
les tons, élan et frappe obtenus en inclinant les polygones autour des pattes (ou poses dédiées).
"""
import math
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, CLEAR, GROUND_SHADOW  # noqa: E402
import styleboard as sb  # noqa: E402

O = P["outline"]
NFRAMES = 8
POSE = {"shear": 0.0, "squash": 1.0}   # posé par strip() pour les images 6-7
POSES = {6: {"shear": -1.6, "squash": 0.9}, 7: {"shear": 2.6, "squash": 1.0}}


def in_poly(x, y, poly):
    inside = False
    for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside


class Beast:
    """Empile des parties (polygones) ; chaque partie a sa rampe (liseré, base, ombre)."""

    def __init__(self, w, h, oy=0):
        self.w, self.h, self.oy = w, h, oy
        self.shear, self.squash = POSE["shear"], POSE["squash"]
        self.bounds = []
        self.part = [[None] * w for _ in range(h)]
        self.ramps = []
        self.details = []

    def poly(self, pts, ramp, dy=0, dx=0):
        pid = len(self.ramps)
        self.ramps.append(ramp)
        pts = [self.xf(x + dx, y + dy + self.oy) for x, y in pts]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        self.bounds.append((min(ys), max(ys)))
        for y in range(max(0, int(min(ys)) - 1), min(self.h, int(max(ys)) + 2)):
            for x in range(max(0, int(min(xs)) - 1), min(self.w, int(max(xs)) + 2)):
                if in_poly(x + 0.5, y + 0.5, pts):
                    self.part[y][x] = pid
        return pid

    def leg(self, hip, paw, ramp, w=2, foot=1, dy=0):
        (hx, hy), (px_, py) = hip, paw
        hy += dy
        pts = [(hx, hy), (hx + w, hy), (px_ + w, py), (px_ + w + foot, py + 1), (px_, py + 1)]
        return self.poly(pts, ramp)

    def xf(self, x, y):
        """Pose : incline la silhouette autour du sol (les pieds restent, le haut part)."""
        g = self.h - 1
        up = max(0.0, g - y) / max(1.0, g)
        return x + self.shear * up, g - (g - y) * self.squash

    def line(self, a, b, ramp, w=1.0):
        """Trait fin (patte articulée, cou) : polygone d'épaisseur w."""
        (x0, y0), (x1, y1) = a, b
        d = math.hypot(x1 - x0, y1 - y0) or 1.0
        nx, ny = -(y1 - y0) / d * w / 2, (x1 - x0) / d * w / 2
        return self.poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx + 0.01, y1 - ny), (x0 - nx, y0 - ny + 0.01)], ramp)

    def dot(self, x, y, c):
        x, y = self.xf(x, y + self.oy)
        self.details.append((round(x), round(y), c))

    def render(self):
        img = Image.new("RGBA", (self.w, self.h), CLEAR)
        px = img.load()
        g = self.part

        def empty(x, y):
            return not (0 <= x < self.w and 0 <= y < self.h) or g[y][x] is None

        for y in range(self.h):
            for x in range(self.w):
                pid = g[y][x]
                if pid is None:
                    continue
                ramp = self.ramps[pid]
                rim, light, base, shade = ramp if len(ramp) == 4 else (ramp[0], ramp[1], ramp[1], ramp[2])
                behind = lambda xx, yy: not empty(xx, yy) and g[yy][xx] < pid   # noqa: E731
                y0, y1 = self.bounds[pid]
                rel = (y + 0.5 - y0) / max(1.0, y1 - y0)
                if empty(x, y - 1) or (empty(x - 1, y) and empty(x - 1, y - 1)):
                    c = rim                                  # liseré d'aube (lumière haut-gauche)
                elif empty(x, y + 1) or empty(x + 1, y):
                    c = shade                                # dessous et côté droit : ombre propre
                elif behind(x, y + 1) or behind(x + 1, y):
                    c = shade                                # pli : la partie de devant se détache
                else:
                    chk = (x + y) % 2
                    if rel < 0.32:
                        c = light
                    elif rel < 0.44:
                        c = light if chk else base           # tramage clair -> base
                    elif rel < 0.72:
                        c = base
                    elif rel < 0.84:
                        c = base if chk else shade           # tramage base -> ombre
                    else:
                        c = shade
                px[x, y] = c
        # contour sélectif : côté lumière, une teinte sombre de la partie ; côté ombre, l'encre
        out = {}
        for y in range(self.h):
            for x in range(self.w):
                if not empty(x, y):
                    continue
                nb = [(x, y + 1), (x + 1, y), (x, y - 1), (x - 1, y)]
                solid = [(xx, yy) for xx, yy in nb if not empty(xx, yy)]
                if not solid:
                    continue
                lit_side = all(yy > y or xx > x for xx, yy in solid)   # le contour est au-dessus/à gauche
                if lit_side and y < self.h - 2:
                    r = self.ramps[g[solid[0][1]][solid[0][0]]]
                    out[(x, y)] = DARKER.get(r[-1], O)
                else:
                    out[(x, y)] = O
        for (x, y), c in out.items():
            px[x, y] = c
        for x, y, c in self.details:
            if 0 <= x < self.w and 0 <= y < self.h:
                px[x, y] = c
        return img


# Teinte du contour côté lumière : un cran plus sombre que l'ombre de la partie
DARKER = {
    P["sun3"]: P["earth3"], P["sun2"]: P["earth3"], P["sun1"]: P["sun3"], P["red1"]: P["wine"],
    P["earth1"]: P["earth3"], P["earth2"]: P["earth4"], P["earth3"]: P["earth4"], P["earth4"]: O,
    P["stone1"]: P["stone3"], P["stone2"]: P["stone3"], P["stone3"]: P["stone4"], P["stone4"]: O,
    P["leaf3"]: P["leaf5"], P["leaf4"]: P["leaf5"], P["shade1"]: O, P["water3"]: P["water4"],
}


def strip(make, ground_rx, custom_poses=False):
    """8 images. Pour 6-7 : la bête fournit sa pose (custom_poses), sinon le repos incliné."""
    global POSE
    imgs = []
    for i in range(NFRAMES):
        if i >= 6 and not custom_poses:
            POSE = POSES[i]
            imgs.append(make(0))
            POSE = {"shear": 0.0, "squash": 1.0}
        else:
            imgs.append(make(i))
    w, h = imgs[0].size
    out = Image.new("RGBA", (w * NFRAMES, h + 1), CLEAR)
    for i, im in enumerate(imgs):
        f = Image.new("RGBA", (w, h + 1), CLEAR)
        if ground_rx:                                       # pas d'ombre au sol pour une bête dans l'eau
            sb.ellipse(f, w / 2 + 1, h - 0.5, ground_rx, 1.6, GROUND_SHADOW)
        f.alpha_composite(im, (0, 0))
        out.alpha_composite(f, (i * w, 0))
    return out


# --------------------------------------------------------------------------- Loup Doré
def loup_dore():
    """Loup élancé, fourrure d'or imprégnée par l'aube ; marque en losange sur l'épaule, oeil pâle immobile."""
    fur = (P["sun1"], P["sun1"], P["sun2"], P["sun3"])
    leg = (P["sun1"], P["sun2"], P["sun2"], P["sun3"])
    far = (P["sun3"], P["sun3"], P["earth3"], P["earth4"])
    far_ear = (P["sun2"], P["sun2"], P["sun3"], P["earth3"])
    mane = (P["sun0"], P["sun0"], P["sun1"], P["sun2"])
    snout = (P["sun0"], P["sun1"], P["sun1"], P["sun2"])
    W, H = 36, 24

    def make(i):
        b = Beast(W, H, oy=1)
        walk = i >= 2
        ph = (i - 2) % 4 if walk else 0
        y = (0, -1, 0, -1)[ph] if walk else 0
        sw = (2, 0, -2, 0)[ph] if walk else 0
        tail = y - (1 if i == 1 else 0)
        # pattes du fond (sombres : elles reculent dans l'ombre)
        b.leg((10, 13), (10 - sw, 20), far, dy=y)
        b.leg((22, 13), (23 + sw, 20), far, dy=y)
        # queue en panache, portée basse : un loup trop calme
        b.poly([(9, 8), (6, 7), (3, 8), (1, 11), (0, 14), (2, 13), (2, 15), (5, 13), (7, 11), (10, 11)],
               fur, dy=tail)
        b.poly([(25, 4), (26, 0), (27.5, 3)], far_ear, dy=y)                       # oreille du fond
        # corps : dos droit, poitrail profond, ventre rentré avec des mèches
        b.poly([(8, 8), (12, 6), (19, 6), (23, 5), (26, 7), (27, 11), (25, 14), (22, 13), (20, 15),
                (18, 13), (16, 15), (14, 13), (11, 14), (8, 12)], fur, dy=y)
        # cuisse arrière (musclée) puis patte
        b.poly([(9, 9), (14, 9), (14, 13), (12, 15), (10, 14)], fur, dy=y)
        b.leg((11, 13), (12 + sw, 20), leg, dy=y)
        # collerette claire
        b.poly([(21, 5), (23, 2), (24, 4), (25, 2), (27, 5), (28, 9), (28, 13), (26, 11), (24, 12), (23, 9)],
               mane, dy=y)
        # crâne, museau effilé, oreille de devant
        b.poly([(24, 4), (26, 2), (29, 2), (31, 4), (31, 7), (29, 9), (26, 9), (24, 7)], fur, dy=y)
        b.poly([(30, 4), (33, 5), (35, 6), (35, 8), (32, 9), (29, 8)], snout, dy=y)
        b.poly([(27, 3), (29, -0.5), (30.5, 4)], fur, dy=y)
        b.leg((24, 13), (24 - sw, 20), leg, dy=y)                                 # patte avant
        # détails
        b.dot(29, 1 + y, P["sun3"])                         # creux d'oreille
        b.dot(29, 2 + y, P["sun3"])
        b.dot(27, 4 + y, P["sun3"])                         # arcade
        b.dot(28, 4 + y, P["sun3"])
        if i == 1:                                          # clignement lent
            b.dot(28, 5 + y, P["sun3"])
            b.dot(29, 5 + y, P["sun3"])
        else:
            b.dot(28, 5 + y, P["sun0"])                     # oeil pâle, sans pupille : trop calme
            b.dot(29, 5 + y, P["sun0"])
        b.dot(35, 6 + y, O)                                 # truffe
        b.dot(32, 8 + y, P["earth3"])                       # babine
        b.dot(33, 8 + y, P["earth3"])
        for x, yy in ((18, 7), (17, 8), (19, 8), (16, 9), (20, 9), (17, 10), (19, 10), (18, 11)):
            b.dot(x, yy + y, P["sun0"])                     # losange doré : le motif du mécanisme
        b.dot(18, 9 + y, P["sun1"])
        b.dot(1, 13 + tail, P["sun0"])                      # pointe de queue
        b.dot(0, 14 + tail, P["sun0"])
        return b.render()
    return strip(make, 11)

# --------------------------------------------------------------------------- Renardeau Curieux
def renardeau():
    """Jeune renard : fin, dos souple, grande tête, oreilles à pointe noire, queue en panache relevée
    au bout blanc, plastron blanc, chaussettes sombres. Il mord avant de fuir."""
    fur = (P["sun2"], P["sun2"], P["sun3"], P["red1"])
    far = (P["earth3"], P["earth3"], P["earth4"], P["earth4"])
    sock = (P["earth3"], P["earth3"], P["earth4"], P["earth4"])
    W, H = 28, 20

    def make(i):
        b = Beast(W, H, oy=1)
        walk = i >= 2
        ph = (i - 2) % 4 if walk else 0
        bob = (0, -1, 0, -1)[ph] if walk else 0
        sw = (2, 0, -2, 0)[ph] if walk else 0
        tilt = -1 if i == 1 else 0                        # tête penchée : curiosité
        wag = (0, 1, 0, -1)[ph] if walk else (1 if i == 1 else 0)
        b.leg((9, 12), (9 - sw, 17), far, dy=bob)          # pattes du fond
        b.leg((17, 12), (18 + sw, 17), far, dy=bob)
        # queue en panache relevée, qui balance
        b.poly([(8, 9), (5, 7 - wag), (2, 4 - wag), (0, 4 - wag), (0, 7 - wag), (2, 10), (5, 12), (8, 12)],
               fur, dy=bob)
        # corps fin, dos souple, ventre rentré
        b.poly([(6, 9), (9, 7), (14, 7), (18, 6), (21, 8), (21, 12), (18, 13), (15, 12), (11, 13), (7, 12)],
               fur, dy=bob)
        b.leg((10, 12), (10 + sw, 17), sock, dy=bob)
        b.leg((19, 12), (19 - sw, 17), sock, dy=bob)
        hy = bob + tilt
        # tête large, joues, museau pointu, grandes oreilles
        b.poly([(18, 5), (20, 3), (23, 3), (25, 5), (27, 7), (26, 8), (23, 9), (19, 9), (18, 7)], fur, dy=hy)
        b.poly([(19, 4), (19, -0.5), (22, 3)], fur, dy=hy)
        b.poly([(22, 3), (24, -0.5), (24.5, 5)], fur, dy=hy)
        for x, yy in ((19, 0), (24, 0), (24, 1)):
            b.dot(x, yy + hy, O)                           # pointes noires
        b.dot(20, 2 + hy, P["earth4"])                     # creux d'oreille
        b.dot(23, 2 + hy, P["earth4"])
        for x, yy in ((22, 7), (23, 7), (24, 7), (23, 8), (24, 8), (21, 8)):
            b.dot(x, yy + hy, P["sun0"])                   # joue blanche
        for x, yy in ((19, 9), (20, 9), (19, 10), (20, 10), (19, 11)):
            b.dot(x, yy + bob, P["sun0"])                  # plastron
        b.dot(22, 5 + hy, O)                               # oeil vif, sombre : lui n'est pas « altéré »
        b.dot(22, 4 + hy, P["sun0"])
        b.dot(27, 7 + hy, O)                               # truffe
        for x, yy in ((0, 4), (1, 4), (0, 5), (0, 6), (1, 7)):
            b.dot(x, yy - wag + bob, P["sun0"])            # bout de queue blanc
        return b.render()
    return strip(make, 8)


# --------------------------------------------------------------------------- Lapin Bondissant
def lapin():
    """Lapin crème au reflet doré, longues oreilles, yeux clairs. Se déplace par bonds."""
    fur = (P["sun0"], P["earth0"], P["earth1"])
    far = (P["earth0"], P["earth1"], P["earth2"])
    W, H = 19, 20

    def make(i):
        b = Beast(W, H, oy=3)
        # repos / variante (oreille) / bond : accroupi, détente, en l'air, réception
        pose = ("rest", "rest", "crouch", "stretch", "air", "land")[i]
        dy = {"rest": 0, "crouch": 1, "stretch": -2, "air": -3, "land": 0}[pose]
        ear = {"rest": 0, "crouch": 1, "stretch": 1, "air": 0, "land": 0}[pose]
        stretch = 1 if pose == "stretch" else 0
        far_y = 16 + (dy if pose in ("air", "stretch") else 0)
        b.poly([(13, 12 + dy), (14, far_y), (16, far_y), (15, 12 + dy)], far)      # patte avant du fond
        b.poly([(4 - stretch, 9), (7, 7), (11, 7), (13, 9), (13, 13), (10, 14), (5, 14), (3 - stretch, 12)],
               fur, dy=dy)                                                       # corps rond
        b.poly([(11, 6), (14, 4), (16, 5), (18, 8), (16, 10), (13, 10), (11, 8)], fur, dy=dy)  # tête
        b.poly([(12, 5), (9 + ear, 0), (11 + ear, 0), (14, 4)], fur, dy=dy)      # oreilles
        tw = 1 if i == 1 else 0
        b.poly([(14, 4), (14 + ear - tw, 0), (16 + ear - tw, 1), (16, 5)], fur, dy=dy)
        # patte arrière : grand pied
        hind = [(5, 12), (9, 12), (10, 15), (4, 15)] if stretch == 0 else [(4, 12), (7, 12), (4, 16), (1, 16)]
        grounded = pose in ("rest", "crouch", "land", "stretch")     # à l'appel, le pied pousse encore le sol
        b.poly([(x, y + (dy if (y < 14 or not grounded) else 0)) for x, y in hind], fur)
        fy = 15 + (dy if pose in ("air", "stretch") else 0)
        b.poly([(13, 12 + dy), (15, 12 + dy), (16 + stretch, fy), (14 + stretch, fy)], fur)
        b.dot(12 + (ear > 0), 2 + dy, P["skin0"])          # intérieur d'oreille rosé
        b.dot(11 + (ear > 0), 3 + dy, P["skin0"])
        b.dot(16, 6 + dy, P["water0"])                      # oeil clair (pas de cyan : réservé aux runes)
        b.dot(15, 6 + dy, P["earth2"])
        b.dot(18, 8 + dy, P["skin1"])                       # nez
        b.dot(3 - stretch, 10 + dy, P["sun0"])              # queue
        b.dot(2 - stretch, 10 + dy, P["sun0"])
        for x in (6, 9, 12):
            b.dot(x, 7 + dy, P["sun1"])                     # reflet doré presque imperceptible
        return b.render()
    return strip(make, 6)


# --------------------------------------------------------------------------- Oiseau Chanteur
def oiseau():
    """Petit oiseau pâle à gorge d'or ; sa note de chant reste suspendue, figée devant lui."""
    body = (P["sun0"], P["stone0"], P["stone1"])
    wing = (P["stone1"], P["stone2"], P["stone2"], P["stone3"])
    W, H = 19, 16

    def make(i):
        b = Beast(W, H, oy=3)
        pose = ("rest", "sing", "crouch", "up", "glide", "land")[i]
        dy = {"rest": 0, "sing": 0, "crouch": 1, "up": -3, "glide": -2, "land": 0}[pose]
        b.poly([(4, 6), (0, 4), (0, 6), (4, 8)], wing, dy=dy)                   # queue
        b.poly([(3, 6), (6, 4), (10, 4), (12, 6), (11, 9), (7, 10), (4, 9)], body, dy=dy)
        b.poly([(9, 2), (11, 1), (13, 2), (13, 5), (10, 6), (9, 4)], body, dy=dy)
        if pose in ("up", "glide"):                                             # ailes ouvertes
            b.poly([(5, 6), (1, 1), (3, 0), (5, 2), (7, 0), (9, 1), (10, 6)], wing,
                   dy=dy - (1 if pose == "up" else 0))
        else:
            b.poly([(5, 5), (9, 5), (10, 7), (7, 8), (4, 7)], wing, dy=dy)
        if dy >= 0:
            for x in (6, 8):
                b.dot(x, 10 + dy, P["sun3"])
                b.dot(x, 11 + dy, P["sun3"])
        b.dot(11, 2 + dy, O)                                 # oeil
        b.dot(14, 3 + dy, P["sun3"])                         # bec
        if pose == "sing":
            b.dot(14, 4 + dy, P["sun3"])
            b.dot(15, 2 + dy, P["sun3"])
        for x, y in ((10, 5), (11, 5), (11, 6), (10, 6)):
            b.dot(x, y + dy, P["sun1"])                      # gorge dorée
        img = b.render()
        if pose in ("rest", "sing"):
            # la note figée : un petit losange d'or, immobile, sans contour (c'est de la lumière)
            for x, y, c in ((17, 0, P["sun1"]), (16, 1, P["sun1"]), (18, 1, P["sun1"]), (17, 2, P["sun1"]),
                            (17, 1, P["sun0"])):
                img.putpixel((x, y + 3), c)
        return img
    return strip(make, 5)


# --------------------------------------------------------------------------- Rive Paisible
def crabe():
    """Crabe des galets : carapace bombée couleur de pierre mouillée, tachée comme un galet ;
    yeux sur pédoncules ; une grosse pince crantée et une plus petite ; pattes articulées, genoux hauts.
    Élan : pinces levées, ouvertes. Frappe : pinces projetées, refermées."""
    shell = (P["stone0"], P["stone1"], P["stone2"], P["stone3"])
    claw = (P["stone1"], P["stone1"], P["stone2"], P["stone3"])
    legr = (P["stone2"], P["stone3"], P["stone3"], P["stone4"])
    W, H = 30, 18

    def make(i):
        b = Beast(W, H)
        walk = 2 <= i <= 5
        ph = (i - 2) % 4 if walk else 0
        y = (0, -1, 0, -1)[ph] if walk else (1 if i == 6 else 0)
        lift = {1: 1, 6: 3, 7: -1}.get(i, 0)
        reach = 3 if i == 7 else 0
        # pattes : trois de chaque côté, genou haut, pointe au sol
        for k, (hx, kx, tx) in enumerate(((11, 7, 5), (12, 8, 7), (13, 10, 9),
                                           (17, 21, 23), (18, 22, 21), (19, 23, 25))):
            st = ((1 if (k + ph) % 2 else -1) if walk else 0)
            b.line((hx, 12 + y), (kx + st, 10 + y), legr)
            b.line((kx + st, 10 + y), (tx + st, 16), legr)
        # bras des pinces (derrière)
        b.line((11, 10 + y), (7 - reach, 8 + y - lift), claw, w=2)
        b.line((19, 10 + y), (22 + reach, 8 + y - lift), claw, w=1.6)
        # carapace bombée
        b.poly([(8, 11), (9, 8), (12, 6), (18, 6), (21, 8), (22, 11), (20, 13), (10, 13)], shell, dy=y)
        for ex in (13, 17):                                 # pédoncules
            b.line((ex, 7 + y), (ex, 4 + y), claw)
        # grosse pince (gauche) : deux mâchoires, ouvertes en élan
        gap = 2 if i in (1, 6) else 0
        cx, cy = 5 - reach, 7 + y - lift
        b.poly([(cx + 3, cy + 1), (cx - 1, cy - 1 - gap), (cx - 4, cy - 3 - gap), (cx - 4, cy - 1 - gap),
                (cx - 1, cy + 1)], claw)
        b.poly([(cx + 3, cy + 1), (cx - 1, cy + 3), (cx - 5, cy + 2), (cx - 5, cy + 1), (cx - 1, cy + 1)], claw)
        b.poly([(cx + 1, cy - 1), (cx + 4, cy - 1), (cx + 4, cy + 3), (cx + 1, cy + 3)], claw)   # paume
        # petite pince (droite)
        dx, dy_ = 24 + reach, 7 + y - lift
        b.poly([(dx - 2, dy_), (dx + 1, dy_ - 1 - gap // 2), (dx + 3, dy_ - 1 - gap // 2), (dx + 1, dy_ + 1),
                (dx + 3, dy_ + 2), (dx, dy_ + 2)], claw)
        for ex in (13, 17):                                 # yeux
            b.dot(ex, 3 + y, O)
            b.dot(ex, 2 + y, O)
        for x, yy, c in ((12, 9, P["stone2"]), (16, 8, P["stone2"]), (19, 10, P["stone2"]), (14, 11, P["stone3"]),
                         (17, 11, P["stone3"]), (11, 10, P["leaf3"])):
            b.dot(x, yy + y, c)                             # taches de galet, un brin d'algue
        for x in (13, 14, 15):
            b.dot(x, 7 + y, P["water0"])                    # reflet de pierre mouillée
        for k in range(3):
            b.dot(cx - 2 - k, cy + 1, P["stone0"])          # crans de la pince
        return b.render()
    return strip(make, 8, custom_poses=True)


def heron():
    """Héron cendré : grand, gris pâle ; longues pattes, cou blanc strié en S, sourcil noir prolongé d'une
    aigrette, bec-dague jaune, rémiges sombres. Si immobile qu'on dirait une statue.
    Élan : cou replié en arrière. Frappe : cou détendu, bec en avant."""
    body = (P["stone0"], P["stone1"], P["stone1"], P["stone2"])
    neck = (P["stone0"], P["stone0"], P["stone1"], P["stone2"])
    wing = (P["stone1"], P["stone2"], P["stone2"], P["stone3"])
    prim = (P["stone3"], P["stone3"], P["stone4"], P["stone4"])
    legr = (P["earth2"], P["earth2"], P["earth3"], P["earth3"])   # pattes fines, jaune terne
    W, H = 32, 36

    def make(i):
        b = Beast(W, H)
        walk = 2 <= i <= 5
        ph = (i - 2) % 4 if walk else 0
        y = (0, -1, 0, -1)[ph] if walk else (1 if i == 6 else 0)
        sw = (2, 0, -2, 0)[ph] if walk else 0
        # longues pattes fines (1 px, sans contour : on les dessine par-dessus), genou vers l'arrière
        def stilt(p0, p1, p2):
            for (ax, ay), (bx, by) in ((p0, p1), (p1, p2)):
                n = max(abs(bx - ax), abs(by - ay), 1)
                for t in range(int(n) + 1):
                    b.dot(round(ax + (bx - ax) * t / n), round(ay + (by - ay) * t / n), P["earth3"])
            b.dot(round(p1[0]), round(p1[1]), P["earth2"])    # genou
            b.dot(round(p2[0]) + 1, round(p2[1]), P["earth3"])  # doigts
        stilt((11, 22 + y), (10 - sw // 2, 28), (11 - sw, 35))
        stilt((14, 22 + y), (15 + sw // 2, 28), (14 + sw, 35))
        # queue courte, corps en goutte penchée, aile repliée, rémiges sombres
        b.poly([(3, 19), (8, 17), (9, 21), (4, 22)], prim, dy=y)
        b.poly([(6, 18), (9, 14), (15, 13), (19, 15), (18, 20), (14, 23), (9, 23), (6, 21)], body, dy=y)
        b.poly([(7, 17), (10, 15), (16, 15), (17, 19), (13, 22), (8, 21)], wing, dy=y)
        b.poly([(5, 20), (9, 19), (13, 22), (7, 22)], prim, dy=y)
        # cou : S au repos, replié en élan, tendu à la frappe
        if i == 6:
            pts = [(16, 15), (14, 11), (12, 8), (12, 5)]
        elif i == 7:
            pts = [(16, 15), (19, 12), (22, 10), (25, 9)]
        else:
            pts = [(16, 15), (18, 11), (16, 8), (17, 4)]
        for p0, p1 in zip(pts, pts[1:]):
            b.line((p0[0], p0[1] + y), (p1[0], p1[1] + y), neck, w=2.4)
        hx, hy = pts[-1][0], pts[-1][1] + y
        b.poly([(hx - 2, hy - 1), (hx, hy - 3), (hx + 3, hy - 2), (hx + 3, hy + 1), (hx - 1, hy + 1)], neck)
        L = 7 if i == 7 else 5                               # bec-dague
        for k in range(L):
            b.dot(hx + 3 + k, hy - 1 + (k // 4), P["sun2"] if k < L - 1 else P["sun3"])
            if k < L - 2:
                b.dot(hx + 3 + k, hy + (k // 4), P["sun3"])
        b.dot(hx + 1, hy - 1, P["sun1"] if i != 1 else P["stone2"])   # oeil fixe (un seul clignement)
        for k in range(5):                                   # sourcil noir et aigrette qui tombe
            b.dot(hx + 1 - k, hy - 2 + (k // 2), O)
        for p0, p1 in zip(pts, pts[1:]):                     # stries sur le devant du cou
            b.dot((p0[0] + p1[0]) / 2 + 1, (p0[1] + p1[1]) / 2 + y, P["stone3"])
        return b.render()
    return strip(make, 7, custom_poses=True)


def anguille():
    """Anguille des hauts-fonds : longue, sombre (olive-noir), nageoire dorsale plus claire ; ses anneaux
    affleurent, la tête pointe, des rides là où elle perce l'eau. Sa peau crépite d'or quand elle s'agite.
    6 = sous l'eau (rides et bulles), 7 = elle jaillit et mord."""
    skin = (P["leaf4"], P["leaf4"], P["leaf5"], O)
    fin = (P["leaf3"], P["leaf3"], P["leaf4"], P["leaf5"])
    W, H = 34, 18
    WL = 13                                                  # ligne d'eau

    def ripples(img, xs, w=3, k=0):
        for x0 in xs:
            for x in range(x0 - w, x0 + w + 1):
                if 0 <= x < W and (x + k) % 3 != 2:
                    img.putpixel((x, WL + 1), P["sun0"] if abs(x - x0) < w else P["water0"])
            for x in (x0 - w - 1, x0 + w + 1):
                if 0 <= x < W:
                    img.putpixel((x, WL), P["water0"])

    def make(i):
        img = Image.new("RGBA", (W, H), CLEAR)
        walk = 2 <= i <= 5
        if i == 6:                                           # sous l'eau : rides et bulles
            ripples(img, (10, 22), 4)
            for x, yy in ((14, 10), (17, 8), (19, 11), (15, 6)):
                img.putpixel((x, yy), P["water0"])
            return img
        b = Beast(W, H)
        ph = (i - 2) * 1.57 if walk else i * 0.4
        if i == 7:                                           # elle jaillit : cou dressé, gueule ouverte
            b.line((14, WL + 1), (20, 6), skin, w=4)
            b.line((20, 6), (25, 3), skin, w=3.4)
            b.line((15, WL - 1), (20, 5), fin, w=1)
            b.poly([(23, 1), (29, 2), (30, 3), (26, 4), (30, 5), (29, 6), (24, 6)], skin)
            hx, hy = 25, 2
            humps = [14]
        else:
            off = round(2 * math.sin(ph))                    # les anneaux glissent avec la nage
            humps = []
            for k, cx in enumerate((8 + off, 18 + off)):     # anneaux bas et longs, à fleur d'eau
                h = 3 if k else 2
                b.poly([(cx - 6, WL + 1), (cx - 4, WL - h + 1), (cx - 1, WL - h), (cx + 2, WL - h),
                        (cx + 5, WL - h + 1), (cx + 6, WL + 1)], skin)
                humps.append(cx)
            hx, hy = 28 + off // 2, WL - 3
            # tête allongée, posée sur l'eau, museau vers l'avant
            b.poly([(hx - 4, WL + 1), (hx - 3, hy + 1), (hx, hy), (hx + 3, hy + 1), (hx + 5, hy + 3),
                    (hx + 4, WL + 1)], skin)
        b.dot(hx + 1, hy, P["sun0"])                         # oeil pâle
        if i == 7:
            for x, yy in ((27, 4), (28, 4)):
                b.dot(x, yy, P["red1"])                      # gueule
            for x, yy in ((26, 2), (28, 3), (26, 5)):
                b.dot(x, yy, P["sun0"])                      # dents
        body = b.render()
        px = body.load()
        if i != 7:
            for x in range(W):                               # fil de nageoire, juste sous le liseré
                for yy in range(H - 1):
                    if px[x, yy][3] and px[x, yy][:3] != P["outline"][:3] and px[x, yy + 1][:3] == P["leaf4"][:3]:
                        if (x + i) % 2 == 0:
                            px[x, yy + 1] = P["leaf3"]
                        break
        if walk or i == 7:                                   # crépitement doré
            for yy in range(H):
                for x in range(W):
                    if px[x, yy][3] and px[x, yy][:3] == P["leaf4"][:3] and (x * 3 + yy * 5 + i) % 7 == 0:
                        px[x, yy] = P["sun1"]
        img.alpha_composite(body)
        px = img.load()                                      # l'eau coupe le corps
        for yy in range(WL + 2, H):
            for x in range(W):
                px[x, yy] = CLEAR
        ripples(img, humps + [hx], 3, i)
        return img
    return strip(make, 0, custom_poses=True)


ALL = {
    "monsters/crabe_des_galets_idle": crabe,
    "monsters/heron_cendre_idle": heron,
    "monsters/anguille_des_hauts_fonds_idle": anguille,
    "monsters/loup_dore_idle": loup_dore,
    "monsters/renardeau_curieux_idle": renardeau,
    "monsters/lapin_bondissant_idle": lapin,
    "monsters/oiseau_chanteur_idle": oiseau,
}


def sheet(out, before=None):
    """Planche : chaque bête, ses 6 images x4 sur fond d'herbe (+ ancienne version si fournie)."""
    rows = list(ALL.items())
    s = 4
    imgs = [(k, fn()) for k, fn in rows]
    width = max(im.width for _, im in imgs) * s + 40
    height = sum(im.height * s + 12 for _, im in imgs)
    if before:
        height += sum(Image.open(p).height * s + 12 for p in before.values())
    bg = Image.new("RGBA", (width, height + 12), P["leaf2"])
    y = 6
    for k, im in imgs:
        if before and k in before:
            old = Image.open(before[k]).convert("RGBA")
            bg.alpha_composite(old.resize((old.width * s, old.height * s), Image.NEAREST), (6, y))
            y += old.height * s + 12
        bg.alpha_composite(im.resize((im.width * s, im.height * s), Image.NEAREST), (6, y))
        y += im.height * s + 12
    bg.save(out)


def main():
    for rel, fn in ALL.items():
        sb.save(fn(), f"{rel}.png")


if __name__ == "__main__":
    import shutil
    tmp = sb.PREVIEW / "_faune_v1"
    tmp.mkdir(exist_ok=True)
    before = {}
    for k in ALL:
        src = sb.OUT / f"{k}.png"
        if src.exists():
            dst = tmp / Path(k).name
            if not dst.exists():
                shutil.copy(src, dst)
            before[k] = dst
    main()                                              # les planches du jeu, pas seulement l'aperçu
    sheet(sb.PREVIEW / "faune_v2.png")
    sheet(sb.PREVIEW / "faune_avant_apres.png", before)
    print("planche :", sb.PREVIEW / "faune_v2.png")
