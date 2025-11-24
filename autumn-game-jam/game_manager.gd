extends Node

# Current score (distance traveled)
@export var score: int = 0

# Tracks the farthest Z position the player has ever reached
var best_z: int = -2147483648  # INT_MIN

# A reference to the player node
var player: Node = null


func _process(delta: float) -> void:
	if player == null:
		return

	_update_score()


func register_player(p):
	print("REGISTERED PLAYER:", p)
	player = p
	score = 0
	best_z = player.gridZ

func _update_score():
	var current_z = player.gridZ
	print("gridZ =", current_z, " best_z =", best_z, " score =", score)

	if current_z > best_z:
		var delta = current_z - best_z
		score += delta
		best_z = current_z
