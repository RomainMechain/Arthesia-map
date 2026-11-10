class_name SkillFx
extends Node2D
## Animations propres aux compétences. Chacune suit sa description et son origine, et plus une
## compétence est rare (difficile à obtenir), plus sa séquence est longue et chargée :
##
## Communes (niveau, premières bêtes) : un geste, une trace, un impact.
##  frappe             « un coup franc, de toute sa force » : élan, croissant épais, poussière.
##  trait_de_lumiere   « un éclat tiré de l'aube, lancé de la main » : la paume se charge, trait, étoile.
##  croc_dore          « la morsure des loups : vite, sans élan » : bond court, mâchoires ambrées.
##  premiers_soins     « quelques gestes sûrs » : bande de lin, lueur chaude, respiration.
##  coup_puissant      « préparé une fraction de seconde de trop, mais qui porte » : long élan, coup
##                     énorme (les dégâts partent avec le coup), fissures au sol, gel d'image.
##  eclat_d_aube       « la lumière se concentre dans la paume, puis éclate » : boule qui grossit, file,
##                     explose en anneau et rayons.
##  lame_d_aube        « une lame enveloppée de lumière » : l'arme balaie avec des reflets dorés.
##  carapace_des_galets « une carapace qui n'existe pas » : des galets se referment en dôme, qui reste
##                     visible tant que le bouclier tient ; les coups y glissent en étincelles.
## Peu communes (dizaines de bêtes, quêtes) : plusieurs temps, effet qui reste sur la cible.
##  bond_du_lynx       « surgir de la lumière » : on s'efface, bond réel en avant, images rémanentes, griffes.
##  chant_du_fond      « une note sourde qui ébranle et ralentit » : ondes, gouttes qui montent ;
##                     les bêtes touchées gardent des ondes à leurs pieds tant qu'elles sont ralenties.
##  estoc_runique      « une rune au bout de la lame, coup bref » : la rune s'allume, estoc, elle éclate.
##  rune_de_rupture    « tracée sur l'ennemi, fend ses défenses » : rune dessinée sur la bête, fissures,
##                     éclats de pierre ; une rune fêlée flotte au-dessus d'elle tant que ça dure.
##  rune_tranchante    « un tranchant de bronze guidé par un éclair » : arc de bronze et éclair qui le suit.
##  secousse_du_colosse « frapper le sol de tout son poids, lentement » : on se dresse, on s'abat, onde
##                     de choc, fissures, mottes de mousse, forte secousse.
##  seve_des_fougeres  « la sève immobile dans tes blessures » : des fougères se déroulent, la sève monte.
##  toile_doree        « un fil de lumière qui s'enroule » : le fil part en courbe, s'enroule, reste.
## Rares (fin d'étage) : mise en scène.
##  lame_des_consignes « frapper juste, au rythme du cercle » : cercle de runes qui bat trois temps, puis
##                     une coupe nette, gel d'image, éclair blanc.
##  lumiere_figee      « arrêter la lumière autour de toi » : le temps ralentit, la lumière se fige en
##                     grains immobiles, qui se collent au corps en armure de facettes (visible tant
##                     que le bouclier tient).
## Légendaire :
##  verdict_du_heraut  « un cercle de lumière qui s'abat sans appel » : l'écran s'assombrit, le cercle du
##                     Héraut se trace au sol, une colonne de lumière tombe du ciel, éclair blanc, onde,
##                     plumes de lumière, cercle brûlé.
## Passives (au déclenchement) : peau d'ambre (coup reçu englué), instinct de traqueuse (esquive),
## matin d'Halvard (tenir encore un instant), mains de ravaudeur (récolte), patience du pêcheur (immobile).
##
## Purement visuel : dégâts, soins et boucliers sont réglés par le joueur (player.gd) et les règles.
## Seul `impact_delay` décale le moment où le coup porte, pour qu'il tombe avec l'animation.

const KINDS := ["frappe", "trait_de_lumiere", "croc_dore", "premiers_soins", "coup_puissant", "eclat_d_aube",
	"lame_d_aube", "carapace_des_galets", "bond_du_lynx", "chant_du_fond", "estoc_runique", "rune_de_rupture",
	"rune_tranchante", "secousse_du_colosse", "seve_des_fougeres", "toile_doree", "lame_des_consignes",
	"lumiere_figee", "verdict_du_heraut"]
## Rareté : 1 commune, 2 peu commune, 3 rare, 4 légendaire (déduite de la difficulté du déblocage).
const TIER := {"frappe": 1, "trait_de_lumiere": 1, "croc_dore": 1, "premiers_soins": 1, "coup_puissant": 1,
	"eclat_d_aube": 1, "lame_d_aube": 1, "carapace_des_galets": 1, "mains_de_ravaudeur": 1, "patience_du_pecheur": 1,
	"bond_du_lynx": 2, "chant_du_fond": 2, "estoc_runique": 2, "rune_de_rupture": 2, "rune_tranchante": 2,
	"secousse_du_colosse": 2, "seve_des_fougeres": 2, "toile_doree": 2, "instinct_de_traqueuse": 2, "peau_d_ambre": 2,
	"matin_d_halvard": 3, "lame_des_consignes": 3, "lumiere_figee": 3, "verdict_du_heraut": 4}
const TIER_NAMES := ["", "commune", "peu commune", "rare", "légendaire"]
const TIER_COLORS := ["", "7a5030", "4a8040", "2a7ea8", "c8782a"]
## Le coup porte avec l'animation, pas au moment de l'appui.
const IMPACT_DELAY := {"coup_puissant": 0.18, "bond_du_lynx": 0.15, "rune_de_rupture": 0.45, "secousse_du_colosse": 0.32,
	"toile_doree": 0.18, "lame_des_consignes": 0.47, "verdict_du_heraut": 0.75}

const OUTLINE := Color("2a1a2e")
const GOLD := Color("ffe08a")
const CREAM := Color("fff4d6")
const AMBER := Color("f5b84a")
const AMBER_DARK := Color("c8782a")
const LINEN := Color("f4ead0")
const LINEN_SEAM := Color("c8a878")
const WARM := Color("ffd890")
const LEAF := Color("c8d870")
const FERN := Color("a8c84e")
const FERN_DARK := Color("5a8a3a")
const RUNE := Color("7fe8e0")             # le cyan reste réservé aux runes des Architectes
const RUNE_DARK := Color("2a9ea0")
const BRONZE := Color("c8883a")
const BRONZE_DARK := Color("7a4a24")
const WATER := Color("52aab8")
const WATER_PALE := Color("a8e0e0")
const STONE := Color("9a8e80")
const STONE_DARK := Color("5a5048")
const PALE := Color("f0f4f8")
const DIRT := Color("b08860")

var kind := ""
var dir := Vector2.RIGHT
var area: Dictionary = {}
var life := 0.3
var reach := 0.0                       # trait / éclat : distance jusqu'à la première bête touchée
var hit := false
var tpos := Vector2.ZERO               # point visé (bête touchée, sinon devant soi), en local
var seed := 0
var tex: Texture2D                     # arme portée
var target: Node2D                     # effet qui reste : la bête (ou le joueur) qui le porte
var _t := 0.0
var _gone := 0.0                       # effet qui reste : fondu de sortie


static func has(sid: String) -> bool:
	return sid in KINDS


static func tier(sid: String) -> int:
	return int(TIER.get(sid, 1))


static func impact_delay(sid: String) -> float:
	return float(IMPACT_DELAY.get(sid, 0.0))


# --------------------------------------------------------------------------- lancement
static func _new(k: String, d: Vector2, ar: Dictionary, lf: float) -> Node2D:
	var n: Node2D = (load("res://game/combat/skill_fx.gd") as GDScript).new()
	n.kind = k
	n.dir = d
	n.area = ar
	n.life = lf
	n.seed = randi()
	return n


## Effet posé dans le monde à `pos`, devant les bêtes (ou au sol si `ground`).
static func _spawn(zone: Node, n: Node2D, pos: Vector2, ground := false) -> Node2D:
	n.global_position = pos
	n.z_index = 0 if ground else 20
	var host: Node = zone.get("_ground") if ground and zone.get("_ground") else zone._fx
	host.add_child(n)
	n.global_position = pos
	return n


## Effet qui suit un nœud (le joueur, une bête).
static func _attach(host: Node2D, n: Node2D, local := Vector2.ZERO, z := 2) -> Node2D:
	n.position = local
	n.z_index = z
	n.target = host
	host.add_child(n)
	return n


static func _later(node: Node, sec: float, cb: Callable) -> void:
	node.get_tree().create_timer(sec).timeout.connect(func():
		if is_instance_valid(node):
			cb.call())


## Voile coloré plein écran (assombrir, éclair blanc) : sous l'interface.
static func _veil(node: Node, col: Color, peak: float, t_in: float, hold: float, t_out: float) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 3
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(col, 0.0)
	cl.add_child(r)
	node.get_tree().current_scene.add_child(cl)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", peak, t_in)
	tw.tween_interval(hold)
	tw.tween_property(r, "color:a", 0.0, t_out)
	tw.tween_callback(cl.queue_free)


## Ralenti bref (temps réel), puis retour à la normale par GameState.
static func _slow(node: Node, scale: float, real_sec: float) -> void:
	var gs := node.get_node_or_null("/root/GameState")
	if gs == null:
		return
	Engine.time_scale = scale
	node.get_tree().create_timer(real_sec, true, false, true).timeout.connect(gs.restore_time_scale, CONNECT_ONE_SHOT)


## Image rémanente du joueur à `pos` (bond, esquive).
static func _ghost(zone: Node, player: Node2D, pos: Vector2, col: Color, sec: float) -> void:
	var src: Sprite2D = player.sprite
	var g := Sprite2D.new()
	g.texture = src.texture
	g.hframes = src.hframes
	g.vframes = src.vframes
	g.frame = src.frame
	g.flip_h = src.flip_h
	g.centered = src.centered
	g.offset = src.offset
	g.modulate = Color(col.r * 0.75, col.g * 0.75, col.b * 0.8, col.a)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD           # une image de lumière, pas d'ombre
	g.material = mat
	g.z_index = 19
	zone._fx.add_child(g)
	g.global_position = pos + src.position
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, sec)
	tw.tween_callback(g.queue_free)


## Lance l'animation de `sid` depuis le joueur, dans la direction `d`. `hits` : bêtes visées.
static func play(sid: String, player: Node2D, zone: Node, ar: Dictionary, d: Vector2, hits: Array) -> void:
	if zone == null or zone.get("_fx") == null:
		return
	var origin: Vector2 = player.global_position + Vector2(0, -8)
	var first: Node2D = hits[0] if not hits.is_empty() else null
	var aim_pt: Vector2 = (first.global_position + Vector2(0, -8)) if first else origin + d * maxf(16.0, float(ar.get("range", 22)) * 0.75)
	var gs := player.get_node_or_null("/root/GameState")
	var wtex: Texture2D = null
	if gs and gs.equipped("weapon") != "":
		wtex = UISkin.item_icon(gs.equipped("weapon"))
	var n: Node2D
	match sid:
		# ------------------------------------------------------------ communes
		"frappe":
			Sfx.play("sk_frappe", -4.0)
			player.pose(-d * 2.0, Vector2(1.06, 0.94), 0.05, 0.0)               # élan
			_later(player, 0.05, func(): player.pose(d * 4.0, Vector2(0.95, 1.05), 0.05, 0.16))
			_later(player, 0.12, func():
				player.shake(1.6, 0.14)
				zone.burst(player.global_position + d * float(ar.get("range", 26)) * 0.7 + Vector2(0, 2), Color("d8b880"), 9, 26.0, false))
			_spawn(zone, _new(sid, d, ar, 0.34), origin)
		"trait_de_lumiere":
			Sfx.play("sk_trait", -4.0)
			n = _new(sid, d, ar, 0.5)
			n.reach = float(ar.get("range", 112))
			n.hit = first != null
			if first:
				n.reach = clampf((aim_pt - origin).dot(d), 8.0, n.reach)
			player.pose(d * 1.5, Vector2.ONE, 0.06, 0.18)                        # la main se tend
			_spawn(zone, n, origin)
		"croc_dore":
			Sfx.play("sk_croc", -3.0)
			player.pose(d * 6.0, Vector2(1.04, 0.97), 0.04, 0.12)                # bond court, sans élan
			_later(player, 0.08, func():
				player.shake(1.0, 0.08)
				zone.burst(origin + d * float(ar.get("range", 26)) * 0.62 + Vector2(0, -6), AMBER, 8, 30.0, false))
			_spawn(zone, _new(sid, d, ar, 0.26), origin)
		"premiers_soins":
			Sfx.play("sk_soins", -5.0)
			player.pose(Vector2(0, 1), Vector2(1.05, 0.92), 0.15, 0.35)          # on se ramasse…
			_later(player, 0.6, func(): player.pose(Vector2.ZERO, Vector2(0.98, 1.04), 0.2, 0.25))   # … on respire
			_attach(player, _new(sid, d, ar, 1.1))
		"coup_puissant":
			Sfx.play("sk_lourd", -3.0)
			player.pose(-d * 3.0 + Vector2(0, -1), Vector2(1.08, 0.92), 0.16, 0.0)   # trop d'élan…
			_later(player, 0.18, func(): player.pose(d * 5.0, Vector2(0.93, 1.07), 0.05, 0.22))
			_later(player, 0.24, func():
				player.shake(2.2, 0.18)
				zone.burst(player.global_position + d * 22.0 + Vector2(0, 2), Color("d8b880"), 14, 34.0, false)
				if first:
					zone.hitstop())
			_spawn(zone, _new(sid, d, ar, 0.6), origin)
			_spawn(zone, _new("coup_puissant_sol", d, ar, 0.9), player.global_position + d * 22.0 + Vector2(0, 1), true)
		"eclat_d_aube":
			Sfx.play("sk_eclat", -4.0)
			n = _new(sid, d, ar, 0.65)
			n.reach = float(ar.get("range", 88))
			n.hit = first != null
			if first:
				n.reach = clampf((aim_pt - origin).dot(d), 8.0, n.reach)
			player.pose(d * 1.0, Vector2(0.98, 1.02), 0.12, 0.0)
			_later(player, 0.14, func(): player.pose(d * 2.5, Vector2.ONE, 0.04, 0.2))
			_spawn(zone, n, origin)
		"lame_d_aube":
			Sfx.play("sk_lame", -4.0)
			n = _new(sid, d, ar, 0.4)
			n.tex = wtex
			player.pose(d * 3.0, Vector2(0.96, 1.04), 0.06, 0.18)
			_spawn(zone, n, origin)
		"carapace_des_galets":
			Sfx.play("sk_carapace", -3.0)
			player.pose(Vector2(0, 1), Vector2(1.08, 0.88), 0.08, 0.0)            # on se ramasse
			_later(player, 0.45, func(): player.pose(Vector2.ZERO, Vector2.ONE, 0.0, 0.3))
			_attach(player, _new(sid, d, ar, 0.6), Vector2.ZERO, 3)
			_attach(player, _new("linger_carapace", d, ar, 8.5), Vector2.ZERO, 3)
		# ------------------------------------------------------------ peu communes
		"bond_du_lynx":
			Sfx.play("sk_lynx", -3.0)
			var start: Vector2 = player.global_position
			var tw := player.create_tween()
			tw.tween_property(player.sprite, "modulate:a", 0.12, 0.1)            # on s'efface dans la lumière
			_later(player, 0.02, func(): zone.burst(start + Vector2(0, -10), PALE, 8, 14.0, true, Vector2(6, 9)))
			_later(player, 0.14, func():
				var from: Vector2 = player.global_position
				player.move_and_collide(d * 20.0)                                 # le bond, pour de vrai
				var to: Vector2 = player.global_position
				for i in 3:
					_ghost(zone, player, from.lerp(to, i / 3.0), Color(PALE, 0.55 - i * 0.12), 0.3)
				player.sprite.modulate.a = 1.0
				player.pose(d * 3.0, Vector2(0.94, 1.06), 0.03, 0.16)
				player.shake(1.3, 0.1)
				_spawn(zone, _new(sid, d, ar, 0.36), to + Vector2(0, -8) + d * 12.0)
				if not hits.is_empty():
					zone.hitstop())
		"chant_du_fond":
			Sfx.play("sk_chant", -2.0)
			player.pose(Vector2(0, -1), Vector2(0.97, 1.04), 0.2, 0.5)
			player.shake(0.7, 0.6)
			_spawn(zone, _new(sid, d, ar, 1.1), origin)
			_spawn(zone, _new("chant_sol", d, ar, 1.1), player.global_position, true)
			for m in hits:
				_attach(m, _new("linger_chant", d, ar, 10.0), Vector2.ZERO, 1)
		"estoc_runique":
			Sfx.play("sk_estoc", -3.0)
			player.pose(-d * 2.0, Vector2(1.03, 0.97), 0.09, 0.0)
			_later(player, 0.11, func(): player.pose(d * 6.0, Vector2(0.95, 1.05), 0.04, 0.16))
			n = _new(sid, d, ar, 0.5)
			n.tex = wtex
			_spawn(zone, n, origin)
		"rune_de_rupture":
			Sfx.play("sk_rupture", -3.0)
			player.pose(d * 1.5, Vector2.ONE, 0.1, 0.5)
			n = _new(sid, d, ar, 0.95)
			_spawn(zone, n, aim_pt + Vector2(0, -4))
			_later(player, 0.45, func(): player.shake(1.6, 0.14))
			for m in hits:
				_later(player, 0.5, func(): if is_instance_valid(m): _attach(m, _new("linger_rupture", d, ar, 12.0), Vector2(0, -8), 20))
		"rune_tranchante":
			Sfx.play("sk_tranchante", -3.0)
			player.pose(-d * 1.5, Vector2(1.04, 0.96), 0.05, 0.0)
			_later(player, 0.06, func(): player.pose(d * 4.0, Vector2(0.95, 1.05), 0.05, 0.16))
			_later(player, 0.13, func(): player.shake(1.4, 0.12))
			n = _new(sid, d, ar, 0.45)
			_spawn(zone, n, origin)
		"secousse_du_colosse":
			Sfx.play("sk_secousse", -2.0)
			player.pose(Vector2(0, -4), Vector2(0.95, 1.09), 0.28, 0.0)          # on se dresse, lentement
			_later(player, 0.06, func(): zone.burst(player.global_position + Vector2(0, -14), FERN_DARK, 6, 8.0, false, Vector2(6, 6)))
			_later(player, 0.3, func(): player.pose(Vector2(0, 2) + d * 2.0, Vector2(1.14, 0.84), 0.04, 0.35))
			var at: Vector2 = player.global_position + d * 14.0
			_later(player, 0.33, func():
				player.shake(3.2, 0.35)
				zone.burst(at, DIRT, 16, 42.0, false)
				zone.burst(at, FERN_DARK, 8, 36.0, false)
				if not hits.is_empty():
					zone.hitstop())
			_spawn(zone, _new(sid, d, ar, 1.0), at + Vector2(0, -8))
			_spawn(zone, _new("secousse_sol", d, ar, 1.4), at, true)
		"seve_des_fougeres":
			Sfx.play("sk_seve", -4.0)
			player.pose(Vector2.ZERO, Vector2(1.02, 0.98), 0.3, 0.8)
			_attach(player, _new(sid, d, ar, 1.5), Vector2.ZERO, 2)
		"toile_doree":
			Sfx.play("sk_toile", -3.0)
			player.pose(d * 2.0, Vector2(0.98, 1.02), 0.08, 0.25)                # le geste du lancer
			n = _new(sid, d, ar, 0.85)
			n.tpos = aim_pt - origin
			_spawn(zone, n, origin)
			for m in hits:
				_later(player, 0.5, func(): if is_instance_valid(m): _attach(m, _new("linger_toile", d, ar, 10.0), Vector2(0, -8), 20))
		# ------------------------------------------------------------ rares
		"lame_des_consignes":
			Sfx.play("sk_consignes", -2.0)
			for i in 3:                                                             # trois temps
				_later(player, i * 0.15, func(): player.pose(Vector2.ZERO, Vector2(1.03, 0.97), 0.03, 0.08))
			_later(player, 0.45, func():
				player.pose(d * 6.0, Vector2(0.93, 1.07), 0.03, 0.22)
				player.shake(1.8, 0.16)
				_veil(player, CREAM, 0.22, 0.02, 0.03, 0.18)
				if not hits.is_empty():
					zone.hitstop())
			n = _new(sid, d, ar, 1.05)
			n.tpos = aim_pt - origin
			_spawn(zone, n, origin)
		"lumiere_figee":
			Sfx.play("sk_figee", -2.0)
			_slow(player, 0.35, 0.4)                                                # le temps se fige
			_veil(player, Color("fff0c0"), 0.28, 0.06, 0.3, 0.5)
			player.pose(Vector2(0, -1), Vector2.ONE, 0.1, 0.0)
			_later(player, 0.75, func(): player.pose(Vector2.ZERO, Vector2.ONE, 0.0, 0.2))
			_attach(player, _new(sid, d, ar, 1.3), Vector2.ZERO, 3)
			_attach(player, _new("linger_figee", d, ar, 10.5), Vector2.ZERO, 3)
		# ------------------------------------------------------------ légendaire
		"verdict_du_heraut":
			Sfx.play("sk_verdict", 0.0)
			_veil(player, Color("140a18"), 0.4, 0.45, 0.3, 0.25)                    # l'écran s'assombrit
			_later(player, 0.74, func(): _veil(player, CREAM, 0.5, 0.02, 0.02, 0.22))    # éclair blanc
			player.pose(Vector2(0, -3), Vector2(0.95, 1.08), 0.2, 0.0)              # la main se lève
			_later(player, 0.75, func():
				player.pose(Vector2(0, 1), Vector2(1.06, 0.94), 0.04, 0.4)
				player.shake(4.0, 0.45)
				if not hits.is_empty():
					zone.hitstop())
			var ground: Vector2 = aim_pt + Vector2(0, 8)
			_attach(player, _new("verdict_halo", d, ar, 0.8), Vector2(0, -26), 3)
			_spawn(zone, _new("verdict_sol", d, ar, 2.4), ground, true)
			n = _new(sid, d, ar, 2.2)
			_spawn(zone, n, ground)
		_:
			return


## Passives, au moment où elles jouent.
static func passive(pid: String, player: Node2D, zone: Node, extra := {}) -> void:
	if zone == null or zone.get("_fx") == null:
		return
	match pid:
		"peau_d_ambre":                                        # le coup s'englue dans la résine
			Sfx.play("pv_ambre", -8.0)
			var n := _new(pid, Vector2.RIGHT, {}, 0.5)
			n.tpos = (extra.get("from", player.global_position) - player.global_position).normalized() * 6.0
			_attach(player, n, Vector2(0, -10), 3)
		"instinct_de_traqueuse":                               # plus vif que la bête : on n'est déjà plus là
			Sfx.play("pv_instinct", -6.0)
			_ghost(zone, player, player.global_position, Color(PALE, 0.6), 0.35)
			_attach(player, _new(pid, Vector2.RIGHT, {}, 0.35), Vector2(0, -10), 3)
		"matin_d_halvard":                                     # tenir encore un instant
			Sfx.play("pv_halvard", -3.0)
			_slow(player, 0.5, 0.35)
			_veil(player, Color("ffd890"), 0.2, 0.1, 0.2, 0.6)
			zone.float_text(player.global_position + Vector2(0, -30), "Encore un instant…", Color("ffe08a"))
			_attach(player, _new(pid, Vector2.RIGHT, {}, 1.4), Vector2.ZERO, 1)
			_attach(player, _new("linger_halvard", Vector2.RIGHT, {}, 10.0), Vector2.ZERO, 3)
		"mains_de_ravaudeur":                                  # les doigts tressent sans y penser
			_attach(player, _new(pid, Vector2.RIGHT, {}, 0.7), Vector2(0, -8), 3)
		"patience_du_pecheur":                                 # le calme : des ronds dans l'eau, même sur l'herbe
			_spawn(zone, _new(pid, Vector2.RIGHT, {}, 2.0), player.global_position, true)


## Coup reçu sur un bouclier de compétence : il glisse (galets) ou se brise sur les facettes.
static func glance(player: Node2D, zone: Node, from: Vector2) -> void:
	if zone == null or zone.get("_fx") == null:
		return
	for c in player.get_children():
		if c.get("kind") in ["linger_carapace", "linger_figee", "linger_halvard"]:
			var col: Color = STONE if c.kind == "linger_carapace" else CREAM
			var side: Vector2 = (from - player.global_position).normalized()
			zone.burst(player.global_position + Vector2(0, -10) + side * 8.0, col, 7, 34.0, false)
			c.set("_flash_t", 0.15)
			return


var _flash_t := 0.0


func _process(delta: float) -> void:
	_t += delta
	_flash_t = maxf(0.0, _flash_t - delta)
	if kind.begins_with("linger"):
		var alive := is_instance_valid(target)
		if alive and target.has_method("is_alive"):
			alive = target.is_alive()
		elif alive and kind in ["linger_carapace", "linger_figee", "linger_halvard"]:
			alive = target.fighter.shield > 0.0
		if not alive or _t >= life:
			_gone += delta * 3.0
			if _gone >= 1.0:
				queue_free()
	elif _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	match kind:
		"frappe":
			_draw_frappe()
		"trait_de_lumiere":
			_draw_trait()
		"croc_dore":
			_draw_croc()
		"premiers_soins":
			_draw_soins()
		"coup_puissant":
			_draw_coup_puissant()
		"coup_puissant_sol":
			_draw_cracks(Vector2.ZERO, 0.24, 6, 16.0, DIRT.darkened(0.45))
		"eclat_d_aube":
			_draw_eclat()
		"lame_d_aube":
			_draw_lame()
		"carapace_des_galets":
			_draw_carapace()
		"linger_carapace":
			_draw_linger_carapace()
		"bond_du_lynx":
			_draw_lynx()
		"chant_du_fond":
			_draw_chant()
		"chant_sol":
			_draw_chant_sol()
		"linger_chant":
			_draw_linger_chant()
		"estoc_runique":
			_draw_estoc()
		"rune_de_rupture":
			_draw_rupture()
		"linger_rupture":
			_draw_linger_rupture()
		"rune_tranchante":
			_draw_tranchante()
		"secousse_du_colosse":
			_draw_secousse()
		"secousse_sol":
			_draw_secousse_sol()
		"seve_des_fougeres":
			_draw_seve()
		"toile_doree":
			_draw_toile()
		"linger_toile":
			_draw_linger_toile()
		"lame_des_consignes":
			_draw_consignes()
		"lumiere_figee":
			_draw_figee()
		"linger_figee", "linger_halvard":
			_draw_linger_facets()
		"verdict_halo":
			_draw_verdict_halo()
		"verdict_sol":
			_draw_verdict_sol()
		"verdict_du_heraut":
			_draw_verdict()
		"peau_d_ambre":
			_draw_ambre()
		"instinct_de_traqueuse":
			_draw_instinct()
		"matin_d_halvard":
			_draw_halvard()
		"mains_de_ravaudeur":
			_draw_mains()
		"patience_du_pecheur":
			_draw_patience()


# --------------------------------------------------------------------------- Frappe
## Croissant épais, plus large au bord qui avance ; il part après l'élan (0,05 s).
func _draw_frappe() -> void:
	var t := _t - 0.05
	if t < 0.0:                                         # élan : un éclat sur le fil de l'arme
		var g := dir.rotated(-1.2) * 10.0
		_star(g, 2.0 + _t * 40.0, Color(CREAM, 0.8))
		return
	var r := float(area.get("range", 26))
	var half := deg_to_rad(float(area.get("angle", 110)) / 2.0)
	var a := dir.angle()
	var k := clampf(t / 0.13, 0.0, 1.0)                 # balayage
	var fade := clampf(1.0 - (t - 0.1) / 0.19, 0.0, 1.0)
	var a0 := a - half
	var a1 := lerpf(a - half, a + half, ease(k, 0.5))
	var tail := maxf(a0, a1 - half * 1.6)
	_crescent(tail, a1, r * 1.0, 9.0, Color(OUTLINE, 0.6 * fade))
	_crescent(tail, a1, r * 0.95, 7.5, Color(GOLD, 0.95 * fade))
	_crescent(tail, a1, r * 0.95, 3.0, Color(CREAM, fade))
	if k >= 1.0:                                        # impact : l'arc « claque » en bout de course
		var tip := Vector2.from_angle(a + half * 0.6) * r * 0.85
		_star(tip, 3.0 + (t - 0.13) * 50.0, Color(CREAM, fade))


## Bande en arc de `from` à `to` (radians), d'épaisseur croissante vers `to`.
func _crescent(from: float, to: float, radius: float, thick: float, col: Color) -> void:
	if to - from < 0.02 or col.a <= 0.0:
		return
	var n := 14
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		var ang := lerpf(from, to, u)
		var th := lerpf(0.6, thick, u * u)
		outer.append(Vector2.from_angle(ang) * radius)
		inner.append(Vector2.from_angle(ang) * (radius - th))
	inner.reverse()
	var poly := outer + inner
	draw_colored_polygon(poly, col)


# --------------------------------------------------------------------------- Trait de lumière
func _draw_trait() -> void:
	var hand := dir * 6.0
	if _t < 0.09:                                       # la lumière se rassemble dans la paume
		var k := _t / 0.09
		for i in 6:
			var ang := i * TAU / 6.0 + _t * 9.0
			var p := hand + Vector2.from_angle(ang) * lerpf(11.0, 1.0, k)
			draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(GOLD, 0.4 + 0.6 * k))
		draw_circle(hand, 1.0 + 2.5 * k, Color(CREAM, 0.5 + 0.5 * k))
		return
	var t := _t - 0.09
	var s := minf(t * 650.0, reach)                      # le trait file
	var arrived := s >= reach
	var tail := maxf(0.0, s - 30.0) if not arrived else minf(reach, (t - reach / 650.0) * 400.0 + maxf(0.0, reach - 30.0))
	var fade := 1.0
	if arrived:
		fade = clampf(1.0 - (t - reach / 650.0) / 0.2, 0.0, 1.0)
	if tail < s:
		draw_line(dir * tail, dir * s, Color(OUTLINE, 0.35 * fade), 5.0)
		draw_line(dir * tail, dir * s, Color(GOLD, 0.9 * fade), 3.0)
		draw_line(dir * tail, dir * s, Color(CREAM, fade), 1.0)
	# grains laissés derrière, qui dérivent et s'éteignent
	var nrm := dir.orthogonal()
	for i in 10:
		var u := (i + 0.5) / 10.0 * reach
		if u > s:
			break
		var age := t - u / 650.0
		var al := clampf(1.0 - age / 0.3, 0.0, 1.0)
		if al > 0.0:
			var off := nrm * sin(i * 2.7) * (2.0 + age * 14.0) + Vector2(0, -age * 10.0)
			draw_rect(Rect2((dir * u + off).round(), Vector2(1, 1)), Color(GOLD, al))
	if not arrived:
		draw_circle(dir * s, 4.0, Color(GOLD, 0.35))
		draw_circle(dir * s, 2.0, CREAM)
	else:                                               # éclat en étoile au bout du trait
		var k2 := clampf((t - reach / 650.0) / 0.2, 0.0, 1.0)
		draw_circle(dir * reach, 7.0 * (1.0 - k2) + 2.0, Color(GOLD, 0.45 * (1.0 - k2)))
		draw_circle(dir * reach, 3.0 * (1.0 - k2) + 1.0, Color(CREAM, 1.0 - k2))
		_star(dir * reach, (7.0 if hit else 4.0) + k2 * (10.0 if hit else 5.0), Color(CREAM, 1.0 - k2))


# --------------------------------------------------------------------------- Croc doré
## Deux mâchoires de part et d'autre du point de morsure, qui se referment en 0,08 s.
func _draw_croc() -> void:
	var r := float(area.get("range", 26))
	var c := dir * r * 0.62 + Vector2(0, -6)                 # à hauteur du corps, pas des pattes
	var n := dir.orthogonal()
	var close := clampf(_t / 0.08, 0.0, 1.0)
	var fade := clampf(1.0 - (_t - 0.1) / 0.16, 0.0, 1.0)
	var gap := lerpf(15.0, 2.0, ease(close, 0.4))
	for side in [-1.0, 1.0]:
		var jc: Vector2 = c + n * gap * side                  # centre de la mâchoire
		var face: Vector2 = -n * float(side)                   # elle mord vers le centre
		var a: float = face.angle()
		draw_arc(jc + face * -4.0, 10.0, a - 1.15, a + 1.15, 12, Color(OUTLINE, 0.7 * fade), 5.0)
		draw_arc(jc + face * -4.0, 10.0, a - 1.15, a + 1.15, 12, Color(AMBER, fade), 3.0)
		draw_arc(jc + face * -4.0, 9.0, a - 0.8, a + 0.8, 10, Color(CREAM, 0.85 * fade), 1.0)
		for k in 4:                                            # crocs
			var along := (k - 1.5) * 4.5
			var base: Vector2 = jc + face * -4.0 + Vector2.from_angle(a + along / 10.0) * 8.5
			var tip: Vector2 = base + face * 4.5
			var w: Vector2 = Vector2.from_angle(a + along / 10.0).orthogonal() * 1.4
			draw_colored_polygon(PackedVector2Array([base - w, base + w, tip]), Color(CREAM, fade))
	if close >= 1.0:
		var k2 := clampf((_t - 0.08) / 0.14, 0.0, 1.0)
		_star(c, 3.0 + k2 * 6.0, Color(CREAM, 1.0 - k2))
		draw_circle(c, 2.0 * (1.0 - k2) + 0.5, Color(AMBER, 1.0 - k2))


# --------------------------------------------------------------------------- Premiers soins
## Lueur chaude au sol, bande de lin qui s'enroule autour du corps puis se dissipe en grains.
func _draw_soins() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	var glow_a := sin(k * PI) * 0.5
	var rr := 5.0 + 8.0 * minf(1.0, k * 2.0)
	_ellipse(Vector2(0, 0), rr, rr * 0.4, Color(WARM, glow_a))
	_ellipse(Vector2(0, 0), rr * 0.6, rr * 0.24, Color(CREAM, glow_a))
	var wrap := clampf(_t / 0.55, 0.0, 1.0)                  # la bande s'enroule…
	var gone := clampf((_t - 0.6) / 0.35, 0.0, 1.0)            # … puis se dissipe d'en bas
	var N := 34
	for i in N:
		var u := float(i) / N
		if u > wrap or u < gone:
			continue
		var ang := u * TAU * 2.3 + _t * 2.5
		var p := Vector2(cos(ang) * 7.5, -3.0 - u * 19.0 + sin(ang) * 1.5)
		var front := sin(ang) > 0.0
		var al := 1.0 if front else 0.3
		if front:
			draw_rect(Rect2(p.round() + Vector2(-1, 1), Vector2(3, 1)), Color(LINEN_SEAM, al))
		draw_rect(Rect2(p.round() - Vector2(1, 0), Vector2(3, 1)), Color(LINEN, al))
	if _t > 0.5:                                              # le souffle revient : grains qui montent
		for i in 9:
			var st := 0.5 + i * 0.05
			var age := _t - st
			if age < 0.0:
				continue
			var al2 := clampf(1.0 - age / 0.45, 0.0, 1.0)
			var p2 := Vector2(sin(i * 2.1) * 7.0, -6.0 - fmod(i * 5.3, 12.0) - age * 22.0)
			draw_rect(Rect2(p2.round(), Vector2(1, 1)), Color(LEAF if i % 2 else WARM, al2))


# --------------------------------------------------------------------------- outils
func _star(p: Vector2, size: float, col: Color) -> void:
	if col.a <= 0.0:
		return
	for a in [0.0, PI / 2.0]:
		var v := Vector2.from_angle(a) * size
		draw_line(p - v, p + v, col, 1.0)
	for a in [PI / 4.0, 3.0 * PI / 4.0]:
		var v2 := Vector2.from_angle(a) * size * 0.5
		draw_line(p - v2, p + v2, col, 1.0)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	if col.a <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

# =========================================================================== communes (suite)
# --------------------------------------------------------------------------- Coup puissant
## Élan trop long (0,18 s) : un arc fantôme derrière, un éclat qui grossit ; puis le coup, énorme.
func _draw_coup_puissant() -> void:
	var a := dir.angle()
	if _t < 0.18:
		var k := _t / 0.18
		draw_arc(Vector2.ZERO, 13.0, a + PI - 0.7, a + PI + 0.7 * k, 10, Color(CREAM, 0.45 * k), 1.0)
		_star(dir.rotated(-2.3) * 12.0, 1.5 + k * 4.5, Color(CREAM, 0.6 + 0.4 * k))
		return
	var tt := _t - 0.18
	var r := float(area.get("range", 30))
	var half := deg_to_rad(float(area.get("angle", 130)) / 2.0)
	var k2 := clampf(tt / 0.12, 0.0, 1.0)
	var fade := clampf(1.0 - (tt - 0.12) / 0.28, 0.0, 1.0)
	var a1 := lerpf(a - half, a + half, ease(k2, 0.45))
	var tail := maxf(a - half, a1 - half * 1.7)
	_crescent(tail, a1, r * 1.02, 12.0, Color(OUTLINE, 0.65 * fade))
	_crescent(tail, a1, r * 0.97, 10.0, Color(GOLD, fade))
	_crescent(tail, a1, r * 0.97, 4.0, Color(CREAM, fade))
	if k2 >= 1.0:
		var t3 := tt - 0.12
		var tip := Vector2.from_angle(a + half * 0.5) * r * 0.85
		_star(tip, 5.0 + t3 * 60.0, Color(CREAM, fade))
		draw_arc(dir * r * 0.7, 4.0 + t3 * 70.0, 0, TAU, 20, Color(CREAM, 0.8 * fade), 2.0)


# --------------------------------------------------------------------------- Éclat d'aube
func _draw_eclat() -> void:
	var hand := dir * 7.0
	if _t < 0.14:                                       # la lumière se concentre dans la paume
		var k := _t / 0.14
		for i in 8:
			var ang := i * TAU / 8.0 + _t * 12.0
			var p := hand + Vector2.from_angle(ang) * lerpf(16.0, 2.0, k)
			draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(GOLD, 0.3 + 0.7 * k))
		for i in 4:
			var v := Vector2.from_angle(i * PI / 2.0 + _t * 20.0) * (3.0 + 5.0 * k)
			draw_line(hand, hand + v, Color(CREAM, 0.5 * k), 1.0)
		draw_circle(hand, 1.0 + 4.0 * k, Color(GOLD, 0.5))
		draw_circle(hand, 0.5 + 2.5 * k, CREAM)
		return
	var t := _t - 0.14
	var speed := 480.0
	var s := minf(t * speed, reach)
	if s < reach:
		draw_line(dir * maxf(0.0, s - 26.0), dir * s, Color(GOLD, 0.45), 8.0)
		draw_line(dir * maxf(0.0, s - 18.0), dir * s, Color(CREAM, 0.9), 3.0)
		draw_circle(dir * s, 8.0, Color(GOLD, 0.3))
		draw_circle(dir * s, 5.0, GOLD)
		draw_circle(dir * s, 3.0, CREAM)
		return
	var ta := t - reach / speed                          # l'éclat éclate contre l'ennemi
	var c := dir * reach
	var f := clampf(1.0 - ta / 0.32, 0.0, 1.0)
	draw_circle(c, 11.0 * clampf(1.0 - ta / 0.12, 0.0, 1.0), Color(CREAM, 0.9))
	draw_arc(c, 4.0 + ta * 70.0, 0, TAU, 24, Color(GOLD, f), 2.0)
	draw_arc(c, 2.0 + ta * 45.0, 0, TAU, 20, Color(CREAM, f * 0.8), 1.0)
	for i in 8:
		var v2 := Vector2.from_angle(i * TAU / 8.0 + 0.2)
		draw_line(c + v2 * (4.0 + ta * 30.0), c + v2 * (8.0 + ta * 55.0), Color(CREAM, f), 1.0)


# --------------------------------------------------------------------------- Lame d'aube
## L'arme balaie, suivie de reflets dorés (des copies d'elle-même qui s'éteignent) et de grains.
func _draw_lame() -> void:
	var r := float(area.get("range", 30))
	var half := deg_to_rad(float(area.get("angle", 120)) / 2.0)
	var a := dir.angle()
	var k := clampf(_t / 0.16, 0.0, 1.0)
	var fade := clampf(1.0 - (_t - 0.14) / 0.26, 0.0, 1.0)
	var cur := lerpf(a - half, a + half, ease(k, 0.5))
	var from := maxf(a - half, cur - 1.4)
	if cur - from > 0.02:
		draw_arc(Vector2.ZERO, r * 0.8, from, cur, 14, Color(GOLD, 0.32 * fade), 9.0)
		draw_arc(Vector2.ZERO, r * 0.85, from, cur, 14, Color(CREAM, fade), 2.0)
	for g in 4:
		var ang := cur - g * 0.24
		if ang < a - half:
			continue
		var al := (1.0 - g * 0.24) * fade
		draw_set_transform(Vector2.from_angle(ang) * r * 0.55, ang + PI / 4.0, Vector2.ONE)
		if tex:
			draw_texture(tex, Vector2(-8, -8), Color(1.0, 0.95, 0.7, al) if g > 0 else Color(1, 1, 1, al))
		else:
			draw_line(Vector2(-6, 6), Vector2(6, -6), Color(CREAM, al), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 8:                                          # grains laissés sur le passage de la lame
		var ai := lerpf(a - half, a + half, i / 7.0)
		if ai > cur:
			break
		var pass_t := _t - (float(i) / 7.0) * 0.16
		var al2 := clampf(1.0 - pass_t / 0.35, 0.0, 1.0)
		var p := Vector2.from_angle(ai) * r * (0.7 + 0.1 * sin(i * 3.0)) + Vector2(0, -pass_t * 18.0)
		draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(GOLD, al2))


# --------------------------------------------------------------------------- Carapace des galets
const PEBBLES := [[-170.0, 1.0], [-140.0, 0.9], [-112.0, 1.05], [-90.0, 1.0], [-68.0, 1.05], [-40.0, 0.9], [-10.0, 1.0]]


func _pebble_pos(i: int) -> Vector2:
	var ang := deg_to_rad(float(PEBBLES[i][0]))
	return Vector2(0, -11) + Vector2(cos(ang) * 12.0, sin(ang) * 14.0) * float(PEBBLES[i][1])


## Des galets arrivent de l'extérieur et se referment en dôme autour de soi, puis un éclat les soude.
func _draw_carapace() -> void:
	for i in PEBBLES.size():
		var st := i * 0.035
		var k := clampf((_t - st) / 0.12, 0.0, 1.0)
		if k <= 0.0:
			continue
		var p := _pebble_pos(i)
		var from := Vector2(0, -11) + (p - Vector2(0, -11)) * 1.9 + Vector2(0, -6)
		var q := from.lerp(p, ease(k, 0.4))
		var fade := clampf(1.0 - (_t - 0.42) / 0.18, 0.0, 1.0)
		_ellipse(q, 4.2, 3.2, Color(OUTLINE, 0.8 * fade))
		_ellipse(q, 3.5, 2.5, Color(STONE, fade))
		draw_rect(Rect2((q + Vector2(-1, -1)).round(), Vector2(1, 1)), Color(CREAM, 0.8 * fade))
	if _t > 0.3:
		var f := clampf(1.0 - (_t - 0.3) / 0.3, 0.0, 1.0)
		draw_arc(Vector2(0, -10), 13.0, PI + 0.1, TAU - 0.1, 18, Color(CREAM, f), 2.0)


## Tant que le bouclier tient : un dôme à peine visible, deux reflets, et il s'éclaire quand un coup y glisse.
func _draw_linger_carapace() -> void:
	var al := (0.2 + 0.07 * sin(_t * 3.0)) * (1.0 - clampf(_gone, 0.0, 1.0)) + _flash_t * 4.0
	draw_arc(Vector2(0, -10), 13.0, PI + 0.1, TAU - 0.1, 18, Color(STONE.lightened(0.3), minf(al, 1.0)), 1.0)
	for i in 3:
		var p := _pebble_pos(i * 3)
		draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(CREAM, minf(al * 1.6, 1.0)))
	var g := fmod(_t * 0.6, 1.0)
	var ang := lerpf(PI + 0.2, TAU - 0.2, g)
	draw_rect(Rect2((Vector2(0, -10) + Vector2.from_angle(ang) * 13.0).round(), Vector2(1, 1)), Color(CREAM, minf(al * 2.5, 1.0)))


# =========================================================================== peu communes
# --------------------------------------------------------------------------- Bond du lynx
## Deux griffures croisées de trois traits, l'une après l'autre (le lynx frappe des deux pattes).
func _draw_lynx() -> void:
	var fade := clampf(1.0 - (_t - 0.16) / 0.2, 0.0, 1.0)
	for set_i in 2:
		var st := set_i * 0.07
		var k := clampf((_t - st) / 0.07, 0.0, 1.0)
		if k <= 0.0:
			continue
		var v := dir.rotated(1.0 if set_i == 0 else -1.0)
		var n := v.orthogonal()
		for j in 3:
			var off := n * (j - 1) * 3.5
			var a0 := -v * 10.0 + off
			var a1 := a0 + v * 20.0 * ease(k, 0.4)
			draw_line(a0, a1, Color(OUTLINE, 0.6 * fade), 3.0)
			draw_line(a0, a1, Color(PALE, fade), 1.5)
	if _t > 0.14:
		_star(Vector2.ZERO, 3.0 + (_t - 0.14) * 40.0, Color(CREAM, fade))


# --------------------------------------------------------------------------- Chant du fond
## Ondes qui partent en avant comme un son sourd ; des gouttes montent au lieu de tomber.
func _draw_chant() -> void:
	var a := dir.angle()
	for i in 4:
		var tt := _t - i * 0.12
		if tt < 0.0 or tt > 0.6:
			continue
		var rr := 6.0 + tt * 62.0
		var al := (1.0 - tt / 0.6) * 0.85
		draw_arc(Vector2.ZERO, rr, a - 0.95, a + 0.95, 18, Color(WATER_PALE, al), 2.0)
		draw_arc(Vector2.ZERO, rr - 2.5, a - 0.8, a + 0.8, 16, Color(WATER, al * 0.6), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var nrm := dir.orthogonal()
	for i in 14:
		var st := 0.1 + i * 0.04
		var along := rng.randf_range(6.0, 34.0)
		var side := rng.randf_range(-12.0, 12.0)
		var sp := rng.randf_range(16.0, 30.0)
		var tt2 := _t - st
		if tt2 < 0.0:
			continue
		var al2 := clampf(1.0 - tt2 / 0.55, 0.0, 1.0)
		var p := dir * along + nrm * side + Vector2(0, 8.0 - tt2 * sp)
		draw_rect(Rect2(p.round(), Vector2(1, 2)), Color(WATER_PALE, al2))


func _draw_chant_sol() -> void:
	for i in 2:
		var tt := _t - i * 0.25
		if tt < 0.0 or tt > 0.8:
			continue
		var rx := 4.0 + tt * 36.0
		_ellipse_ring(Vector2.ZERO, rx, rx * 0.4, Color(WATER_PALE, (1.0 - tt / 0.8) * 0.6), 1.0)


## Bête ralentie : des ronds dans l'eau à ses pieds, quelques gouttes qui montent.
func _draw_linger_chant() -> void:
	var g := 1.0 - clampf(_gone, 0.0, 1.0)
	var ph := fmod(_t, 1.3) / 1.3
	var rx := 4.0 + ph * 11.0
	_ellipse_ring(Vector2(0, 1), rx, rx * 0.4, Color(WATER_PALE, (1.0 - ph) * 0.6 * g), 1.0)
	for i in 2:
		var ph2 := fmod(_t * 0.7 + i * 0.5, 1.0)
		var p := Vector2(-4.0 + i * 8.0, -2.0 - ph2 * 14.0)
		draw_rect(Rect2(p.round(), Vector2(1, 2)), Color(WATER_PALE, (1.0 - ph2) * 0.7 * g))


# --------------------------------------------------------------------------- Estoc runique
func _draw_estoc() -> void:
	var tip0 := dir * 9.0
	if _t < 0.11:                                       # la rune s'allume au bout de la lame
		_rune(tip0, 4.0, _t / 0.09, Color(RUNE, 1.0))
		draw_circle(tip0, 6.0, Color(RUNE, 0.18))
		return
	var tt := _t - 0.11
	var head := dir * lerpf(9.0, 30.0, clampf(tt / 0.05, 0.0, 1.0))
	var fade := clampf(1.0 - (tt - 0.06) / 0.2, 0.0, 1.0)
	draw_line(dir * 6.0, head, Color(RUNE_DARK, 0.6 * fade), 4.0)
	draw_line(dir * 6.0, head, Color(CREAM, fade), 1.0)
	if tt < 0.06:
		_rune(head, 4.0, 1.0, RUNE)
		return
	var ts := tt - 0.06                                 # la rune éclate en éclats cyan
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 9:
		var v := Vector2.from_angle(i * TAU / 9.0 + rng.randf() * 0.5)
		var p := head + v * (2.0 + ts * rng.randf_range(40.0, 70.0))
		var al := clampf(1.0 - ts / 0.3, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([p + v * 2.0, p + v.orthogonal() * 1.0, p - v.orthogonal() * 1.0]), Color(RUNE, al))
	_star(head, 3.0 + ts * 30.0, Color(CREAM, clampf(1.0 - ts / 0.2, 0.0, 1.0)))


# --------------------------------------------------------------------------- Rune de rupture
const RUPTURE_GLYPH := [[Vector2(0, -6), Vector2(0, 6)], [Vector2(-5, -3), Vector2(4, 4)], [Vector2(-4, 1), Vector2(5, 1)],
	[Vector2(3, -5), Vector2(-2, -1)]]


## La rune se trace sur la bête (cercle, puis quatre traits), se fend, et la pierre tombe en éclats.
func _draw_rupture() -> void:
	var fade := clampf(1.0 - (_t - 0.6) / 0.25, 0.0, 1.0)
	var kc := clampf(_t / 0.28, 0.0, 1.0)
	draw_arc(Vector2.ZERO, 10.0, -PI / 2.0, -PI / 2.0 + TAU * kc, 24, Color(RUNE, 0.25 * fade), 4.0)
	draw_arc(Vector2.ZERO, 10.0, -PI / 2.0, -PI / 2.0 + TAU * kc, 24, Color(RUNE, fade), 1.5)
	for i in RUPTURE_GLYPH.size():
		var k := clampf((_t - 0.28 - i * 0.04) / 0.04, 0.0, 1.0)
		if k <= 0.0:
			continue
		var seg: Array = RUPTURE_GLYPH[i]
		var p0: Vector2 = seg[0]
		var p1: Vector2 = seg[1]
		draw_line(p0, p0.lerp(p1, k), Color(RUNE, fade), 1.5)
	if _t > 0.45:                                       # elle se fend comme une pierre trop vieille
		var kk := clampf((_t - 0.45) / 0.12, 0.0, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		for i in 7:
			var ang := i * TAU / 7.0 + rng.randf() * 0.6
			var pts := PackedVector2Array([Vector2.ZERO])
			var p := Vector2.ZERO
			for j in 3:
				p += Vector2.from_angle(ang + rng.randf_range(-0.5, 0.5)) * 5.0 * kk
				pts.append(p)
			draw_polyline(pts, Color(CREAM.lerp(RUNE, kk), fade), 1.0)
		draw_circle(Vector2.ZERO, 12.0 * clampf(1.0 - (_t - 0.45) / 0.1, 0.0, 1.0), Color(CREAM, 0.7))
	if _t > 0.5:                                        # éclats de pierre
		var tf := _t - 0.5
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = seed + 7
		for i in 10:
			var vx := rng2.randf_range(-30.0, 30.0)
			var vy := rng2.randf_range(-40.0, -10.0)
			var p2 := Vector2(rng2.randf_range(-6, 6), rng2.randf_range(-6, 6)) + Vector2(vx * tf, vy * tf + 160.0 * tf * tf)
			draw_rect(Rect2(p2.round(), Vector2(2, 1) if i % 2 else Vector2(1, 2)), Color(STONE if i % 3 else STONE_DARK, clampf(1.0 - tf / 0.45, 0.0, 1.0)))


## Défenses fendues : une petite rune fêlée flotte au-dessus de la bête, une miette de pierre tombe parfois.
func _draw_linger_rupture() -> void:
	var g := 1.0 - clampf(_gone, 0.0, 1.0)
	var c := Vector2(0, -14)
	var al := (0.55 + 0.2 * sin(_t * 4.0)) * g
	draw_arc(c, 4.0, 0, TAU, 14, Color(RUNE, al), 1.0)
	draw_polyline(PackedVector2Array([c + Vector2(-2, -3), c + Vector2(0, -1), c + Vector2(-1, 1), c + Vector2(1, 3)]), Color(CREAM, al), 1.0)
	var ph := fmod(_t, 2.4) / 2.4
	if ph < 0.4:
		draw_rect(Rect2((c + Vector2(2, 4 + ph * 30.0)).round(), Vector2(1, 1)), Color(STONE, (1.0 - ph / 0.4) * g))


# --------------------------------------------------------------------------- Rune tranchante
## La rune s'allume sur l'arme, puis un arc de bronze, suivi d'un éclair qui crépite sur son bord.
func _draw_tranchante() -> void:
	var hand := dir * 6.0
	if _t < 0.07:
		_rune(hand, 3.5, 1.0, Color(RUNE, 1.0 - _t / 0.07 * 0.3))
		draw_circle(hand, 5.0, Color(RUNE, 0.25))
	var tt := _t - 0.05
	if tt < 0.0:
		return
	var r := float(area.get("range", 24)) + 2.0
	var half := deg_to_rad(float(area.get("angle", 80)) / 2.0 + 10.0)
	var a := dir.angle()
	var k := clampf(tt / 0.1, 0.0, 1.0)
	var fade := clampf(1.0 - (tt - 0.1) / 0.25, 0.0, 1.0)
	var a1 := lerpf(a - half, a + half, ease(k, 0.5))
	var tail := maxf(a - half, a1 - half * 1.6)
	_crescent(tail, a1, r, 8.0, Color(OUTLINE, 0.6 * fade))
	_crescent(tail, a1, r * 0.96, 6.5, Color(BRONZE, fade))
	_crescent(tail, a1, r * 0.96, 2.0, Color(CREAM, fade))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + int(_t * 30.0)                     # l'éclair crépite (change toutes les 0,03 s)
	var pts := PackedVector2Array()
	for i in 8:
		var ang := lerpf(tail, a1, i / 7.0)
		pts.append(Vector2.from_angle(ang) * (r * 0.96 + rng.randf_range(-3.5, 3.5)))
	if a1 - tail > 0.05:
		draw_polyline(pts, Color(RUNE, fade), 1.0)
	if k >= 1.0 and tt < 0.22:
		var tip := Vector2.from_angle(a1) * r * 0.96
		for b in 2:
			var p := tip
			var bp := PackedVector2Array([p])
			for j in 3:
				p += Vector2.from_angle(a1 + (0.6 if b == 0 else -0.6) + rng.randf_range(-0.6, 0.6)) * 4.0
				bp.append(p)
			draw_polyline(bp, Color(CREAM, fade), 1.0)


# --------------------------------------------------------------------------- Secousse du colosse
## Au sol : un cercle qui se resserre pendant qu'on se dresse, puis l'onde de choc quand on s'abat.
func _draw_secousse() -> void:
	var g := Vector2(0, 8)                               # le sol, sous le point d'impact
	if _t < 0.33:
		var k := _t / 0.33
		var rx := lerpf(26.0, 6.0, k)
		_ellipse_ring(g, rx, rx * 0.42, Color(DIRT.darkened(0.3), 0.5 * k), 1.0)
		return
	var tt := _t - 0.33
	for i in 2:
		var t2 := tt - i * 0.08
		if t2 < 0.0 or t2 > 0.5:
			continue
		var rx2 := 6.0 + t2 * 95.0
		var al := 1.0 - t2 / 0.5
		_ellipse_ring(g, rx2, rx2 * 0.42, Color(DIRT, al), 3.0)
		_ellipse_ring(g, rx2 - 2.0, (rx2 - 2.0) * 0.42, Color(CREAM, al * 0.8), 1.0)
	_ellipse(g, 20.0 * clampf(tt / 0.1, 0.0, 1.0), 7.0 * clampf(tt / 0.1, 0.0, 1.0), Color(DIRT, 0.35 * clampf(1.0 - tt / 0.6, 0.0, 1.0)))


func _draw_secousse_sol() -> void:
	_draw_cracks(Vector2.ZERO, 0.33, 9, 24.0, STONE_DARK)


# --------------------------------------------------------------------------- Sève des fougères
const FRONDS := [[Vector2(-11, 1), -112.0, 1.0], [Vector2(11, 1), -68.0, -1.0], [Vector2(-6, 4), -98.0, 1.0], [Vector2(7, 4), -82.0, -1.0]]


func _frond_points(i: int, prog: float) -> PackedVector2Array:
	var base: Vector2 = FRONDS[i][0]
	var ang := deg_to_rad(float(FRONDS[i][1]))
	var side: float = FRONDS[i][2]
	var pts := PackedVector2Array([base])
	var p := base
	var n := 10
	var curl := (1.0 - prog) * 6.0                       # la crosse se déroule
	for j in n:
		var u := float(j + 1) / n
		if u > maxf(prog, 0.15):
			break
		var th := ang + side * u * u * (0.5 + curl)
		p += Vector2.from_angle(th) * 1.9
		pts.append(p)
	return pts


## Des fougères dorées se déroulent autour de soi, puis leur sève remonte jusqu'aux blessures.
func _draw_seve() -> void:
	var fade := clampf(1.0 - (_t - 1.1) / 0.4, 0.0, 1.0)
	for i in FRONDS.size():
		var prog := clampf((_t - i * 0.08) / 0.5, 0.0, 1.0)
		if prog <= 0.0:
			continue
		var pts := _frond_points(i, prog)
		draw_polyline(pts, Color(OUTLINE, 0.55 * fade), 3.0)
		draw_polyline(pts, Color(AMBER, fade), 1.5)        # fougères dorées
		for j in range(1, pts.size(), 2):                # folioles
			var v := (pts[j] - pts[j - 1]).normalized().orthogonal() * (1.2 + j * 0.3)
			draw_line(pts[j] - v, pts[j] + v, Color(GOLD, fade), 1.0)
		if _t > 0.5 and _t < 1.2:                          # la sève monte vers le corps
			var tip: Vector2 = pts[pts.size() - 1]
			for dj in 3:
				var k := clampf((_t - 0.5 - dj * 0.1 - i * 0.04) / 0.35, 0.0, 1.0)
				if k <= 0.0 or k >= 1.0:
					continue
				var p := tip.lerp(Vector2(0, -10), ease(k, 0.5)) + Vector2(sin(k * 6.0 + i) * 2.0, 0)
				draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(AMBER.lerp(FERN, 0.45), 1.0 - k * 0.3))
	if _t > 0.8:
		var g := clampf(sin((_t - 0.8) / 0.6 * PI), 0.0, 1.0)
		_ellipse(Vector2(0, -10), 8.0, 11.0, Color(WARM, 0.25 * g))


# --------------------------------------------------------------------------- Toile dorée
func _bez(u: float) -> Vector2:
	var p0 := dir * 6.0
	var mid := (p0 + tpos) / 2.0 + dir.orthogonal() * 14.0
	return p0.lerp(mid, u).lerp(mid.lerp(tpos, u), u)


## Le fil part de la main en courbe, s'enroule autour de la bête, se noue en trois points brillants.
func _draw_toile() -> void:
	var fade := clampf(1.0 - (_t - 0.65) / 0.2, 0.0, 1.0)
	var kf := clampf(_t / 0.18, 0.0, 1.0)
	var thread_a := clampf(1.0 - (_t - 0.55) / 0.15, 0.0, 1.0)
	var pts := PackedVector2Array()
	for i in 13:
		var u := i / 12.0 * kf
		pts.append(_bez(u))
	draw_polyline(pts, Color(GOLD, 0.45 * thread_a), 4.0)
	draw_polyline(pts, Color(CREAM, thread_a), 1.5)
	if kf < 1.0:
		draw_circle(_bez(kf), 2.0, CREAM)
		return
	var kw := clampf((_t - 0.18) / 0.35, 0.0, 1.0)       # il s'enroule
	var N := 30
	for i in N:
		var u2 := float(i) / N
		if u2 > kw:
			break
		var ang := u2 * TAU * 2.6
		var p := tpos + Vector2(cos(ang) * 8.0, 6.0 - u2 * 15.0 + sin(ang) * 2.0)
		var front := sin(ang) > 0.0
		draw_rect(Rect2(p.round() - Vector2(1, 0), Vector2(2, 2) if front else Vector2(2, 1)), Color(CREAM if front else GOLD, (1.0 if front else 0.5) * fade))
	if _t > 0.5:
		for j in 3:
			var kp := tpos + Vector2(-5.0 + j * 5.0, -6.0 + (j % 2) * 7.0)
			_star(kp, 1.5 + (_t - 0.5) * 8.0, Color(CREAM, fade))


## Bête entravée : trois fils dorés en travers, une lueur qui court dessus.
func _draw_linger_toile() -> void:
	var g := (1.0 - clampf(_gone, 0.0, 1.0)) * 0.7
	var strands := [[Vector2(-8, -6), Vector2(7, 4)], [Vector2(-7, 3), Vector2(8, -5)], [Vector2(-9, -1), Vector2(9, 0)]]
	for i in strands.size():
		var s: Array = strands[i]
		var a0: Vector2 = s[0]
		var a1: Vector2 = s[1]
		draw_line(a0, a1, Color(GOLD, g), 1.0)
		var ph := fmod(_t * 0.8 + i * 0.33, 1.0)
		draw_rect(Rect2(a0.lerp(a1, ph).round(), Vector2(1, 1)), Color(CREAM, g * 1.8))


# =========================================================================== rares
# --------------------------------------------------------------------------- Lame des consignes
## Le cercle des consignes se trace autour de soi et bat trois temps ; au quatrième, il se resserre
## dans la lame : une coupe nette à travers la cible, puis ses fragments tournent et se dispersent.
func _draw_consignes() -> void:
	var R := 18.0
	var rot := _t * 0.9
	if _t < 0.45:
		var kd := clampf(_t / 0.12, 0.0, 1.0)
		draw_arc(Vector2.ZERO, R, rot, rot + TAU * kd, 32, Color(RUNE, 0.8), 1.0)
		for i in 12:
			if float(i) / 12.0 > kd:
				break
			var v := Vector2.from_angle(rot + i * TAU / 12.0)
			draw_line(v * (R - 2.0), v * (R + 2.0), Color(RUNE, 0.9), 1.0)
		for b in 3:                                    # trois temps
			var tb := _t - b * 0.15
			if tb < 0.0:
				continue
			var a0 := rot + b * TAU / 3.0
			draw_arc(Vector2.ZERO, R, a0, a0 + TAU / 3.0, 12, Color(CREAM, clampf(1.0 - tb / 0.5, 0.35, 1.0)), 2.5)
			if tb < 0.14:
				draw_arc(Vector2.ZERO, R + tb * 70.0, 0, TAU, 28, Color(RUNE, 1.0 - tb / 0.14), 1.0)
		return
	var tt := _t - 0.45
	if tt < 0.05:                                       # le cercle se resserre dans la lame
		var kc := tt / 0.05
		var c := (dir * 10.0) * kc
		draw_arc(c, lerpf(R, 1.0, kc), 0, TAU, 24, Color(CREAM, 1.0), 2.0)
		return
	var ts := tt - 0.05
	var v2 := dir.rotated(PI / 2.0 - 0.55)
	var kcut := clampf(ts / 0.04, 0.0, 1.0)
	var fade := clampf(1.0 - (ts - 0.08) / 0.3, 0.0, 1.0)
	var a := tpos - v2 * 22.0
	var b2 := a + v2 * 44.0 * kcut
	draw_line(a, b2, Color(RUNE, 0.45 * fade), 5.0)
	draw_line(a, b2, Color(CREAM, fade), 1.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 12:                                        # fragments de consignes
		var ang := i * TAU / 12.0 + ts * (9.0 - ts * 8.0)
		var rr := 10.0 + maxf(0.0, ts - 0.15) * 70.0
		var p := tpos + Vector2.from_angle(ang) * rr
		var al := clampf(1.0 - (ts - 0.15) / 0.35, 0.0, 1.0)
		var tv := Vector2.from_angle(ang) * 1.5
		draw_line(p - tv, p + tv, Color(RUNE, al), 1.0)


# --------------------------------------------------------------------------- Lumière figée
## Le temps ralentit (play), des grains de lumière apparaissent et s'arrêtent net autour de soi, puis
## se collent au corps en facettes : l'armure de lumière figée.
func _figee_mote(i: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + i * 13
	var ang := rng.randf() * TAU
	var far := Vector2(0, -12) + Vector2(cos(ang), sin(ang) * 1.2) * rng.randf_range(16.0, 26.0)
	var near := Vector2(0, -12) + Vector2(cos(ang) * 7.0, sin(ang) * 12.0)
	return [far, near]


func _draw_figee() -> void:
	for i in 18:
		var fn: Array = _figee_mote(i)
		var far: Vector2 = fn[0]
		var near: Vector2 = fn[1]
		var appear := clampf((_t - i * 0.003) / 0.06, 0.0, 1.0)
		var snap := clampf((_t - 0.2) / 0.15, 0.0, 1.0)
		var p := far.lerp(near, ease(snap, 2.4))
		var tw := 3 if int(_t * 30.0 + i) % 3 == 0 else 2
		var fade := clampf(1.0 - (_t - 0.5) / 0.8, 0.0, 1.0)
		if snap < 1.0:
			draw_rect(Rect2(p.round(), Vector2(tw, tw)), Color(CREAM if i % 2 else GOLD, appear))
		else:
			_diamond(p, 3.2, Color(GOLD, fade))
			_diamond(p, 1.8, Color(CREAM, fade))
	if _t > 0.35:
		var f := clampf(1.0 - (_t - 0.35) / 0.25, 0.0, 1.0)
		_ellipse(Vector2(0, -12), 9.0, 14.0, Color(CREAM, 0.55 * f))


## Armure de facettes (lumière figée) ou lueur d'aube (matin d'Halvard), tant que le bouclier tient.
func _draw_linger_facets() -> void:
	var g := 1.0 - clampf(_gone, 0.0, 1.0)
	var col := WARM if kind == "linger_halvard" else CREAM
	var glint := int(_t * 4.0) % 10
	for i in 10:
		var ang := i * TAU / 10.0 + 0.3
		var p := Vector2(0, -12) + Vector2(cos(ang) * 8.0, sin(ang) * 12.0)
		var al := (0.4 + 0.1 * sin(_t * 3.0 + i) + _flash_t * 4.0) * g
		_diamond(p, 2.6, Color(col, minf(al, 1.0)))
		if i == glint:
			_star(p, 2.0, Color(CREAM, 0.8 * g))


# =========================================================================== légendaire
# --------------------------------------------------------------------------- Verdict du Héraut
func _draw_verdict_halo() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	var a := sin(k * PI)
	_ellipse_ring(Vector2.ZERO, 7.0, 2.5, Color(GOLD, a), 1.5)
	for i in 5:
		var x := -6.0 + i * 3.0
		draw_line(Vector2(x, -2), Vector2(x * 1.4, -6.0 - 4.0 * a), Color(CREAM, a * 0.6), 1.0)


## Le cercle du Héraut se trace au sol, flambe quand la colonne tombe, puis reste brûlé un moment.
func _draw_verdict_sol() -> void:
	var rot := _t * 0.4
	var ko := clampf((_t - 0.1) / 0.4, 0.0, 1.0)
	var ki := clampf((_t - 0.25) / 0.3, 0.0, 1.0)
	if _t < 0.75:
		_ellipse_ring(Vector2.ZERO, 28.0, 12.0, Color(GOLD, 0.9), 1.5, rot, rot + TAU * ko)
		_ellipse_ring(Vector2.ZERO, 19.0, 8.0, Color(GOLD, 0.7), 1.0, -rot, -rot + TAU * ki)
		for i in 8:
			var kg := clampf((_t - 0.3 - i * 0.03) / 0.06, 0.0, 1.0)
			if kg <= 0.0:
				continue
			var ang := rot + i * TAU / 8.0
			var p := Vector2(cos(ang) * 28.0, sin(ang) * 12.0)
			_diamond(p, 2.5 * kg, Color(CREAM, kg))
			draw_line(p, p * 0.8, Color(GOLD, kg), 1.0)
		return
	var tt := _t - 0.75
	var flare := clampf(1.0 - tt / 0.45, 0.0, 1.0)
	var burn := clampf(1.0 - tt / 1.6, 0.0, 1.0)
	_ellipse(Vector2.ZERO, 28.0, 12.0, Color(GOLD, 0.3 * burn))
	_ellipse_ring(Vector2.ZERO, 28.0, 12.0, Color(CREAM, flare), 3.0)
	_ellipse_ring(Vector2.ZERO, 28.0, 12.0, Color(BRONZE, 0.6 * burn), 1.0)
	_ellipse_ring(Vector2.ZERO, 19.0, 8.0, Color(GOLD, 0.6 * burn), 1.0)


## La colonne de lumière tombe du ciel sur le cercle ; à l'impact : onde, rayons, plumes de lumière.
func _draw_verdict() -> void:
	if _t >= 0.45 and _t < 1.0:
		var kc := clampf((_t - 0.45) / 0.3, 0.0, 1.0)
		var head := lerpf(-240.0, 0.0, kc * kc)
		var after := clampf((_t - 0.75) / 0.25, 0.0, 1.0)
		var w := lerpf(18.0, 34.0, after)
		var al := 1.0 - after
		draw_rect(Rect2(-w / 2.0, -300.0, w, head + 300.0), Color(GOLD, 0.45 * al))
		draw_rect(Rect2(-w / 6.0, -300.0, w / 3.0, head + 300.0), Color(CREAM, 0.9 * al))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		for i in 10:
			var y := head - fmod(rng.randf() * 200.0 + _t * 300.0, 200.0)
			draw_rect(Rect2(rng.randf_range(-w / 2.0, w / 2.0), y, 1, 2), Color(CREAM, al))
	if _t < 0.75:
		return
	var tt := _t - 0.75
	for i in 2:
		var t2 := tt - i * 0.06
		if t2 < 0.0 or t2 > 0.55:
			continue
		var rx := 6.0 + t2 * 130.0
		_ellipse_ring(Vector2.ZERO, rx, rx * 0.45, Color(CREAM if i == 0 else GOLD, 1.0 - t2 / 0.55), 3.0 - i)
	var fr := clampf(1.0 - tt / 0.35, 0.0, 1.0)
	for i in 12:
		var v := Vector2.from_angle(i * TAU / 12.0)
		v.y *= 0.6
		draw_line(Vector2(0, -6) + v * (6.0 + tt * 40.0), Vector2(0, -6) + v * (14.0 + tt * 110.0), Color(CREAM, fr), 1.0)
	_star(Vector2(0, -8), 8.0 + tt * 40.0, Color(CREAM, fr))
	var rng2 := RandomNumberGenerator.new()                # plumes de lumière, lentes
	rng2.seed = seed + 3
	for i in 18:
		var st := 0.05 + rng2.randf() * 0.3
		var x0 := rng2.randf_range(-34.0, 34.0)
		var y0 := rng2.randf_range(-70.0, -20.0)
		var tf := tt - st
		if tf < 0.0:
			continue
		var al2 := clampf(1.0 - tf / 1.1, 0.0, 1.0)
		var p := Vector2(x0 + sin(tf * 4.0 + i) * 4.0, y0 + tf * 16.0)
		draw_rect(Rect2(p.round(), Vector2(2, 1) if i % 2 else Vector2(1, 2)), Color(GOLD if i % 3 else CREAM, al2))


# =========================================================================== passives
## Peau d'ambre : le coup s'enfonce dans une résine qui s'étire, puis se referme dessus.
func _draw_ambre() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	var out := clampf(_t / 0.12, 0.0, 1.0)
	var back := clampf((_t - 0.12) / 0.25, 0.0, 1.0)
	var r := lerpf(0.0, 7.0, ease(out, 0.4)) * (1.0 - 0.55 * back)
	var fade := 1.0 - clampf((_t - 0.35) / 0.15, 0.0, 1.0)
	for i in 8:
		var v := Vector2.from_angle(i * TAU / 8.0 + 0.3)
		draw_line(tpos, tpos + v * r, Color(AMBER, 0.8 * fade), 2.0)
		draw_circle(tpos + v * r, 1.2, Color(AMBER_DARK, fade))
	_ellipse(tpos, 3.0 + 2.0 * out, 3.0 + 2.0 * out, Color(AMBER, 0.6 * fade))
	_star(tpos, 2.0 * (1.0 - k), Color(CREAM, fade))


## Instinct de traqueuse : trois traits pâles, on a déjà bougé.
func _draw_instinct() -> void:
	var f := clampf(1.0 - _t / life, 0.0, 1.0)
	for i in 3:
		var y := -6.0 + i * 5.0
		var x := -4.0 - _t * 60.0
		draw_line(Vector2(x, y), Vector2(x - 8.0, y), Color(PALE, f), 1.0)


## Matin d'Halvard : une aube se lève derrière soi, et on tient encore un instant.
func _draw_halvard() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	var a := sin(k * PI)
	var pts := PackedVector2Array()
	for i in 13:
		var ang := PI + i * PI / 12.0
		pts.append(Vector2(0, -4) + Vector2(cos(ang) * 16.0, sin(ang) * 22.0 * minf(1.0, k * 3.0)))
	draw_colored_polygon(pts, Color(WARM, 0.5 * a))
	for i in 7:
		var ang2 := PI + (i + 0.5) * PI / 7.0
		var v := Vector2(cos(ang2), sin(ang2))
		draw_line(Vector2(0, -4) + v * 10.0, Vector2(0, -4) + v * (14.0 + 16.0 * a), Color(CREAM, 0.9 * a), 1.0)
	_ellipse_ring(Vector2.ZERO, 6.0 + k * 14.0, (6.0 + k * 14.0) * 0.4, Color(GOLD, 0.6 * (1.0 - k)), 1.0)


## Mains de ravaudeur : deux brins dorés se tressent entre les mains.
func _draw_mains() -> void:
	var k := clampf(_t / 0.4, 0.0, 1.0)
	var f := clampf(1.0 - (_t - 0.4) / 0.3, 0.0, 1.0)
	for s in 2:
		var pts := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			if u > k:
				break
			pts.append(Vector2(-7.0 + u * 14.0, sin(u * TAU * 1.5 + s * PI) * 2.0))
		if pts.size() > 1:
			draw_polyline(pts, Color(GOLD if s == 0 else AMBER, f), 1.0)


## Patience du pêcheur : des ronds dans l'eau à ses pieds, même sur l'herbe.
func _draw_patience() -> void:
	for i in 2:
		var tt := _t - i * 0.8
		if tt < 0.0 or tt > 1.2:
			continue
		var rx := 5.0 + tt * 20.0
		_ellipse_ring(Vector2.ZERO, rx, rx * 0.4, Color(CREAM, (1.0 - tt / 1.2) * 0.75), 1.0)
		_ellipse_ring(Vector2(0, 1), rx, rx * 0.4, Color(WATER, (1.0 - tt / 1.2) * 0.4), 1.0)


# --------------------------------------------------------------------------- outils (suite)
## Fissures au sol (aplaties), qui s'ouvrent après `delay` puis s'effacent.
func _draw_cracks(c: Vector2, delay: float, n: int, length: float, col: Color) -> void:
	if _t < delay:
		return
	var k := clampf((_t - delay) / 0.12, 0.0, 1.0)
	var fade := clampf(1.0 - (_t - delay - 0.3) / maxf(0.1, life - delay - 0.3), 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in n:
		var ang := dir.angle() + (float(i) / maxf(1.0, n - 1.0) - 0.5) * 3.6 + rng.randf_range(-0.2, 0.2)
		var p := c
		var pts := PackedVector2Array([p])
		for j in 3:
			var v := Vector2.from_angle(ang + rng.randf_range(-0.45, 0.45)) * length / 3.0 * k
			v.y *= 0.5
			p += v
			pts.append(p)
		draw_polyline(pts, Color(col, 0.8 * fade), 1.0)


## Petite rune : un cercle qui se trace, puis trois traits.
func _rune(c: Vector2, r: float, prog: float, col: Color) -> void:
	var k := clampf(prog, 0.0, 1.0)
	draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * minf(1.0, k / 0.6), 16, col, 1.0)
	if k > 0.6:
		var g := Color(col, col.a * (k - 0.6) / 0.4)
		draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), g, 1.0)
		draw_line(c + Vector2(-r * 0.5, -r * 0.2), c + Vector2(r * 0.4, r * 0.3), g, 1.0)


func _ellipse_ring(c: Vector2, rx: float, ry: float, col: Color, w: float, from := 0.0, to := TAU) -> void:
	if col.a <= 0.0 or to - from < 0.02:
		return
	var pts := PackedVector2Array()
	var n := 28
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w)


func _diamond(c: Vector2, s: float, col: Color) -> void:
	if col.a <= 0.0 or s <= 0.0:
		return
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, 0), c + Vector2(0, s), c + Vector2(-s * 0.7, 0)]), col)
