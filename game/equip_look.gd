class_name EquipLook
## Apparence d'un équipement sur le joueur : sa forme (quel calque de tools/art/equipment_layers.py)
## et sa matière (3 couleurs). La matière se lit d'abord dans le nom de l'objet, puis dans sa
## description (un objet crafté dit de quoi il est fait), sinon dans les couleurs de son icône.

const PATH := "res://assets/art/characters/player/equip/%s.png"

## Matières : mots-clés (début de mot ; mot exact pour les mots courts ou préfixés « = », ex. « cuir »
## pour ne pas prendre une cuirasse pour du cuir) -> clair, moyen, sombre.
const MATERIALS := [
	[["or", "doré", "dorée", "aube", "ambre", "soleil", "lumière", "miel"], ["fff4d6", "f5b84a", "d9822b"]],
	[["rune", "runique", "architecte", "mécanisme", "verre", "cristal"], ["b8fff0", "5ae8e0", "2aa8c0"]],
	[["écaille", "nacre", "ciré", "eau", "rive", "lac", "pêcheur", "poisson"], ["8fd8d0", "52aab8", "347a98"]],
	[["fer", "acier", "métal", "heaume", "alliage"], ["ece2cf", "c4b59c", "665c55"]],
	[["pierre", "galet", "roche", "colonne", "gardien", "gantelet"], ["c4b59c", "948672", "665c55"]],
	[["os", "croc", "dent", "corne", "ivoire", "défense", "griffe", "ramure"], ["fff4d6", "f0d29a", "948672"]],
	[["écorce", "bois", "branche", "chêne", "racine"], ["d4a265", "a8743f", "7a5030"]],
	[["ronce", "feuille", "mousse", "lierre"], ["a8c84e", "74a843", "4a8040"]],
	[["=cuir", "peau", "fourrure", "poil", "traqueuse", "traqueur"], ["d4a265", "a8743f", "4f3324"]],
	[["lin", "étoffe", "fibre", "roseau", "toile", "laine", "ravaudeur", "passeuse", "tissu"], ["f0d29a", "d4a265", "a8743f"]],
	[["sombre", "ombre", "nuit", "noir", "noirci"], ["7a5878", "4a3450", "433c42"]],
	[["sang", "rouge", "braise", "feu", "rubis"], ["e05a48", "a83a40", "6a2a44"]],
	[["pâle", "lynx", "cerf", "neige", "blanc"], ["ece2cf", "c4b59c", "948672"]],
]

static var _ramps := {}


## Forme du calque pour un emplacement : "weapon_lame", "head_capuche", "chest_plastron", "gloves"…
static func shape(slot: String, t: Dictionary) -> String:
	var name := str(t.get("name", "")).to_lower()
	match slot:
		"weapon":
			var eq: Dictionary = t.get("equipment", {})
			var st := str(eq.get("weapon_style", ""))
			if st in ["dague", "lame", "hachette", "masse", "lance"]:
				return "weapon_" + st
			var a: Dictionary = eq.get("area", {})
			if a.get("shape") == "line":
				return "weapon_lance"
			var ang := float(a.get("angle", 110))
			if ang >= 150:
				return "weapon_masse"
			if ang >= 125:
				return "weapon_hachette"
			return "weapon_dague" if float(a.get("range", 30)) <= 26 else "weapon_lame"
		"head":
			for k in ["capuche", "chaperon", "cape", "cagoule"]:
				if k in name:
					return "head_capuche"
			for k in ["couronne", "diadème", "bandeau", "cercle", "tiare"]:
				if k in name:
					return "head_diademe"
			return "head_casque"
		"chest":
			for k in ["plastron", "cuirasse", "armure", "cotte", "écaille", "écorce", "carapace", "cœur"]:
				if k in name:
					return "chest_plastron"
			return "chest_tunique"
		"gloves":
			return "gloves"
		"boots":
			return "boots"
	return ""


static func texture(shape_id: String) -> Texture2D:
	var p := PATH % shape_id
	return load(p) if ResourceLoader.exists(p) else null


## Trois couleurs (clair, moyen, sombre) pour la matière de l'objet.
static func ramp(item_id: String, t: Dictionary, icon: Texture2D) -> Array:
	var base := item_id.get_slice("~", 0)
	if _ramps.has(base):
		return _ramps[base]
	var r := _from_words(str(t.get("name", "")))
	if r.is_empty():
		r = _from_words(str(t.get("description", "")))
	if r.is_empty():
		r = _from_icon(icon)
	_ramps[base] = r
	return r


static func _words(text: String) -> PackedStringArray:
	var s := text.to_lower()
	for ch in ["'", "’", ",", ".", ";", ":", "!", "?", "(", ")", "«", "»", "-"]:
		s = s.replace(ch, " ")
	return s.split(" ", false)


static func _from_words(text: String) -> Array:
	for w in _words(text):                       # le premier mot de matière rencontré l'emporte
		for m in MATERIALS:
			for k in m[0]:
				var exact: bool = k.begins_with("=") or k.length() <= 3
				var kk: String = k.trim_prefix("=")
				if (w == kk) if exact else w.begins_with(kk):
					return (m[1] as Array).map(func(h): return Color(h))
	return []


## Couleurs dominantes de l'icône : clair, moyen et sombre parmi les pixels qui ne sont pas du contour.
static func _from_icon(icon: Texture2D) -> Array:
	var fallback := [Color("ece2cf"), Color("c4b59c"), Color("665c55")]
	if icon == null:
		return fallback
	var img := icon.get_image()
	if img == null:
		return fallback
	if img.is_compressed():
		img.decompress()
	var cols := []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.get_luminance() > 0.18:
				cols.append(c)
	if cols.size() < 3:
		return fallback
	cols.sort_custom(func(a, b): return a.get_luminance() > b.get_luminance())
	return [cols[int(cols.size() * 0.15)], cols[int(cols.size() * 0.5)], cols[int(cols.size() * 0.85)]]
