"""Planches des PNJ : 4 colonnes × 3 lignes de 16×26.

Lignes : 0 = face (vers le bas), 1 = dos (vers le haut), 2 = profil (vers la droite ; le jeu retourne
pour la gauche). Colonnes : 0-1 = repos (léger rebond), 2-3 = marche (une jambe puis l'autre).
Les couleurs viennent des mêmes clés que le joueur d'origine (styleboard.KEYS_CHAR + NPC_KEYS).
"""
from PIL import Image

import styleboard as sb
from palette import CLEAR, GROUND_SHADOW

UP = [
    "................",
    "................",
    "................",
    ".....OOOOOO.....",
    "....OHHHHHHO....",
    "...OHHLLHHHHO...",
    "...OHHHHHHHhO...",
    "...OHHHHHHHhO...",
    "...OHHHHHHHhO...",
    "...OHHHHHHhhO...",
    "...OhHHHHHHhO...",
    "....OhHHHHhO....",
    "....OOTTTTOO....",
    "...OTTTTTTTtO...",
    ".OTOTTTTTTTtOtO.",
    ".OTOTTTTTTTtOtO.",
    ".OSOBBBBBBBBOsO.",
    ".OOOTTTTTTTtOOO.",
    "...OTTTTTTTtO...",
    "...OPPPOOPPpO...",
    "...OPPPOOPPpO...",
    "...OKKKOOKKkO...",
    "...OOOOOOOOOO...",
    "................",
]

SIDE = [
    "................",
    "................",
    "................",
    "......OOOOO.....",
    ".....OHHHHHO....",
    "....OHHLLHHHO...",
    "....OHHHHHHHO...",
    "....OHHHHSSSO...",
    "....OHHHSSOSO...",
    "....OHHSSSSSO...",
    "....OhHSSSSsO...",
    ".....OhSSSsO....",
    ".....OOTTTOO....",
    "....OTTTTTTtO...",
    "....OTTTTTTtO...",
    "....OTtTTTTtO...",
    "....OBBBBBGBO...",
    "....OTsTTTTtO...",
    "....OTTTTTTtO...",
    ".....OPPPPpO....",
    ".....OPPOPpO....",
    ".....OKKOKkO....",
    ".....OOOOOOO....",
    "................",
]

W, H = 16, 24
LEG_TOP = 19


def _step(img, side_left):
    """Marche : une jambe (moitié gauche ou droite) remonte d'un pixel."""
    out = img.copy()
    px, po = img.load(), out.load()
    xs = range(0, 8) if side_left else range(8, W)
    for x in xs:
        for y in range(LEG_TOP, H):
            po[x, y] = CLEAR
        for y in range(LEG_TOP, H):
            if y + 1 < H:
                po[x, y] = px[x, y + 1]
    return out


def _frame(sprite, dy):
    f = Image.new("RGBA", (W, H + 2), CLEAR)
    sb.ellipse(f, W / 2 + 1, H, W * 0.32, 1.6, GROUND_SHADOW)
    f.alpha_composite(sprite, (0, 2 + dy))
    return f


def sheet(keys):
    rows = [sb.from_ascii(sb.PLAYER_DOWN, keys), sb.from_ascii(UP, keys), sb.from_ascii(SIDE, keys)]
    out = Image.new("RGBA", (W * 4, (H + 2) * 3), CLEAR)
    for r, spr in enumerate(rows):
        frames = [_frame(spr, 0), _frame(spr, -1), _frame(_step(spr, True), -1), _frame(_step(spr, False), -1)]
        for c, f in enumerate(frames):
            out.alpha_composite(f, (c * W, r * (H + 2)))
    return out
