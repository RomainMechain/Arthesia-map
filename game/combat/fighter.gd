class_name Fighter
extends RefCounted
## État de combat d'un combattant (joueur ou monstre) : stats de base, effets temporaires, bouclier,
## PV, mana, recharges. Les stats effectives sont toujours recalculées (jamais stockées).
## Aucun nœud ici : la même logique pourra tourner sur un serveur.

signal hp_changed(hp: float, max_hp: float)
signal died

var id := ""
var display_name := ""
var level := 1
var role := "normal"
var base: Dictionary = {}          # hp, atk, def, agi, int, sag (équipement et points compris)
var effects: Array = []            # {source, label, stat, percent, flat, expires_at}
var hp := 1.0
var mana := 0.0
var shield := 0.0
var shield_expires_at := -1.0
var cooldowns: Dictionary = {}     # id -> instant où c'est de nouveau prêt
var last_combat_at := -100.0
var rng := RandomNumberGenerator.new()


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func setup(stats: Dictionary, lvl: int, full := true) -> void:
	base = stats.duplicate()
	level = lvl
	if full:
		hp = max_hp()
		mana = max_mana()


func alive() -> bool:
	return hp > 0.0


func stat(s: String) -> float:
	return CombatRules.modified(float(base.get(s, 0.0)), effects, s)


func max_hp() -> float:
	return stat("hp")


func max_mana() -> float:
	return CombatRules.max_mana(stat("int"), level)


func in_combat(window := 6.0) -> bool:
	return now() - last_combat_at < window


# --- effets
func add_effect(source: String, label: String, s: String, duration: float, percent := 0.0, flat := 0.0) -> void:
	effects = effects.filter(func(e): return not (e.source == source and e.stat == s))
	effects.append({"source": source, "label": label, "stat": s, "percent": percent, "flat": flat,
		"expires_at": now() + duration, "duration": duration})


func tick(delta: float) -> void:
	var t := now()
	var before := effects.size()
	effects = effects.filter(func(e): return e.expires_at > t)
	if shield > 0.0 and shield_expires_at > 0.0 and shield_expires_at <= t:
		shield = 0.0
	if effects.size() != before:
		hp = minf(hp, max_hp())
		hp_changed.emit(hp, max_hp())
	mana = minf(max_mana(), mana + CombatRules.mana_regen(stat("sag"), level) * delta)


func ready(key: String) -> bool:
	return now() >= float(cooldowns.get(key, 0.0))


func remaining(key: String) -> float:
	return maxf(0.0, float(cooldowns.get(key, 0.0)) - now())


func start_cooldown(key: String, seconds: float) -> void:
	cooldowns[key] = now() + seconds


# --- encaisser / soigner
## Coup reçu : esquive, variance, critique, défense, puis bouclier et PV (damage_player / damage_monster).
func take_hit(raw: float, attacker: Fighter) -> Dictionary:
	var r := CombatRules.resolve_hit(raw, attacker.stat("agi"), attacker.level, stat("agi"), stat("def"), rng)
	var absorbed := minf(shield, r.damage)
	shield -= absorbed
	var final := snappedf(r.damage - absorbed, 0.1)
	hp = maxf(0.0, hp - final)
	last_combat_at = now()
	attacker.last_combat_at = now()
	r["final_damage"] = final
	r["absorbed"] = absorbed
	hp_changed.emit(hp, max_hp())
	if hp <= 0.0:
		died.emit()
	return r


func heal(amount: float) -> float:
	var before := hp
	hp = minf(max_hp(), hp + amount)
	hp_changed.emit(hp, max_hp())
	return hp - before


# --- dégâts bruts d'un coup (avant esquive / défense)
func basic_attack_raw() -> float:
	return CombatRules.BASIC_ATTACK_POWER * maxf(stat("atk"), stat("int"))


func skill_stat(damage_type: String) -> float:
	if damage_type == "hybrid":
		return CombatRules.HYBRID_STAT_FACTOR * minf(stat("atk"), stat("int"))
	return stat("int" if damage_type == "magical" else "atk")


## Coup de monstre : power x ATK (INT si magique).
func move_raw(move: Dictionary) -> float:
	return float(move.get("power", 0.0)) * stat("int" if move.get("damage_type") == "magical" else "atk")


func attack_cooldown() -> float:
	return CombatRules.basic_attack_cooldown(stat("agi"), level)
