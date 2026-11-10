"""Planche du joueur à partir des animations PixelLab (art/pixellab/joueur_v2), au même format que
tools/art/player_sheet.py : 12 colonnes × 5 lignes, toile 32×32.

Lignes  : 0 bas (S), 1 bas-droite (SE), 2 droite (E), 3 haut-droite (NE), 4 haut (N) ; les 3 autres en miroir.
Colonnes: 0-1 repos | 2-5 marche | 6-8 attaque (armé, frappe, retour) | 9 touché | 10-11 KO.
Usage   : python tools/art/pixellab_player.py
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import CLEAR, GROUND_SHADOW  # noqa: E402
import styleboard as sb  # noqa: E402

SRC = Path(__file__).resolve().parents[2] / "art/pixellab/joueur_v2/Idle"
FW = FH = 32
COLS = 12
DIRS = ("south", "south-east", "east", "north-east", "north")


def frame(anim, d, i):
    return Image.open(SRC / "animations" / anim / d / f"frame_{i:03d}.png").convert("RGBA")


def feet_y():
    """Ligne du bas du personnage (vue de face, au repos) : là où l'on pose ses pieds."""
    im = Image.open(SRC / "rotations" / "south.png").convert("RGBA")
    px = im.load()
    return max(y for y in range(im.height) for x in range(im.width) if px[x, y][3] > 0)


def hurt(im):
    """Touché : recul d'un pixel et léger affaissement (le jeu ajoute le flash blanc)."""
    out = Image.new("RGBA", im.size, CLEAR)
    out.alpha_composite(im.crop((0, 0, im.width, im.height - 1)), (0, 1))
    return out


def sheet():
    out = Image.new("RGBA", (FW * COLS, FH * 5), CLEAR)
    fy = feet_y()
    for row, d in enumerate(DIRS):
        frames = [frame("repos", d, 0), frame("repos", d, 2)]
        frames += [frame("marche", d, k) for k in range(4)]
        frames += [frame("attaque", d, k) for k in range(3)]
        frames += [hurt(frame("repos", d, 0)), frame("ko", "south", 3), frame("ko", "south", 6)]
        for col, f in enumerate(frames):
            cell = Image.new("RGBA", (FW, FH), CLEAR)
            sb.ellipse(cell, FW / 2, fy + 0.5, 6.5 if col < 11 else 10, 1.7, GROUND_SHADOW)
            cell.alpha_composite(f)
            out.alpha_composite(cell, (col * FW, row * FH))
    return out, fy


def main():
    img, fy = sheet()
    sb.save(img, "characters/player/player_8dir.png")
    return fy


if __name__ == "__main__":
    fy = main()
    img, _ = sheet()
    img.resize((img.width * 4, img.height * 4), Image.NEAREST).save(sb.PREVIEW / "joueur_pixellab.png")
    print("pieds à y =", fy, "-> offset (-16, %d)" % -(fy + 1))
