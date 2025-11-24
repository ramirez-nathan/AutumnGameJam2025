# roadLane.gd
extends Node3D

@export var numColumns: int = 30
@export var cellSize: float = 1.0
@export var groundHeight: float = 0.5
@export var obstacleChance: float = 0.2
@export var playableHalfWidth: int = 10    # should match Player.maxAbsGridX

var rng := RandomNumberGenerator.new()
var halfColumns: int = 0
var blockedColumns: Dictionary = {}      # xIndex -> true if blocked
var protectedColumns: Dictionary = {}    # xIndex -> true if should NEVER spawn obstacle
var obstacleNodes: Dictionary = {}       # xIndex -> Node3D for that obstacle


func _ready() -> void:
	rng.randomize()
	createRow()


func setProtectedColumns(columns: Array[int]) -> void:
	protectedColumns.clear()
	for x in columns:
		protectedColumns[int(x)] = true


func clearObstaclesAtColumns(columns: Array[int]) -> void:
	for x in columns:
		var key: int = int(x)
		if obstacleNodes.has(key):
			var node: Node3D = obstacleNodes[key]
			if is_instance_valid(node):
				node.queue_free()
			obstacleNodes.erase(key)
		if blockedColumns.has(key):
			blockedColumns.erase(key)


func createRow() -> void:
	halfColumns = numColumns / 2

	for col in range(numColumns):
		var xIndex: int = col - halfColumns
		createGroundCell(xIndex)

		if not protectedColumns.has(xIndex) and rng.randf() < obstacleChance:
			createObstacleAt(xIndex)


func createGroundCell(xIndex: int) -> void:
	var cell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(cellSize, groundHeight, cellSize)
	cell.mesh = box

	var mat := StandardMaterial3D.new()

	# Inside playable band = mid gray, outside = very dark gray
	if abs(xIndex) <= playableHalfWidth:
		mat.albedo_color = Color(0.4, 0.4, 0.4)   # main road
	else:
		mat.albedo_color = Color(0.1, 0.1, 0.1)   # dark shoulder / off-limits

	cell.set_surface_override_material(0, mat)

	cell.position = Vector3(float(xIndex) * cellSize, -groundHeight / 2.0, 0.0)
	add_child(cell)


func createObstacleAt(xIndex: int) -> void:
	# TEMP: simple box obstacle — replace this block with your own scene instantiate
	var obstacle := MeshInstance3D.new()
	var box := BoxMesh.new()

	var obstacleHeight: float = cellSize * 0.8
	box.size = Vector3(cellSize * 0.6, obstacleHeight, cellSize * 0.6)
	obstacle.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0)  # RED barrier
	obstacle.set_surface_override_material(0, mat)

	obstacle.position = Vector3(float(xIndex) * cellSize, obstacleHeight / 2.0, 0.0)
	add_child(obstacle)

	blockedColumns[xIndex] = true
	obstacleNodes[xIndex] = obstacle


func isCellWalkable(xIndex: int) -> bool:
	if abs(xIndex) > halfColumns:
		return false

	if blockedColumns.has(xIndex):
		return false

	return true
