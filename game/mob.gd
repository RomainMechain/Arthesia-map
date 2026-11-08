extends "res://game/interactable.gd"
## Créature issue d'une Entry « monster » : erre autour de son point d'apparition (laisse).
## Tempérament : « shy » fuit le joueur qui s'approche, « watch » s'arrête et le fixe.
## Le combat viendra plus tard ; pour l'instant on peut l'observer (nom, niveau, description).

@export var leash := 48.0
@export var temper := "watch"
@export var speed := 22.0

const NOTICE_DIST := 56.0

var _home := Vector2.ZERO
var _goal := Vector2.ZERO
var _wait := 0.0
var _player: Node2D


func _ready() -> void:
	super()
	_home = position
	_goal = position
	_wait = randf_range(0.0, 2.5)
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	var moving := false
	var spd := speed
	var to_player := Vector2.INF
	if _player:
		to_player = _player.global_position - global_position
	if to_player.length() < NOTICE_DIST and temper == "shy":
		# fuit, sans sortir de sa zone
		var away := (-to_player).normalized() * leash * 0.8
		_goal = _clamp_leash(position + away)
		spd = speed * 2.4
		_wait = 0.0
	elif to_player.length() < NOTICE_DIST and temper == "watch":
		_wait = 0.6                                  # s'arrête et fixe le joueur
		if sprite:
			sprite.flip_h = to_player.x < 0.0
	if _wait > 0.0:
		_wait -= delta
	else:
		var d := _goal - position
		if d.length() < 1.5:
			_wait = randf_range(1.2, 3.5)
			_goal = _clamp_leash(_home + Vector2.from_angle(randf() * TAU) * randf() * leash)
		else:
			var step := d.normalized() * spd * delta
			position += step if step.length() < d.length() else d
			moving = true
			if sprite and absf(d.x) > 0.5:
				sprite.flip_h = d.x < 0.0
	if sprite:
		_anim_t += delta * (9.0 if moving else 2.5)
		# planche : 0-1 repos (1 = clignement, oreille, note figée), 2-5 cycle de déplacement
		sprite.frame = 2 + int(_anim_t) % 4 if moving else (1 if int(_anim_t) % 5 == 4 else 0)


func _clamp_leash(p: Vector2) -> Vector2:
	var off := p - _home
	return _home + off.limit_length(leash)
