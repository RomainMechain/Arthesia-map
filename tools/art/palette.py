"""Palette verrouillée de l'étage 1 — seule source des couleurs (voir docs/art_direction.md)."""

def _hex(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)

P = {k: _hex(v) for k, v in {
    # Lumière d'aube / or
    "sun0": "fff4d6", "sun1": "ffe08a", "sun2": "f5b84a", "sun3": "d9822b",
    # Végétation (claire -> sombre)
    "leaf0": "e0e070", "leaf1": "a8c84e", "leaf2": "74a843", "leaf3": "4a8040",
    "leaf4": "2f5a3a", "leaf5": "1d3a2e",
    # Terre / bois
    "earth0": "f0d29a", "earth1": "d4a265", "earth2": "a8743f", "earth3": "7a5030",
    "earth4": "4f3324",
    # Eau
    "water0": "d4f4ec", "water1": "8fd8d0", "water2": "52aab8", "water3": "347a98",
    "water4": "244e70",
    # Pierre architecte
    "stone0": "ece2cf", "stone1": "c4b59c", "stone2": "948672", "stone3": "665c55",
    "stone4": "433c42",
    # Runes / magie
    "rune0": "b8fff0", "rune1": "5ae8e0", "rune2": "2aa8c0",
    # Peau / tissus
    "skin0": "f8d0a8", "skin1": "d8946a", "red0": "e05a48", "red1": "a83a40",
    "wine": "6a2a44", "blue0": "5868c8", "blue1": "38407a",
    # Ombres / contour
    "shade0": "7a5878", "shade1": "4a3450", "outline": "2a1a2e",
}.items()}

CLEAR = (0, 0, 0, 0)
GROUND_SHADOW = P["shade1"][:3] + (110,)  # seule couleur semi-transparente autorisée
