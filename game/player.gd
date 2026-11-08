extends CharacterBody2D
## Joueur : clavier (flèches / ZQSD / WASD) ou toucher/clic pour se déplacer vers un point.

const SPEED := 80.0
const ARRIVE_DIST := 3.0

@onready var sprite: Sprite2D = $Sprite
@onready var camera: Camera2D = $Camera2D

var _target: Variant = null   # Vector2 ou null
var _anim_t := 0.0


func _ready() -> void:
	_add_keys("ui_up", [KEY_W, KEY_Z])
	_add_keys("ui_down", [KEY_S])
	_add_keys("ui_left", [KEY_A, KEY_Q])
	_add_keys("ui_right", [KEY_D])


func move_to(world_pos: Vector2) -> void:
	_target = world_pos


func stop() -> void:
	_target = null


func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		_target = null
	elif _target != null:
		var to: Vector2 = _target - global_position
		if to.length() > ARRIVE_DIST:
			dir = to.normalized()
		else:
			_target = null
	velocity = dir * SPEED
	move_and_slide()
	# coincé contre un obstacle en allant vers une cible : on abandonne
	if _target != null and get_real_velocity().length() < SPEED * 0.15 and get_slide_collision_count() > 0:
		_target = null
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0
	_animate(delta, dir != Vector2.ZERO)


func _animate(delta: float, moving: bool) -> void:
	_anim_t += delta * (8.0 if moving else 3.0)
	sprite.frame = int(_anim_t) % sprite.hframes


func _add_keys(action: StringName, keys: Array) -> void:
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
