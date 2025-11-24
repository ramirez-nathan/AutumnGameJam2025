# carHitbox.gd
extends Node3D

func _ready() -> void:
	# Connect the hitbox signal when the car is created
	var hitbox: Area3D = $HitboxArea
	hitbox.body_entered.connect(_onHitboxBodyEntered)


func _onHitboxBodyEntered(body: Node3D) -> void:
	# Only react to the player
	if not body.is_in_group("player"):
		return

	# Ask the current scene (your World) to handle game over
	var world: Node = get_tree().current_scene
	if world != null and world.has_method("onPlayerDied"):
		world.onPlayerDied()
