"""Convertit un tileset Wang de PixelLab (2 terrains, coins NW/NE/SW/SE) vers le format de notre moteur :
  - un atlas de transitions 4×4 indexé comme overlay_layer (idx = tl*8 + tr*4 + bl*2 + br, case
    (idx % 4, idx // 4)), le terrain « bas » de PixelLab = notre calque (ex. la terre) ;
  - les tuiles pleines des deux terrains.
Usage : python tools/art/pixellab_tiles.py <tileset.png> <metadata.json> <sortie_prefixe>
"""
import json
import sys
from pathlib import Path

from PIL import Image


def convert(png, meta, out_prefix):
    sheet = Image.open(png).convert("RGBA")
    tiles = json.loads(Path(meta).read_text(encoding="utf-8"))["tileset_data"]["tiles"]
    by_corners = {}
    for t in tiles:
        c = t["corners"]
        key = tuple(int(c[k] == "lower") for k in ("NW", "NE", "SW", "SE"))
        b = t["bounding_box"]
        by_corners[key] = sheet.crop((b["x"], b["y"], b["x"] + b["width"], b["y"] + b["height"]))
    T = next(iter(by_corners.values())).width
    atlas = Image.new("RGBA", (T * 4, T * 4))
    for idx in range(16):
        key = ((idx >> 3) & 1, (idx >> 2) & 1, (idx >> 1) & 1, idx & 1)
        atlas.alpha_composite(by_corners[key], ((idx % 4) * T, (idx // 4) * T))
    atlas.save(f"{out_prefix}_overlay.png")
    by_corners[(1, 1, 1, 1)].save(f"{out_prefix}_lower_full.png")
    by_corners[(0, 0, 0, 0)].save(f"{out_prefix}_upper_full.png")
    return atlas


if __name__ == "__main__":
    convert(*sys.argv[1:4])
    print("ok")
