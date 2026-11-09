extends Node
## Autoload « GameState » : tout ce qui survit aux changements de zone.
##  - transitions (fondu, zone d'arrivée) ;
##  - profil du joueur : niveau, XP, points, sac, or, quêtes, compteurs, compétences, barre ;
##  - combattant du joueur (Fighter) : PV, mana, effets ;
##  - évaluation des Conditions du modèle de données ; défaite ; sauvegarde (user://, versionnée).

signal zone_changed(zone_id: String)
signal profile_changed
signal leveled_up(level: int)
signal quest_changed(quest_id: String)
signal item_gained(item_id: String, qty: int)
signal notice(text: String)
signal hint(key: String, text: String)          # bulle d'aide (une seule fois par clé)
signal objective_changed
signal title_unlocked(title_id: String)
signal settings_changed

const SAVE_PATH := "user://arthesia_save.json"
const SETTINGS_PATH := "user://arthesia_settings.json"
const SAVE_VERSION := 1
const START_ZONE := "village_aube"
const START_SKILLS := []                 # « mains nues » : la barre se remplit par les déblocages

var floor_id := "floor_1"
var current_zone := ""
var zone_type := "town"
var arrival_from := ""          # zone d'où l'on arrive ("" = point d'apparition par défaut)
var persist := true             # les tests coupent la sauvegarde

var profile: Dictionary = {}
var settings := {"ambience": 1.0, "vibrate": true, "hints": true}
var fighter := Fighter.new()

var _fade: ColorRect
var _busy := false
var _tpl_cache := {}
var _save_t := 0.0


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color("2a1a2e")
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	_load_settings()
	if not (persist and _load()):
		reset_profile()


func _process(delta: float) -> void:
	fighter.tick(delta)
	# PV hors combat : pleins en 10 min, 3 fois plus vite en ville
	if fighter.alive() and fighter.hp < fighter.max_hp() * 0.4 and fighter.in_combat():
		show_hint("low_hp")
	if fighter.alive() and not fighter.in_combat() and fighter.hp < fighter.max_hp():
		var k := CombatRules.TOWN_REGEN_FACTOR if zone_type == "town" else 1.0
		fighter.heal(fighter.max_hp() / CombatRules.HP_FULL_REGEN_SECONDS * k * delta)
	_save_t += delta
	if _save_t > 20.0:
		_save_t = 0.0
		save()


# --------------------------------------------------------------------------- templates
func tpl(kind: String, id: String) -> Dictionary:
	var key := kind + "/" + id
	if not _tpl_cache.has(key):
		var path := "res://data/templates/%s/%s.json" % [kind, id]
		var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_tpl_cache[key] = d if d is Dictionary else {}
	return _tpl_cache[key]


func item_name(item_id: String) -> String:
	return tpl("items", item_id).get("name", item_id)


# --------------------------------------------------------------------------- profil
func reset_profile() -> void:
	profile = {
		"version": SAVE_VERSION, "level": 1, "xp": 0,
		"unspent": CombatRules.POINTS_PER_LEVEL,   # le niveau 1 donne aussi ses 6 points (joueur de référence)
		"alloc": {"hp": 0, "atk": 0, "def": 0, "agi": 0, "int": 0, "sag": 0},
		"gold": 0, "inventory": {}, "kills": {}, "quests": {}, "visited": [],
		"skills": [], "bar": ["", "", "", ""], "equipment": {},
		"professions": {}, "gathers": {}, "titles": [], "title": "", "notes": {},
		"tutorial": {"step": 0, "seen": {}, "kills_at_step": 0},
	}
	recompute_stats(true)
	check_unlocks(false)


func recompute_stats(full := false) -> void:
	var s := {}
	for k in CombatRules.BASE_STATS:
		s[k] = CombatRules.BASE_STATS[k] + profile.alloc[k] * CombatRules.POINT_VALUE[k]
	for slot in profile.equipment:
		var eq: Dictionary = tpl("items", profile.equipment[slot]).get("equipment", {})
		for k in eq.get("stat_bonuses", {}):
			s[k] = s.get(k, 0.0) + float(eq.stat_bonuses[k])
	# titre porté : bonus en % sur les stats (équipement compris)
	if profile.get("title", "") != "":
		for e in tpl("titles", profile.title).get("effects", []):
			if e.get("type") == "stat_bonus_percent":
				s[e.stat] = s.get(e.stat, 0.0) * (1.0 + float(e.amount_percent) / 100.0)
			elif e.get("type") == "stat_bonus":
				s[e.stat] = s.get(e.stat, 0.0) + float(e.amount)
	var ratio := fighter.hp / fighter.max_hp() if fighter.base.size() > 0 and fighter.max_hp() > 0 else 1.0
	fighter.id = "player"
	fighter.display_name = "Vous"
	fighter.setup(s, int(profile.level), full)
	if not full:
		fighter.hp = clampf(ratio * fighter.max_hp(), 1.0, fighter.max_hp())
	profile_changed.emit()


func spend_point(stat_key: String) -> bool:
	if profile.unspent <= 0:
		return false
	profile.unspent -= 1
	profile.alloc[stat_key] += 1
	recompute_stats()
	tutorial_check()
	save()
	return true


func gain_xp(amount: float) -> void:
	profile.xp = float(profile.xp) + amount
	var leveled := false
	while profile.xp >= CombatRules.xp_to_next(profile.level):
		profile.xp -= CombatRules.xp_to_next(profile.level)
		profile.level += 1
		profile.unspent += CombatRules.POINTS_PER_LEVEL
		leveled = true
		leveled_up.emit(profile.level)
	if leveled:
		recompute_stats(true)                 # monter de niveau remet les PV au maximum
		check_unlocks()
		show_hint("level")
		save()
	profile_changed.emit()


func add_gold(n: int) -> void:
	profile.gold = maxi(0, profile.gold + n)
	profile_changed.emit()


func add_item(item_id: String, qty: int) -> void:
	_give(item_id, qty)
	item_gained.emit(item_id, qty)
	show_hint("loot")
	_refresh_quests()
	profile_changed.emit()


func item_count(item_id: String) -> int:
	return int(profile.inventory.get(item_id, 0))


func _give(item_id: String, qty: int) -> void:
	profile.inventory[item_id] = item_count(item_id) + qty


func _take(item_id: String, qty := 1) -> bool:
	if item_count(item_id) < qty:
		return false
	profile.inventory[item_id] = item_count(item_id) - qty
	if profile.inventory[item_id] <= 0:
		profile.inventory.erase(item_id)
	return true


# --------------------------------------------------------------------------- équipement
const SLOTS := ["weapon", "head", "chest", "gloves", "boots", "ring", "amulet"]


## "" si l'objet peut être porté, sinon la raison (affichée au joueur).
func can_equip(item_id: String) -> String:
	var t := tpl("items", item_id)
	if t.get("category") != "equipment":
		return "ne se porte pas"
	var need := int(t.equipment.get("level_required", 1))
	if int(profile.level) < need:
		return "niveau %d requis" % need
	return ""


func equipped(slot: String) -> String:
	return profile.equipment.get(slot, "")


## Équipe un objet du sac ; l'objet déjà porté à cet emplacement retourne dans le sac.
func equip_item(item_id: String) -> String:
	var why := can_equip(item_id)
	if why != "":
		return why
	if not _take(item_id):
		return "pas dans le sac"
	var slot: String = tpl("items", item_id).equipment.slot
	var prev := equipped(slot)
	if prev != "":
		_give(prev, 1)
	profile.equipment[slot] = item_id
	recompute_stats()
	tutorial_check()
	notice.emit("Équipé : %s" % item_name(item_id))
	save()
	return ""


func unequip(slot: String) -> void:
	var prev := equipped(slot)
	if prev == "":
		return
	profile.equipment.erase(slot)
	_give(prev, 1)
	recompute_stats()
	save()


## Zone du coup de base : celle de l'arme portée, sinon les poings.
func weapon_area() -> Dictionary:
	var w := equipped("weapon")
	if w == "":
		return {"shape": "arc", "range": 22, "angle": 100}
	return tpl("items", w).equipment.get("area", CombatRules.DEFAULT_AREA)


# --------------------------------------------------------------------------- métiers de récolte
## Courbe du document d'équilibrage : ~50 récoltes de sa tranche par niveau de métier. Une récolte de
## niveau r vaut 10 x (1 + 0,1 (r-1)) XP ; plus facile que le métier : -25 %/niveau d'écart (25 % min).
const PROF_NAMES := {"herboristerie": "Herboristerie", "bucheronnage": "Bûcheronnage", "minage": "Minage",
	"peche": "Pêche", "chasse": "Chasse", "runographie": "Runographie", "sourcellerie": "Sourcellerie",
	"archeologie": "Archéologie"}


func prof_level(p: String) -> int:
	return int(profile.professions.get(p, {}).get("level", 1))


func prof_xp(p: String) -> float:
	return float(profile.professions.get(p, {}).get("xp", 0.0))


static func prof_to_next(level: int) -> int:
	return int(round(500.0 * (1.0 + 0.1 * (level - 1))))


func gain_prof_xp(p: String, resource_level: int) -> float:
	var lvl := prof_level(p)
	var xp := 10.0 * (1.0 + 0.1 * (resource_level - 1))
	var gap := lvl - resource_level
	if gap > 0:
		xp *= maxf(0.25, 1.0 - 0.25 * gap)
	var e: Dictionary = profile.professions.get(p, {"level": 1, "xp": 0.0})
	e.xp = float(e.xp) + xp
	while e.xp >= prof_to_next(int(e.level)):
		e.xp -= prof_to_next(int(e.level))
		e.level = int(e.level) + 1
		notice.emit("%s : niveau %d !" % [PROF_NAMES.get(p, p), e.level])
	profile.professions[p] = e
	return xp


## Une récolte réussie : compteur (conditions gather_count), XP de métier, déblocages.
func on_gather(resource_id: String, profession: String, resource_level: int) -> void:
	profile.gathers[resource_id] = int(profile.gathers.get(resource_id, 0)) + 1
	for qid in profile.quests:                    # objectifs « récolter N fois »
		var q: Dictionary = profile.quests[qid]
		if q.state != "active":
			continue
		var objs: Array = tpl("quests", qid).get("objectives", [])
		for i in objs.size():
			if objs[i].get("type") == "gather_count" and objs[i].get("resource_id") == resource_id:
				q.progress[i] = mini(int(q.progress[i]) + 1, int(objs[i].count))
	if profession != "":
		gain_prof_xp(profession, resource_level)
	_refresh_quests()
	check_unlocks()
	profile_changed.emit()
	save()


# --------------------------------------------------------------------------- commerce et consommables
const SELL_SHARE := 0.35                  # le marchand rachète à 35 % de la valeur (K_SELL)


func sell_price(item_id: String) -> int:
	return maxi(1, int(round(float(tpl("items", item_id).get("base_value", 1)) * SELL_SHARE)))   # arrondi


func buy(shop_id: String, item_id: String) -> String:
	var offer: Dictionary = {}
	for o in tpl("shops", shop_id).get("sell_offers", []):
		if o.item_id == item_id:
			offer = o
	if offer.is_empty():
		return "pas en vente ici"
	if int(profile.gold) < int(offer.price):
		return "pas assez d'or"
	profile.gold -= int(offer.price)
	add_item(item_id, 1)
	save()
	return ""


func sell(item_id: String, qty := 1) -> int:
	if not _take(item_id, qty):
		return 0
	var gain := sell_price(item_id) * qty
	profile.gold += gain
	_refresh_quests()
	profile_changed.emit()
	save()
	return gain


## Meilleur soin du sac (le plus fort), pour le raccourci du HUD ; "" s'il n'y en a aucun.
func best_heal() -> String:
	var best := ""
	var best_amount := -1.0
	for id in profile.inventory:
		var c: Dictionary = tpl("items", id).get("consumable", {})
		if c.get("effect_type") == "heal" and float(c.get("amount", 0)) > best_amount:
			best = id
			best_amount = float(c.get("amount", 0))
	return best


## Consommable (combat_engine.apply_consumable) : soin, mana, renfort ; recharge commune de 5 s.
func use_item(item_id: String) -> String:
	var c: Dictionary = tpl("items", item_id).get("consumable", {})
	if c.is_empty():
		return "ne s'utilise pas"
	if item_count(item_id) <= 0:
		return "plus aucun"
	if not fighter.ready("item"):
		return "attends encore %d s" % ceili(fighter.remaining("item"))
	var amount := float(c.get("amount", 0))
	match c.get("effect_type"):
		"heal":
			if fighter.hp >= fighter.max_hp():
				return "tes PV sont déjà au maximum"
			fighter.heal(amount)
		"restore_mana":
			if fighter.mana >= fighter.max_mana():
				return "ton mana est déjà au maximum"
			fighter.mana = minf(fighter.max_mana(), fighter.mana + amount)
		"buff_stat":
			fighter.add_effect(item_id, item_name(item_id), c.get("stat", "atk"), float(c.get("duration_seconds", 30)), 0.0, amount)
		_:
			return "effet inconnu"
	_take(item_id)
	fighter.start_cooldown("item", 5.0)
	profile_changed.emit()
	save()
	return ""


# --------------------------------------------------------------------------- compétences
func check_unlocks(announce := true) -> void:
	check_titles(announce)
	for path in _skill_ids():
		var sk := tpl("skills", path)
		if sk.is_empty() or path in profile.skills:
			continue
		if eval_condition(sk.get("unlock_condition")):
			profile.skills.append(path)
			if sk.get("kind") == "active":
				var free: int = profile.bar.find("")
				if free >= 0:
					profile.bar[free] = path
			if announce:
				notice.emit("Nouvelle compétence : %s" % sk.get("name", path))
	profile_changed.emit()


# --------------------------------------------------------------------------- titres
## Titres (templates/titles) : accomplissements composés et secrets ; un seul porté à la fois.
func title_ids() -> Array:
	var out := []
	var dir := DirAccess.open("res://data/templates/titles")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json"):
				out.append(f.get_basename())
	out.sort()
	return out


func check_titles(announce := true) -> void:
	if not profile.has("titles"):
		return
	for tid in title_ids():
		if tid in profile.titles:
			continue
		if eval_condition(tpl("titles", tid).get("unlock_condition")):
			profile.titles.append(tid)
			if announce:
				title_unlocked.emit(tid)
				notice.emit("Nouveau titre : %s" % tpl("titles", tid).get("name", tid))


func equip_title(tid: String) -> void:
	if tid != "" and not tid in profile.titles:
		return
	profile.title = tid
	recompute_stats()
	save()


## Place une compétence active débloquée dans un emplacement (échange si elle y était déjà ailleurs).
func equip_skill(sid: String, slot: int) -> void:
	if not sid in profile.skills or tpl("skills", sid).get("kind") != "active":
		return
	var prev: int = profile.bar.find(sid)
	if prev >= 0:
		profile.bar[prev] = profile.bar[slot]
	profile.bar[slot] = sid
	profile_changed.emit()
	save()


func _skill_ids() -> Array:
	var out := []
	var dir := DirAccess.open("res://data/templates/skills")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json"):
				out.append(f.get_basename())
	out.sort_custom(func(a, b): return int(tpl("skills", a).get("level", 1)) < int(tpl("skills", b).get("level", 1)) \
		or (int(tpl("skills", a).get("level", 1)) == int(tpl("skills", b).get("level", 1)) and a < b))
	return out


# --------------------------------------------------------------------------- partie, réglages
const TITLE_SCENE := "res://scenes/ui/titre.tscn"


## Retour à l'écran titre (fondu), la partie est sauvegardée.
func go_title() -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	save()
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file(TITLE_SCENE)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.35)
	await tw2.finished
	_busy = false


## Lance la partie depuis l'écran titre : au cercle d'arrivée du village.
func start_game() -> void:
	travel("", START_ZONE, "")


## Découverte : la note rejoint le Carnet (une seule fois) et rapporte un peu d'XP.
func add_note(note_id: String, title: String, text: String) -> bool:
	if profile.notes.has(note_id):
		return false
	profile.notes[note_id] = {"title": title, "text": text}
	gain_xp(maxf(1.0, CombatRules.xp_to_next(int(profile.level)) * 0.05))
	notice.emit("Note ajoutée au Carnet : %s" % title)
	save()
	return true


## Fondu au noir, puis `action` (déplacement du joueur...), puis retour de l'image.
func fade_do(action: Callable) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.35)
	await tw.finished
	action.call()
	await get_tree().create_timer(0.25).timeout
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.4)
	await tw2.finished
	_busy = false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func new_game() -> void:
	if persist and FileAccess.file_exists(SAVE_PATH):          # jamais en test
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	reset_profile()
	fighter.effects.clear()
	current_zone = ""
	save()


func delete_save() -> void:
	if persist and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func set_setting(key: String, value) -> void:
	settings[key] = value
	if persist:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(settings))
	settings_changed.emit()


func _load_settings() -> void:
	if persist and FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if d is Dictionary:
			settings.merge(d, true)


# --------------------------------------------------------------------------- accueil du joueur
## Fil d'objectifs des premières minutes. `targets` : où pointe la flèche de guidage, par zone
## (nom d'une entrée, d'une sortie, « mobs » = la bête la plus proche, « hud:carnet » = le bouton).
const TUTORIAL := [
	{"text": "Parle à Mère Yvenne, près du puits.",
		"targets": {"village_aube": "npc_yvenne", "sentier_lisiere": "exit_village_aube"}},
	{"text": "Ouvre le Carnet et répartis tes points.",
		"targets": {"*": "hud:carnet"}},
	{"text": "Rejoins le Sentier de la Lisière, au nord-est.",
		"targets": {"village_aube": "exit_sentier_lisiere"}},
	{"text": "Chasse quelques bêtes du sentier (0/3).",
		"targets": {"sentier_lisiere": "mobs", "village_aube": "exit_sentier_lisiere"}},
	{"text": "Vends ton butin, achète une arme chez Thessaly et équipe-la.",
		"targets": {"village_aube": "shop_echoppe", "sentier_lisiere": "exit_village_aube"}},
	{"text": "Va voir Aurin, l'ermite du sentier.",
		"targets": {"sentier_lisiere": "aurin_presence", "village_aube": "exit_sentier_lisiere"}},
]
const YVENNE_WELCOME := [
	"Ah… encore un Marqué. Le cercle t'a déposé comme les autres, au petit matin. Ici, le matin ne finit jamais : tu t'y feras.",
	"Tu n'as rien sur toi, pas même une lame. Thessaly tient l'échoppe sur la place ; elle t'en vendra une, si tu as de quoi payer.",
	"Les bêtes de la lisière, au nord, laissent toujours quelque chose derrière elles. Vends-le, et prends garde aux loups dorés.",
]
const HINTS := {
	"aggro": "Un « ! » rouge : cette bête t'a repéré. Frappe-la avec le gros bouton (ou clic gauche).",
	"telegraph": "Zone rouge au sol : sors-en avant qu'elle soit pleine pour éviter le coup !",
	"loot": "Le butin va directement dans ton Sac. Ouvre le Carnet pour le voir.",
	"low_hp": "Tes PV baissent : mange avec le bouton de soin (F), ou éloigne-toi pour récupérer.",
	"level": "Niveau supérieur ! De nouveaux points t'attendent dans le Carnet.",
	"resource": "Touche une ressource pour la récolter. Bouger interrompt la récolte.",
	"quest": "Un « ! » doré au-dessus d'une tête : quelqu'un a une quête pour toi.",
}


func tutorial_step() -> int:
	return int(profile.get("tutorial", {}).get("step", TUTORIAL.size()))


func objective() -> Dictionary:
	var st := tutorial_step()
	if st >= TUTORIAL.size():
		return {}
	var o: Dictionary = TUTORIAL[st].duplicate()
	if st == 3:
		var k := mini(3, _total_kills() - int(profile.tutorial.get("kills_at_step", 0)))
		o.text = (o.text as String).replace("(0/3)", "(%d/3)" % k)
	return o


func _total_kills() -> int:
	var n := 0
	for k in profile.kills:
		n += int(profile.kills[k])
	return n


func _advance_tutorial() -> void:
	profile.tutorial.step = tutorial_step() + 1
	profile.tutorial.kills_at_step = _total_kills()
	objective_changed.emit()
	save()


## Fait avancer l'accueil selon ce qui vient de se passer ; appelé sur chaque événement utile.
func tutorial_check(event := "") -> void:
	if not profile.has("tutorial"):
		return
	match tutorial_step():
		0:
			if event == "talk:npc_yvenne":
				_advance_tutorial()
		1:
			if int(profile.unspent) == 0:
				_advance_tutorial()
		2:
			if current_zone == "sentier_lisiere":
				_advance_tutorial()
		3:
			if _total_kills() - int(profile.tutorial.kills_at_step) >= 3:
				_advance_tutorial()
			else:
				objective_changed.emit()
		4:
			if equipped("weapon") != "":
				_advance_tutorial()
		5:
			if quest_state("veille_silencieuse") != "":
				_advance_tutorial()


## Bulle d'aide unique (si les bulles sont activées).
func show_hint(key: String) -> void:
	if not settings.get("hints", true) or not HINTS.has(key):
		return
	if profile.get("tutorial", {}).get("seen", {}).has(key):
		return
	profile.tutorial.seen[key] = true
	hint.emit(key, HINTS[key])


func replay_tutorial() -> void:
	profile.tutorial = {"step": 0, "seen": {}, "kills_at_step": _total_kills()}
	objective_changed.emit()
	save()


# --------------------------------------------------------------------------- étage (squelette)
var _floor_cache := {}
var _unlock_stack := []


## Squelette de l'étage (zones, positions de la carte à nœuds, connexions).
func floor_data() -> Dictionary:
	if not _floor_cache.has(floor_id):
		var path := "res://data/zone_skeletons/%s_skeleton.json" % floor_id
		var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_floor_cache[floor_id] = d if d is Dictionary else {"zones": [], "connections": []}
	return _floor_cache[floor_id]


func zone_info(zone_id: String) -> Dictionary:
	for z in floor_data().get("zones", []):
		if z.id == zone_id:
			return z
	return {}


## Zone débloquée selon son unlock_condition (récursif : « zone X débloquée »).
func zone_unlocked(zone_id: String) -> bool:
	if zone_id in profile.visited or zone_id == START_ZONE:
		return true
	if zone_id in _unlock_stack:
		return false
	_unlock_stack.append(zone_id)
	var ok := eval_condition(zone_info(zone_id).get("unlock_condition"))
	_unlock_stack.erase(zone_id)
	return ok


# --------------------------------------------------------------------------- conditions (modèle de données)
func eval_condition(c) -> bool:
	if c == null or not (c is Dictionary) or c.is_empty():
		return true
	match c.get("type"):
		"level":
			return profile.level >= int(c.get("min", 1))
		"quest":
			var st := quest_state(c.quest_id)
			match c.get("state"):
				"completed":
					return st == "turned_in"
				"active":
					return st == "active" or st == "complete"
			return st != ""
		"item":
			return item_count(c.item_id) > 0
		"kill_count":
			return int(profile.kills.get(c.monster_id, 0)) >= int(c.get("count", 1))
		"zone":
			return zone_unlocked(c.zone_id) if c.get("state", "unlocked") == "unlocked" else c.zone_id in profile.visited
		"gather_count":
			return int(profile.gathers.get(c.resource_id, 0)) >= int(c.get("count", 1))
		"group":
			var results: Array = c.get("conditions", []).map(func(x): return eval_condition(x))
			return not (false in results) if c.get("mode", "all") == "all" else (true in results)
	return false                                  # boss... : pas encore suivi


# --------------------------------------------------------------------------- combat
func on_kill(monster_id: String, level: int, role: String) -> void:
	profile.kills[monster_id] = int(profile.kills.get(monster_id, 0)) + 1
	gain_xp(CombatRules.monster_xp(level, role, profile.level))
	for qid in profile.quests:
		var q: Dictionary = profile.quests[qid]
		if q.state != "active":
			continue
		var objs: Array = tpl("quests", qid).get("objectives", [])
		for i in objs.size():
			if objs[i].get("type") == "kill_count" and objs[i].get("monster_id") == monster_id:
				q.progress[i] = mini(int(q.progress[i]) + 1, int(objs[i].count))
	_refresh_quests()
	check_unlocks()
	tutorial_check()


## Défaite : retour au cercle d'arrivée, 20 % des PV, « Ébranlé », perte de 3 % de l'or (max 20 x niveau).
func defeat() -> void:
	var lost := mini(int(floor(profile.gold * CombatRules.DEFEAT_GOLD_SHARE)),
		CombatRules.DEFEAT_GOLD_CAP_PER_LEVEL * int(profile.level))
	profile.gold -= lost
	await travel(current_zone, START_ZONE, "")
	fighter.hp = fighter.max_hp() * CombatRules.DEFEAT_HP_SHARE
	for s in ["hp", "atk", "def", "agi", "int", "sag"]:
		fighter.add_effect("ebranle", "Ébranlé", s, CombatRules.SHAKEN_SECONDS, CombatRules.SHAKEN_PERCENT)
	fighter.hp = minf(fighter.hp, fighter.max_hp())
	fighter.hp_changed.emit(fighter.hp, fighter.max_hp())
	notice.emit("Vous êtes tombé. Ébranlé pendant %d s%s." % [int(CombatRules.SHAKEN_SECONDS),
		(", %d or perdu" % lost) if lost > 0 else ""])
	profile_changed.emit()
	save()


# --------------------------------------------------------------------------- quêtes
## "" (jamais prise), "active", "complete" (prête à rendre), "turned_in".
func quest_state(qid: String) -> String:
	return profile.quests.get(qid, {}).get("state", "")


func accept_quest(qid: String) -> void:
	if quest_state(qid) != "":
		return
	var objs: Array = tpl("quests", qid).get("objectives", [])
	profile.quests[qid] = {"state": "active", "progress": objs.map(func(_o): return 0)}
	notice.emit("Quête acceptée : %s" % tpl("quests", qid).get("name", qid))
	tutorial_check()
	_refresh_quests()
	quest_changed.emit(qid)
	save()


func quest_progress_text(qid: String) -> Array:
	var out := []
	var q: Dictionary = profile.quests.get(qid, {})
	var objs: Array = tpl("quests", qid).get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		var n := int(o.get("count", 1))
		match o.get("type"):
			"kill_count":
				out.append("%s : %d/%d" % [tpl("monsters", o.monster_id).get("name", o.monster_id), int(q.progress[i]), n])
			"deliver_item", "gather_item":
				out.append("%s : %d/%d" % [item_name(o.item_id), mini(item_count(o.item_id), n), n])
			"gather_count":
				out.append("Récolter : %s : %d/%d" % [tpl("resources", o.resource_id).get("name", o.resource_id),
					int(q.progress[i]) if q else 0, n])
			_:
				out.append("%s : %d/%d" % [o.get("type"), int(q.progress[i]) if q else 0, n])
	return out


func _objectives_done(qid: String) -> bool:
	var q: Dictionary = profile.quests[qid]
	var objs: Array = tpl("quests", qid).get("objectives", [])
	for i in objs.size():
		var o: Dictionary = objs[i]
		var n := int(o.get("count", 1))
		var have := item_count(o.item_id) if o.has("item_id") else int(q.progress[i])
		if have < n:
			return false
	return true


func _refresh_quests() -> void:
	for qid in profile.quests:
		var q: Dictionary = profile.quests[qid]
		if q.state in ["active", "complete"]:
			var st := "complete" if _objectives_done(qid) else "active"
			if st != q.state:
				q.state = st
				if st == "complete":
					notice.emit("Quête terminée : %s — retournez voir son donneur" % tpl("quests", qid).get("name", qid))
				quest_changed.emit(qid)


func turn_in_quest(qid: String) -> void:
	if quest_state(qid) != "complete":
		return
	var t := tpl("quests", qid)
	for o in t.get("objectives", []):
		if o.get("type") == "deliver_item":
			profile.inventory[o.item_id] = item_count(o.item_id) - int(o.count)
			if profile.inventory[o.item_id] <= 0:
				profile.inventory.erase(o.item_id)
	profile.quests[qid].state = "turned_in"
	var rw: Dictionary = t.get("rewards", {})
	add_gold(int(rw.get("gold", 0)))
	for it in rw.get("items", []):
		add_item(it.item_id, int(it.get("quantity", 1)))
	gain_xp(int(rw.get("xp", 0)))
	notice.emit("Quête rendue : %s (+%d XP, +%d or)" % [t.get("name", qid), int(rw.get("xp", 0)), int(rw.get("gold", 0))])
	check_unlocks()
	quest_changed.emit(qid)
	save()


# --------------------------------------------------------------------------- sauvegarde
func save() -> void:
	if not persist:
		return
	profile.hp = fighter.hp
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profile))


func _load() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (d is Dictionary) or int(d.get("version", 0)) != SAVE_VERSION:
		return false                              # (migrations : à ajouter ici quand la version change)
	profile = d
	for k in ["professions", "gathers", "equipment", "visited", "titles", "notes"]:          # sauvegardes plus anciennes
		if not profile.has(k):
			profile[k] = [] if k in ["visited", "titles"] else {}
	if not profile.has("title"):
		profile.title = ""
	if not profile.has("tutorial"):            # partie commencée avant l'accueil : on ne la refait pas
		profile.tutorial = {"step": TUTORIAL.size(), "seen": {}, "kills_at_step": 0}
	profile.level = int(profile.level)
	profile.unspent = int(profile.unspent)
	for k in profile.alloc:
		profile.alloc[k] = int(profile.alloc[k])
	recompute_stats(true)
	fighter.hp = clampf(float(d.get("hp", fighter.max_hp())), 1.0, fighter.max_hp())
	check_unlocks(false)
	return true


# --------------------------------------------------------------------------- zones
func zone_path(zone_id: String) -> String:
	return "res://scenes/zones/%s/%s.tscn" % [floor_id, zone_id]


func has_zone(zone_id: String) -> bool:
	return ResourceLoader.exists(zone_path(zone_id))


func is_travelling() -> bool:
	return _busy


func enter_zone(zone_id: String, type: String) -> void:
	current_zone = zone_id
	zone_type = type
	if not zone_id in profile.visited:
		profile.visited.append(zone_id)
	zone_changed.emit(zone_id)
	tutorial_check()


## Fondu au noir, changement de scène, fondu retour. La nouvelle zone place le joueur
## à la sortie qui mène vers `arrival` (par défaut la zone quittée ; "" = point d'apparition).
func travel(from_zone: String, to_zone: String, arrival = null) -> void:
	if _busy or not has_zone(to_zone):
		return
	_busy = true
	arrival_from = from_zone if arrival == null else arrival
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file(zone_path(to_zone))
	await get_tree().process_frame
	await get_tree().process_frame
	save()
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.35)
	await tw2.finished
	_busy = false
