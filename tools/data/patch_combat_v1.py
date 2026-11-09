"""Adapte les templates au combat action de la version carte (docs/combat_v1.md).

Ajoute à chaque coup (moveset des monstres, compétences actives du joueur) un champ optionnel `area`,
la zone d'impact en pixels (tuile = 16 px), et donne un vrai télégraphe aux gros coups des bêtes de la
Lisière pour qu'on puisse les éviter en sortant de la zone. Idempotent : relancer ne change rien de plus.

  area = {"shape": "arc",    "range": px, "angle": degrés}       devant le lanceur
         {"shape": "circle", "radius": px}                       autour du lanceur
         {"shape": "line",   "range": px, "width": px}           trait : touche la première cible
         {"shape": "self"}                                        soin / buff sur soi

Sans `area`, le jeu prend un arc court (22 px, 80°).
Usage : python tools/data/patch_combat_v1.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TPL = ROOT / "data" / "templates"

MONSTER_MOVES = {
    "lapin_bondissant": {
        "coup_de_patte": {"area": {"shape": "arc", "range": 20, "angle": 90}},
        "ruade_apeuree": {"area": {"shape": "arc", "range": 26, "angle": 120},
                          "telegraph_seconds": 0.6, "avoidable_by": "esquive"},
    },
    "loup_dore": {
        "morsure_doree": {"area": {"shape": "arc", "range": 24, "angle": 70}},
        "griffure_luisante": {"area": {"shape": "arc", "range": 32, "angle": 110},
                              "telegraph_seconds": 0.6, "avoidable_by": "esquive"},
    },
    "oiseau_chanteur": {
        "bec_acere": {"area": {"shape": "arc", "range": 18, "angle": 80}},
        "cri_percant": {"area": {"shape": "circle", "radius": 40},
                        "telegraph_seconds": 0.5, "avoidable_by": "esquive"},
    },
    "renardeau_curieux": {
        "morsure_vive": {"area": {"shape": "arc", "range": 20, "angle": 80}},
        "feinte_agile": {"area": {"shape": "arc", "range": 28, "angle": 100},
                         "telegraph_seconds": 0.5, "avoidable_by": "esquive"},
    },
    # Forêt des Anciens
    "sanglier_des_fougeres": {
        "coup_de_boutoir": {"area": {"shape": "arc", "range": 22, "angle": 90}},
        "charge_furieuse": {"area": {"shape": "line", "range": 72, "width": 14}, "charge": True,
                            "telegraph_seconds": 0.8, "avoidable_by": "esquive"},
    },
    "lynx_a_robe_claire": {
        "griffes_vives": {"area": {"shape": "arc", "range": 22, "angle": 100}},
        "bond_silencieux": {"area": {"shape": "line", "range": 46, "width": 14}, "charge": True,
                            "telegraph_seconds": 0.45, "avoidable_by": "esquive"},
    },
    "ours_moussu": {
        "patte_lourde": {"area": {"shape": "arc", "range": 28, "angle": 120}},
        "etreinte_d_ours": {"area": {"shape": "circle", "radius": 30},
                            "telegraph_seconds": 1.0, "avoidable_by": "esquive"},
    },
    "veilleur_d_ecorce": {
        "branche_fouet": {"area": {"shape": "arc", "range": 34, "angle": 120}},
        "racines_etouffantes": {"area": {"shape": "circle", "radius": 40},
                                "telegraph_seconds": 1.5, "avoidable_by": "esquive"},
        "pulsation_runique": {"area": {"shape": "circle", "radius": 56},
                              "telegraph_seconds": 0.9, "avoidable_by": "esquive"},
    },
    # Rive Paisible
    "crabe_des_galets": {
        "pincement": {"area": {"shape": "arc", "range": 18, "angle": 90}},
        "etau_de_pierre": {"area": {"shape": "arc", "range": 22, "angle": 140},
                           "telegraph_seconds": 0.6, "avoidable_by": "esquive"},
    },
    "heron_cendre": {
        "coup_de_bec": {"area": {"shape": "line", "range": 30, "width": 8}},     # long cou : il pique loin
        "plongeon_brutal": {"area": {"shape": "line", "range": 44, "width": 14},
                            "telegraph_seconds": 0.7, "avoidable_by": "esquive"},
    },
    "anguille_des_hauts_fonds": {   # nageuse : chaque attaque = plongée, rides, sortie dans le cercle
        "morsure_glissante": {"area": {"shape": "circle", "radius": 16},
                              "telegraph_seconds": 0.8, "avoidable_by": "esquive"},
        "decharge_doree": {"area": {"shape": "circle", "radius": 28},
                           "telegraph_seconds": 1.0, "avoidable_by": "esquive"},
    },
}

SKILLS = {
    "frappe": {"shape": "arc", "range": 26, "angle": 110},
    "trait_de_lumiere": {"shape": "line", "range": 112, "width": 10},
    "premiers_soins": {"shape": "self"},
    "coup_puissant": {"shape": "arc", "range": 30, "angle": 130},
    "eclat_d_aube": {"shape": "line", "range": 88, "width": 16},
    "lame_d_aube": {"shape": "arc", "range": 30, "angle": 120},
    "croc_dore": {"shape": "arc", "range": 26, "angle": 90},
}


# Armes : zone du coup de base quand elles sont équipées (mains nues : arc 22 px / 100°).
WEAPONS = {
    "dague_villageoise": {"shape": "arc", "range": 26, "angle": 100},   # courte, rapide à placer
    "hachette_d_isarn": {"shape": "arc", "range": 28, "angle": 130},    # large balayage
    "lame_d_ambre": {"shape": "arc", "range": 32, "angle": 110},
    "lance_du_seuil": {"shape": "line", "range": 44, "width": 12},      # longue portée, une cible
}


def rw(path, fn):
    data = json.loads(path.read_text(encoding="utf-8"))
    fn(data)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    for mid, moves in MONSTER_MOVES.items():
        def patch(d, moves=moves):
            for m in d["moveset"]:
                m.update(moves.get(m["id"], {}))
        rw(TPL / "monsters" / f"{mid}.json", patch)
    for sid, area in SKILLS.items():
        p = TPL / "skills" / f"{sid}.json"
        if p.exists():
            rw(p, lambda d, area=area: d.update({"area": area}))
    for wid, area in WEAPONS.items():
        rw(TPL / "items" / f"{wid}.json", lambda d, area=area: d["equipment"].update({"area": area}))
    print("templates adaptés :", len(MONSTER_MOVES), "monstres,", len(SKILLS), "compétences,", len(WEAPONS), "armes")


if __name__ == "__main__":
    main()
