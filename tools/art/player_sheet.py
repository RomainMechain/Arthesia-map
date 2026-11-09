"""Planche du joueur, 8 directions (5 dessinées + 3 en miroir), mains nues.

Lignes  : 0 bas (S), 1 bas-droite (SE), 2 droite (E), 3 haut-droite (NE), 4 haut (N).
          SO, O, NO = SE, E, NE retournées en jeu.
Colonnes: 0-1 repos | 2-5 marche | 6-8 attaque (armé, frappe, retour) | 9 touché | 10-11 KO.
Image   : 24x26, pied au centre du bas. Même palette et mêmes couleurs que le sprite d'origine.
Usage   : python tools/art/player_sheet.py
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from palette import P, CLEAR, GROUND_SHADOW  # noqa: E402
import styleboard as sb  # noqa: E402

FW, FH = 24, 26
OX, OY = 4, 1          # décalage du personnage (grille 16 de large) dans l'image
COLS = 12

# Haut du corps (tête + torse jusqu'aux hanches), lignes 3 à 18 de la grille 16x24 d'origine.
UPPER = {
    "S": [
        ".....OOOOOO.....",
        "....OHHHHHHO....",
        "...OHLLHHHHHO...",
        "...OHHHHHHHhO...",
        "...OHSSSSSShO...",
        "...OSSOSSOSsO...",
        "...OSSOSSOSsO...",
        "...OsSSSSSSsO...",
        "....OsSSSSsO....",
        "....OOTTTTOO....",
        "...OTTTGTTTtO...",
        ".OTOTTTTTTTtOtO.",
        ".OTOTTTTTTTtOtO.",
        ".OSOBBBGBBBBOsO.",
        ".OOOTTTTTTTtOOO.",
        "...OTTTTTTTtO...",
    ],
    "SE": [
        ".....OOOOOO.....",
        "....OHHHHHHO....",
        "...OHLLHHHHHO...",
        "...OHHHHHHHHO...",
        "...OHHSSSSSSO...",
        "...OhSSOSSOSO...",
        "...OhSSOSSOSO...",
        "...OhSSSSSSsO...",
        "....OhSSSSsO....",
        "....OOTTTTOO....",
        "...OTTTTGTTtO...",
        "..OtOTTTTTTTOtO.",
        "..OtOTTTTTTTOtO.",
        "..OsOBBBBGBBOsO.",
        "..OOOTTTTTTtOOO.",
        "...OTTTTTTTtO...",
    ],
    "E": [
        ".....OOOOOO.....",
        "....OHHHHHHO....",
        "...OHLLHHHHHO...",
        "...OHHHHHHHHO...",
        "...OHHHHSSSSO...",
        "...OhHHHSSOSO...",
        "...OhHHHSSOSO...",
        "...OhHHSSSSSSO..",
        "....OhSSSSsOO...",
        ".....OOTTTOO....",
        "....OTTttTTtO...",
        "....OTTttTTtO...",
        "....OTTttTTtO...",
        "....OBBSsGBBO...",
        "....OTTTTTTtO...",
        "....OTTTTTTtO...",
    ],
    "NE": [
        ".....OOOOOO.....",
        "....OHHHHHHO....",
        "...OHLLHHHHHO...",
        "...OHLHHHHHHO...",
        "...OHHHHHHHSO...",
        "...OhHHHHHHSO...",
        "...OhHHHHHSSO...",
        "...OhhHHHHSsO...",
        "....OhhSSSsO....",
        "....OOTTTTOO....",
        "...OTTTTTTTtO...",
        "..OtOTTTTTTTOTO.",
        "..OtOTTTTTTTOTO.",
        "..OsOBBBBBBBOSO.",
        "..OOOTTTTTTtOOO.",
        "...OTTTTTTTtO...",
    ],
    "N": [
        ".....OOOOOO.....",
        "....OHHHHHHO....",
        "...OHLLHHHHHO...",
        "...OHLHHHHHhO...",
        "...OHHHHHHHhO...",
        "...OHHHHHHHhO...",
        "...OhHHHHHHhO...",
        "...OhhHHHHhhO...",
        "....OsSSSSsO....",
        "....OOTTTTOO....",
        "...OTTTTTTTtO...",
        ".OTOTTTTTTTtOtO.",
        ".OTOTTTTTTTtOtO.",
        ".OSOBBBBBBBBOsO.",
        ".OOOTTTTTTTtOOO.",
        "...OTTTTTTTtO...",
    ],
}

# Bras qui frappe (poing), par direction : (x, y) dans la grille 16x24 ; "T" manche, "S" main.
PUNCH = {
    "S": [(12, 15, "T"), (12, 16, "T"), (12, 17, "S"), (13, 17, "S"), (12, 18, "S"), (13, 18, "s")],
    "SE": [(13, 15, "T"), (14, 16, "T"), (14, 17, "S"), (15, 17, "S"), (15, 18, "s")],
    "E": [(12, 14, "T"), (13, 14, "T"), (14, 14, "S"), (15, 14, "S"), (15, 15, "s")],
    "NE": [(13, 13, "T"), (14, 12, "T"), (14, 11, "S"), (15, 11, "S"), (15, 10, "s")],
    "N": [(12, 13, "T"), (12, 12, "T"), (12, 11, "S"), (13, 11, "S"), (12, 10, "s")],
}
WINDUP = {   # bras armé, ramené en arrière
    "S": [(12, 14, "T"), (13, 14, "S")],
    "SE": [(13, 13, "T"), (13, 12, "S")],
    "E": [(5, 14, "T"), (4, 14, "S")],
    "NE": [(12, 15, "T"), (12, 16, "S")],
    "N": [(12, 16, "T"), (13, 16, "S")],
}


def keys():
    return dict(sb.KEYS_CHAR)


def legs(img, d, phase, lean=0):
    """Jambes et bottes (lignes 19-22) sur un calque contouré à part.
    Pas de marche : phase 0 neutre, 1 jambe A levée / en avant, 2 neutre, 3 jambe B."""
    K = keys()
    layer = Image.new("RGBA", (FW, FH), CLEAR)
    px = layer.load()

    def put(x, y, ch):
        X, Y = OX + x + lean, OY + y
        if 0 <= X < FW and 0 <= Y < FH:
            px[X, Y] = K[ch]

    if d == "E":
        stride = (0, 2, 0, -2)[phase]
        # jambe du fond d'abord (plus sombre), puis celle de devant
        for x0, s, far in ((6, -stride, True), (8, stride, False)):
            for y in range(19, 22):
                x = x0 + round(s * (y - 19) / 2)
                put(x, y, "p" if far else "P")
                put(x + 1, y, "p")
            xb = x0 + s
            put(xb, 22, "K"); put(xb + 1, 22, "K"); put(xb + 2, 22, "k")
    else:
        lift = {(1, 0): 1, (3, 1): 1}
        for i, x0 in enumerate((4, 9)):
            up = lift.get((phase, i), 0)
            for y in range(19, 22 - up):
                put(x0, y, "P"); put(x0 + 1, y, "P"); put(x0 + 2, y, "p")
            yb = 22 - up
            put(x0, yb, "K"); put(x0 + 1, yb, "K"); put(x0 + 2, yb, "k")
    sb.outline(layer)
    img.alpha_composite(layer)

def frame(d, kind, i=0):
    img = Image.new("RGBA", (FW, FH), CLEAR)
    K = keys()
    phase = 0
    bob = 0
    lean = 0
    rows = [r for r in UPPER[d]]
    if kind == "idle":
        bob = 1 if i == 1 else 0                 # respiration : la tête et le torse descendent d'1 px
    elif kind == "walk":
        phase = i
        bob = 0 if i in (0, 2) else -1
    elif kind == "attack":
        lean = {"E": 1, "SE": 1, "NE": 1}.get(d, 0) if i == 1 else 0
    elif kind == "hurt":
        lean = {"E": -1, "SE": -1, "NE": -1}.get(d, 0)
        rows = [r.replace("SSOSSOS", "SSSSSSS") for r in rows]   # yeux plissés
    # torse et tête
    upper = Image.new("RGBA", (FW, FH), CLEAR)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                X, Y = OX + x + lean, OY + 3 + y + bob
                if 0 <= X < FW and 0 <= Y < FH:
                    upper.putpixel((X, Y), K[ch])
    if kind == "hurt":
        for x, y in ((6, 9), (9, 9), (7, 9), (10, 9)) if d in ("S", "SE") else ():
            upper.putpixel((OX + x + lean + (1 if d == "SE" else 0), OY + y + 0), K["O"])
    legs(img, d, phase, lean=0)
    img.alpha_composite(upper)
    if kind == "attack":
        pose = WINDUP if i == 0 else PUNCH if i == 1 else None
        if pose:
            for x, y, ch in pose[d]:
                X, Y = OX + x + lean, OY + y
                if 0 <= X < FW and 0 <= Y < FH:
                    img.putpixel((X, Y), K[ch])
            # contour du bras ajouté
            arm = Image.new("RGBA", (FW, FH), CLEAR)
            for x, y, ch in pose[d]:
                arm.putpixel((OX + x + lean, OY + y), K[ch])
            sb.outline(arm)
            arm.alpha_composite(img)
            img = arm
    return img


def ko(i):
    base = frame("S", "idle", 0)
    if i == 0:                                    # à genoux
        img = Image.new("RGBA", (FW, FH), CLEAR)
        top = base.crop((0, 0, FW, OY + 19))
        img.alpha_composite(top, (0, 4))
        legs_part = base.crop((0, OY + 19, FW, OY + 21))
        img.alpha_composite(legs_part, (0, OY + 23 - 2))
        return img
    # allongé : le personnage tourné d'un quart de tour, posé au sol
    body = base.crop((OX, OY + 3, OX + 16, OY + 24)).rotate(90, expand=True)
    img = Image.new("RGBA", (FW, FH), CLEAR)
    img.alpha_composite(body, ((FW - body.width) // 2, FH - body.height - 1))
    return img


def sheet():
    out = Image.new("RGBA", (FW * COLS, FH * 5), CLEAR)
    for row, d in enumerate(("S", "SE", "E", "NE", "N")):
        frames = [frame(d, "idle", 0), frame(d, "idle", 1)]
        frames += [frame(d, "walk", k) for k in range(4)]
        frames += [frame(d, "attack", k) for k in range(3)]
        frames += [frame(d, "hurt"), ko(0), ko(1)]
        for col, f in enumerate(frames):
            cell = Image.new("RGBA", (FW, FH), CLEAR)
            sb.ellipse(cell, FW / 2 + 1, FH - 2, 5.5 if col < 11 else 9, 1.6, GROUND_SHADOW)
            cell.alpha_composite(f)
            out.alpha_composite(cell, (col * FW, row * FH))
    return out


def main():
    sb.save(sheet(), "characters/player/player_8dir.png")


if __name__ == "__main__":
    main()
    img = sheet()
    img.resize((img.width * 4, img.height * 4), Image.NEAREST).save(sb.PREVIEW / "joueur_8dir.png")
    print(sb.PREVIEW / "joueur_8dir.png")
