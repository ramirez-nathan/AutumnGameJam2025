# forestLane.gd
extends Node3D

@export var numColumns: int = 30      # width of lane in tiles
@export var cellSize: float = 1.0
@export var groundHeight: float = 0.5
@export var obstacleChance: float = 0.3   # chance per cell for a red block
@export var playableHalfWidth: int = 7    # matches Player.maxAbsGridX

var rng := RandomNumberGenerator.new()
var halfColumns: int = 0
var blockedColumns: Dictionary = {}      # xIndex -> true if blocked
var protectedColumns: Dictionary = {}    # xIndex -> true if should NEVER spawn obstacle
var obstacleNodes: Dictionary = {}       # xIndex -> MeshInstance3D for that obstacle


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

	# Inside playable band = brighter green, outside = darker green
	if abs(xIndex) <= playableHalfWidth:
		mat.albedo_color = Color(0.1, 0.8, 0.1)   # bright playable area
	else:
		mat.albedo_color = Color(0.05, 0.3, 0.05) # darker "no-go" zone

	cell.set_surface_override_material(0, mat)

	cell.position = Vector3(float(xIndex) * cellSize, -groundHeight / 2.0, 0.0)
	add_child(cell)


func createObstacleAt(xIndex: int) -> void:
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()

	var obstacleHeight: float = cellSize * 0.8
	box.size = Vector3(cellSize * 0.6, obstacleHeight, cellSize * 0.6)
	block.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0)  # RED
	block.set_surface_override_material(0, mat)

	block.position = Vector3(float(xIndex) * cellSize, obstacleHeight / 2.0, 0.0)
	add_child(block)

	blockedColumns[xIndex] = true
	obstacleNodes[xIndex] = block


func isCellWalkable(xIndex: int) -> bool:
	if abs(xIndex) > halfColumns:
		return false

	if blockedColumns.has(xIndex):
		return false

	return true
