"""Calibre la « couche action » du combat (version carte) par simulation.

Les formules sont celles de docs/combat_engine.py (importé tel quel) ; les templates restent ceux du
pipeline d'équilibrage. On cherche des multiplicateurs appliqués au moment du jeu :
  HP      : PV des monstres                 -> durée d'un combat
  DMG     : dégâts des monstres              -> PV perdus par combat
  TELE    : puissance des coups annoncés     -> part des dégâts évitables en esquivant

Cibles (décisions de Romain, 2026-11-08) contre une bête normale de son niveau :
  durée ~27 s ; PV perdus ~35 % sans rien esquiver, ~18 % en esquivant toutes les annonces.

Modèle du joueur : frappe dès que l'attaque est prête 85 % du temps (déplacements), lance ses
compétences dès qu'elles sont prêtes s'il a le mana. Kit de niveau 1 : Frappe, Trait de Lumière.
Usage : python tools/balance/simulate_action.py
"""
import importlib.util
import json
import random
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("ce", ROOT / "docs" / "combat_engine.py")
ce = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ce)

TPL = ROOT / "data" / "templates"
DT = 0.05
UPTIME = 0.85


def tpl(kind, i):
    return json.loads((TPL / kind / f"{i}.json").read_text(encoding="utf-8"))


PLAYERS = {
    # joueur de référence équipé, niveau 1 (arthesia_balance_reference.md)
    "référence niv. 1": ({"hp": 137, "atk": 14, "def": 10, "agi": 6, "int": 8, "sag": 8}, 1),
    # notre départ : mains nues, 6 points (hp, atk x2, def x2, int)
    "départ mains nues": ({"hp": 105, "atk": 12, "def": 9, "agi": 5, "int": 8, "sag": 5}, 1),
}
KIT = [tpl("skills", "frappe"), tpl("skills", "trait_de_lumiere")]
MONSTERS = ["lapin_bondissant", "loup_dore", "oiseau_chanteur", "renardeau_curieux"]


def hit(raw, a_agi, a_lvl, d_agi, d_def, rng):
    if rng.random() < ce.dodge_chance(a_agi, d_agi):
        return 0.0
    dmg = raw * rng.uniform(1 - ce.DAMAGE_VARIANCE, 1 + ce.DAMAGE_VARIANCE)
    if rng.random() < ce.crit_chance(a_agi, d_agi):
        dmg *= ce.CRIT_MULTIPLIER
    return dmg * (1 - ce.compute_mitigation(d_def, a_lvl))


def fight(player, plvl, mon, k_hp, k_dmg, k_tele, dodge, rng):
    ps = player
    m = mon["stats"]
    php, mhp = ps["hp"], m["hp"] * k_hp
    mana = ce.compute_max_mana(ps["int"], plvl)
    regen = ce.compute_mana_regen(ps["sag"], plvl)
    basic_cd = ce.compute_basic_attack_cooldown(ps["agi"], plvl)
    t, basic_ready = 0.0, 0.0
    skill_ready = {s["id"]: 0.0 for s in KIT}
    mcd = {mv["id"]: rng.uniform(0.4, 0.9) for mv in mon["moveset"]}
    pending = None
    while t < 600:
        t += DT
        mana = min(ce.compute_max_mana(ps["int"], plvl), mana + regen * DT)
        # joueur
        if t >= basic_ready and rng.random() < UPTIME * DT / basic_cd * 4:
            mhp -= hit(ce.BASIC_ATTACK_POWER * max(ps["atk"], ps["int"]), ps["agi"], plvl, m["agi"], m["def"], rng)
            basic_ready = t + basic_cd
        for s in KIT:
            if t >= skill_ready[s["id"]] and mana >= s["mana_cost"]:
                mana -= s["mana_cost"]
                skill_ready[s["id"]] = t + s["cooldown_seconds"]
                stat = ps["int"] if s["damage_type"] == "magical" else ps["atk"]
                e = s["effects"][0]
                mhp -= hit(e["base"] + e["power"] * stat, ps["agi"], plvl, m["agi"], m["def"], rng)
        if mhp <= 0:
            return t, 1 - php / ps["hp"], True
        # monstre
        for k in mcd:
            mcd[k] -= DT
        if pending:
            if t >= pending[1]:
                mv = pending[0]
                pending = None
                if not (rng.random() < dodge):
                    php -= hit(mv["power"] * m["atk"] * k_dmg * k_tele, m["agi"], mon["level"], ps["agi"], ps["def"], rng)
        else:
            ready = [mv for mv in mon["moveset"] if mcd[mv["id"]] <= 0]
            if ready:
                mv = rng.choices(ready, weights=[x.get("weight", 1) for x in ready])[0]
                mcd[mv["id"]] = mv["cooldown_seconds"]
                if mv.get("telegraph_seconds", 0) > 0:
                    pending = (mv, t + mv["telegraph_seconds"])
                else:
                    php -= hit(mv["power"] * m["atk"] * k_dmg, m["agi"], mon["level"], ps["agi"], ps["def"], rng)
        if php <= 0:
            return t, 1.0, False
    return t, 1 - php / ps["hp"], mhp <= 0


def run(k_hp, k_dmg, k_tele, dodge, player="référence niv. 1", n=300, monsters=MONSTERS):
    rng = random.Random(42)
    ps, lvl = PLAYERS[player]
    durs, lost, wins = [], [], 0
    for mid in monsters:
        mon = tpl("monsters", mid)
        for _ in range(n):
            d, l, w = fight(ps, lvl, mon, k_hp, k_dmg, k_tele, dodge, rng)
            durs.append(d)
            lost.append(l)
            wins += w
    return statistics.mean(durs), statistics.mean(lost), wins / (n * len(monsters))


def calibrate():
    base = run(1, 1, 1, 0)
    print(f"actuel (x1)          : {base[0]:5.1f} s, {base[1] * 100:4.1f} % PV perdus, victoires {base[2] * 100:.0f} %")
    # 1) PV des monstres -> durée 27 s
    lo, hi = 0.1, 1.0
    for _ in range(14):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if run(mid, 1, 1, 0, n=120)[0] < 27 else (lo, mid)
    k_hp = round((lo + hi) / 2, 2)
    # 2) poids des coups annoncés : esquiver tout doit diviser les pertes par ~2 (35 % -> 18 %)
    best = None
    for k_tele in [1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.5]:
        a = run(k_hp, 1, k_tele, 0, n=120)[1]
        b = run(k_hp, 1, k_tele, 1, n=120)[1]
        ratio = b / a if a else 1
        if best is None or abs(ratio - 18 / 35) < abs(best[1] - 18 / 35):
            best = (k_tele, ratio)
    k_tele = best[0]
    # 3) dégâts -> 35 % sans esquive
    lo, hi = 0.5, 6.0
    for _ in range(14):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if run(k_hp, mid, k_tele, 0, n=120)[1] < 0.35 else (lo, mid)
    k_dmg = round((lo + hi) / 2, 2)
    return k_hp, k_dmg, k_tele


def report(k_hp, k_dmg, k_tele):
    print(f"\nréglages : PV monstres x{k_hp}, dégâts monstres x{k_dmg}, coups annoncés x{k_tele}")
    for player in PLAYERS:
        for dodge in (0.0, 0.5, 1.0):
            d, l, w = run(k_hp, k_dmg, k_tele, dodge, player=player)
            print(f"  {player:18s} esquive {int(dodge * 100):3d} % : {d:5.1f} s, {l * 100:4.1f} % PV perdus, "
                  f"victoires {w * 100:.0f} %")
        for mid in MONSTERS:
            d, l, w = run(k_hp, k_dmg, k_tele, 0.5, player=player, monsters=[mid])
            print(f"      {mid:20s} : {d:5.1f} s, {l * 100:4.1f} %")


# --------------------------------------------------------------------------- progression et économie (étage 1)
REF_TABLE = {1: (137, 14, 10, 6, 8, 8), 5: (364, 35, 28, 12, 15, 19), 10: (648, 62, 50, 19, 24, 32)}
XP_ANCHORS = [(1, 43.0), (10, 298.0), (50, 5345.0), (100, 178745.0)]
REGEN_FULL_S = 60.0          # PV pleins hors combat (couche action)
OUT_OF_COMBAT_S = 6.0        # délai avant la régénération
TRAVEL_S = 12.0              # marche jusqu'à la bête suivante
QUEST_XP_SHARE = 0.30        # 30 % de l'XP vient des quêtes (document d'équilibrage)
SHOP_MARKUP = 35 / 30        # Thessaly vend la dague (valeur 30) 35 or


def ref_player(lvl):
    keys = ["hp", "atk", "def", "agi", "int", "sag"]
    lo = max(k for k in REF_TABLE if k <= lvl)
    hi = min(k for k in REF_TABLE if k >= lvl)
    t = 0 if hi == lo else (lvl - lo) / (hi - lo)
    return {k: REF_TABLE[lo][i] + (REF_TABLE[hi][i] - REF_TABLE[lo][i]) * t for i, k in enumerate(keys)}


def xp_to_next(lvl):
    import math
    for (a, xa), (b, xb) in zip(XP_ANCHORS, XP_ANCHORS[1:]):
        if lvl <= b:
            t = (lvl - a) / (b - a)
            return round(math.exp(math.log(xa) + (math.log(xb) - math.log(xa)) * t))


def kit(lvl):
    k = ["frappe", "trait_de_lumiere"]
    if lvl >= 3:
        k.append("coup_puissant")
    if lvl >= 4:
        k.append("lame_d_aube")
    return [tpl("skills", s) for s in k]


def loot_per_kill(mon, guaranteed):
    """Objets ordinaires lâchés par bête (moyenne) et leur valeur de revente."""
    w = [l for l in mon.get("loot_table", []) if "weight" in l]
    tot = sum(l["weight"] for l in w) or 1
    qty, value = 0.0, 0.0
    for l in w:
        p = l["weight"] / tot * guaranteed
        q = (l["quantity_min"] + l["quantity_max"]) / 2
        qty += p * q
        value += p * q * tpl("items", l["item_id"]).get("base_value", 5)
    return qty, value


def progression(k_hp, k_dmg, k_tele, action_xp, drop, sell_share, round_sell=True):
    global KIT
    print(f"\nprogression : XP x{action_xp}, butin {int(drop * 100)} %, rachat {int(sell_share * 100)} %"
          f" ({'arrondi' if round_sell else 'tronqué'})")
    print("niv | combat | PV perdus | bêtes/h | durée du niveau (cible) | or/h | équipement du niveau")
    import glob
    for lvl in range(1, 11):
        mons = [json.loads(Path(p).read_text(encoding="utf-8")) for p in glob.glob(str(TPL / "monsters" / "*.json"))]
        mons = [m for m in mons if m["level"] == lvl and m["role"] == "normal"]
        if not mons:
            continue
        KIT = kit(lvl)
        rng = random.Random(lvl)
        ps = ref_player(lvl)
        durs, lost = [], []
        for mon in mons:
            for _ in range(80):
                d, l, _w = fight(ps, lvl, mon, k_hp, k_dmg, k_tele, 0.5, rng)
                durs.append(d)
                lost.append(l)
        d, l = statistics.mean(durs), statistics.mean(lost)
        cycle = d + OUT_OF_COMBAT_S + l * REGEN_FULL_S + TRAVEL_S
        kph = 3600 / cycle
        xp_kill = 10 * 1.06 ** (lvl - 1) * action_xp * (1 + 0.035 * (lvl - 1))   # ACTION_XP_PER_LEVEL
        lvl_min = xp_to_next(lvl) * (1 - QUEST_XP_SHARE) / (xp_kill * kph) * 60
        target = 15 * 4 ** ((lvl - 1) / 10)
        gold_kill = 0.0
        for mon in mons:
            q, v = loot_per_kill(mon, drop)
            unit = v / q if q else 0
            sp = max(1, round(unit * sell_share)) if round_sell else max(1, int(unit * sell_share))
            gold_kill += q * sp / len(mons)
        gph = gold_kill * kph
        gear = 30 * lvl * SHOP_MARKUP
        print(f"{lvl:3d} | {d:5.1f} s | {l * 100:5.1f} %  | {kph:6.0f}  | {lvl_min:5.1f} min ({target:4.1f}) "
              f"| {gph:5.0f} | {gear:4.0f} or = {gear / gph * 60 if gph else 0:5.1f} min")
    KIT = [tpl("skills", "frappe"), tpl("skills", "trait_de_lumiere")]


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "progression":
        a = list(map(float, sys.argv[2:])) or [0.4, 1.8, 1.2, 0.18, 1.0, 0.35]   # réglages en jeu
        progression(*a)
    elif len(sys.argv) == 4:
        report(*map(float, sys.argv[1:]))
    else:
        report(*calibrate())
