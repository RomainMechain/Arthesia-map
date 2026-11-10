"""Planche de bête (8 images de profil, vers la droite) à partir d'un personnage PixelLab animé vers l'est.

Format du jeu (tools/art/fauna.py) : 0-1 repos | 2-5 déplacement | 6 élan | 7 frappe.
Les images sont recadrées sur la silhouette commune (pieds en bas de l'image), avec l'ombre au sol.
Usage : python tools/art/pixellab_monster.py
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import CLEAR, GROUND_SHADOW  # noqa: E402
import styleboard as sb  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

# bête -> (dossier PixelLab extrait, [(animation, image)] pour les 8 cases)
MONSTERS = {
    "loup_dore": ("art/pixellab/loup_pro/Idle", [
        ("repos", 0), ("repos", 4),
        ("marche", 0), ("marche", 1), ("marche", 2), ("marche", 3),
        ("attaque", 1), ("attaque", 3)]),
}


def build(src, plan):
    frames = [Image.open(ROOT / src / "animations" / a / "east" / f"frame_{i:03d}.png").convert("RGBA")
              for a, i in plan]
    boxes = [f.getbbox() for f in frames]
    x0 = min(b[0] for b in boxes)
    y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes)
    y1 = max(b[3] for b in boxes)
    w, h = x1 - x0 + 2, y1 - y0 + 2                       # une marge pour l'ombre
    out = Image.new("RGBA", (w * len(frames), h), CLEAR)
    for i, f in enumerate(frames):
        cell = Image.new("RGBA", (w, h), CLEAR)
        sb.ellipse(cell, w / 2, h - 1.5, w * 0.36, 1.8, GROUND_SHADOW)
        cell.alpha_composite(f.crop((x0, y0, x1, y1)), (1, 0))
        out.alpha_composite(cell, (i * w, 0))
    return out


def main():
    for mid, (src, plan) in MONSTERS.items():
        sb.save(build(src, plan), f"monsters/{mid}_idle.png")
        print(mid, "ok")


if __name__ == "__main__":
    main()
