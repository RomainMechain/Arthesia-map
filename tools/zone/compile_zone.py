"""Compile un layout de zone en fichier de build pour Godot + aperçu.

Entrées : data/layouts/<floor>/<zone>.json (géographie), data/zones/<floor>/<zone>.json (gameplay),
          data/templates/... (noms, dialogues).
Sorties : data/build/<zone>.build.json (lu par tools/godot/build_zone.gd)
          art/preview/<zone>_build.png (aperçu composé à partir des mêmes données)

Tout est déterministe (graines fixes) : recompiler redonne la même carte.
Usage : python tools/zone/compile_zone.py floor_1 village_aube
"""
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
T = 16
ART = "assets/art"


def res(rel):
    return f"res://{ART}/{rel}"


# --------------------------------------------------------------------------- géométrie
def seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    t = 0 if L == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / L))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def poly_dist(p, pts):
    return min(seg_dist(p, a, b) for a, b in zip(pts, pts[1:]))


def in_poly(p, poly):
    x, y = p
    inside = False
    for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside


def shape_contains(shape, p, grow=0.0):
    if "poly" in shape:
        return in_poly(p, shape["poly"])
    if "circle" in shape:
        cx, cy, r = shape["circle"]
        return math.hypot(p[0] - cx, p[1] - cy) <= r + grow
    x, y, w, h = shape["rect"]
    return x - grow <= p[0] <= x + w + grow and y - grow <= p[1] <= y + h + grow


def polyline_samples(pts, step):
    """Points régulièrement espacés le long d'une polyligne, avec la normale."""
    out = []
    for a, b in zip(pts, pts[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(L / step))
        nx, ny = -(b[1] - a[1]) / L, (b[0] - a[0]) / L
        for i in range(n):
            t = i / n
            out.append(((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), (nx, ny)))
    return out


# Notes de lore des découvertes (texte original, cohérent avec le lore de l'étage 1)
LORE = {
    "lignes_sous_la_mousse": {
        "title": "Les lignes sous la mousse",
        "text": "Sous la mousse des sept pierres, les motifs ne sont pas sculptés : ils sont tracés, d'un seul "
                "trait, sans reprise, comme par une main qui n'hésitait jamais. Les lignes ne décrivent rien. "
                "Elles relient. Et quand on suit la plus longue du regard, elle ne s'arrête pas à la pierre : "
                "elle continue dans l'écorce des chênes morts, juste à côté.",
    },
    "cercle_immerge": {
        "title": "Le cercle sous l'îlot",
        "text": "Sous l'eau claire de l'anse, sept pierres taillées dessinent un cercle parfait. Leurs runes, "
                "d'un cyan presque éteint, battent au même rythme que la lumière de l'aube : une fois, puis rien, "
                "puis une fois. Ce n'est pas un ouvrage de pêcheurs. Quelqu'un, avant le village, a voulu que "
                "le lac garde quelque chose.",
    },
}

# Rayon où une bête prédatrice repère le joueur (px)
AGGRO = {"crabe_des_galets": 44, "heron_cendre": 44, "anguille_des_hauts_fonds": 60,
         "sanglier_des_fougeres": 70, "lynx_a_robe_claire": 44, "ours_moussu": 52, "veilleur_d_ecorce": 40}

# Tempérament des bêtes, déduit de leur description (docs/combat_v1.md)
TEMPER = {
    "crabe_des_galets": "predator",   # « attaquent les barques amarrées »
    "heron_cendre": "sentinel",       # « immobile… il surveille le lac »
    "anguille_des_hauts_fonds": "swimmer",   # vit dans l'eau des hauts-fonds, plonge et ressurgit
    "lapin_bondissant": "calm",       # « détale au moindre bruit »
    "oiseau_chanteur": "calm",
    "renardeau_curieux": "skittish",  # « il mord avant de fuir »
    "loup_dore": "predator",          # « rôdent plus près du village chaque matin »
    "sanglier_des_fougeres": "charger",   # « il charge tout ce qui bouge »
    "lynx_a_robe_claire": "ambusher",     # « se fond dans les rais de lumière… on ne le voit qu'au moment où il bondit »
    "ours_moussu": "guardian",            # « garde les sentiers… ne laisse passer personne »
    "veilleur_d_ecorce": "dormant",       # « ce qu'on prenait pour un chêne mort se déplie »
}


# --------------------------------------------------------------------------- compilateur
class Zone:
    def __init__(self, floor, zone_id):
        self.lay = json.loads((ROOT / f"data/layouts/{floor}/{zone_id}.json").read_text(encoding="utf-8"))
        self.zone = json.loads((ROOT / f"data/zones/{floor}/{zone_id}.json").read_text(encoding="utf-8"))
        self.W, self.H = self.lay["size_tiles"]
        self.blocked = [[False] * self.W for _ in range(self.H)]
        self.rng = random.Random(zone_id)
        self.layers = []
        self.floor_props, self.props, self.colliders = [], [], []
        self.fx = []
        self.interactables = []
        self.doors = [b["door"] for b in self.lay["buildings"] if "door" in b]
        self.forest = self.lay.get("forest_fill")
        self.ancient = self.lay.get("biome") == "foret_ancienne"
        # biome rive : lac, îlots, eau profonde, marais praticable, galets, pontons
        lay = self.lay
        self.lakes = [l["poly"] for l in lay.get("lake", [])]
        self.islands = [i["poly"] for i in lay.get("islands", [])]
        self.marsh = [r["poly"] for r in lay["regions"] if r["kind"] == "marsh"]
        self.shore = [r["poly"] for r in lay["regions"] if r["kind"] == "shore"]
        self.reeds = [r["poly"] for r in lay["regions"] if r["kind"] == "reeds"]
        dl = lay.get("deep_line")
        self.deep = (dl["points"] + [[self.W + 2, -2]]) if dl else None
        self.boardwalks = [p for p in lay["paths"] if p["kind"] == "boardwalk"]
        self.open_d = self._open_distance() if self.forest else None

    # -- rive
    def in_island(self, p):
        return any(in_poly(p, i) for i in self.islands)

    def in_lake(self, p):
        return any(in_poly(p, l) for l in self.lakes) and not self.in_island(p)

    def in_marsh(self, p):
        return any(in_poly(p, m) for m in self.marsh)

    def on_boardwalk(self, p, grow=0.0):
        return any(poly_dist(p, b["points"]) <= b["width"] / 2 + grow for b in self.boardwalks)

    def wet(self, p):
        """Eau infranchissable (lac hors marais et hors pontons)."""
        return self.in_lake(p) and not self.in_marsh(p) and not self.on_boardwalk(p)

    def no_veg(self, p):
        """Ni arbre ni fougère : eau, marais, galets, pontons."""
        return (self.in_lake(p) or self.in_marsh(p) or any(in_poly(p, s) for s in self.shore)
                or self.on_boardwalk(p, 0.6))

    # -- forêt « par défaut » : distance au terrain ouvert (sentier, clairières), en tuiles
    def open_dist(self, p):
        best = 1e9
        for pth in self.lay["paths"]:
            best = min(best, poly_dist(p, pth["points"]) - pth["width"] / 2)
        for poly in self.lakes + self.islands + self.marsh + self.shore:
            ring = poly + poly[:1]
            best = min(best, -poly_dist(p, ring) if in_poly(p, poly) else poly_dist(p, ring))
        for r in self.lay["regions"]:
            if r["kind"] not in ("clearing", "square_dirt", "open_wood"):
                continue
            if "poly" in r:
                ring = r["poly"] + r["poly"][:1]
                best = min(best, -poly_dist(p, ring) if in_poly(p, r["poly"]) else poly_dist(p, ring))
            elif "circle" in r:
                cx, cy, rad = r["circle"]
                best = min(best, math.hypot(p[0] - cx, p[1] - cy) - rad)
            else:
                x, y, w, h = r["rect"]
                dx = max(x - p[0], 0, p[0] - (x + w))
                dy = max(y - p[1], 0, p[1] - (y + h))
                best = min(best, math.hypot(dx, dy))
        return best

    def _open_distance(self):
        return [[self.open_dist((tx + 0.5, ty + 0.5)) for tx in range(self.W)] for ty in range(self.H)]

    def dense(self, tx, ty):
        return self.open_d[ty][tx] > self.forest["margin"]

    # -- occupation
    def block_rect(self, x, y, w, h):
        for ty in range(int(math.floor(y)), int(math.ceil(y + h))):
            for tx in range(int(math.floor(x)), int(math.ceil(x + w))):
                if 0 <= tx < self.W and 0 <= ty < self.H:
                    self.blocked[ty][tx] = True

    def free(self, x, y, r=0):
        for ty in range(int(y) - r, int(y) + r + 1):
            for tx in range(int(x) - r, int(x) + r + 1):
                if not (0 <= tx < self.W and 0 <= ty < self.H) or self.blocked[ty][tx]:
                    return False
        return True

    # -- grilles de coins
    def corners(self, pred):
        return [[pred((cx, cy)) for cx in range(self.W + 1)] for cy in range(self.H + 1)]

    def add_layer(self, name, atlas, cells):
        self.layers.append({"name": name, "atlas": atlas, "cells": cells})

    def overlay_layer(self, name, overlay_atlas, full_row, grid, full_atlas="ground_base"):
        """Tuile pleine (variante du sol de base) si 4 coins, sinon tuile de transition."""
        full, part = [], []
        for ty in range(self.H):
            for tx in range(self.W):
                tl, tr = grid[ty][tx], grid[ty][tx + 1]
                bl, br = grid[ty + 1][tx], grid[ty + 1][tx + 1]
                idx = tl * 8 + tr * 4 + bl * 2 + br
                if idx == 15:
                    full.append([tx, ty, self.rng.randrange(4), full_row])
                elif idx:
                    part.append([tx, ty, idx % 4, idx // 4])
        self.add_layer(name + "_plein", full_atlas, full)
        self.add_layer(name + "_bord", overlay_atlas, part)

    def build_ground(self):
        lay = self.lay
        forests = [r for r in lay["regions"] if r["kind"] == "forest_wall"]
        cells = []
        for ty in range(self.H):
            for tx in range(self.W):
                c = (tx + 0.5, ty + 0.5)
                # herbe sombre seulement au cœur des forêts : la lisière garde l'herbe claire
                dark = any(in_poly(c, f["poly"]) and poly_dist(c, f["poly"] + f["poly"][:1]) > 1.6
                           for f in forests)
                if self.forest:                     # sous le couvert : herbe sombre
                    dark = self.open_d[ty][tx] > self.forest["margin"] + 0.9
                    if self.ancient:                # forêt ancienne : sombre sauf sous la lumière des clairières
                        dark = not any(shape_contains(r, c) for r in self.lay["regions"] if r["kind"] == "clearing")
                cells.append([tx, ty, self.rng.randrange(4), 1 if dark else 0])
        self.add_layer("sol", "ground_base", cells)

        def on_path(p, kinds):
            for pth in lay["paths"]:
                grow = 0.2 if pth["kind"] == "lane" else -0.1
                if pth["kind"] in kinds and poly_dist(p, pth["points"]) <= pth["width"] / 2 + grow:
                    return True
            return False

        rock = [r for r in lay["regions"] if r["kind"] in ("rock", "square_dirt")]
        dirt_kinds = ("trail",) if self.forest else ("road_main", "road", "lane")   # en forêt, les allées restent herbeuses
        dirt = self.corners(lambda p: int(on_path(p, dirt_kinds)
                                          or any(in_poly(p, r["poly"]) for r in rock)))
        self.overlay_layer("terre", "overlay_dirt", 2, dirt)

        fields = [r for r in lay["regions"] if r["kind"] == "field"]
        fcells = []
        for f in fields:
            x, y, w, h = f["rect"]
            row = 0 if "ble" in f["id"] else 1
            for ty in range(y, y + h):
                for tx in range(x, x + w):
                    fcells.append([tx, ty, self.rng.randrange(2), row])
        self.add_layer("champs", "ground_fields", fcells)

        squares = [r for r in lay["regions"] if r["kind"] in ("square", "ruin_floor")]
        cob = self.corners(lambda p: int(any(shape_contains(s, p) for s in squares)))
        self.overlay_layer("paves", "overlay_cobble", 3, cob)

        ruins = [r for r in lay["regions"] if r["kind"] == "ruin_floor"]
        rcells = []
        for ty in range(self.H):
            for tx in range(self.W):
                pts = [(tx, ty), (tx + 1, ty), (tx, ty + 1), (tx + 1, ty + 1)]
                if any(all(shape_contains(r, p, grow=-0.6) for p in pts) for r in ruins):
                    rcells.append([tx, ty, 1 if self.rng.random() < 0.25 else 0, 0])
        self.add_layer("dalles", "ground_ruins", rcells)

        if self.lakes:                                   # plage de galets, sous l'eau du lac
            gal = self.corners(lambda p: int(any(in_poly(p, s) for s in self.shore)))
            self.overlay_layer("galets", "overlay_galets", 0, gal, full_atlas="ground_rive")
        water = self.corners(lambda p: int(any(poly_dist(p, w["points"]) <= w["width"] / 2
                                               for w in lay["water"]) or self.in_lake(p)))
        self.overlay_layer("eau", "overlay_water", 4, water)
        if self.lakes:
            # au-delà de la ligne des roseaux : eau sombre et immobile (pas de miroitement)
            if self.deep:
                deep = self.corners(lambda p: int(self.in_lake(p) and in_poly(p, self.deep)))
                self.overlay_layer("profonde", "overlay_profonde", 2, deep, full_atlas="ground_rive")
            anses = [r for r in lay["regions"] if r["kind"] == "shallows"]
            bas = self.corners(lambda p: int(self.in_lake(p) and any(shape_contains(a, p) for a in anses)))
            self.overlay_layer("eau_basses", "overlay_basses", 1, bas, full_atlas="ground_rive")
            mar = self.corners(lambda p: int(self.in_marsh(p)))
            self.overlay_layer("eau_marais", "overlay_marais", 1, mar, full_atlas="ground_rive")
            # pontons : planches dans le sens de marche (segments horizontaux ou verticaux)
            pcells = []
            for b in self.boardwalks:
                for a, c in zip(b["points"], b["points"][1:]):
                    vertical = abs(c[1] - a[1]) > abs(c[0] - a[0])
                    x0, x1 = sorted((a[0], c[0]))
                    y0, y1 = sorted((a[1], c[1]))
                    half = b["width"] / 2
                    for ty in range(int(math.floor(y0 - (0 if vertical else half))), int(math.ceil(y1 + (0 if vertical else half)))):
                        for tx in range(int(math.floor(x0 - (half if vertical else 0))), int(math.ceil(x1 + (half if vertical else 0)))):
                            if 0 <= tx < self.W and 0 <= ty < self.H:
                                pcells.append([tx, ty, self.rng.randrange(4), 5 if vertical else 4])
            seen = set()
            self.add_layer("ponton", "ground_rive", [c for c in pcells if (c[0], c[1]) not in seen and not seen.add((c[0], c[1]))])

        # occupation : routes, places, eau, champs
        for ty in range(self.H):
            for tx in range(self.W):
                c = (tx + 0.5, ty + 0.5)
                if on_path(c, ("road_main", "road", "lane", "trail", "boardwalk")) or any(shape_contains(s, c) for s in squares) \
                        or any(poly_dist(c, w["points"]) <= w["width"] / 2 + 0.6 for w in lay["water"]) \
                        or (self.lakes and self.no_veg(c)):
                    self.blocked[ty][tx] = True
        for f in fields:
            self.block_rect(*f["rect"])
        # collisions de l'eau : rangées de tuiles dont le centre est dans le lit, hors pont
        bridges = [b["rect"] for b in lay["buildings"] if b["kind"] == "bridge"]
        for ty in range(self.H):
            run = None
            for tx in range(self.W + 1):
                c = (tx + 0.5, ty + 0.5)
                wet = tx < self.W and (any(poly_dist(c, w["points"]) <= w["width"] / 2 - 0.2 for w in lay["water"])
                                       or (self.lakes and self.wet(c))) \
                    and not any(bx <= tx < bx + bw and by <= ty < by + bh for bx, by, bw, bh in bridges)
                if wet and run is None:
                    run = tx
                elif not wet and run is not None:
                    self.colliders.append({"rect": [run * T, ty * T, (tx - run) * T, T]})
                    run = None

    # -- props
    def on_road(self, p, margin):
        return any(poly_dist(p, pth["points"]) < pth["width"] / 2 + margin for pth in self.lay["paths"])

    def prop(self, rel, fx, fy, cols=None, floor=False, kind="decor"):
        """fx, fy en tuiles = point de pied (bas-centre). cols = [(ox, oy, w, h)] px relatifs au pied."""
        # garde-fou : jamais d'arbre ni de buisson sur une route (le feuillage déborde d'~1 tuile)
        if "/vegetation/" in rel and not rel.endswith(("fleurs_a.png", "fleurs_b.png", "fleurs_c.png")) \
                and "roseaux" not in rel and self.on_road((fx, fy - 0.3), 1.0):
            return None
        item = {"sprite": res(rel), "x": round(fx * T), "y": round(fy * T), "kind": kind}
        if cols:
            item["colliders"] = [list(c) for c in cols]
        (self.floor_props if floor else self.props).append(item)
        return item

    def foot_col(self, w, h):
        return [(-w // 2, -h, w, h)]

    def build_buildings(self):
        sprite = {
            "inn": "props/village/auberge.png", "stall": "props/village/etal_thessaly.png",
            "bridge": "props/village/pont.png",
        }
        ws_sprite = {"ws_cuisine_b": "cuisine", "ws_couture_b": "couture", "ws_sculpture_b": "sculpture",
                     "ws_forge_b": "forge", "ws_alchimie_b": "alchimie", "ws_enchantement_b": "enchantement"}
        houses = ["maison_chaume_a", "maison_tuile_a", "maison_bois_a", "maison_chaume_b", "maison_tuile_b"]
        hi = 0
        for b in self.lay["buildings"]:
            x, y, w, h = b["rect"]
            fx, fy = x + w / 2, y + h
            if b["kind"] == "bridge":
                rel = "props/anciens/pont_rondins.png" if self.ancient else sprite["bridge"]
                self.prop(rel, fx, fy, floor=True, kind="bridge")
                continue
            if b["kind"] == "hut":
                rel = {"cabane_bertold": "props/rive/cabane_a.png", "fumoir": "props/rive/fumoir.png"}.get(
                    b["id"], "props/rive/cabane_b.png")
                self.prop(rel, fx, fy, cols=self.foot_col(w * T - 8, int(h * T * 0.5)), kind="building")
                self.block_rect(x - 0.5, y - 0.5, w + 1, h + 1)
                if b["id"] == "fumoir":
                    self.fx.append({"kind": "smoke", "x": round((x + w * 0.45) * T), "y": round(y * T - 6)})
                continue
            if b["kind"] == "house":
                rel = f"props/village/{houses[hi % len(houses)]}.png"
                hi += 1
            elif b["kind"].startswith("workshop"):
                rel = f"props/ateliers/{ws_sprite[b['id']]}.png"
            else:
                rel = sprite[b["kind"]]
            ch = int(h * T * 0.55) if b["kind"] != "stall" else 12
            self.prop(rel, fx, fy, cols=self.foot_col(w * T - 6, ch), kind="building")
            self.block_rect(x - 0.5, y - 0.5, w + 1, h + 1)
            if b["id"] == "ws_forge_b":
                self.fx.append({"kind": "smoke", "x": round((x + w * 0.72) * T + 4), "y": round(y * T - 2)})
            if b["id"] in ("ws_cuisine_b", "auberge"):
                cxr = 0.7 if b["id"] == "ws_cuisine_b" else 0.78
                self.fx.append({"kind": "smoke_light", "x": round((x + w * cxr) * T + 4), "y": round(y * T - 2)})
            if b["kind"] == "house":
                self.house_life(b)

    def house_life(self, b):
        x, y, w, h = b["rect"]
        objs = [("tonneau", (8, 5)), ("banc", (16, 5)), ("bois_coupe", (16, 5)), ("caisse", (10, 5))]
        name, col = objs[self.rng.randrange(len(objs))]
        for side in (self.rng.choice((-1, 1)), 0):
            ox = x + w + 0.6 if side > 0 else x - 0.6
            if side == 0:
                ox = x + w - 0.8
            oy = y + h + 0.9
            if self.free(ox, oy - 0.5):
                self.prop(f"props/objets/{name}.png", ox, oy, cols=[(-col[0] // 2, -col[1], *col)])
                self.block_rect(ox - 0.5, oy - 1, 1, 1)
                return

    def build_landmarks(self):
        lay = self.lay
        lm = {l["id"]: l for l in lay["landmarks"]}
        if "puits_central" in lm:
            x, y = lm["puits_central"]["pos"]
            self.prop("props/village/puits.png", x + 0.5, y + 1.5, cols=[(-13, -9, 26, 9)], kind="landmark")
        # cercle d'arrivée des Marqués : pierres runiques autour du point d'apparition
        sx, sy = lay["spawn"]["pos"]
        if lay["spawn"].get("rune_circle"):
            for deg in (60, 100, 140, 220, 260, 300):
                a = math.radians(deg)
                px_, py_ = sx + 0.5 + math.cos(a) * 3.0, sy + 0.6 + math.sin(a) * 2.6
                self.prop("props/objets/pierre_runique.png", px_, py_, cols=[(-3, -3, 6, 3)], kind="landmark")
                self.block_rect(px_ - 0.5, py_ - 1, 1, 1)
            self.fx.append({"kind": "fireflies_rune", "x": round((sx + 0.5) * T), "y": round((sy + 0.5) * T)})
        # repères de la forêt
        if "panneau_entree" in lm:
            x, y = lm["panneau_entree"]["pos"]
            self.prop("props/foret/panneau.png", x + 0.5, y + 1, cols=[(-2, -3, 5, 3)], kind="landmark")
            self.block_rect(x, y, 1, 1)
        if "chene_ancien" in lm:
            x, y = lm["chene_ancien"]["pos"]
            self.prop("props/foret/chene_ancien.png", x + 0.5, y + 1, cols=[(-14, -8, 28, 8)], kind="landmark")
            self.block_rect(x - 2, y - 1, 5, 2)
        if "abri_aurin" in lm:
            x, y = lm["abri_aurin"]["pos"]
            self.prop("props/foret/auvent_aurin.png", x + 0.5, y + 1,
                      cols=[(-26, -10, 52, 10)], kind="landmark")
            self.block_rect(x - 2, y - 2, 6, 3)
        if "feu_aurin" in lm:
            x, y = lm["feu_aurin"]["pos"]
            self.prop("props/foret/feu_camp.png", x + 0.5, y + 1, cols=[(-7, -5, 14, 5)], kind="landmark")
            self.fx.append({"kind": "embers", "x": round((x + 0.5) * T), "y": round((y + 0.6) * T)})
            self.fx.append({"kind": "smoke_light", "x": round((x + 0.5) * T), "y": round((y + 0.4) * T)})
            self.block_rect(x - 0.5, y, 2, 1)
        if "panneau_rive" in lm:
            x, y = lm["panneau_rive"]["pos"]
            self.prop("props/foret/panneau.png", x + 0.5, y + 1, cols=[(-2, -3, 5, 3)], kind="landmark")
            self.block_rect(x, y, 1, 1)
        if "filets_bertold" in lm:                       # vie de pêcheur autour de Bertold
            x, y = lm["filets_bertold"]["pos"]
            self.prop("props/rive/filets.png", x - 1.5, y + 1, cols=[(-26, -3, 6, 3), (20, -3, 6, 3)], kind="landmark")
            self.prop("props/rive/barque_retournee.png", x + 1.8, y + 2.6, cols=[(-18, -6, 36, 6)])
            self.prop("props/rive/nasse.png", x - 3.6, y + 2.4, cols=[(-7, -4, 14, 4)])
            self.prop("props/rive/nasse.png", x + 4.6, y + 0.8, cols=[(-7, -4, 14, 4)])
            self.prop("props/objets/tonneau.png", x - 4.8, y + 0.9, cols=[(-4, -5, 8, 5)])
            self.block_rect(x - 5, y - 1, 10, 4)
        for b in self.boardwalks:                        # poteaux d'amarrage au bout des pontons
            ex, ey = b["points"][-1]
            for dx in (-1.0, 1.0):
                self.prop("props/rive/poteau.png", ex + 0.5 + dx * 1.1, ey + 0.4)
        if "barques" in lm:
            x, y = lm["barques"]["pos"]
            self.prop("props/rive/barque_vide.png", x, y + 1)
            self.prop("props/rive/barque.png", x + 4, y + 3.5)
        if "porte_lisiere" in lm:
            x, y = lm["porte_lisiere"]["pos"]
            self.prop("props/village/arche_lisiere.png", x + 0.5, y + 1,
                      cols=[(-28, -5, 6, 5), (22, -5, 6, 5)], kind="landmark")
        if "carriere" in lm:
            poly = next(r for r in lay["regions"] if r["kind"] == "rock")["poly"]
            for i in range(9):
                for _ in range(20):
                    p = (self.rng.uniform(4, 17), self.rng.uniform(3, 11))
                    if in_poly(p, poly) and self.free(*p):
                        rel = "props/objets/bloc_pierre.png" if i % 3 else "props/commun/rocher.png"
                        self.prop(rel, p[0], p[1], cols=[(-6, -5, 12, 5)])
                        self.block_rect(p[0] - 1, p[1] - 1, 2, 1.5)
                        break

    def build_entries(self):
        """PNJ, boutique, marché, quêtes, ateliers -> interactables + accessoires."""
        lay, zone = self.lay, self.zone
        by_id = {e["id"]: e for e in zone["entries"]}
        tpl_dir = ROOT / "data/templates"

        def tpl(kind, tid):
            folder = {"npc": "npcs", "shop": "shops", "player_market": "player_markets",
                      "quest_giver": "quests", "workshop": "workshops", "monster": "monsters",
                      "resource": "resources", "item": "items"}[kind]
            p = tpl_dir / folder / f"{tid}.json"
            return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}

        prof_names = {"herboristerie": "herboristerie", "bucheronnage": "bûcheronnage", "peche": "pêche", "minage": "minage",
                      "archeologie": "archéologie", "chasse": "chasse"}
        hosted = {}
        for eid, e in lay["entries"].items():
            if "at" in e:
                hosted.setdefault(e["at"], []).append(eid)
        for eid, e in lay["entries"].items():
            if "at" in e:
                continue
            entry = by_id[eid]
            kind, tid = entry["template_type"], entry["template_id"]
            t = tpl(kind, tid)
            x, y = e["pos"]
            quests = []
            for qid in hosted.get(eid, []):
                q = by_id[qid]
                qt = tpl("quest_giver", q["template_id"])
                quests.append({"entry_id": qid, "quest_id": q["template_id"], "name": qt.get("name", ""),
                               "spawn": q["spawn"]})
            item = {"entry_id": eid, "template_type": kind, "template_id": tid,
                    "name": t.get("name", e.get("label", eid)), "role": t.get("role", ""),
                    "x": round((x + 0.5) * T), "y": round((y + 1) * T), "quests": quests}
            if kind == "monster":
                # une entrée = un point d'apparition ; on y place la meute (pack) qui erre autour
                pack, radius = e.get("pack", 1), e.get("radius", 2.5)
                rare = entry.get("rarity") == "rare"
                for k in range(pack):
                    a = k * math.tau / pack + self.rng.uniform(-0.4, 0.4)
                    rr = 0 if pack == 1 else radius * 0.5
                    self.interactables.append({
                        **item, "entry_id": f"{eid}_{k + 1}" if pack > 1 else eid,
                        "x": round((x + 0.5 + math.cos(a) * rr) * T), "y": round((y + 1 + math.sin(a) * rr) * T),
                        "sprite": res(f"monsters/{tid}_idle.png"), "frames": 8,
                        "role": f"Niv. {t.get('level', 1)}" + (" · rare" if rare else ""),
                        "dialogues": [t.get("description", "")],
                        "mob": {"leash": round(radius * T), "level": t.get("level", 1),
                                "temper": TEMPER.get(tid, "predator" if t.get("role") != "normal" else "calm"),
                                "aggro": AGGRO.get(tid, 64),
                                "respawn": entry["spawn"].get("cooldown_seconds") or 60,
                                "spawn": entry["spawn"]}})
                continue
            if kind == "resource":
                prof = t.get("profession_required") or {}
                yields = []
                for yd in t.get("yields", []):
                    it_name = tpl("item", yd["item_id"]).get("name", yd["item_id"])
                    q = f"{yd['quantity_min']}" if yd["quantity_min"] == yd["quantity_max"] \
                        else f"{yd['quantity_min']}-{yd['quantity_max']}"
                    yields.append(f"{q} × {it_name}")
                item.update({
                    "sprite": res(f"props/ressources/{tid}.png"), "frames": 1,
                    "role": f"{prof_names.get(prof.get('profession_id'), prof.get('profession_id', ''))}"
                            f" niv. {prof.get('min_level', 1)}",
                    "dialogues": [t.get("description", "")],
                    "resource": {"gather_time": t.get("gather_time_seconds", 3), "yields": yields,
                                 "stock": entry["spawn"].get("stock") or 1,
                                 "respawn": entry["spawn"].get("cooldown_seconds") or 90}})
                self.interactables.append(item)
                self.block_rect(x - 0.5, y - 0.5, 2, 2)
                continue
            if kind == "npc":
                item["frames"] = 4
                item["rows"] = 3
                item["sprite"] = res(f"characters/npcs/{tid}_idle.png")
                item["dialogues"] = t.get("dialogues", [])
            elif kind == "shop":
                item["frames"] = 4
                item["rows"] = 3
                item["sprite"] = res("characters/npcs/thessaly_idle.png")
                item["y"] -= 12                         # derrière le comptoir : visible de la taille à la tête
                item["dialogues"] = [t.get("description", "")]
            elif kind == "player_market":
                self.prop("props/ruines/autel_ventes.png", x + 0.5, y + 1.3, cols=[(-15, -8, 30, 8)],
                          kind="landmark")
                item["dialogues"] = [t.get("description", "")]
                self.fx.append({"kind": "fireflies_rune", "x": round((x + 0.5) * T), "y": round((y + 0.5) * T)})
            self.interactables.append(item)
            self.block_rect(x - 0.5, y - 0.5, 2, 2)

        stations = {
            "forge": [("enclume", 0, 0, (12, 5)), ("minerai", 1.4, -0.2, (9, 4)), ("tonneau", -1.4, -0.1, (8, 5))],
            "alchimie": [("chaudron", 0, 0, (12, 6)), ("table_alambic", 1.6, -0.1, (12, 5))],
            "couture": [("metier_tisser", 0, 0.1, (16, 5)), ("corde_linge", 2.6, -0.4, None)],
            "sculpture": [("statue_inachevee", 0, 0, (12, 5)), ("bloc_pierre", 1.4, 0.1, (12, 5)),
                          ("bloc_pierre", -1.4, -0.2, (12, 5))],
            "cuisine": [("four", 0, 0, (16, 6)), ("bois_coupe", 1.6, 0.1, (16, 5)), ("tonneau", -1.2, 0, (8, 5))],
            "enchantement": [("pierre_runique", -0.6, 0, (6, 4)), ("pierre_runique", 0.8, -0.2, (6, 4))],
        }
        for eid, e in lay.get("extra_entries", {}).items():
            if eid.startswith("_"):
                continue
            x, y = e["pos"]
            if e["template_type"] == "resource":         # poste de récolte supplémentaire (même template)
                t = tpl("resource", e["template_id"])
                prof = t.get("profession_required") or {}
                yields = []
                for yd in t.get("yields", []):
                    q = f"{yd['quantity_min']}" if yd["quantity_min"] == yd["quantity_max"]                         else f"{yd['quantity_min']}-{yd['quantity_max']}"
                    yields.append(f"{q} × {tpl('item', yd['item_id']).get('name', yd['item_id'])}")
                self.interactables.append({
                    "entry_id": eid, "template_type": "resource", "template_id": e["template_id"],
                    "name": t.get("name", e.get("label", eid)), "quests": [],
                    "role": f"{prof_names.get(prof.get('profession_id'), prof.get('profession_id', ''))} niv. {prof.get('min_level', 1)}",
                    "x": round((x + 0.5) * T), "y": round((y + 1) * T),
                    "sprite": res(f"props/ressources/{e['template_id']}.png"), "frames": 1,
                    "dialogues": [t.get("description", "")],
                    "resource": {"gather_time": t.get("gather_time_seconds", 3), "yields": yields,
                                 "stock": e.get("stock", 3), "respawn": 90}})
                self.block_rect(x - 0.5, y - 0.5, 2, 2)
                continue
            if e["template_type"] == "ferry":            # la barque de Maëlis : traversée vers l'îlot
                tx_, ty_ = e["to"]
                self.interactables.append({
                    "entry_id": eid, "template_type": "ferry", "template_id": eid, "quests": [],
                    "name": e["label"], "role": "Traversée",
                    "x": round((x + 0.5) * T), "y": round((y + 1) * T),
                    "sprite": res("props/rive/barque.png"), "frames": 1,
                    "dialogues": ["Maëlis tient la barque : « Jusqu'aux roseaux, pas plus loin. »"
                                  if "back" in e else "La barque attend, amarrée à l'îlot."],
                    "extra": {"to": [round((tx_ + 0.5) * T), round((ty_ + 1) * T)]}})
                continue
            if e["template_type"] == "board":            # tableau des contrats du jour (village)
                self.interactables.append({
                    "entry_id": eid, "template_type": "board", "template_id": eid, "quests": [],
                    "name": e["label"], "role": "Contrats du jour",
                    "x": round((x + 0.5) * T), "y": round((y + 1) * T),
                    "sprite": res("props/village/tableau_contrats.png"), "frames": 1,
                    "dialogues": ["Trois demandes punaisées, renouvelées chaque jour."]})
                self.block_rect(x - 1, y, 3, 1)
                continue
            if e["template_type"] == "discovery":        # découverte de lore (note du Carnet)
                # le cercle repose sous l'eau claire, juste au large de la rive où l'on se tient
                self.prop("props/rive/cercle_immerge.png", x + 0.5, y - 0.6, floor=True, kind="landmark")
                self.fx.append({"kind": "fireflies_rune", "x": round((x + 0.5) * T), "y": round((y - 1.6) * T)})
                self.interactables.append({
                    "entry_id": eid, "template_type": "discovery", "template_id": eid, "quests": [],
                    "name": e["label"].split(" (")[0], "role": "Découverte",
                    "x": round((x + 0.5) * T), "y": round((y + 1.4) * T),
                    "dialogues": [LORE[eid]["text"]], "extra": {"note": eid, "title": LORE[eid]["title"]}})
                continue
            t = tpl(e["template_type"], e["template_id"])
            for name, dx, dy, col in stations[e["template_id"]]:
                fx, fy = x + 0.5 + dx, y + 1 + dy
                cols = [(-col[0] // 2, -col[1], *col)] if col else None
                self.prop(f"props/objets/{name}.png", fx, fy, cols=cols, kind="station")
            self.block_rect(x - 2, y - 1, 5, 2.5)
            self.interactables.append({
                "entry_id": eid, "template_type": "workshop", "template_id": e["template_id"],
                "name": t.get("name", e["label"]), "role": "Atelier",
                "x": round((x + 0.5) * T), "y": round((y + 1) * T), "quests": [],
                "dialogues": [t.get("description", "")]})
            if e["template_id"] == "enchantement":
                self.fx.append({"kind": "fireflies_rune", "x": round((x + 0.5) * T), "y": round((y + 0.3) * T)})
            if e["template_id"] == "forge":
                self.fx.append({"kind": "embers", "x": round((x + 0.5) * T), "y": round((y + 0.6) * T)})

    # -- habillage par règles
    def build_forests(self):
        trees_dark = ["arbre_sombre_a", "arbre_sombre_b", "arbre_sombre_c"]
        trees_light = ["arbre_aube_a", "arbre_aube_b", "arbre_aube_c"]
        for f in [r for r in self.lay["regions"] if r["kind"] == "forest_wall"]:
            poly = f["poly"]
            xs, ys = [p[0] for p in poly], [p[1] for p in poly]
            step = 1.55
            y = min(ys) - 1.0
            row = 0
            while y <= max(ys) + 2.2:
                x = min(xs) - 1 + (step / 2 if row % 2 else 0)
                while x <= max(xs) + 1:
                    p = (x + self.rng.uniform(-0.4, 0.4), y + self.rng.uniform(-0.35, 0.35))
                    if in_poly((p[0], p[1] - 0.6), poly) and -1 <= p[0] <= self.W + 1:
                        edge = poly_dist(p, poly + poly[:1]) < 1.2
                        pool = trees_light if (edge and self.rng.random() < 0.55) else trees_dark
                        self.prop(f"props/vegetation/{self.rng.choice(pool)}.png", p[0], p[1], kind="forest")
                    x += step
                y += step * 0.8
                row += 1
            # lisière : buissons et jeunes arbres devant le mur (dégradé de densité)
            for (p, n) in polyline_samples(poly + poly[:1], 1.3):
                out = (p[0] + n[0] * 0.9, p[1] + n[1] * 0.9)
                if in_poly(out, poly):
                    out = (p[0] - n[0] * 0.9, p[1] - n[1] * 0.9)
                if not (1 <= out[0] < self.W - 1 and 1 <= out[1] < self.H - 0.5):
                    continue
                if self.free(out[0], out[1] - 0.5) and self.rng.random() < 0.6:
                    rel = self.rng.choice(["buisson_a", "buisson_b", "buisson_sombre", "buisson_sombre"])
                    self.prop(f"props/vegetation/{rel}.png", out[0], out[1], kind="forest_edge")
            self.colliders.append({"polygon": [[round(px * T), round(py * T)] for px, py in poly]})

    def build_orchard(self):
        for r in [r for r in self.lay["regions"] if r["kind"] == "orchard"]:
            x, y, w, h = r["rect"]
            for ty in range(y, y + h, 2):
                for tx in range(x, x + w, 2):
                    fx, fy = tx + 1 + (0.5 if (ty // 2) % 2 else 0), ty + 1.6
                    self.prop("props/vegetation/arbre_fruitier.png", fx, fy, cols=[(-4, -4, 8, 4)])
            self.block_rect(x, y, w + 1, h + 1)

    def build_fields(self):
        for f in [r for r in self.lay["regions"] if r["kind"] == "field"]:
            x, y, w, h = f["rect"]
            gap = x + w // 2
            for tx in range(x, x + w):
                self.prop("props/village/cloture_h.png", tx + 0.5, y + 0.15, cols=[(-8, -3, 16, 3)])
                if tx != gap:
                    self.prop("props/village/cloture_h.png", tx + 0.5, y + h + 0.6, cols=[(-8, -3, 16, 3)])
            for ty in range(y, y + h):
                for sx in (x - 0.1, x + w + 0.1):
                    self.prop("props/village/cloture_v.png", sx, ty + 1, cols=[(-2, -16, 4, 16)])
            if "ble" in f["id"]:
                self.prop("props/objets/epouvantail.png", x + w / 2 + 1.5, y + h / 2 + 0.8)
            self.block_rect(x - 1, y - 1, w + 2, h + 2)

    def build_lanterns(self):
        lay = self.lay
        sq = next((r for r in lay["regions"] if r["id"] == "place_centrale"), None)
        if sq:
            cx, cy, rad = sq["circle"]
            placed = 0
            for k in range(24):
                if placed >= 6:
                    break
                a = k * math.tau / 24 + 0.13
                p = (cx + 0.5 + math.cos(a) * (rad + 0.6), cy + 0.5 + math.sin(a) * (rad + 0.6))
                near_path = any(poly_dist(p, pth["points"]) < pth["width"] / 2 + 0.7 for pth in lay["paths"])
                spaced = all(math.hypot(p[0] - q["x"] / T, p[1] - q["y"] / T) > 4.5
                             for q in self.props if q["sprite"].endswith("lanterne.png"))
                if not near_path and spaced and self.free(p[0], p[1] - 0.5):
                    self.prop("props/village/lanterne.png", p[0], p[1], cols=[(-3, -3, 6, 3)])
                    self.block_rect(p[0] - 0.5, p[1] - 1, 1, 1)
                    placed += 1
        for pid in ("route_lisiere", "route_rive"):
            pth = next((p for p in lay["paths"] if p["id"] == pid), None)
            if pth is None:
                continue
            for i, (p, n) in enumerate(polyline_samples(pth["points"], 7)):
                if i == 0:
                    continue
                side = 1 if i % 2 else -1
                q = (p[0] + n[0] * side * (pth["width"] / 2 + 0.8), p[1] + n[1] * side * (pth["width"] / 2 + 0.8))
                if self.free(q[0], q[1] - 0.5):
                    self.prop("props/village/lanterne.png", q[0], q[1], cols=[(-3, -3, 6, 3)])
                    self.block_rect(q[0] - 0.5, q[1] - 1, 1, 1)

    def near_door(self, p, r=2.0):
        return any(math.hypot(p[0] - (dx + 0.5), p[1] - (dy + 0.5)) < r for dx, dy in self.doors)

    def build_flowers(self):
        for pth in self.lay["paths"]:
            if pth["kind"] == "lane":
                continue
            for p, n in polyline_samples(pth["points"], 1.0):
                for side in (-1, 1):
                    if self.rng.random() > 0.28:
                        continue
                    q = (p[0] + n[0] * side * (pth["width"] / 2 + 0.7), p[1] + n[1] * side * (pth["width"] / 2 + 0.7))
                    if self.free(q[0], q[1]) and not self.near_door(q):
                        self.prop(f"props/vegetation/fleurs_{self.rng.choice('abc')}.png",
                                  q[0], q[1] + 0.5, floor=True)

    def build_open_trees(self):
        lay = self.lay
        target, placed = 28, 0
        cands = [(x + self.rng.uniform(0, 2), y + self.rng.uniform(0, 2))
                 for y in range(2, self.H - 2, 3) for x in range(2, self.W - 2, 3)]
        self.rng.shuffle(cands)
        forests = [r["poly"] for r in lay["regions"] if r["kind"] == "forest_wall"]
        for c in cands:
            if placed >= target:
                break
            if any(in_poly(c, f) or poly_dist(c, f + f[:1]) < 2.2 for f in forests):
                continue
            if any(poly_dist(c, pth["points"]) < pth["width"] / 2 + 3 for pth in lay["paths"]):
                continue
            if not self.free(c[0], c[1] - 0.5, r=1):
                continue
            n = self.rng.choice((2, 2, 3))
            for k in range(n):
                q = (c[0] + self.rng.uniform(-1.6, 1.6), c[1] + self.rng.uniform(-1.2, 1.2)) if k else c
                if self.free(q[0], q[1] - 0.5):
                    rel = self.rng.choice(["arbre_aube_a", "arbre_aube_b", "arbre_aube_c", "buisson_a"])
                    col = [(-5, -4, 10, 4)] if rel.startswith("arbre") else [(-6, -4, 12, 4)]
                    self.prop(f"props/vegetation/{rel}.png", q[0], q[1], cols=col)
                    self.block_rect(q[0] - 1, q[1] - 1.5, 2, 2)
            placed += 1

    def build_stream_banks(self):
        bridges = [b["rect"] for b in self.lay["buildings"] if b["kind"] == "bridge"]
        for w in self.lay["water"]:
            for p, n in polyline_samples(w["points"], 1.4):
                if any(bx - 3 <= p[0] <= bx + bw + 3 for bx, by, bw, bh in bridges):
                    continue
                for side in (-1, 1):
                    if self.rng.random() > 0.35:
                        continue
                    q = (p[0] + n[0] * side * (w["width"] / 2 + 0.2), p[1] + n[1] * side * (w["width"] / 2 + 0.2))
                    if 0.5 < q[0] < self.W - 0.5:
                        self.prop(f"props/vegetation/roseaux_{self.rng.choice('ab')}.png", q[0], q[1] + 0.4)

    def build_garin_dock(self):
        lm = next((l for l in self.lay["landmarks"] if l["id"] == "ponton_garin"), None)
        if lm:
            x, y = lm["pos"]
            self.prop("props/objets/tonneau.png", x - 0.6, y - 0.6, cols=[(-4, -5, 8, 5)])
            self.prop("props/objets/caisse.png", x + 0.6, y - 0.7, cols=[(-5, -5, 10, 5)])
            self.prop("props/objets/tonneau.png", x + 0.1, y - 1.5, cols=[(-4, -5, 8, 5)])

    # -- biome forêt : la forêt remplit tout ce qui n'est ni sentier ni clairière
    def build_forest_fill(self):
        m = self.forest["margin"]
        dark_x = self.forest.get("dark_from_x", self.W)
        light = ["arbre_aube_a", "arbre_aube_b", "arbre_aube_c"]
        dark = ["arbre_sombre_a", "arbre_sombre_b", "arbre_sombre_c"]
        folder = "vegetation"
        step, row, y = 1.6, 0, -0.4
        if self.ancient:
            light = dark = ["arbre_ancien_a", "arbre_ancien_b", "arbre_ancien_c"]
            folder = "anciens"
            step = 2.2
        while y <= self.H + 2.4:
            x = -0.8 + (step / 2 if row % 2 else 0)
            while x <= self.W + 0.8:
                p = (x + self.rng.uniform(-0.4, 0.4), y + self.rng.uniform(-0.3, 0.3))
                d = self.open_dist((p[0], p[1] - 0.4))
                if d > m - 0.5:
                    # plus sombre vers l'est (la Forêt des Anciens) et au cœur des massifs
                    p_dark = min(1.0, max(0.0, (p[0] - 8) / max(1, dark_x - 8))) * 0.8 + (0.3 if d > m + 2 else 0)
                    if d < m + 0.4:
                        p_dark *= 0.4                     # la lisière reste claire
                    pool = dark if self.rng.random() < p_dark else light
                    edge = d < m + 0.3
                    rel = f"props/{folder}/{self.rng.choice(pool)}.png"
                    if self.ancient and d > m + 2.5 and self.rng.random() < 0.04:
                        rel = "props/anciens/arbre_geant.png"     # quelques géants dépassent de la voûte
                    self.prop(rel, p[0], p[1], cols=[(-6, -4, 12, 4)] if edge else None, kind="forest")
                x += step
            y += step * 0.85
            row += 1
        # collisions : rangées de tuiles du massif (au-delà de la marge)
        for ty in range(self.H):
            run = None
            for tx in range(self.W + 1):
                solid = tx < self.W and self.open_d[ty][tx] > m + 0.2
                if solid and run is None:
                    run = tx
                elif not solid and run is not None:
                    self.colliders.append({"rect": [run * T, ty * T, (tx - run) * T, T]})
                    run = None
                if solid:
                    self.blocked[ty][tx] = True

    def build_undergrowth(self):
        m = self.forest["margin"]
        ferns = ["fougere_a", "fougere_b", "fougere_c"]
        for ty in range(self.H):
            for tx in range(self.W):
                d = self.open_d[ty][tx]
                if self.blocked[ty][tx] or d > m + 0.3:
                    continue
                p = (tx + self.rng.uniform(0.15, 0.85), ty + self.rng.uniform(0.5, 1.0))
                if self.on_road(p, 0.5) or (self.lakes and self.no_veg(p)):
                    continue
                r = self.rng.random()
                if d > 0:                                 # bande de lisière
                    if r < 0.34:
                        self.prop(f"props/foret/{self.rng.choice(ferns)}.png", *p, kind="undergrowth")
                    elif r < 0.42:
                        rel = self.rng.choice(["buisson_a", "buisson_b", "buisson_sombre"])
                        self.prop(f"props/vegetation/{rel}.png", *p, cols=[(-6, -4, 12, 4)])
                        self.block_rect(p[0] - 0.5, p[1] - 1, 1, 1)
                    elif r < 0.445 and d > 0.5:
                        self.prop("props/foret/souche.png", *p, cols=[(-6, -5, 12, 5)])
                        self.block_rect(p[0] - 0.5, p[1] - 1, 1, 1)
                    elif r < 0.455 and d > 0.6 and self.free(p[0] + 1, p[1] - 0.5):
                        self.prop("props/foret/tronc_couche.png", *p, cols=[(-16, -7, 32, 6)])
                        self.block_rect(p[0] - 1.5, p[1] - 1, 3, 1)
                    elif r < 0.50:
                        self.prop("props/foret/champignons_deco.png", *p, floor=True)
                else:                                     # dans les clairières : clairsemé
                    if r < 0.035 and d > -1.5:
                        self.prop(f"props/foret/{self.rng.choice(ferns)}.png", *p, kind="undergrowth")
                    elif r < 0.06:
                        self.prop(f"props/vegetation/fleurs_{self.rng.choice('abc')}.png", *p, floor=True)

    def build_rive(self):
        """Habillage de rive : roselières denses dans l'eau, nénuphars, canards, saules, bois flotté."""
        if not self.lakes:
            return
        for poly in self.reeds:                          # roselières : touffes serrées, dans l'eau
            xs, ys = [p[0] for p in poly], [p[1] for p in poly]
            y = min(ys)
            while y <= max(ys) + 1:
                x = min(xs)
                while x <= max(xs) + 1:
                    p = (x + self.rng.uniform(-0.3, 0.3), y + self.rng.uniform(-0.2, 0.2))
                    if in_poly(p, poly) and not self.on_boardwalk(p, 0.8):
                        self.prop(f"props/rive/roseaux_{self.rng.choice('ab')}.png", p[0], p[1] + 0.6, kind="reeds")
                    x += 1.1
                y += 0.9
        # nénuphars et canards : sur l'eau calme près de l'îlot, de l'anse et des hauts-fonds
        spots = [(i, 3.5) for i in [(sum(p[0] for p in isl) / len(isl), sum(p[1] for p in isl) / len(isl)) for isl in self.islands]]
        spots += [((r["circle"][0], r["circle"][1]), r["circle"][2] + 1.5) for r in self.lay["regions"] if r["kind"] == "shallows"]
        spots += [((sum(p[0] for p in m) / len(m), sum(p[1] for p in m) / len(m)), 6.0) for m in self.marsh]
        for (cx, cy), rad in spots:
            for _ in range(14):
                a, d = self.rng.uniform(0, math.tau), self.rng.uniform(rad * 0.6, rad + 3)
                p = (cx + math.cos(a) * d, cy + math.sin(a) * d * 0.7)
                if (self.in_lake(p) or self.in_marsh(p)) and not self.on_boardwalk(p, 1.0):
                    self.prop(f"props/rive/nenuphars_{self.rng.choice('ab')}.png", p[0], p[1], floor=True)
        for k in range(5):                               # canards immobiles près de l'îlot
            for _ in range(20):
                if not self.islands:
                    break
                isl = self.islands[0]
                p = (self.rng.uniform(min(q[0] for q in isl) - 4, max(q[0] for q in isl) + 4),
                     self.rng.uniform(min(q[1] for q in isl) - 3, max(q[1] for q in isl) + 3))
                if self.in_lake(p) and not self.on_boardwalk(p, 1.5):
                    self.prop("props/rive/canard.png", p[0], p[1] + 0.4)
                    break
        placed = 0                                        # saules au bord du pré
        cands = [(x + self.rng.uniform(0, 3), y + self.rng.uniform(0, 3)) for y in range(4, self.H - 3, 4) for x in range(4, self.W - 4, 4)]
        self.rng.shuffle(cands)
        for c in cands:
            if placed >= 10:
                break
            d = self.open_dist(c)
            if -4.5 < d < -1.2 and not self.no_veg(c) and self.free(c[0], c[1] - 0.5, r=1) and not self.on_road(c, 2.0):
                self.prop(f"props/rive/saule_{self.rng.choice('ab')}.png", c[0], c[1], cols=[(-5, -4, 10, 4)])
                self.block_rect(c[0] - 1, c[1] - 1.5, 2, 2)
                placed += 1
        for poly in self.shore:                          # bois flotté sur les galets
            for _ in range(6):
                for _ in range(20):
                    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
                    p = (self.rng.uniform(min(xs), max(xs)), self.rng.uniform(min(ys), max(ys)))
                    if in_poly(p, poly) and not self.on_road(p, 1.0) and not self.in_lake(p):
                        self.prop("props/rive/bois_flotte.png", p[0], p[1], floor=True)
                        break

    def build_anciens(self):
        """Forêt des Anciens : sous-bois clairs, champ de fougères, camp d'Isarn, cercle de pierres,
        chênes morts, fosse des ours."""
        if not self.ancient:
            return
        lay = self.lay
        lm = {l["id"]: l for l in lay["landmarks"]}
        if "panneau_anciens" in lm:
            x, y = lm["panneau_anciens"]["pos"]
            self.prop("props/foret/panneau.png", x + 0.5, y + 1, cols=[(-2, -3, 5, 3)], kind="landmark")
            self.block_rect(x, y, 1, 1)
        if "camp_isarn" in lm:
            x, y = lm["camp_isarn"]["pos"]
            self.prop("props/anciens/tente.png", x - 1.5, y + 0.5, cols=[(-20, -10, 40, 10)], kind="landmark")
            self.prop("props/anciens/billot_hache.png", x + 3.2, y + 1.6, cols=[(-6, -5, 12, 5)])
            self.prop("props/anciens/bois_empile.png", x - 5.0, y + 2.6, cols=[(-15, -6, 30, 6)])
            self.prop("props/foret/feu_camp.png", x + 1.0, y + 3.4, cols=[(-7, -5, 14, 5)])
            self.fx.append({"kind": "smoke_light", "x": round((x + 1.0) * T), "y": round((y + 3.0) * T)})
            self.block_rect(x - 5, y - 2, 10, 5)
        if "chene_millenaire" in lm:
            x, y = lm["chene_millenaire"]["pos"]
            self.prop("props/anciens/arbre_geant.png", x + 0.5, y + 1, cols=[(-14, -6, 28, 6)], kind="landmark")
            self.block_rect(x - 1, y - 1, 3, 2)
        if "affut_vesna" in lm:
            x, y = lm["affut_vesna"]["pos"]
            self.prop("props/ressources/affut_des_berges.png", x + 0.5, y + 1, cols=[(-13, -5, 26, 5)], kind="landmark")
            self.block_rect(x - 1, y, 3, 1)
        if "cercle_pierres" in lm:
            x, y = lm["cercle_pierres"]["pos"]
            for k in range(7):                                  # sept pierres en cercle parfait
                a = k * math.tau / 7 - math.pi / 2
                px_, py_ = x + 0.5 + math.cos(a) * 4.2, y + 0.8 + math.sin(a) * 3.2
                self.prop("props/anciens/pierre_cercle.png", px_, py_, cols=[(-5, -4, 10, 4)], kind="landmark")
                self.block_rect(px_ - 0.5, py_ - 1, 1, 1)
            self.fx.append({"kind": "fireflies_rune", "x": round((x + 0.5) * T), "y": round((y + 0.5) * T)})
        if "chenes_morts" in lm:
            x, y = lm["chenes_morts"]["pos"]
            for i, (dx, dy) in enumerate(((-2.6, 0.4), (2.4, -0.6), (0.6, -2.4), (-1.0, 2.6))):
                self.prop(f"props/anciens/chene_mort_{'ab'[i % 2]}.png", x + 0.5 + dx, y + 1 + dy,
                          cols=[(-4, -3, 8, 3)], kind="landmark")
                self.block_rect(x + dx, y + dy, 1, 1)
        if "os_ours" in lm:
            x, y = lm["os_ours"]["pos"]
            for dx, dy, rel in ((-1.5, 0.3, "ossements"), (1.6, -0.6, "terre_retournee"), (0.4, 1.4, "ossements")):
                self.prop(f"props/anciens/{rel}.png", x + dx, y + dy, floor=True)
        # sous-bois clairs : arbres anciens espacés (troncs à collision), fougères, racines, pierres
        woods = [r["poly"] for r in lay["regions"] if r["kind"] == "open_wood"]
        clears = [r for r in lay["regions"] if r["kind"] == "clearing"]
        for poly in woods:
            xs, ys = [p[0] for p in poly], [p[1] for p in poly]
            y = min(ys) + 1.5
            row = 0
            while y < max(ys):
                x = min(xs) + (2.1 if row % 2 else 0)
                while x < max(xs):
                    p = (x + self.rng.uniform(-1.0, 1.0), y + self.rng.uniform(-0.8, 0.8))
                    ok = in_poly(p, poly) and not any(shape_contains(c, p, grow=0.8) for c in clears) \
                        and not self.on_road(p, 1.6) and self.free(p[0], p[1] - 0.5, r=1)
                    if ok and self.rng.random() < 0.8:
                        self.prop(f"props/anciens/arbre_ancien_{self.rng.choice('abc')}.png", p[0], p[1],
                                  cols=[(-5, -5, 10, 5)], kind="forest")
                        self.block_rect(p[0] - 0.5, p[1] - 1, 1, 1)
                    x += 4.2
                y += 3.4
                row += 1
            for _ in range(int(len(poly) * 14)):                # sol du sous-bois
                p = (self.rng.uniform(min(xs), max(xs)), self.rng.uniform(min(ys), max(ys)))
                if not in_poly(p, poly) or self.on_road(p, 0.8) or not self.free(p[0], p[1] - 0.5):
                    continue
                r = self.rng.random()
                if r < 0.55:
                    self.prop(f"props/foret/fougere_{self.rng.choice('abc')}.png", *p, kind="undergrowth")
                elif r < 0.7:
                    self.prop("props/anciens/racines.png", *p, floor=True)
                elif r < 0.78:
                    self.prop(f"props/anciens/pierre_moussue_{self.rng.choice('ab')}.png", *p, cols=[(-6, -4, 12, 4)])
                    self.block_rect(p[0] - 0.5, p[1] - 1, 1, 1)
                elif r < 0.86:
                    self.prop("props/foret/champignons_deco.png", *p, floor=True)
        # mer de fougères : hautes, denses, praticables ; terre labourée par les sangliers
        for r in lay["regions"]:
            if r["kind"] != "fern_field":
                continue
            poly = r["poly"]
            xs, ys = [p[0] for p in poly], [p[1] for p in poly]
            y = min(ys)
            while y <= max(ys):
                x = min(xs)
                while x <= max(xs):
                    p = (x + self.rng.uniform(-0.4, 0.4), y + self.rng.uniform(-0.3, 0.3))
                    if in_poly(p, poly) and not self.on_road(p, 0.6) and self.free(p[0], p[1] - 0.5):
                        if self.rng.random() < 0.12:
                            self.prop("props/anciens/terre_retournee.png", *p, floor=True)
                        else:
                            self.prop(f"props/anciens/fougere_haute_{self.rng.choice('abc')}.png", p[0], p[1] + 0.3,
                                      kind="undergrowth")
                    x += 1.25
                y += 1.0

    def build_mist(self):
        if not self.lay.get("ambient", {}).get("mist"):
            return
        for r in self.lay["regions"]:
            if r["kind"] != "clearing":
                continue
            if "poly" in r:
                xs, ys = [p[0] for p in r["poly"]], [p[1] for p in r["poly"]]
                cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
                w, h = (max(xs) - min(xs)) * 0.5, (max(ys) - min(ys)) * 0.5
            elif "circle" in r:
                cx, cy, rad = r["circle"]
                w = h = rad * 1.4
            else:
                x, y, w, h = r["rect"]
                cx, cy = x + w / 2, y + h / 2
                w, h = w * 0.7, h * 0.7
            self.fx.append({"kind": "mist", "x": round(cx * T), "y": round(cy * T),
                            "w": round(w * T), "h": round(h * T)})

    def compile(self):
        lay = self.lay
        self.build_ground()
        self.build_buildings()
        self.build_landmarks()
        self.build_entries()
        if self.forest:
            self.build_forest_fill()
            self.build_anciens()
            self.build_rive()
            self.build_undergrowth()
            self.build_mist()
        else:
            self.build_garin_dock()
            self.build_fields()
            self.build_orchard()
            self.build_lanterns()
            self.build_forests()
            self.build_open_trees()
        self.build_stream_banks()
        self.build_flowers()
        W, H = self.W * T, self.H * T
        bounds = [[-32, -32, W + 64, 32], [-32, H, W + 64, 32], [-32, 0, 32, H], [W, 0, 32, H]]
        self.colliders += [{"rect": b, "bounds": True} for b in bounds]
        exits = [{"id": e["id"], "to": e["to"], "label": e["label"], "hidden": e.get("hidden", False),
                  "rect": [v * T for v in e["rect"]],
                  "arrival": [(e["arrival"][0] + 0.5) * T, (e["arrival"][1] + 1) * T]} for e in lay["exits"]]
        sx, sy = lay["spawn"]["pos"]
        return {
            "zone_id": lay["zone_id"], "name": self.zone["name"], "zone_type": self.zone.get("type", "wilderness"),
            "size_px": [W, H], "tile_size": T,
            "atlases": {
                "ground_base": res("tiles/floor_1/ground_base.png"),
                "ground_fields": res("tiles/floor_1/ground_fields.png"),
                "ground_ruins": res("tiles/floor_1/ground_ruins.png"),
                "overlay_dirt": res("tiles/floor_1/overlay_dirt.png"),
                "overlay_cobble": res("tiles/floor_1/overlay_cobble.png"),
                "overlay_water": res("tiles/floor_1/overlay_water.png"),
                "ground_rive": res("tiles/floor_1/ground_rive.png"),
                "overlay_galets": res("tiles/floor_1/overlay_galets.png"),
                "overlay_basses": res("tiles/floor_1/overlay_basses.png"),
                "overlay_profonde": res("tiles/floor_1/overlay_profonde.png"),
                "overlay_marais": res("tiles/floor_1/overlay_marais.png"),
            },
            "slow_polys": [[[round(x * T), round(y * T)] for x, y in m] for m in self.marsh],
            "layers": self.layers, "floor_props": self.floor_props, "props": self.props,
            "colliders": self.colliders, "interactables": self.interactables, "fx": self.fx,
            "exits": exits, "spawn": [(sx + 0.5) * T, (sy + 1) * T],
            "ambient": {"modulate": lay.get("ambient", {}).get("modulate", "#fff4e0")},
            "music_mood": lay.get("ambient", {}).get("music_mood", ""),
        }


# --------------------------------------------------------------------------- aperçu
def render_preview(build, out):
    W, H = build["size_px"]
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    cache = {}

    def load(path):
        if path not in cache:
            cache[path] = Image.open(ROOT / path.replace("res://", "")).convert("RGBA")
        return cache[path]

    for layer in build["layers"]:
        atlas = load(build["atlases"][layer["atlas"]])
        for tx, ty, ax, ay in layer["cells"]:
            tile = atlas.crop((ax * T, ay * T, ax * T + T, ay * T + T))
            img.alpha_composite(tile, (tx * T, ty * T))

    def draw(item, nframes=None):
        spr = load(item["sprite"])
        if nframes and nframes > 1:
            spr = spr.crop((0, 0, spr.width // nframes, spr.height // int(item.get("rows", 1))))
        x, y = int(item["x"]) - spr.width // 2, int(item["y"]) - spr.height
        if -spr.width < x < W and -spr.height < y < H:
            img.alpha_composite(spr, (max(0, x), max(0, y)),
                                (max(0, -x), max(0, -y)))

    for fp in build["floor_props"]:
        draw(fp)
    drawables = [(p["y"], p, None) for p in build["props"]]
    for it in build["interactables"]:
        if "sprite" in it:
            drawables.append((it["y"], it, it.get("frames", 4)))
    drawables.append((build["spawn"][1], {"sprite": res("characters/player/player_idle_down.png"),
                                          "x": build["spawn"][0], "y": build["spawn"][1]}, 4))
    for _, item, fw in sorted(drawables, key=lambda d: d[0]):
        draw(item, fw)
    img.save(out)


# --------------------------------------------------------------------------- mini-carte
# Un pixel par tuile, couleurs de la palette : herbe, couvert forestier, chemins, eau (claire,
# profonde, hauts-fonds), pontons, galets, pavés, champs, bâtiments. Lue par game/ui/minimap.gd.
MINI = {
    "herbe": (116, 168, 67), "foret": (47, 90, 58), "terre": (212, 162, 101), "paves": (196, 181, 156),
    "champs": (245, 184, 74), "dalles": (148, 134, 114), "galets": (236, 226, 207), "eau": (82, 170, 184),
    "profonde": (36, 78, 112), "basses": (143, 216, 208), "ponton": (168, 116, 63), "batiment": (168, 58, 64),
    "pont": (168, 116, 63),
}
LAYER_COLOR = {"terre": "terre", "champs": "champs", "paves": "paves", "dalles": "dalles", "galets": "galets",
               "eau": "eau", "profonde": "profonde", "eau_basses": "basses", "eau_marais": "basses",
               "ponton": "ponton"}


def render_minimap(z, out):
    img = Image.new("RGB", (z.W, z.H), MINI["herbe"])
    px = img.load()
    for layer in z.layers:
        name = layer["name"]
        if name == "sol":
            for tx, ty, _v, row in layer["cells"]:
                if row == 1:
                    px[tx, ty] = MINI["foret"]
            continue
        key = name.removesuffix("_plein").removesuffix("_bord")
        col = LAYER_COLOR.get(key)
        if not col:
            continue
        edge = name.endswith("_bord")
        for c in layer["cells"]:
            tx, ty = c[0], c[1]
            if 0 <= tx < z.W and 0 <= ty < z.H:
                if edge and key in ("eau", "profonde", "eau_basses", "eau_marais", "galets"):
                    idx = c[3] * 4 + c[2]            # tuile de bord : au moins 2 coins dedans
                    if bin(idx).count("1") < 2:
                        continue
                px[tx, ty] = MINI[col]
    if z.forest:                                          # le couvert, là où l'on ne passe pas
        for ty in range(z.H):
            for tx in range(z.W):
                if z.open_d[ty][tx] > z.forest["margin"] + 0.2 and not (z.lakes and z.in_lake((tx + 0.5, ty + 0.5))):
                    px[tx, ty] = MINI["foret"]
    for r in z.lay["regions"]:
        if r["kind"] == "forest_wall":
            for ty in range(z.H):
                for tx in range(z.W):
                    if in_poly((tx + 0.5, ty + 0.5), r["poly"]):
                        px[tx, ty] = MINI["foret"]
    for b in z.lay["buildings"]:
        x, y, w, h = b["rect"]
        col = MINI["pont"] if b["kind"] == "bridge" else MINI["batiment"]
        for ty in range(int(y), int(y + h)):
            for tx in range(int(x), int(x + w)):
                if 0 <= tx < z.W and 0 <= ty < z.H:
                    px[tx, ty] = col
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)


def main(floor, zone_id):
    z = Zone(floor, zone_id)
    build = z.compile()
    render_minimap(z, ROOT / ART / "minimap" / f"{zone_id}.png")
    build["minimap"] = res(f"minimap/{zone_id}.png")
    out = ROOT / "data" / "build" / f"{zone_id}.build.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(build, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    prev = ROOT / "art" / "preview" / f"{zone_id}_build.png"
    render_preview(build, prev)
    n_cells = sum(len(l["cells"]) for l in build["layers"])
    print(f"{out.relative_to(ROOT)} : {n_cells} tuiles, {len(build['props'])} props, "
          f"{len(build['floor_props'])} props au sol, {len(build['colliders'])} collisions, "
          f"{len(build['interactables'])} interactions")
    print(prev)


if __name__ == "__main__":
    main(*sys.argv[1:3])
