extends Area2D
## Sortie vers une zone voisine (connexion du Floor).
## `arrival` : point où le joueur apparaît dans CETTE zone quand il revient de `target_zone`.

signal exit_reached(target_zone: String, label: String)

@export var target_zone := ""
@export var label := ""
@export var arrival := Vector2.ZERO
## Sortie cachée : ni nom ni repère tant que la zone n'est pas débloquée
@export var secret := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		exit_reached.emit(target_zone, label)
