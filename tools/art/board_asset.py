"""Tableau des contrats de Val-de-l'Aube : deux poteaux, un petit toit de planches, un panneau
où sont punaisées trois feuilles (et un sceau doré). 36×40, pieds en bas au centre.
"""
from PIL import Image, ImageDraw

from palette import P, CLEAR, GROUND_SHADOW

W, H = 36, 40


def board():
    img = Image.new("RGBA", (W, H), CLEAR)
    d = ImageDraw.Draw(img)
    O = P["outline"]
    # ombre au sol
    d.ellipse((5, H - 5, W - 6, H - 1), fill=GROUND_SHADOW)
    # poteaux
    for x in (5, W - 9):
        d.rectangle((x, 10, x + 3, H - 3), fill=P["earth3"], outline=O)
        d.line((x + 1, 12, x + 1, H - 4), fill=P["earth2"])
    # panneau
    d.rectangle((2, 12, W - 3, 32), fill=P["earth2"], outline=O)
    for y in (17, 22, 27):                                   # planches
        d.line((3, y, W - 4, y), fill=P["earth3"])
    d.line((3, 13, W - 4, 13), fill=P["earth1"])
    # toit à deux pans
    d.polygon([(0, 12), (W // 2 - 1, 3), (W - 1, 12)], fill=P["earth4"], outline=O)
    d.line((2, 11, W // 2 - 1, 4), fill=P["earth3"])
    d.line((W // 2, 4, W - 3, 11), fill=P["red1"])
    # trois feuilles punaisées (une un peu de travers), un sceau doré
    sheets = [(5, 15, 12, 25), (14, 14, 21, 23), (23, 16, 30, 26)]
    for i, (x0, y0, x1, y1) in enumerate(sheets):
        d.rectangle((x0, y0, x1, y1), fill=P["sun0"], outline=P["earth4"])
        for ly in range(y0 + 3, y1 - 1, 2):                  # lignes d'écriture
            d.line((x0 + 2, ly, x1 - 2 - (ly % 3), ly), fill=P["earth1"])
        d.point((x0 + (x1 - x0) // 2, y0 + 1), fill=P["red0"])  # punaise
    d.ellipse((24, 22, 28, 26), fill=P["sun2"], outline=P["sun3"])   # sceau
    d.point((26, 24), fill=P["sun1"])
    return img


def main(save):
    save(board(), "props/village/tableau_contrats.png")
