class_name QuestGuide
## Suivi de quête : où aller pour la prochaine étape d'une quête, même dans une autre zone.
##
## Index du monde lu une fois dans data/build/*.build.json : donneurs de quêtes, bêtes, ressources
## et sorties de chaque zone. step() renvoie la cible de l'étape en cours :
##   {zone, spec, exit, text}  — spec : "<entry_id>" (PNJ), "mob:<monster_id>", "res:<resource_id>" ;
##   exit : la sortie de la zone actuelle à prendre si la cible est ailleurs ("" sinon).

static var _index: Dictionary = {}        # zone_id -> {name, exits[], givers{qid: entry}, names{entry: nom}, mobs{}, res{}}


static func index() -> Dictionary:
	if not _index.is_empty():
		return _index
	var dir := DirAccess.open("res://data/build")
	if dir == null:
		return _index
	for f in dir.get_files():
		if not f.ends_with(".build.json"):
			continue
		var b = JSON.parse_string(FileAccess.get_file_as_string("res://data/build/" + f))
		if not b is Dictionary:
			continue
		var z := {"name": b.get("name", ""), "exits": [], "givers": {}, "names": {}, "mobs": {}, "res": {}}
		for e in b.get("exits", []):
			z.exits.append({"id": e.id, "to": e.to, "hidden": bool(e.get("hidden", false))})
		for it in b.get("interactables", []):
			if it.has("mob"):
				z.mobs[it.template_id] = str(it.mob.get("temper", "calm"))
			elif it.has("resource"):
				z.res[it.template_id] = true
			else:
				z.names[it.entry_id] = it.name
				for q in it.get("quests", []):
					z.givers[q.quest_id] = it.entry_id
		_index[b.zone_id] = z
	return _index


## Nombre de passages de `from` à `to` (sorties non secrètes), et la première sortie à prendre.
static func route(from: String, to: String) -> Dictionary:
	var idx := index()
	if from == to:
		return {"hops": 0, "exit": ""}
	var seen := {from: true}
	var queue := []
	for e in idx.get(from, {}).get("exits", []):
		if not e.hidden and idx.has(e.to) and not seen.has(e.to):
			seen[e.to] = true
			queue.append([e.to, e.id, 1])
	while not queue.is_empty():
		var cur: Array = queue.pop_front()
		if cur[0] == to:
			return {"hops": cur[2], "exit": cur[1]}
		for e in idx[cur[0]].exits:
			if not e.hidden and idx.has(e.to) and not seen.has(e.to):
				seen[e.to] = true
				queue.append([e.to, cur[1], cur[2] + 1])
	return {"hops": -1, "exit": ""}


## Zone la plus proche (en passages) parmi celles qui vérifient `has`.
static func _nearest_zone(from: String, has: Callable) -> String:
	var best := ""
	var best_h := 999
	for zid in index():
		if not has.call(index()[zid]):
			continue
		var h: int = route(from, zid).hops
		if h >= 0 and h < best_h:
			best_h = h
			best = zid
	return best


static func giver_zone(qid: String) -> String:
	for zid in index():
		if index()[zid].givers.has(qid):
			return zid
	return ""


## Prochaine étape de la quête `qid`, vue depuis la zone `here`. Vide si rien à montrer.
static func step(gs: Node, qid: String, here: String) -> Dictionary:
	var st: String = gs.quest_state(qid)
	if st == "" or st == "turned_in":
		return {}
	var t: Dictionary = gs.tpl("quests", qid)
	var spec := ""
	var text := ""
	var zone := ""
	if st == "complete":
		zone = giver_zone(qid)
		spec = index().get(zone, {}).get("givers", {}).get(qid, "")
		text = "Rendre à %s" % index().get(zone, {}).get("names", {}).get(spec, "son donneur")
	else:
		var q: Dictionary = gs.profile.quests[qid]
		var objs: Array = t.get("objectives", [])
		var lines: Array = gs.quest_progress_text(qid)
		for i in objs.size():
			var o: Dictionary = objs[i]
			var n := int(o.get("count", 1))
			var have: int = int(gs.item_count(o.item_id)) if o.has("item_id") else int(q.progress[i])
			if have >= n and o.get("type") != "level":
				continue
			text = str(lines[i]) if i < lines.size() else ""
			match o.get("type"):
				"kill_count":
					spec = "mob:" + o.monster_id
					zone = _nearest_zone(here, func(z): return z.mobs.has(o.monster_id))
				"gather_count":
					spec = "res:" + o.resource_id
					zone = _nearest_zone(here, func(z): return z.res.has(o.resource_id))
				"deliver_item", "gather_item":
					var src := _item_source(gs, o.item_id, here)
					spec = src.spec
					zone = src.zone
				"level":
					text = "Atteindre le niveau %d" % int(o.get("level", o.get("count", 1)))
			if spec != "" or text != "":
				break
	if zone == "":
		return {"zone": "", "spec": "", "exit": "", "text": text}
	var r := route(here, zone)
	return {"zone": zone, "spec": spec, "exit": r.exit, "text": text,
		"where": "" if zone == here else str(index()[zone].name)}


## D'où vient un objet : une ressource qui le donne, sinon une bête qui le laisse.
static func _item_source(gs: Node, item_id: String, here: String) -> Dictionary:
	var best := {"spec": "", "zone": ""}
	var best_h := 999
	for zid in index():
		var h: int = route(here, zid).hops
		if h < 0 or h >= best_h:
			continue
		var z: Dictionary = index()[zid]
		for rid in z.res:
			for y in gs.tpl("resources", rid).get("yields", []):
				if y.get("item_id") == item_id:
					best = {"spec": "res:" + rid, "zone": zid}
					best_h = h
		if best.zone == zid:
			continue
		for mid in z.mobs:
			for l in gs.tpl("monsters", mid).get("loot_table", []):
				if l.get("item_id") == item_id and float(l.get("chance", 1.0)) >= 0.05:
					best = {"spec": "mob:" + mid, "zone": zid}
					best_h = h
	return best
