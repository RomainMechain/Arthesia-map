class_name CraftRules
## Règles du craft (docs/arthesia_balance_reference.md § Craft, docs/arthesia_data_model.md § Craft).
## Pur : aucun nœud. L'IA ne fournit que l'identité de l'objet (nom, description, cohérence,
## répartition des stats, forme d'arme, icône) ; tous les chiffres viennent d'ici.

const MAX_INPUTS := 4                 # ingrédients différents
const MAX_TOTAL := 8                  # quantité totale posée sur l'établi
const CRAFT_SECONDS := 3.0
const MAX_GENERATION := 1             # un objet crafté sert d'ingrédient une fois, pas plus

## Métier exigé par chaque atelier (data/templates/workshops/*.json)
const PROFESSION := {"forge": "forgeron", "couture": "couturier", "sculpture": "sculpteur",
	"alchimie": "alchimiste", "cuisine": "cuisinier", "enchantement": "enchanteur"}

const RANKS := ["commun", "peu_commun", "rare", "epique", "legendaire"]
const RANK_NAMES := {"commun": "commun", "peu_commun": "peu commun", "rare": "rare", "epique": "épique",
	"legendaire": "légendaire"}
const RANK_COLORS := {"commun": "ece2cf", "peu_commun": "74a843", "rare": "52aab8", "epique": "b06ad0",
	"legendaire": "f5b84a"}
## Le rang multiplie les bonus, l'effet d'un consommable et la valeur.
const RANK_STATS := {"commun": 1.0, "peu_commun": 1.15, "rare": 1.3, "epique": 1.5, "legendaire": 1.8}
const RANK_EFFECT := {"commun": 1.0, "peu_commun": 1.1, "rare": 1.2, "epique": 1.35, "legendaire": 1.5}
const RANK_VALUE := {"commun": 1.0, "peu_commun": 1.5, "rare": 2.5, "epique": 4.0, "legendaire": 7.0}

## Chances de base par cohérence (commun, peu commun, rare, épique, légendaire), en %.
const ODDS := {"aucune": [92.0, 7.0, 1.0, 0.0, 0.0], "normale": [70.0, 22.0, 7.0, 1.0, 0.0],
	"rare": [25.0, 35.0, 27.0, 10.0, 3.0]}
## Budget de stats selon la cohérence (part du budget du niveau).
const BUDGET := {"aucune": 0.7, "normale": 1.0, "rare": 1.15}
const EFFECT := {"aucune": 0.8, "normale": 1.0, "rare": 1.2}
## Chaque cran (niveau de métier d'avance, rang d'un ingrédient) fait monter cette part des chances
## d'un rang ; au plus MAX_SHIFT.
const SHIFT_PER_STEP := 0.08
const MAX_SHIFT := 0.6

## Poids d'une stat en « points équivalents » : hp/25 + atk/2 + def/2 + agi + int/2 + sag/2.
const POINT := {"hp": 1.0 / 25.0, "atk": 0.5, "def": 0.5, "agi": 1.0, "int": 0.5, "sag": 0.5}

## Zone du coup de base selon la forme d'arme choisie par l'IA.
const WEAPON_AREAS := {
	"dague": {"shape": "arc", "range": 26, "angle": 100},
	"lame": {"shape": "arc", "range": 30, "angle": 110},
	"hachette": {"shape": "arc", "range": 28, "angle": 130},
	"masse": {"shape": "arc", "range": 24, "angle": 160},
	"lance": {"shape": "line", "range": 44, "width": 12},
}


## Clé canonique : atelier | type | ingrédients triés (id:quantité). Pas de réglage (choix v1).
static func recipe_key(workshop: String, type_id: String, inputs: Dictionary) -> String:
	var ids: Array = inputs.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		parts.append("%s:%d" % [id, int(inputs[id])])
	return "%s|%s|%s" % [workshop, type_id, ",".join(parts)]


## Variante de rareté d'un objet : « base~rang » (le commun garde l'id de base).
static func variant_id(base: String, rank: String) -> String:
	return base if rank == "commun" else "%s~%s" % [base, rank]


static func split_variant(item_id: String) -> Array:
	var i := item_id.find("~")
	return [item_id, "commun"] if i < 0 else [item_id.substr(0, i), item_id.substr(i + 1)]


## Niveau du résultat : moyenne des ingrédients pondérée par la quantité, jamais au-dessus du plus haut.
static func result_level(levels: Array, qtys: Array) -> int:
	var s := 0.0
	var n := 0.0
	var top := 1
	for i in levels.size():
		s += float(levels[i]) * float(qtys[i])
		n += float(qtys[i])
		top = maxi(top, int(levels[i]))
	return clampi(int(floor(s / maxf(n, 1.0) + 0.5)), 1, top)


static func equipment_points(level: int) -> float:
	return 0.7 * level


static func heal_amount(level: int) -> int:
	return int(round(41.0 + 17.0 * (level - 1)))


static func mana_amount(level: int) -> int:
	return int(round(26.0 + 4.9 * (level - 1)))


static func value_target(category: String, level: int) -> int:
	return {"material": 5, "consumable": 15, "equipment": 30}.get(category, 5) * level


## Valeur de base : ~85 % des ingrédients, dans 70-130 % de la cible du niveau.
static func base_value(category: String, level: int, inputs_value: float) -> int:
	var t := float(value_target(category, level))
	return maxi(1, int(round(clampf(inputs_value * 0.85, t * 0.7, t * 1.3))))


## Stats d'un équipement : répartit le budget (points équivalents) selon les poids de l'IA.
## Une stat qui retomberait sous 1 disparaît, sauf la principale (au moins 1).
static func stat_bonuses(level: int, coherence: String, weights: Dictionary, fallback_stats: Array) -> Dictionary:
	var w := {}
	for k in weights:
		if POINT.has(k) and float(weights[k]) > 0.0:
			w[k] = float(weights[k])
	if w.is_empty():
		var st: Array = fallback_stats if not fallback_stats.is_empty() else ["atk"]
		w[st[0]] = 7.0
		if st.size() > 1:
			w[st[1]] = 3.0
	var keys: Array = w.keys()
	keys.sort_custom(func(a, b): return w[a] > w[b])
	keys = keys.slice(0, 2)
	var total := 0.0
	for k in keys:
		total += w[k]
	var pts := equipment_points(level) * float(BUDGET.get(coherence, 1.0))
	var out := {}
	for i in keys.size():
		var k: String = keys[i]
		var v := int(round(pts * w[k] / total / POINT[k]))
		if v >= 1:
			out[k] = v
		elif i == 0:
			out[k] = 1
	return out


## Chances (5 rangs, somme 100) : table de la cohérence, puis chaque cran fait monter une part des
## chances d'un rang (au plus 60 %) ; un ingrédient épique ou mieux garantit au moins « rare ».
static func rarity_odds(coherence: String, steps: int, best_input_rank := 0) -> Array:
	var o: Array = (ODDS.get(coherence, ODDS.normale) as Array).duplicate()
	var s := minf(MAX_SHIFT, SHIFT_PER_STEP * maxi(0, steps))
	if s > 0.0:
		var n := [0.0, 0.0, 0.0, 0.0, 0.0]
		for i in 5:
			if i == 4:
				n[i] += o[i]
			else:
				n[i] += o[i] * (1.0 - s)
				n[i + 1] += o[i] * s
		o = n
	if best_input_rank >= 3:                       # épique ou légendaire en entrée
		var low: float = o[0] + o[1]
		o[0] = 0.0
		o[1] = 0.0
		o[2] += low
	return o


static func roll_rank(odds: Array, r: float) -> String:
	var acc := 0.0
	for i in 5:
		acc += float(odds[i])
		if r * 100.0 < acc:
			return RANKS[i]
	return RANKS[0]


static func rank_index(rank: String) -> int:
	return maxi(0, RANKS.find(rank))


## Applique un rang à un objet de base (copie) : stats, effet, valeur, nom.
static func apply_rank(base: Dictionary, rank: String) -> Dictionary:
	var t := base.duplicate(true)
	if rank == "commun":
		return t
	t.id = variant_id(str(base.get("id", "")), rank)
	t.rarity = rank
	t.name = "%s (%s)" % [base.get("name", ""), RANK_NAMES[rank]]
	t.base_value = int(round(float(base.get("base_value", 1)) * RANK_VALUE[rank]))
	if t.has("equipment"):
		var sb: Dictionary = t.equipment.get("stat_bonuses", {})
		for k in sb:                               # dès « rare », au moins +1 même sur une petite stat
			var x := int(sb[k])
			sb[k] = maxi(int(round(float(x) * RANK_STATS[rank])), x + (1 if rank_index(rank) >= 2 else 0))
	if t.has("consumable"):
		t.consumable.amount = int(round(float(t.consumable.amount) * RANK_EFFECT[rank]))
	return t


## XP de métier d'une fabrication : 4 récoltes de ce niveau (+10 %/niveau d'objet), pénalité si
## l'objet est trop facile pour le métier ; recette inédite : ×1,5.
static func craft_xp(prof_level: int, item_level: int, discovered: bool) -> float:
	var xp := 4.0 * 10.0 * (1.0 + 0.1 * (item_level - 1))
	var gap := prof_level - item_level
	if gap > 0:
		xp *= maxf(0.25, 1.0 - 0.25 * gap)
	return xp * (1.5 if discovered else 1.0)
