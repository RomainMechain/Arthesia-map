"""Faune de l'étage 1 (v2) : silhouettes par polygones, ombrage par bords, détails posés à la main.

Lore commun (docs/art_direction.md + floor_1) : l'aube est fabriquée par un mécanisme architecte,
la faune en est « légèrement altérée ». Traduction visuelle, partagée par toutes les bêtes :
  - un liseré de lumière d'aube (or pâle) sur le haut de la silhouette : la lumière qui ne bouge jamais ;
  - des yeux pâles, sans pupille sombre : un regard « trop calme » ;
  - chez les plus touchées, une marque géométrique dorée dans la fourrure (comme les motifs de l'écorce).
Le cyan reste réservé aux runes et aux Architectes : aucune bête de la Lisière n'en porte.

Chaque planche : 6 images de profil (vers la droite, retournées en jeu)
  0-1 repos (1 = variante : clignement, oreille, note figée)   2-5 déplacement.
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, CLEAR, GROUND_SHADOW  # noqa: E402
import styleboard as sb  # noqa: E402

O = P["outline"]
NFRAMES = 6


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
        self.bounds = []
        self.part = [[None] * w for _ in range(h)]
        self.ramps = []
        self.details = []

    def poly(self, pts, ramp, dy=0, dx=0):
        pid = len(self.ramps)
        self.ramps.append(ramp)
        pts = [(x + dx, y + dy + self.oy) for x, y in pts]
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

    def dot(self, x, y, c):
        self.details.append((x, y + self.oy, c))

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
                    c = light if rel < 0.38 else base if rel < 0.78 else shade   # volume
                px[x, y] = c
        sb.outline(img)
        for x, y, c in self.details:
            if 0 <= x < self.w and 0 <= y < self.h:
                px[x, y] = c
        return img


def strip(make, ground_rx):
    imgs = [make(i) for i in range(NFRAMES)]
    w, h = imgs[0].size
    out = Image.new("RGBA", (w * NFRAMES, h + 1), CLEAR)
    for i, im in enumerate(imgs):
        f = Image.new("RGBA", (w, h + 1), CLEAR)
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
    """Jeune renard : grosse tête, grandes oreilles, queue touffue au bout blanc, chaussettes sombres."""
    fur = (P["sun2"], P["sun3"], P["red1"])
    far = (P["earth3"], P["earth4"], P["outline"])
    sock = (P["earth3"], P["earth4"], P["earth4"])
    W, H = 25, 18

    def make(i):
        b = Beast(W, H)
        walk = i >= 2
        ph = (i - 2) % 4 if walk else 0
        bob = (0, -1, 0, -1)[ph] if walk else 0
        sw = (2, 0, -2, 0)[ph] if walk else 0
        tilt = -1 if i == 1 else 0                        # tête penchée : curiosité
        b.leg((8, 12), (8 - sw, 16), far, dy=bob)
        b.leg((15, 12), (16 + sw, 16), far, dy=bob)
        b.poly([(8, 9), (5, 6), (2, 5), (0, 7), (0, 10), (2, 12), (5, 12), (8, 12)], fur, dy=bob)   # queue
        b.poly([(6, 9), (9, 7), (15, 7), (18, 8), (18, 12), (15, 13), (9, 13), (6, 12)], fur, dy=bob)  # corps
        hy = bob + tilt
        b.poly([(15, 5), (17, 3), (20, 3), (22, 5), (24, 7), (23, 8), (20, 9), (16, 9)], fur, dy=hy)  # tête
        b.poly([(16, 4), (16, -1), (19, 3)], fur, dy=hy)                       # grandes oreilles
        b.poly([(19, 3), (21, -1), (21, 5)], fur, dy=hy)
        b.leg((10, 12), (10 + sw, 16), sock, dy=bob)
        b.leg((16, 12), (16 - sw, 16), sock, dy=bob)
        for x, yy in ((17, 1), (17, 2), (20, 1), (20, 2)):
            b.dot(x, yy + hy, P["earth4"])                 # intérieur des oreilles
        for x, yy in ((19, 7), (20, 7), (21, 7), (20, 8), (17, 9), (17, 10), (18, 10)):
            b.dot(x, yy + (hy if yy < 9 else bob), P["sun0"])   # joue et poitrail blancs
        b.dot(20, 5 + hy, O)                               # oeil vif
        b.dot(21, 4 + hy, P["sun0"])                       # reflet
        b.dot(24, 7 + hy, O)                               # truffe
        for x, yy in ((0, 7), (0, 8), (0, 9), (1, 7), (1, 10)):
            b.dot(x, yy + bob, P["sun0"])                  # bout de queue blanc
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


ALL = {
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
    sheet(sb.PREVIEW / "faune_v2.png")
    sheet(sb.PREVIEW / "faune_avant_apres.png", before)
    print("planche :", sb.PREVIEW / "faune_v2.png")
