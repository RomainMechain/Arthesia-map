extends SceneTree
## Test du craft : règles, fabrication (sans IA : nom provisoire), recette figée, rareté, équipement,
## écran d'atelier au clic. Avec `-- --ai` : une vraie recette inédite inventée par Claude Code.
## godot --headless --path . --script res://tools/godot/craft_test.gd [-- --ai]

var _fail := 0
var gs: Node
var got := ""                       # rempli par le signal craft_done (les lambdas copient les locales)


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func(): print("TIMEOUT"); quit(2))
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_fail += 1


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await process_frame


func _on_done(id: String, discovered: bool) -> void:
	got = id + ("|new" if discovered else "")


func _points(sb: Dictionary) -> float:
	var p := 0.0
	for k in sb:
		p += float(sb[k]) * CraftRules.POINT[k]
	return p


func _run() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.reset_profile()
	gs.profile.tutorial.step = 99
	gs.craft_cache = {"items": {}, "recipes": {}}
	var with_ai := "--ai" in OS.get_cmdline_user_args()
	gs.settings.craft_ai = with_ai

	# --- règles
	var k1 := CraftRules.recipe_key("forge", "arme", {"b": 2, "a": 1})
	var k2 := CraftRules.recipe_key("forge", "arme", {"a": 1, "b": 2})
	_check(k1 == k2 and k1 == "forge|arme|a:1,b:2", "clé canonique : %s" % k1)
	_check(CraftRules.result_level([1, 4], [3, 1]) == 2 and CraftRules.result_level([3], [1]) == 3, "niveau du résultat (moyenne pondérée)")
	var sb5 := CraftRules.stat_bonuses(5, "normale", {"atk": 7, "agi": 3}, [])
	var sb5r := CraftRules.stat_bonuses(5, "rare", {"atk": 7, "agi": 3}, [])
	var sb5a := CraftRules.stat_bonuses(5, "aucune", {"atk": 7, "agi": 3}, [])
	_check(absf(_points(sb5) - 3.5) <= 0.75, "budget niv. 5 normal ≈ 3,5 points : %s (%.1f)" % [sb5, _points(sb5)])
	_check(_points(sb5a) < _points(sb5) and _points(sb5) <= _points(sb5r), "cohérence : aucune < normale ≤ rare (%.1f / %.1f / %.1f)" % [_points(sb5a), _points(sb5), _points(sb5r)])
	var o0 := CraftRules.rarity_odds("normale", 0)
	var o3 := CraftRules.rarity_odds("normale", 3)
	var sum3 := 0.0
	for v in o3:
		sum3 += v
	_check(absf(sum3 - 100.0) < 0.01 and o3[0] < o0[0] and o3[2] > o0[2], "niveau de métier d'avance : meilleures chances (commun %d → %d %%)" % [o0[0], o3[0]])
	_check(CraftRules.rarity_odds("normale", 99)[0] >= 70.0 * 0.4 - 0.01, "plafond du décalage (60 %)")
	_check(CraftRules.rarity_odds("aucune", 0, 3)[0] == 0.0, "ingrédient épique : au moins rare")
	var base := {"id": "x", "name": "Lame", "base_value": 30, "equipment": {"slot": "weapon", "stat_bonuses": {"atk": 4}}}
	var rare := CraftRules.apply_rank(base, "rare")
	_check(rare.id == "x~rare" and rare.equipment.stat_bonuses.atk == 5 and rare.base_value == 75 and base.equipment.stat_bonuses.atk == 4,
		"rang rare : stats ×1,3, valeur ×2,5, base intacte (%s)" % rare.name)

	# --- en jeu : la forge du village
	change_scene_to_file(gs.zone_path("village_aube"))
	await _wait(0.6)
	var z := current_scene
	var forge: Node = null
	for n in z.find_children("*", "Node2D", true, false):
		if n.get("template_type") == "workshop" and n.get("template_id") == "forge":
			forge = n
	_check(forge != null and forge.interact().action.get("kind") == "workshop", "la forge propose « Fabriquer »")
	gs.add_item("croc_d_or_pur", 2)
	gs.add_item("branche_morte", 4)
	gs.add_item("eclat_de_pierre_taillee", 1)
	_check(gs.ingredient_block("forge", "eclat_de_pierre_taillee") != "", "objet niv. 2 refusé au forgeron niv. 1 : %s" % gs.ingredient_block("forge", "eclat_de_pierre_taillee"))
	var recipe := {"croc_d_or_pur": 1, "branche_morte": 2}
	var pv: Dictionary = gs.craft_preview("forge", "arme", recipe)
	_check(not pv.known and pv.level == 1, "aperçu : recette inédite, niv. 1")

	# --- fabrication (sans IA : nom provisoire, ou avec IA : Claude)
	var why: String = gs.craft_start("forge", "arme", recipe)
	_check(why == "" and gs.item_count("croc_d_or_pur") == 1 and gs.item_count("branche_morte") == 2, "fabrication lancée, ingrédients pris")
	_check(gs.craft_start("forge", "arme", recipe) != "", "une seule fabrication à la fois")
	got = ""
	var t_end := Time.get_ticks_msec() + (150000 if with_ai else 8000)
	gs.craft_done.connect(_on_done, CONNECT_ONE_SHOT)
	while got == "" and Time.get_ticks_msec() < t_end:
		await process_frame
	got = got.get_slice("|", 0)
	_check(got != "" and gs.item_count(got) == 1, "objet obtenu : %s" % gs.item_name(got))
	var rec: Dictionary = gs.craft_cache.recipes.get(CraftRules.recipe_key("forge", "arme", recipe), {})
	var bt: Dictionary = gs.tpl("items", rec.get("item", ""))
	_check(not rec.is_empty() and bt.category == "equipment" and bt.equipment.slot == "weapon" and bt.equipment.has("area"),
		"recette figée : %s, %s, zone %s" % [bt.get("name"), bt.equipment.stat_bonuses, bt.equipment.get("area", {}).get("shape")])
	if with_ai:
		_check(not rec.pending, "Claude a inventé l'objet : « %s » — %s (cohérence %s)" % [bt.name, bt.description, rec.coherence])
	else:
		_check(rec.pending and bt.name.begins_with("Lame"), "sans Claude : nom provisoire « %s », à renommer" % bt.name)
	_check(gs.prof_level("forgeron") >= 1 and gs.prof_xp("forgeron") > 0.0, "XP de forgeron : %.0f" % gs.prof_xp("forgeron"))
	_check(UISkin.item_icon(got) != null, "l'objet a une icône (%s)" % bt.get("icon"))

	# --- même recette : même objet de base, sans IA, rareté retirée
	gs.settings.craft_ai = false
	why = gs.craft_start("forge", "arme", recipe)
	got = ""
	gs.craft_done.connect(_on_done, CONNECT_ONE_SHOT)
	t_end = Time.get_ticks_msec() + 6000
	while got == "" and Time.get_ticks_msec() < t_end:
		await process_frame
	_check(got.get_slice("~", 0) == rec.item and not got.ends_with("|new"), "recette connue : même objet (%s)" % got)
	var ranks := {}
	for i in 400:                                  # recette ordinaire (le croc, épique, garantit « rare »)
		ranks[CraftRules.roll_rank(CraftRules.rarity_odds("normale", 0), randf())] = true
	_check(ranks.size() >= 3, "la rareté varie d'une fabrication à l'autre : %s" % [ranks.keys()])
	var floor_ok := true
	for i in 200:
		floor_ok = floor_ok and CraftRules.rank_index(CraftRules.roll_rank(gs.craft_preview("forge", "arme", recipe).odds, randf())) >= 2
	_check(floor_ok, "avec le Croc d'Or Pur (épique) : jamais sous « rare »")

	# --- équiper l'objet crafté
	var weapon: String = got.get_slice("|", 0)
	_check(gs.equip_item(weapon) == "" and gs.weapon_area() == bt.equipment.area, "équipé : zone de coup %s" % [gs.weapon_area()])

	# --- écran d'atelier : sac -> établi -> fabriquer, au clic
	forge.get_parent()
	z.hud.open_workshop("forge")
	var at: Control = z.hud.atelier
	await _wait(0.2)
	_check(at.visible and at._title.text.begins_with("Forge"), "écran d'atelier ouvert")
	gs.add_item("croc_d_or_pur", 1)
	gs.add_item("branche_morte", 2)
	at._add("croc_d_or_pur")
	at._add("branche_morte")
	at._type = "arme"
	at.refresh()
	_check(at._bench.size() == 2 and not at._go.disabled, "établi : %s, bouton actif" % [at._bench])
	at._type = "casque"
	at.refresh()
	_check(at._preview.text.begins_with("Recette inédite"), "autre type d'objet = autre recette : %s" % at._preview.text.left(40))
	at._on_go()
	await _wait(0.1)
	_check(not gs.crafting.is_empty() and at._go.disabled, "fabrication lancée depuis l'écran")
	await _wait(3.6)
	_check(gs.crafting.is_empty() and at._info.text != "", "résultat affiché : %s" % at._info.text.left(70))

	print("\n%d échec(s)" % _fail)
	quit(_fail)
