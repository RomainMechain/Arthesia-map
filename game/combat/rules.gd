class_name CombatRules
extends RefCounted
## Formules du combat : portage fidèle de docs/combat_engine.py (font foi) et de
## docs/arthesia_balance_reference.md. Pur : aucun nœud, aucun rendu — transposable côté serveur.
## Ajouts propres à la version carte (docs/combat_v1.md) : géométrie des zones d'impact (`area`).

# --- combat_engine.py
const K_DEF := 6.6
const K_DEF_PER_LEVEL := 6.0
const BASE_ATTACK_COOLDOWN := 2.0
const K_AGI := 7.4
const K_AGI_PER_LEVEL := 2.0
const BASIC_ATTACK_POWER := 0.4
const BASE_MANA := 50.0
const MANA_PER_LEVEL := 10.0
const K_INT := 2.0
const BASE_MANA_REGEN := 1.0
const MANA_REGEN_PER_LEVEL := 0.2
const K_SAG := 0.05
const HYBRID_STAT_FACTOR := 2.0
const DAMAGE_VARIANCE := 0.08
const BASE_CRIT_CHANCE := 0.05
const K_CRIT := 0.15
const CRIT_MULTIPLIER := 1.5
const BASE_DODGE_CHANCE := 0.05
const K_DODGE := 0.10

# --- balance reference : personnage
const BASE_STATS := {"hp": 80.0, "atk": 8.0, "def": 5.0, "agi": 5.0, "int": 6.0, "sag": 5.0}
const POINT_VALUE := {"hp": 25.0, "atk": 2.0, "def": 2.0, "agi": 1.0, "int": 2.0, "sag": 2.0}
const POINTS_PER_LEVEL := 6
const MAX_ACTIVE_SKILLS := 4
const ROLE_XP := {"normal": 1.0, "elite": 4.0, "boss": 15.0}
const HP_FULL_REGEN_SECONDS := 60.0       # PV pleins en 1 min hors combat (10 min en mode nœuds)...
const TOWN_REGEN_FACTOR := 3.0            # ...3 fois plus vite en ville
const DEFEAT_GOLD_SHARE := 0.03           # 3 % de l'or, au plus 20 x niveau
const DEFEAT_GOLD_CAP_PER_LEVEL := 20
const DEFEAT_HP_SHARE := 0.2              # on se relève à 20 % des PV
# --- décisions version carte (docs/combat_v1.md)
const SHAKEN_PERCENT := -20.0             # « Ébranlé » après une défaite
const SHAKEN_SECONDS := 60.0
const DEFAULT_AREA := {"shape": "arc", "range": 22.0, "angle": 80.0}
const AIM_ASSIST_DEG := 60.0

# --- couche action (version carte). Les templates et les formules ci-dessus restent ceux du pipeline
#     d'équilibrage ; ces multiplicateurs s'appliquent en jeu pour un combat ~2,5 fois plus court.
#     Calibrés par tools/balance/simulate_action.py contre le joueur de référence (niv. 1, équipé) :
#     ~27 s par bête normale, ~35 % des PV perdus sans esquive, ~18 % en esquivant les annonces.
const ACTION_MONSTER_HP := 0.4            # durée des combats
const ACTION_MONSTER_DAMAGE := 1.8        # PV perdus par combat malgré la durée plus courte
const ACTION_TELEGRAPH_POWER := 1.2       # les coups annoncés pèsent plus : esquiver compte
# Combats plus courts => ~65 bêtes par heure au lieu de 12 (régénération et marche comprises).
# Pour garder les durées de niveau (15 min au niveau 1) et le rythme du butin :
const ACTION_XP := 0.18                   # XP par bête (12 / 65)
const ACTION_XP_PER_LEVEL := 0.035        # +3,5 %/niveau : les zones profondes coûtent plus de PV,
										  # donc plus de régénération et moins de bêtes à l'heure
# Butin ordinaire GARANTI : chaque bête lâche un objet de sa table (décision de Romain, 2026-11-09).
# Avec le rachat à 35 % arrondi, la dague se paie en ~13 min de chasse et un équipement de son niveau
# en 12-21 min (tools/balance/simulate_action.py progression).
const ACTION_RARE_LOOT := 0.18            # butin très rare : même fréquence par heure qu'avant


static func basic_attack_cooldown(agi: float, level: int) -> float:
	agi = maxf(agi, 0.0)
	return BASE_ATTACK_COOLDOWN / (1.0 + agi / (agi + K_AGI + K_AGI_PER_LEVEL * maxi(level, 1)))


static func max_mana(int_stat: float, level: int) -> float:
	return BASE_MANA + MANA_PER_LEVEL * maxi(level, 1) + maxf(int_stat, 0.0) * K_INT


static func mana_regen(sag: float, level: int) -> float:
	return BASE_MANA_REGEN + MANA_REGEN_PER_LEVEL * maxi(level, 1) + maxf(sag, 0.0) * K_SAG


static func agility_edge(att_agi: float, def_agi: float) -> float:
	var total := maxf(att_agi, 0.0) + maxf(def_agi, 0.0)
	return (maxf(att_agi, 0.0) - maxf(def_agi, 0.0)) / total if total > 0.0 else 0.0


static func crit_chance(att_agi: float, def_agi: float) -> float:
	return maxf(0.0, BASE_CRIT_CHANCE + K_CRIT * agility_edge(att_agi, def_agi))


static func dodge_chance(att_agi: float, def_agi: float) -> float:
	return maxf(0.0, BASE_DODGE_CHANCE + K_DODGE * agility_edge(def_agi, att_agi))


static func mitigation(defense: float, attacker_level: int) -> float:
	defense = maxf(defense, 0.0)
	return defense / (defense + K_DEF + K_DEF_PER_LEVEL * maxi(attacker_level, 1))


## Esquive, variance ±8 %, critique x1,5 (roll_hit), puis défense (damage_monster / damage_player).
static func resolve_hit(raw: float, att_agi: float, att_level: int, def_agi: float, def_def: float,
		rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() < dodge_chance(att_agi, def_agi):
		return {"damage": 0.0, "critical": false, "dodged": true}
	var dmg := raw * rng.randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)
	var crit := rng.randf() < crit_chance(att_agi, def_agi)
	if crit:
		dmg *= CRIT_MULTIPLIER
	dmg = snappedf(dmg * (1.0 - mitigation(def_def, att_level)), 0.1)
	return {"damage": dmg, "critical": crit, "dodged": false}


static func modified(base: float, effects: Array, stat: String) -> float:
	var pct := 0.0
	var flat := 0.0
	for e in effects:
		if e.stat == stat:
			pct += e.percent
			flat += e.flat
	return maxf(0.0, (base + flat) * (1.0 + pct / 100.0))


# --- progression (balance reference ; back/balance.py absent du projet : courbe reconstituée
#     à partir des valeurs publiées, exacte aux niveaux 1, 10, 50 et 100)
const XP_ANCHORS := [[1, 43.0], [10, 298.0], [50, 5345.0], [100, 178745.0]]


static func xp_to_next(level: int) -> int:
	level = maxi(level, 1)
	for i in XP_ANCHORS.size() - 1:
		var a: Array = XP_ANCHORS[i]
		var b: Array = XP_ANCHORS[i + 1]
		if level <= b[0]:
			var t := float(level - a[0]) / float(b[0] - a[0])
			return int(round(exp(lerpf(log(a[1]), log(b[1]), t))))
	return int(XP_ANCHORS[-1][1])


## XP d'un monstre normal : 10 au niveau 1, x1,06 par niveau (17 au 10, 174 au 50, 3 201 au 100),
## puis x ACTION_XP (combats plus courts, plus nombreux).
static func monster_xp(monster_level: int, role: String, player_level: int) -> float:
	var xp := 10.0 * pow(1.06, monster_level - 1) * float(ROLE_XP.get(role, 1.0)) * ACTION_XP \
		* (1.0 + ACTION_XP_PER_LEVEL * (monster_level - 1))
	var gap := monster_level - player_level
	if gap > 0:
		xp *= 1.0 + minf(0.1 * gap, 0.5)
	elif gap < 0:
		xp *= maxf(1.0 + 0.2 * gap, 0.1)
	return snappedf(xp, 0.01)


# --- zones d'impact (version carte)
static func area_of(move: Dictionary) -> Dictionary:
	return move.get("area", DEFAULT_AREA)


static func area_reach(area: Dictionary) -> float:
	match area.get("shape", "arc"):
		"circle":
			return float(area.get("radius", 24))
		"self":
			return 0.0
	return float(area.get("range", 22))


## Vrai si une cible de rayon `r` au point `p` est dans la zone lancée depuis `origin` vers `dir`.
static func in_area(area: Dictionary, origin: Vector2, dir: Vector2, p: Vector2, r: float = 6.0) -> bool:
	var to := p - origin
	var dist := to.length()
	match area.get("shape", "arc"):
		"circle":
			return dist <= float(area.get("radius", 24)) + r
		"line":
			var along := to.dot(dir)
			var across := absf(to.cross(dir))
			return along >= -r and along <= float(area.get("range", 96)) + r \
				and across <= float(area.get("width", 10)) / 2.0 + r
		"self":
			return false
	if dist > float(area.get("range", 22)) + r:
		return false
	if dist < r + 2.0:
		return true                                    # au contact : touché quel que soit l'angle
	return absf(rad_to_deg(dir.angle_to(to))) <= float(area.get("angle", 80)) / 2.0 + rad_to_deg(atan2(r, dist))


## Aide à la visée : la direction vers la cible la plus proche dans le cône devant, sinon `dir`.
static func assisted_dir(origin: Vector2, dir: Vector2, targets: Array, reach: float) -> Vector2:
	var best := dir
	var best_d := INF
	for t in targets:
		var to: Vector2 = t - origin
		var d := to.length()
		if d < 1.0 or d > reach + 20.0:
			continue
		if absf(rad_to_deg(dir.angle_to(to))) <= AIM_ASSIST_DEG / 2.0 + 15.0 and d < best_d:
			best_d = d
			best = to.normalized()
	return best
