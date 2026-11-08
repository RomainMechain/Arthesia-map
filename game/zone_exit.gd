extends Area2D
## Sortie vers une zone voisine (connexion du Floor). Le chargement de la zone cible
## viendra quand elle sera construite ; pour l'instant on l'annonce.

signal exit_reached(target_zone: String, label: String)

@export var target_zone := ""
@export var label := ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		exit_reached.emit(target_zone, label)
