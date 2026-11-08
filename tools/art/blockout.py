"""Rend un layout de zone (data/layouts/...) en plan blockout annoté, pour validation.

Usage : python tools/art/blockout.py data/layouts/floor_1/village_aube.json
Sortie : art/preview/<zone>_blockout.png
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
S = 20            # px par tuile dans le plan (recalculé selon la taille de la zone)
LEGEND_W = 380

COL = {
    "bg": (172, 196, 120), "grid": (160, 184, 110),
    "forest_wall": (58, 98, 66), "square": (206, 196, 176), "ruin_floor": (180, 210, 214),
    "field": (222, 206, 120), "road_main": (236, 214, 160), "road": (236, 214, 160),
    "lane": (226, 204, 150), "stream": (82, 170, 184),
    "inn": (214, 120, 60), "house": (232, 168, 96), "stall": (190, 120, 80),
    "bridge": (150, 104, 64), "rock": (150, 140, 124), "orchard": (128, 170, 90),
    "workshop": (196, 132, 170), "workshop_ruin": (150, 196, 204), "view": (255, 250, 240), "outline": (42, 26, 46), "npc": (88, 104, 200),
    "shop": (224, 90, 72), "market": (42, 168, 192), "spawn": (255, 255, 255),
    "exit": (224, 90, 72), "landmark": (245, 184, 74), "text": (42, 26, 46),
    "panel": (250, 244, 230),
}


def font(size, bold=False):
    for name in (("arialbd.ttf" if bold else "arial.ttf"), "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def tp(p):
    return (p[0] * S, p[1] * S)


def main(path):
    global S
    lay = json.loads(Path(path).read_text(encoding="utf-8"))
    W, H = lay["size_tiles"]
    S = max(10, min(20, 1120 // W))
    img = Image.new("RGB", (W * S + LEGEND_W, max(H * S, 760)), COL["panel"])
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W * S, H * S], fill=COL["bg"])
    for x in range(0, W + 1):
        d.line([x * S, 0, x * S, H * S], fill=COL["grid"])
    for y in range(0, H + 1):
        d.line([0, y * S, W * S, y * S], fill=COL["grid"])

    f_small, f_mid, f_big = font(12), font(14, True), font(18, True)

    for r in lay["regions"]:
        c = COL[r["kind"]]
        if "poly" in r:
            d.polygon([tp(p) for p in r["poly"]], fill=c)
        elif "circle" in r:
            cx, cy, rad = r["circle"]
            d.ellipse([(cx - rad) * S, (cy - rad) * S, (cx + rad) * S, (cy + rad) * S], fill=c)
        else:
            x, y, w, h = r["rect"]
            d.rectangle([x * S, y * S, (x + w) * S, (y + h) * S], fill=c)
            if r["kind"] == "orchard":
                for yy in range(y, y + h):
                    for xx in range(x, x + w, 2):
                        cx, cy = (xx + 0.5) * S, (yy + 0.5) * S
                        d.ellipse([cx - S * 0.4, cy - S * 0.4, cx + S * 0.4, cy + S * 0.4],
                                  fill=COL["forest_wall"])
            if r["kind"] == "field":
                for yy in range(y * S + 5, (y + h) * S, 7):
                    d.line([x * S + 3, yy, (x + w) * S - 3, yy], fill=(196, 176, 90), width=2)

    for wtr in lay["water"]:
        d.line([tp(p) for p in wtr["points"]], fill=COL["stream"], width=wtr["width"] * S, joint="curve")
    for pth in lay["paths"]:
        pts = [tp(p) for p in pth["points"]]
        d.line(pts, fill=COL[pth["kind"]], width=pth["width"] * S, joint="curve")
        for p in pts:
            rr = pth["width"] * S / 2
            d.ellipse([p[0] - rr, p[1] - rr, p[0] + rr, p[1] + rr], fill=COL[pth["kind"]])

    for b in lay["buildings"]:
        x, y, w, h = b["rect"]
        d.rectangle([x * S, y * S, (x + w) * S, (y + h) * S], fill=COL[b["kind"]],
                    outline=COL["outline"], width=2)
        if "door" in b:
            dx, dy = b["door"]
            d.rectangle([dx * S + 4, dy * S + 6, dx * S + S - 4, dy * S + S], fill=COL["outline"])

    for ex in lay["exits"]:
        x, y, w, h = ex["rect"]
        d.rectangle([x * S, y * S, (x + w) * S, (y + h) * S], outline=COL["exit"], width=4)

    # repères (étoiles numérotées) et entrées (pastilles)
    legend = []
    for i, lm in enumerate(lay["landmarks"], 1):
        cx, cy = (lm["pos"][0] + 0.5) * S, (lm["pos"][1] + 0.5) * S
        r = 13 if lm["rank"] == 1 else 10
        d.regular_polygon((cx, cy, r), 5, rotation=-90, fill=COL["landmark"], outline=COL["outline"])
        d.text((cx, cy), str(i), font=f_small, fill=COL["outline"], anchor="mm")
        legend.append((f"({i})", lm["label"]))

    positions = {}
    tags = {"npc": ("npc", "P"), "shop": ("shop", "€"), "market": ("market", "⇄")}
    for eid, e in lay["entries"].items():
        if "at" in e:
            positions.setdefault(e["at"], []).append(eid)
            continue
        kind = "shop" if eid.startswith("shop") else "market" if eid.startswith("market") else "npc"
        cx, cy = (e["pos"][0] + 0.5) * S, (e["pos"][1] + 0.5) * S
        d.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=COL[tags[kind][0]], outline=COL["outline"], width=2)
        positions.setdefault(eid, [])
    for host, quests in positions.items():
        if quests:
            e = lay["entries"][host]
            cx, cy = (e["pos"][0] + 0.5) * S, (e["pos"][1] + 0.5) * S
            d.rectangle([cx + 6, cy - 22, cx + 18, cy - 8], fill=(255, 224, 138), outline=COL["outline"])
            d.text((cx + 12, cy - 15), "!" * min(len(quests), 3), font=f_small, fill=COL["outline"], anchor="mm")

    sx, sy = (lay["spawn"]["pos"][0] + 0.5) * S, (lay["spawn"]["pos"][1] + 0.5) * S
    d.ellipse([sx - 11, sy - 11, sx + 11, sy + 11], outline=COL["spawn"], width=4)
    d.ellipse([sx - 4, sy - 4, sx + 4, sy + 4], fill=COL["spawn"])

    # chemin d'or : flèches pointillées
    def center(name):
        if name == "spawn":
            return lay["spawn"]["pos"]
        if name == "place_centrale":
            return lay["landmarks"][0]["pos"]
        if name in lay["entries"]:
            return lay["entries"][name]["pos"]
        ex = next(e for e in lay["exits"] if e["id"] == name)
        return ex["arrival"]
    gp = [center(n) for n in lay["intent"]["golden_path"]]
    for a, b in zip(gp, gp[1:]):
        ax, ay = (a[0] + 0.5) * S, (a[1] + 0.5) * S
        bx, by = (b[0] + 0.5) * S, (b[1] + 0.5) * S
        n = int(((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5 // 14)
        for k in range(0, n, 2):
            t0, t1 = k / n, min(1, (k + 1) / n)
            d.line([ax + (bx - ax) * t0, ay + (by - ay) * t0, ax + (bx - ax) * t1, ay + (by - ay) * t1],
                   fill=(255, 250, 240), width=3)

    # ateliers (entrées propres à la carte) : losanges
    for eid, e in lay.get("extra_entries", {}).items():
        if eid.startswith("_"):
            continue
        cx, cy = (e["pos"][0] + 0.5) * S, (e["pos"][1] + 0.5) * S
        d.regular_polygon((cx, cy, 8), 4, fill=COL["workshop"], outline=COL["outline"])

    # cadre de la vue joueur centré sur l'arrivée
    vw, vh = lay["player_metrics"]["view_tiles"]
    sxp, syp = lay["spawn"]["pos"]
    vx0 = max(0, min(W - vw, sxp - vw / 2))
    vy0 = max(0, min(H - vh, syp - vh / 2))
    for k in range(0, int(vw * S), 12):
        d.line([vx0 * S + k, vy0 * S, vx0 * S + k + 6, vy0 * S], fill=COL["view"], width=2)
        d.line([vx0 * S + k, (vy0 + vh) * S, vx0 * S + k + 6, (vy0 + vh) * S], fill=COL["view"], width=2)
    for k in range(0, int(vh * S), 12):
        d.line([vx0 * S, vy0 * S + k, vx0 * S, vy0 * S + k + 6], fill=COL["view"], width=2)
        d.line([(vx0 + vw) * S, vy0 * S + k, (vx0 + vw) * S, vy0 * S + k + 6], fill=COL["view"], width=2)

    # étiquettes (toutes tirées des données)
    def label(pos, text, dy=-1.1, bold=False):
        x, y = (pos[0] + 0.5) * S, (pos[1] + dy) * S
        x = min(max(x, 60), W * S - 60)
        f = f_mid if bold else f_small
        bb = d.textbbox((x, y), text, font=f, anchor="mm")
        d.rectangle([bb[0] - 3, bb[1] - 2, bb[2] + 3, bb[3] + 2], fill=(255, 250, 240))
        d.text((x, y), text, font=f, fill=COL["text"], anchor="mm")

    for e in lay["entries"].values():
        if "label" in e:
            label(e["pos"], e["label"], dy=1.7)
    for b in lay["buildings"]:
        if "label" in b:
            x, y, w, h = b["rect"]
            label([x + w / 2 - 0.5, y], b["label"], dy=h / 2 - 0.2, bold=True)
    label(lay["spawn"]["pos"], "Arrivée", dy=1.8)
    for ex in lay["exits"]:
        x, y, w, h = ex["rect"]
        label(ex["arrival"], "→ " + ex["label"], dy=1.6)
    label([vx0 + 2.5, vy0], "vue joueur", dy=0.9)

    # légende
    lx = W * S + 20
    y = 18
    d.text((lx, y), lay["zone_id"], font=f_big, fill=COL["text"]); y += 24
    d.text((lx, y), lay.get("status", ""), font=f_small, fill=COL["text"]); y += 22
    vw, vh = lay["player_metrics"]["view_tiles"]
    spd = lay["player_metrics"]["speed_tiles_s"]
    d.text((lx, y), f"{W}×{H} tuiles ({W*16}×{H*16} px)", font=f_small, fill=COL["text"]); y += 16
    d.text((lx, y), f"≈ {W/vw:.1f} × {H/vh:.1f} écrans · traversée ≈ {W/spd:.0f} s",
           font=f_small, fill=COL["text"]); y += 28
    items = [
        ("forest_wall", "Lisière de forêt (bloquante)"), ("road", "Routes"),
        ("square", "Place pavée / terrasse"), ("field", "Champs"), ("stream", "Ruisseau (bloquant)"),
        ("inn", "Auberge"), ("house", "Maisons"), ("workshop", "Ateliers de craft"),
        ("workshop_ruin", "Atelier architecte"), ("stall", "Étal"), ("bridge", "Pont"),
        ("ruin_floor", "Dalles architectes"), ("rock", "Carrière"), ("orchard", "Verger"),
    ]
    for k, txt in items:
        d.rectangle([lx, y, lx + 18, y + 14], fill=COL[k], outline=COL["outline"])
        d.text((lx + 28, y), txt, font=f_small, fill=COL["text"]); y += 20
    y += 6
    for c, txt in [("npc", "PNJ"), ("shop", "Boutique"), ("market", "Marché joueurs")]:
        d.ellipse([lx + 1, y, lx + 17, y + 16], fill=COL[c], outline=COL["outline"], width=2)
        d.text((lx + 28, y + 1), txt, font=f_small, fill=COL["text"]); y += 22
    d.regular_polygon((lx + 9, y + 8, 8), 4, fill=COL["workshop"], outline=COL["outline"])
    d.text((lx + 28, y + 1), "Poste d'artisanat", font=f_small, fill=COL["text"]); y += 22
    d.rectangle([lx + 2, y, lx + 16, y + 14], fill=(255, 224, 138), outline=COL["outline"])
    d.text((lx + 28, y), "Quêtes (! = nombre)", font=f_small, fill=COL["text"]); y += 22
    d.rectangle([lx, y, lx + 18, y + 14], outline=COL["exit"], width=3)
    d.text((lx + 28, y), "Sortie de zone", font=f_small, fill=COL["text"]); y += 22
    d.line([lx, y + 7, lx + 18, y + 7], fill=(140, 120, 100), width=3)
    d.text((lx + 28, y), "Chemin d'or (1re quête)", font=f_small, fill=COL["text"]); y += 22
    d.rectangle([lx, y, lx + 18, y + 14], outline=(200, 200, 190), width=2)
    d.text((lx + 28, y), f"Vue joueur ({vw}×{vh} tuiles)", font=f_small, fill=COL["text"]); y += 30
    d.text((lx, y), "Points de repère", font=f_mid, fill=COL["text"]); y += 22
    for tag, txt in legend:
        d.text((lx, y), f"{tag}  {txt}", font=f_small, fill=COL["text"]); y += 18

    out = ROOT / "art" / "preview" / f"{lay['zone_id']}_blockout.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    print(out)


if __name__ == "__main__":
    main(sys.argv[1])
