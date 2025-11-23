# player.gd
extends Node3D

@export var cellSize: float = 1.0       # must match World / lane cellSize
@export var moveDuration: float = 0.12  # seconds for one hop animation
@export var maxAbsGridX: int = 7        # player can move from -7 to +7 (15 tiles wide)

var gridX: int = 0
var gridZ: int = 0

var isMoving: bool = false
var moveTimer: float = 0.0
var startPos: Vector3
var targetPos: Vector3


func _ready() -> void:
	gridX = roundi(position.x / cellSize)
	gridZ = roundi(position.z / cellSize)
	position = Vector3(gridX * cellSize, position.y, gridZ * cellSize)


func _physics_process(delta: float) -> void:
	if isMoving:
		moveTimer += delta
		var t: float = min(moveTimer / moveDuration, 1.0)
		position = startPos.lerp(targetPos, t)

		if t >= 1.0:
			isMoving = false
		return

	var dx: int = 0
	var dz: int = 0

	if Input.is_action_just_pressed("move_forward"):
		dz += 1
	elif Input.is_action_just_pressed("move_back"):
		dz -= 1
	elif Input.is_action_just_pressed("move_left"):
		dx += 1     # flip signs if this still feels reversed
	elif Input.is_action_just_pressed("move_right"):
		dx -= 1

	if dx == 0 and dz == 0:
		return

	var newX: int = gridX + dx
	var newZ: int = gridZ + dz

	# 0. Horizontal clamp: don't allow leaving the center band
	if abs(newX) > maxAbsGridX:
		# Debug:
		# print("Blocked move: X out of band. newX=", newX)
		return

	var worldNode: Node = get_parent()

	# 1. Check lane window bounds (back/forward limits)
	if worldNode != null and worldNode.has_method("isLaneWithinBounds"):
		if not worldNode.isLaneWithinBounds(newZ):
			# Debug:
			# print("Blocked move: lane ", newZ, " outside playable window")
			return

	# 2. Check per-cell walkability (red blocks / ravine void)
	if worldNode != null and worldNode.has_method("isCellWalkable"):
		if not worldNode.isCellWalkable(newX, newZ):
			# Debug:
			# print("Blocked move: cell (", newX, ",", newZ, ") not walkable")
			return

	# Start the hop
	startPos = position
	targetPos = Vector3(newX * cellSize, position.y, newZ * cellSize)
	gridX = newX
	gridZ = newZ

	isMoving = true
	moveTimer = 0.0
